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
