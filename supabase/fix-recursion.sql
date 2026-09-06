-- ============================================================
-- FIX: "infinite recursion detected in policy for relation conversation_members"
-- हे Supabase SQL Editor मध्ये पेस्ट करून Run करा (एकदाच, आधीच्या schema.sql नंतर)
-- ============================================================

-- कारण: conversation_members वरची SELECT policy स्वतःच conversation_members ला
-- क्वेरी करत होती -> RLS पुन्हा तीच policy चालवते -> अनंत loop.
-- उपाय: SECURITY DEFINER function वापरणे, जी RLS शिवाय (bypass करून) तपासते.

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

-- जुन्या (recursive) policies काढून टाका
drop policy if exists "सभासदांची यादी सभासदांनाच दिसते" on conversation_members;
drop policy if exists "फक्त सभासद आपलं conversation बघू शकतात" on conversations;
drop policy if exists "फक्त त्या conversation चे सभासद मेसेज बघू शकतात" on messages;
drop policy if exists "फक्त सभासदच मेसेज पाठवू शकतात, आणि स्वतःच्याच नावाने" on messages;

-- नवीन (recursion-free) policies, function वापरून
create policy "सभासदांची यादी सभासदांनाच दिसते"
  on conversation_members for select using (
    is_conversation_member(conversation_id, auth.uid())
  );

create policy "फक्त सभासद आपलं conversation बघू शकतात"
  on conversations for select using (
    is_conversation_member(id, auth.uid())
  );

create policy "फक्त त्या conversation चे सभासद मेसेज बघू शकतात"
  on messages for select using (
    is_conversation_member(conversation_id, auth.uid())
  );

create policy "फक्त सभासदच मेसेज पाठवू शकतात, आणि स्वतःच्याच नावाने"
  on messages for insert with check (
    auth.uid() = sender_id
    and is_conversation_member(conversation_id, auth.uid())
  );
