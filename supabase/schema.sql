-- ============================================================
-- Connect Platform — Supabase Schema (Phase 1 MVP)
-- Supabase SQL Editor मध्ये हे संपूर्ण पेस्ट करून Run करा.
-- Supabase Auth (auth.users) आधीच अस्तित्वात आहे — त्याला जोडणारं
-- profiles टेबल इथे बनवतो.
-- ============================================================

-- 1) PROFILES (auth.users ला extend करतं — username, display_name इ.)
create table if not exists profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text unique not null,
  display_name text,
  avatar_url text,
  created_at timestamptz default now()
);

alter table profiles enable row level security;

drop policy if exists "Profiles सगळ्यांना दिसतील (username शोधण्यासाठी आवश्यक)" on profiles;
create policy "Profiles सगळ्यांना दिसतील (username शोधण्यासाठी आवश्यक)"
  on profiles for select using (true);

drop policy if exists "प्रत्येकजण फक्त स्वतःचा profile बदलू शकतो" on profiles;
create policy "प्रत्येकजण फक्त स्वतःचा profile बदलू शकतो"
  on profiles for update using (auth.uid() = id);

drop policy if exists "नवीन user स्वतःचा profile तयार करू शकतो" on profiles;
create policy "नवीन user स्वतःचा profile तयार करू शकतो"
  on profiles for insert with check (auth.uid() = id);

-- नवीन signup झाल्यावर आपोआप profile row तयार करणारा trigger
create or replace function handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, username, display_name)
  values (new.id, new.raw_user_meta_data->>'username', new.raw_user_meta_data->>'username');
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function handle_new_user();

-- 2) CONVERSATIONS

-- Helper function: RLS policies मध्ये self-recursion टाळण्यासाठी (SECURITY DEFINER RLS bypass करतो)
create or replace function is_conversation_member(conv_id uuid, uid uuid)
returns boolean
language sql
security definer
stable
as $$
  select exists (
    select 1 from conversation_members
    where conversation_id = conv_id and user_id = uid
  );
$$;

create table if not exists conversations (
  id uuid primary key default gen_random_uuid(),
  type text not null default 'direct', -- direct | group | channel
  name text,
  created_by uuid references profiles(id),
  created_at timestamptz default now()
);

-- आधीच table तयार असेल (जुन्या run मधून) तर column जोडतो
alter table conversations add column if not exists created_by uuid references profiles(id);

create table if not exists conversation_members (
  conversation_id uuid references conversations(id) on delete cascade,
  user_id uuid references profiles(id) on delete cascade,
  role text default 'member',
  joined_at timestamptz default now(),
  last_read_message_id uuid,
  primary key (conversation_id, user_id)
);

alter table conversations enable row level security;
alter table conversation_members enable row level security;

drop policy if exists "फक्त सभासद आपलं conversation बघू शकतात" on conversations;
create policy "फक्त सभासद आपलं conversation बघू शकतात"
  on conversations for select using (
    is_conversation_member(id, auth.uid()) or created_by = auth.uid()
  );

drop policy if exists "लॉगिन केलेला कोणीही नवीन conversation तयार करू शकतो" on conversations;
create policy "लॉगिन केलेला कोणीही नवीन conversation तयार करू शकतो"
  on conversations for insert with check (auth.uid() is not null);

drop policy if exists "सभासदांची यादी सभासदांनाच दिसते" on conversation_members;
create policy "सभासदांची यादी सभासदांनाच दिसते"
  on conversation_members for select using (
    is_conversation_member(conversation_id, auth.uid())
  );

drop policy if exists "स्वतःला/इतरांना सभासद म्हणून जोडता येतं (create flow साठी)" on conversation_members;
create policy "स्वतःला/इतरांना सभासद म्हणून जोडता येतं (create flow साठी)"
  on conversation_members for insert with check (auth.uid() is not null);

-- 3) MESSAGES
create table if not exists messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid references conversations(id) on delete cascade,
  sender_id uuid references profiles(id) on delete cascade,
  content text not null,
  reply_to uuid references messages(id),
  created_at timestamptz default now(),
  edited boolean default false,
  deleted boolean default false
);

alter table messages enable row level security;

drop policy if exists "फक्त त्या conversation चे सभासद मेसेज बघू शकतात" on messages;
create policy "फक्त त्या conversation चे सभासद मेसेज बघू शकतात"
  on messages for select using (
    is_conversation_member(messages.conversation_id, auth.uid())
  );

drop policy if exists "फक्त सभासदच मेसेज पाठवू शकतात, आणि स्वतःच्याच नावाने" on messages;
create policy "फक्त सभासदच मेसेज पाठवू शकतात, आणि स्वतःच्याच नावाने"
  on messages for insert with check (
    auth.uid() = sender_id
    and is_conversation_member(messages.conversation_id, auth.uid())
  );

-- 4) REPORTS (safety basics)
create table if not exists reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid references profiles(id),
  target_type text,
  target_id uuid,
  category text,
  status text default 'open',
  created_at timestamptz default now()
);

alter table reports enable row level security;

drop policy if exists "फक्त स्वतःचा report टाकता येतो" on reports;
create policy "फक्त स्वतःचा report टाकता येतो"
  on reports for insert with check (auth.uid() = reporter_id);

-- 5) REALTIME चालू करणे (Supabase Realtime साठी) — आधीच जोडलेलं असेल तर स्किप
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and tablename = 'messages'
  ) then
    alter publication supabase_realtime add table messages;
  end if;
end $$;

-- 6) MEDIA (photo/file sharing) — Storage bucket + messages columns
insert into storage.buckets (id, name, public)
values ('chat-media', 'chat-media', true)
on conflict (id) do nothing;

drop policy if exists "लॉगिन केलेले chat-media मध्ये अपलोड करू शकतात" on storage.objects;
create policy "लॉगिन केलेले chat-media मध्ये अपलोड करू शकतात"
  on storage.objects for insert
  with check (bucket_id = 'chat-media' and auth.uid() is not null);

drop policy if exists "chat-media सगळ्यांना वाचता येतं" on storage.objects;
create policy "chat-media सगळ्यांना वाचता येतं"
  on storage.objects for select
  using (bucket_id = 'chat-media');

alter table messages add column if not exists media_url text;
alter table messages add column if not exists media_type text;

drop policy if exists "पाठवणारा स्वतःचा मेसेज delete करू शकतो" on messages;
create policy "पाठवणारा स्वतःचा मेसेज delete करू शकतो"
  on messages for update
  using (auth.uid() = sender_id)
  with check (auth.uid() = sender_id);

-- 7) GROUP ADMIN — owner भूमिका, सभासद काढणं
create or replace function is_conversation_owner(conv_id uuid, uid uuid)
returns boolean language sql security definer stable as $$
  select exists (
    select 1 from conversation_members
    where conversation_id = conv_id and user_id = uid and role = 'owner'
  );
$$;

drop policy if exists "सभासद स्वतःला काढू शकतो किंवा owner इतरांना काढू शकतो" on conversation_members;
create policy "सभासद स्वतःला काढू शकतो किंवा owner इतरांना काढू शकतो"
  on conversation_members for delete using (
    user_id = auth.uid() or is_conversation_owner(conversation_id, auth.uid())
  );

-- 8) PRIVACY: last-seen / online status
alter table profiles add column if not exists hide_last_seen boolean default false;
alter table profiles add column if not exists last_seen_at timestamptz default now();

-- 9) DISAPPEARING MESSAGES + AUTOMATIC CLEANUP ("zero/near-zero storage" तत्वानुसार)
alter table messages add column if not exists expires_at timestamptz;
alter table conversations add column if not exists disappearing_seconds integer; -- null = बंद

drop policy if exists "सभासद disappearing सेटिंग बदलू शकतात" on conversations;
create policy "सभासद disappearing सेटिंग बदलू शकतात"
  on conversations for update using (
    is_conversation_member(id, auth.uid())
  );

-- Expire झालेले मेसेज + त्यांचे media files पूर्णपणे काढून टाकणारं function
create or replace function cleanup_expired_messages()
returns void
language plpgsql
security definer
as $$
begin
  -- expire झालेल्या मेसेजची media फाईल असेल तर आधी storage मधून काढतो
  delete from storage.objects
  where bucket_id = 'chat-media'
    and name in (
      select substring(media_url from '/chat-media/(.*)$')
      from messages
      where expires_at is not null and expires_at < now() and media_url is not null
    );

  -- मग मेसेज रो सुद्धा काढतो
  delete from messages where expires_at is not null and expires_at < now();
end;
$$;

-- दर तासाला आपोआप चालवण्यासाठी pg_cron (उपलब्ध असेल तर) — नसेल तर हा भाग सुरक्षितपणे स्किप होतो
do $$
begin
  create extension if not exists pg_cron;
  perform cron.schedule('cleanup-expired-messages', '0 * * * *', 'select cleanup_expired_messages();');
exception when others then
  raise notice 'pg_cron सेटअप करता आलं नाही — Supabase Dashboard च्या Database > Extensions मध्ये जाऊन "pg_cron" चालू करा, मग SQL Editor मध्ये फक्त हे एकदा चालवा: select cron.schedule(''cleanup-expired-messages'', ''0 * * * *'', ''select cleanup_expired_messages();'');';
end $$;

-- 10) COMMUNITIES/CHANNELS — broadcast-style: फक्त owner/admin पोस्ट करू शकतात, बाकीचे फक्त वाचतात
alter table conversations add column if not exists is_public boolean default false;
alter table conversations add column if not exists description text;

-- Channel मध्ये पोस्ट करण्याचा अधिकार आहे का हे तपासणारं function
create or replace function can_post_in_conversation(conv_id uuid, uid uuid)
returns boolean
language sql
security definer
stable
as $$
  select case
    when (select type from conversations where id = conv_id) = 'channel'
      then exists (select 1 from conversation_members where conversation_id = conv_id and user_id = uid and role in ('owner', 'admin'))
    else is_conversation_member(conv_id, uid)
  end;
$$;

-- Public channels कोणालाही (सभासद नसतानाही) शोधता/बघता याव्यात
drop policy if exists "फक्त सभासद आपलं conversation बघू शकतात" on conversations;
create policy "फक्त सभासद आपलं conversation बघू शकतात"
  on conversations for select using (
    is_conversation_member(id, auth.uid()) or created_by = auth.uid() or (type = 'channel' and is_public = true)
  );

-- मेसेज पाठवण्याची अट: group/direct मध्ये कोणीही सभासद, channel मध्ये फक्त owner/admin
drop policy if exists "फक्त सभासदच मेसेज पाठवू शकतात, आणि स्वतःच्याच नावाने" on messages;
create policy "फक्त सभासदच मेसेज पाठवू शकतात, आणि स्वतःच्याच नावाने"
  on messages for insert with check (
    auth.uid() = sender_id
    and can_post_in_conversation(messages.conversation_id, auth.uid())
  );


-- 11) READ RECEIPTS — last_read_at प्रत्येक सभासदासाठी
alter table conversation_members add column if not exists last_read_at timestamptz default now();

drop policy if exists "सभासद स्वतःचं last_read_at अपडेट करू शकतो" on conversation_members;
create policy "सभासद स्वतःचं last_read_at अपडेट करू शकतो"
  on conversation_members for update using (user_id = auth.uid()) with check (user_id = auth.uid());

-- 12) REACTIONS — कोणत्याही मेसेजवर (group/channel मध्ये subscribers सुद्धा react करू शकतात)
create table if not exists message_reactions (
  id uuid primary key default gen_random_uuid(),
  message_id uuid references messages(id) on delete cascade,
  user_id uuid references profiles(id) on delete cascade,
  emoji text not null,
  created_at timestamptz default now(),
  unique (message_id, user_id, emoji)
);

alter table message_reactions enable row level security;

create or replace function message_conversation_id(msg_id uuid)
returns uuid language sql security definer stable as $$
  select conversation_id from messages where id = msg_id;
$$;

drop policy if exists "सभासद reactions बघू शकतात" on message_reactions;
create policy "सभासद reactions बघू शकतात"
  on message_reactions for select using (
    is_conversation_member(message_conversation_id(message_id), auth.uid())
  );

drop policy if exists "सभासद react करू शकतात" on message_reactions;
create policy "सभासद react करू शकतात"
  on message_reactions for insert with check (
    auth.uid() = user_id and is_conversation_member(message_conversation_id(message_id), auth.uid())
  );

drop policy if exists "स्वतःची reaction काढू शकतो" on message_reactions;
create policy "स्वतःची reaction काढू शकतो"
  on message_reactions for delete using (auth.uid() = user_id);

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and tablename = 'message_reactions'
  ) then
    alter publication supabase_realtime add table message_reactions;
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and tablename = 'conversation_members'
  ) then
    alter publication supabase_realtime add table conversation_members;
  end if;
end $$;


-- 13) CHANNEL COMMENTS — subscribers top-level post करू शकत नाहीत, पण एखाद्या पोस्टला comment (reply) करू शकतात
drop policy if exists "फक्त सभासदच मेसेज पाठवू शकतात, आणि स्वतःच्याच नावाने" on messages;
create policy "फक्त सभासदच मेसेज पाठवू शकतात, आणि स्वतःच्याच नावाने"
  on messages for insert with check (
    auth.uid() = sender_id
    and (
      can_post_in_conversation(messages.conversation_id, auth.uid())
      or (
        messages.reply_to is not null
        and (select type from conversations where id = messages.conversation_id) = 'channel'
        and is_conversation_member(messages.conversation_id, auth.uid())
      )
    )
  );


-- 14) ACCOUNT TYPES + BUSINESS DIRECTORY + CREATOR BIO
alter table profiles add column if not exists account_type text default 'personal'; -- personal | creator | business
alter table profiles add column if not exists bio text;

create table if not exists business_profiles (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid references profiles(id) unique,
  name text not null,
  category text,
  location text,
  phone text,
  website text,
  hours text,
  description text,
  created_at timestamptz default now()
);

alter table business_profiles enable row level security;

drop policy if exists "Business profiles सगळ्यांना दिसतात" on business_profiles;
create policy "Business profiles सगळ्यांना दिसतात"
  on business_profiles for select using (true);

drop policy if exists "मालक स्वतःचा business profile तयार करू शकतो" on business_profiles;
create policy "मालक स्वतःचा business profile तयार करू शकतो"
  on business_profiles for insert with check (auth.uid() = owner_id);

drop policy if exists "मालक स्वतःचा business profile बदलू शकतो" on business_profiles;
create policy "मालक स्वतःचा business profile बदलू शकतो"
  on business_profiles for update using (auth.uid() = owner_id) with check (auth.uid() = owner_id);

drop policy if exists "मालक स्वतःचा business profile काढू शकतो" on business_profiles;
create policy "मालक स्वतःचा business profile काढू शकतो"
  on business_profiles for delete using (auth.uid() = owner_id);

