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
