-- ============================================================
-- FIX-ALL v3 — नवीन फीचर्ससाठी (Photo sharing, Delete messages, Group admin)
-- Supabase SQL Editor मध्ये संपूर्ण paste करून Run कर. सुरक्षितपणे पुन्हा चालवता येतं.
-- (यात आधीचे सगळे fixes (recursion, conversations insert) सुद्धा समाविष्ट आहेत)
-- ============================================================

-- ---------- आधीचे fixes (recursion + conversations insert) ----------
alter table conversations add column if not exists created_by uuid references profiles(id);

create or replace function is_conversation_member(conv_id uuid, uid uuid)
returns boolean language sql security definer stable as $$
  select exists (select 1 from conversation_members where conversation_id = conv_id and user_id = uid);
$$;

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

-- ---------- 1) STORAGE BUCKET — फोटो/फाईल्स साठी ----------
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

-- ---------- 2) MESSAGES — media columns + delete करता येण्यासाठी policy ----------
alter table messages add column if not exists media_url text;
alter table messages add column if not exists media_type text;

drop policy if exists "पाठवणारा स्वतःचा मेसेज delete करू शकतो" on messages;
create policy "पाठवणारा स्वतःचा मेसेज delete करू शकतो"
  on messages for update
  using (auth.uid() = sender_id)
  with check (auth.uid() = sender_id);

-- ---------- 3) GROUP ADMIN — owner भूमिका आणि सभासद काढणं ----------
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

-- ---------- 4) PRIVACY: avatar (आधीच होतं) + last-seen ----------
alter table profiles add column if not exists hide_last_seen boolean default false;
alter table profiles add column if not exists last_seen_at timestamptz default now();

-- ---------- 5) DISAPPEARING MESSAGES + AUTO-CLEANUP ----------
alter table messages add column if not exists expires_at timestamptz;
alter table conversations add column if not exists disappearing_seconds integer;

drop policy if exists "सभासद disappearing सेटिंग बदलू शकतात" on conversations;
create policy "सभासद disappearing सेटिंग बदलू शकतात"
  on conversations for update using (
    is_conversation_member(id, auth.uid())
  );

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
  raise notice 'pg_cron आपोआप सेटअप झालं नाही — README मध्ये manual स्टेप बघा.';
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


-- 15) MUTE + BLOCK
alter table conversation_members add column if not exists muted boolean default false;

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

-- टीप: नवीन conversation सुरू करताना block तपासणी frontend मध्ये केली जाते
-- (त्या दोन विशिष्ट व्यक्तींमधलं नातं conversations table वर उपलब्ध नसल्यामुळे DB-level इथे शक्य नाही)


-- 16) PIN + ARCHIVE
alter table conversation_members add column if not exists pinned boolean default false;
alter table conversation_members add column if not exists archived boolean default false;

