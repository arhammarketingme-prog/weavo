-- ============================================================
-- Weavo — Supabase Schema (संपूर्ण, नीटनेटकं — फक्त अंतिम स्थिती)
-- Supabase SQL Editor मध्ये हे संपूर्ण पेस्ट करून Run करा.
-- हे कितीही वेळा सुरक्षितपणे चालवता येतं (idempotent).
--
-- टीप: हा file पूर्वीच्या १-२० टप्प्यांतल्या इतिहासाऐवजी फक्त अंतिम,
-- स्वच्छ स्थिती दाखवतो — वाचायला/समजायला सोपा. जुना इतिहास हवा असल्यास
-- git history किंवा जुन्या zip files मध्ये आहे.
-- ============================================================

-- ---------- 1) PROFILES ----------
create table if not exists profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text unique not null,
  display_name text,
  avatar_url text,
  hide_last_seen boolean default false,
  last_seen_at timestamptz default now(),
  hide_read_receipts boolean default false,
  account_type text default 'personal', -- personal | creator | business
  bio text,
  created_at timestamptz default now()
);
alter table profiles add column if not exists hide_last_seen boolean default false;
alter table profiles add column if not exists last_seen_at timestamptz default now();
alter table profiles add column if not exists hide_read_receipts boolean default false;
alter table profiles add column if not exists account_type text default 'personal';
alter table profiles add column if not exists bio text;

alter table profiles enable row level security;

drop policy if exists "Profiles सगळ्यांना दिसतील (username शोधण्यासाठी आवश्यक)" on profiles;
drop policy if exists "Profiles फक्त लॉगिन केलेल्यांना दिसतील" on profiles;
create policy "Profiles फक्त लॉगिन केलेल्यांना दिसतील"
  on profiles for select using (auth.uid() is not null);

drop policy if exists "प्रत्येकजण फक्त स्वतःचा profile बदलू शकतो" on profiles;
create policy "प्रत्येकजण फक्त स्वतःचा profile बदलू शकतो"
  on profiles for update using (auth.uid() = id);

drop policy if exists "नवीन user स्वतःचा profile तयार करू शकतो" on profiles;
create policy "नवीन user स्वतःचा profile तयार करू शकतो"
  on profiles for insert with check (auth.uid() = id);

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

-- ---------- 2) HELPER FUNCTIONS (RLS recursion टाळण्यासाठी, SECURITY DEFINER) ----------
create or replace function is_conversation_member(conv_id uuid, uid uuid)
returns boolean language sql security definer stable as $$
  select exists (select 1 from conversation_members where conversation_id = conv_id and user_id = uid);
$$;

create or replace function is_conversation_owner(conv_id uuid, uid uuid)
returns boolean language sql security definer stable as $$
  select exists (select 1 from conversation_members where conversation_id = conv_id and user_id = uid and role = 'owner');
$$;

create or replace function is_conversation_admin(conv_id uuid, uid uuid)
returns boolean language sql security definer stable as $$
  select exists (select 1 from conversation_members where conversation_id = conv_id and user_id = uid and role in ('owner', 'admin'));
$$;

create or replace function can_post_in_conversation(conv_id uuid, uid uuid)
returns boolean language sql security definer stable as $$
  select case
    when (select type from conversations where id = conv_id) = 'channel'
      then is_conversation_admin(conv_id, uid)
    else is_conversation_member(conv_id, uid)
  end;
$$;

create or replace function message_conversation_id(msg_id uuid)
returns uuid language sql security definer stable as $$
  select conversation_id from messages where id = msg_id;
$$;

-- ---------- 3) CONVERSATIONS ----------
create table if not exists conversations (
  id uuid primary key default gen_random_uuid(),
  type text not null default 'direct', -- direct | group | channel
  name text,
  description text,
  avatar_url text,
  is_public boolean default false,
  disappearing_seconds integer, -- null = बंद
  created_by uuid references profiles(id),
  created_at timestamptz default now()
);
alter table conversations add column if not exists description text;
alter table conversations add column if not exists avatar_url text;
alter table conversations add column if not exists is_public boolean default false;
alter table conversations add column if not exists disappearing_seconds integer;
alter table conversations add column if not exists created_by uuid references profiles(id);

alter table conversations enable row level security;

drop policy if exists "फक्त सभासद आपलं conversation बघू शकतात" on conversations;
create policy "फक्त सभासद आपलं conversation बघू शकतात"
  on conversations for select using (
    is_conversation_member(id, auth.uid()) or created_by = auth.uid() or (type = 'channel' and is_public = true)
  );

drop policy if exists "लॉगिन केलेला कोणीही नवीन conversation तयार करू शकतो" on conversations;
create policy "लॉगिन केलेला कोणीही नवीन conversation तयार करू शकतो"
  on conversations for insert with check (auth.uid() is not null);

drop policy if exists "सभासद disappearing सेटिंग बदलू शकतात" on conversations;
create policy "सभासद disappearing सेटिंग बदलू शकतात"
  on conversations for update using (is_conversation_member(id, auth.uid()));

-- ---------- 4) CONVERSATION_MEMBERS ----------
create table if not exists conversation_members (
  conversation_id uuid references conversations(id) on delete cascade,
  user_id uuid references profiles(id) on delete cascade,
  role text default 'member', -- member | admin | owner | subscriber
  joined_at timestamptz default now(),
  last_read_message_id uuid,
  last_read_at timestamptz default now(),
  muted boolean default false,
  pinned boolean default false,
  archived boolean default false,
  primary key (conversation_id, user_id)
);
alter table conversation_members add column if not exists last_read_at timestamptz default now();
alter table conversation_members add column if not exists muted boolean default false;
alter table conversation_members add column if not exists pinned boolean default false;
alter table conversation_members add column if not exists archived boolean default false;

alter table conversation_members enable row level security;

drop policy if exists "सभासदांची यादी सभासदांनाच दिसते" on conversation_members;
create policy "सभासदांची यादी सभासदांनाच दिसते"
  on conversation_members for select using (is_conversation_member(conversation_id, auth.uid()));

drop policy if exists "स्वतःला/इतरांना सभासद म्हणून जोडता येतं (create flow साठी)" on conversation_members;
drop policy if exists "फक्त निर्माता/admin इतरांना जोडू शकतो; स्वतःला फक्त public channel मध्ये" on conversation_members;
create policy "फक्त निर्माता/admin इतरांना जोडू शकतो; स्वतःला फक्त public channel मध्ये"
  on conversation_members for insert with check (
    auth.uid() is not null
    and (
      (user_id = auth.uid() and (
        exists (select 1 from conversations c where c.id = conversation_id and c.created_by = auth.uid())
        or exists (select 1 from conversations c where c.id = conversation_id and c.type = 'channel' and c.is_public = true)
      ))
      or exists (select 1 from conversations c where c.id = conversation_id and c.created_by = auth.uid())
      or is_conversation_admin(conversation_id, auth.uid())
    )
  );

drop policy if exists "सभासद स्वतःचं last_read_at अपडेट करू शकतो" on conversation_members;
create policy "सभासद स्वतःचं last_read_at अपडेट करू शकतो"
  on conversation_members for update using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists "सभासद स्वतःला काढू शकतो किंवा owner इतरांना काढू शकतो" on conversation_members;
create policy "सभासद स्वतःला काढू शकतो किंवा owner इतरांना काढू शकतो"
  on conversation_members for delete using (
    user_id = auth.uid() or is_conversation_owner(conversation_id, auth.uid())
  );

-- ---------- 5) MESSAGES ----------
create table if not exists messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid references conversations(id) on delete cascade,
  sender_id uuid references profiles(id) on delete cascade,
  content text not null,
  reply_to uuid references messages(id),
  media_url text,
  media_type text, -- image | audio | file | location | contact | poll
  expires_at timestamptz,
  created_at timestamptz default now(),
  edited boolean default false,
  deleted boolean default false
);
alter table messages add column if not exists media_url text;
alter table messages add column if not exists media_type text;
alter table messages add column if not exists expires_at timestamptz;

alter table messages enable row level security;

drop policy if exists "फक्त त्या conversation चे सभासद मेसेज बघू शकतात" on messages;
create policy "फक्त त्या conversation चे सभासद मेसेज बघू शकतात"
  on messages for select using (is_conversation_member(messages.conversation_id, auth.uid()));

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

drop policy if exists "पाठवणारा स्वतःचा मेसेज delete करू शकतो" on messages;
create policy "पाठवणारा स्वतःचा मेसेज delete करू शकतो"
  on messages for update using (auth.uid() = sender_id) with check (auth.uid() = sender_id);

alter table messages drop constraint if exists messages_content_length;
alter table messages add constraint messages_content_length check (char_length(content) <= 5000) not valid;

create or replace function enforce_message_rate_limit()
returns trigger language plpgsql as $$
declare
  recent_count integer;
begin
  select count(*) into recent_count
  from messages
  where sender_id = new.sender_id and created_at > now() - interval '10 seconds';
  if recent_count >= 15 then
    raise exception 'खूप वेगाने मेसेज पाठवत आहात, थोडं थांबा';
  end if;
  return new;
end;
$$;

drop trigger if exists messages_rate_limit on messages;
create trigger messages_rate_limit
  before insert on messages
  for each row execute function enforce_message_rate_limit();

create or replace function cleanup_expired_messages()
returns void language plpgsql security definer as $$
begin
  delete from storage.objects
  where bucket_id = 'chat-media'
    and name in (
      select substring(media_url from '/chat-media/(.*)$')
      from messages
      where expires_at is not null and expires_at < now() and media_url is not null
    );
  delete from messages where expires_at is not null and expires_at < now();
end;
$$;

do $$
begin
  create extension if not exists pg_cron;
  perform cron.schedule('cleanup-expired-messages', '0 * * * *', 'select cleanup_expired_messages();');
exception when others then
  raise notice 'pg_cron सेटअप करता आलं नाही — Supabase Dashboard च्या Database > Extensions मध्ये जाऊन pg_cron चालू करा';
end $$;

-- ---------- 6) MESSAGE REACTIONS ----------
create table if not exists message_reactions (
  id uuid primary key default gen_random_uuid(),
  message_id uuid references messages(id) on delete cascade,
  user_id uuid references profiles(id) on delete cascade,
  emoji text not null,
  created_at timestamptz default now(),
  unique (message_id, user_id, emoji)
);
alter table message_reactions enable row level security;

drop policy if exists "सभासद reactions बघू शकतात" on message_reactions;
create policy "सभासद reactions बघू शकतात"
  on message_reactions for select using (is_conversation_member(message_conversation_id(message_id), auth.uid()));

drop policy if exists "सभासद react करू शकतात" on message_reactions;
create policy "सभासद react करू शकतात"
  on message_reactions for insert with check (auth.uid() = user_id and is_conversation_member(message_conversation_id(message_id), auth.uid()));

drop policy if exists "स्वतःची reaction काढू शकतो" on message_reactions;
create policy "स्वतःची reaction काढू शकतो"
  on message_reactions for delete using (auth.uid() = user_id);

-- ---------- 7) STARRED MESSAGES ----------
create table if not exists starred_messages (
  user_id uuid references profiles(id) on delete cascade,
  message_id uuid references messages(id) on delete cascade,
  created_at timestamptz default now(),
  primary key (user_id, message_id)
);
alter table starred_messages enable row level security;

drop policy if exists "स्वतःचे starred messages बघू शकतो" on starred_messages;
create policy "स्वतःचे starred messages बघू शकतो"
  on starred_messages for select using (auth.uid() = user_id);

drop policy if exists "स्वतः star करू शकतो" on starred_messages;
create policy "स्वतः star करू शकतो"
  on starred_messages for insert with check (auth.uid() = user_id);

drop policy if exists "स्वतःचा star काढू शकतो" on starred_messages;
create policy "स्वतःचा star काढू शकतो"
  on starred_messages for delete using (auth.uid() = user_id);

-- ---------- 8) POLLS ----------
create table if not exists poll_votes (
  message_id uuid references messages(id) on delete cascade,
  user_id uuid references profiles(id) on delete cascade,
  option_index integer not null,
  created_at timestamptz default now(),
  primary key (message_id, user_id)
);
alter table poll_votes enable row level security;

drop policy if exists "सभासद poll votes बघू शकतात" on poll_votes;
create policy "सभासद poll votes बघू शकतात"
  on poll_votes for select using (is_conversation_member(message_conversation_id(message_id), auth.uid()));

drop policy if exists "सभासद vote करू शकतात" on poll_votes;
create policy "सभासद vote करू शकतात"
  on poll_votes for insert with check (auth.uid() = user_id and is_conversation_member(message_conversation_id(message_id), auth.uid()));

drop policy if exists "स्वतःचं vote बदलू शकतो" on poll_votes;
create policy "स्वतःचं vote बदलू शकतो"
  on poll_votes for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "स्वतःचं vote काढू शकतो" on poll_votes;
create policy "स्वतःचं vote काढू शकतो"
  on poll_votes for delete using (auth.uid() = user_id);

-- ---------- 9) BUSINESS PROFILES ----------
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

-- ---------- 10) BLOCKED USERS ----------
create table if not exists blocked_users (
  blocker_id uuid references profiles(id) on delete cascade,
  blocked_id uuid references profiles(id) on delete cascade,
  created_at timestamptz default now(),
  primary key (blocker_id, blocked_id)
);
alter table blocked_users enable row level security;

drop policy if exists "स्वतःची blocked यादी बघू शकतो" on blocked_users;
create policy "स्वतःची blocked यादी बघू शकतो"
  on blocked_users for select using (auth.uid() = blocker_id);

drop policy if exists "स्वतः कोणाला तरी block करू शकतो" on blocked_users;
create policy "स्वतः कोणाला तरी block करू शकतो"
  on blocked_users for insert with check (auth.uid() = blocker_id);

drop policy if exists "स्वतःचा block काढू शकतो (unblock)" on blocked_users;
create policy "स्वतःचा block काढू शकतो (unblock)"
  on blocked_users for delete using (auth.uid() = blocker_id);

-- ---------- 11) PUSH SUBSCRIPTIONS ----------
create table if not exists push_subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references profiles(id) on delete cascade,
  endpoint text not null,
  p256dh text not null,
  auth_key text not null,
  created_at timestamptz default now(),
  unique (user_id, endpoint)
);
alter table push_subscriptions enable row level security;

drop policy if exists "स्वतःचं subscription टाकू शकतो" on push_subscriptions;
create policy "स्वतःचं subscription टाकू शकतो"
  on push_subscriptions for insert with check (auth.uid() = user_id);

drop policy if exists "स्वतःचं subscription बघू शकतो" on push_subscriptions;
create policy "स्वतःचं subscription बघू शकतो"
  on push_subscriptions for select using (auth.uid() = user_id);

drop policy if exists "स्वतःचं subscription काढू शकतो" on push_subscriptions;
create policy "स्वतःचं subscription काढू शकतो"
  on push_subscriptions for delete using (auth.uid() = user_id);

-- ---------- 12) REPORTS ----------
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

-- ---------- 13) STORAGE (फोटो/फाईल/voice/avatars) ----------
insert into storage.buckets (id, name, public)
values ('chat-media', 'chat-media', true)
on conflict (id) do nothing;

drop policy if exists "लॉगिन केलेले chat-media मध्ये अपलोड करू शकतात" on storage.objects;
create policy "लॉगिन केलेले chat-media मध्ये अपलोड करू शकतात"
  on storage.objects for insert with check (bucket_id = 'chat-media' and auth.uid() is not null);

drop policy if exists "chat-media सगळ्यांना वाचता येतं" on storage.objects;
create policy "chat-media सगळ्यांना वाचता येतं"
  on storage.objects for select using (bucket_id = 'chat-media');

-- ---------- 14) REALTIME ----------
do $$
begin
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and tablename = 'messages') then
    alter publication supabase_realtime add table messages;
  end if;
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and tablename = 'conversation_members') then
    alter publication supabase_realtime add table conversation_members;
  end if;
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and tablename = 'message_reactions') then
    alter publication supabase_realtime add table message_reactions;
  end if;
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and tablename = 'poll_votes') then
    alter publication supabase_realtime add table poll_votes;
  end if;
end $$;

-- 21) BUSINESS PROFILE PHOTO
alter table business_profiles add column if not exists photo_url text;

