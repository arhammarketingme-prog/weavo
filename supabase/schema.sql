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

create policy "Profiles सगळ्यांना दिसतील (username शोधण्यासाठी आवश्यक)"
  on profiles for select using (true);

create policy "प्रत्येकजण फक्त स्वतःचा profile बदलू शकतो"
  on profiles for update using (auth.uid() = id);

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
create table if not exists conversations (
  id uuid primary key default gen_random_uuid(),
  type text not null default 'direct', -- direct | group | channel
  name text,
  created_at timestamptz default now()
);

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

create policy "फक्त सभासद आपलं conversation बघू शकतात"
  on conversations for select using (
    exists (select 1 from conversation_members m where m.conversation_id = id and m.user_id = auth.uid())
  );

create policy "लॉगिन केलेला कोणीही नवीन conversation तयार करू शकतो"
  on conversations for insert with check (auth.uid() is not null);

create policy "सभासदांची यादी सभासदांनाच दिसते"
  on conversation_members for select using (
    exists (select 1 from conversation_members m where m.conversation_id = conversation_id and m.user_id = auth.uid())
  );

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

create policy "फक्त त्या conversation चे सभासद मेसेज बघू शकतात"
  on messages for select using (
    exists (select 1 from conversation_members m where m.conversation_id = messages.conversation_id and m.user_id = auth.uid())
  );

create policy "फक्त सभासदच मेसेज पाठवू शकतात, आणि स्वतःच्याच नावाने"
  on messages for insert with check (
    auth.uid() = sender_id
    and exists (select 1 from conversation_members m where m.conversation_id = messages.conversation_id and m.user_id = auth.uid())
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

create policy "फक्त स्वतःचा report टाकता येतो"
  on reports for insert with check (auth.uid() = reporter_id);

-- 5) REALTIME चालू करणे (Supabase Realtime साठी)
alter publication supabase_realtime add table messages;
