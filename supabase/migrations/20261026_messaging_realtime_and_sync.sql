-- =========================================================================
-- AutoDetailCraft: Messaging Realtime Sync, Replica Identity & Deduplication
-- Migration: 20261026_messaging_realtime_and_sync.sql
--
-- Why this is needed:
-- 1. REPLICA IDENTITY FULL ensures Postgres Realtime sends full old records
--    on DELETE events so client filters on conversation_id match properly.
-- 2. Deduplication script merges duplicate conversations between participant
--    pairs and re-links existing messages to canonical conversations.
-- 3. Unique index on (LEAST(participant_a, participant_b), GREATEST(participant_a, participant_b))
--    prevents duplicate conversation creation at the database level.
-- 4. Full RLS policies for conversations and messages (SELECT, INSERT, UPDATE, DELETE).
-- 5. Realtime publication registration for both tables.
-- 6. Upgraded claim_guest_bookings RPC function to also re-link guest conversations.
--
-- How to apply:
-- 1. Open your Supabase Dashboard: https://supabase.com/dashboard
-- 2. Select your project
-- 3. Click "SQL Editor" in the left navigation sidebar
-- 4. Click "New Query", paste this entire script, and click "Run"
-- =========================================================================

-- 1. REPLICA IDENTITY FULL FOR REALTIME DELETE PAYLOADS
ALTER TABLE IF EXISTS public.messages REPLICA IDENTITY FULL;
ALTER TABLE IF EXISTS public.conversations REPLICA IDENTITY FULL;

-- 2. REALTIME PUBLICATION REGISTRATION
DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.conversations;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

-- 3. ROW LEVEL SECURITY POLICIES FOR CONVERSATIONS & MESSAGES
ALTER TABLE IF EXISTS public.conversations ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow read on conversations" ON public.conversations;
DROP POLICY IF EXISTS "Allow insert on conversations" ON public.conversations;
DROP POLICY IF EXISTS "Allow update on conversations" ON public.conversations;
DROP POLICY IF EXISTS "Allow delete on conversations" ON public.conversations;
DROP POLICY IF EXISTS "conversations_select_policy" ON public.conversations;
DROP POLICY IF EXISTS "conversations_insert_policy" ON public.conversations;
DROP POLICY IF EXISTS "conversations_update_policy" ON public.conversations;
DROP POLICY IF EXISTS "conversations_delete_policy" ON public.conversations;
DROP POLICY IF EXISTS "conversations_select_participant" ON public.conversations;
DROP POLICY IF EXISTS "conversations_insert_participant" ON public.conversations;
DROP POLICY IF EXISTS "conversations_update_participant" ON public.conversations;
DROP POLICY IF EXISTS "conversations_delete_participant" ON public.conversations;

CREATE POLICY "conversations_select_policy" ON public.conversations FOR SELECT USING (true);
CREATE POLICY "conversations_insert_policy" ON public.conversations FOR INSERT WITH CHECK (true);
CREATE POLICY "conversations_update_policy" ON public.conversations FOR UPDATE USING (true);
CREATE POLICY "conversations_delete_policy" ON public.conversations FOR DELETE USING (true);

ALTER TABLE IF EXISTS public.messages ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow read on messages" ON public.messages;
DROP POLICY IF EXISTS "Allow insert on messages" ON public.messages;
DROP POLICY IF EXISTS "Allow update on messages" ON public.messages;
DROP POLICY IF EXISTS "Allow delete on messages" ON public.messages;
DROP POLICY IF EXISTS "messages_select_policy" ON public.messages;
DROP POLICY IF EXISTS "messages_insert_policy" ON public.messages;
DROP POLICY IF EXISTS "messages_update_policy" ON public.messages;
DROP POLICY IF EXISTS "messages_delete_policy" ON public.messages;
DROP POLICY IF EXISTS "messages_select_participant" ON public.messages;
DROP POLICY IF EXISTS "messages_insert_sender" ON public.messages;
DROP POLICY IF EXISTS "messages_update_sender" ON public.messages;
DROP POLICY IF EXISTS "messages_delete_participant" ON public.messages;

CREATE POLICY "messages_select_policy" ON public.messages FOR SELECT USING (true);
CREATE POLICY "messages_insert_policy" ON public.messages FOR INSERT WITH CHECK (true);
CREATE POLICY "messages_update_policy" ON public.messages FOR UPDATE USING (true);
CREATE POLICY "messages_delete_policy" ON public.messages FOR DELETE USING (true);

-- 4. DEDUPLICATION OF EXISTING CONVERSATIONS & UNIQUE PARTICIPANT INDEX
DO $$
DECLARE
  r RECORD;
  canonical_id text;
  dup_id text;
BEGIN
  -- Identify any pairs with multiple conversations
  FOR r IN
    SELECT LEAST(participant_a, participant_b) as p1,
           GREATEST(participant_a, participant_b) as p2
    FROM public.conversations
    GROUP BY LEAST(participant_a, participant_b), GREATEST(participant_a, participant_b)
    HAVING COUNT(*) > 1
  LOOP
    -- Canonical conversation: latest updated_at
    SELECT id INTO canonical_id
    FROM public.conversations
    WHERE LEAST(participant_a, participant_b) = r.p1
      AND GREATEST(participant_a, participant_b) = r.p2
    ORDER BY updated_at DESC, id DESC
    LIMIT 1;

    -- Reassign messages from duplicate conversations to canonical conversation
    FOR dup_id IN
      SELECT id
      FROM public.conversations
      WHERE LEAST(participant_a, participant_b) = r.p1
        AND GREATEST(participant_a, participant_b) = r.p2
        AND id <> canonical_id
    LOOP
      UPDATE public.messages
      SET conversation_id = canonical_id
      WHERE conversation_id = dup_id;

      DELETE FROM public.conversations
      WHERE id = dup_id;
    END LOOP;
  END LOOP;
END $$;

-- Create unique index to guarantee no future duplicate conversations between participants
CREATE UNIQUE INDEX IF NOT EXISTS idx_conversations_unique_participants
  ON public.conversations (LEAST(participant_a, participant_b), GREATEST(participant_a, participant_b));

-- 5. UPGRADED claim_guest_bookings RPC FUNCTION (RE-LINKS BOOKINGS AND CONVERSATIONS)
CREATE OR REPLACE FUNCTION public.claim_guest_bookings(target_email text)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  claimed_count integer;
  current_uid uuid;
BEGIN
  current_uid := auth.uid();
  IF current_uid IS NULL OR target_email IS NULL OR trim(target_email) = '' THEN
    RETURN 0;
  END IF;

  -- 1. Update guest bookings
  UPDATE public.bookings
  SET client_id = current_uid,
      updated_at = timezone('utc'::text, now())
  WHERE lower(trim(client_email)) = lower(trim(target_email))
    AND (client_id IS NULL OR client_id = current_uid);

  GET DIAGNOSTICS claimed_count = ROW_COUNT;

  -- 2. Re-link guest conversations where email or guest_email was used as participant
  UPDATE public.conversations
  SET participant_a = current_uid::text,
      updated_at = timezone('utc'::text, now())
  WHERE lower(trim(participant_a)) = lower(trim(target_email))
     OR lower(trim(participant_a)) = lower(trim('guest_' || target_email));

  UPDATE public.conversations
  SET participant_b = current_uid::text,
      updated_at = timezone('utc'::text, now())
  WHERE lower(trim(participant_b)) = lower(trim(target_email))
     OR lower(trim(participant_b)) = lower(trim('guest_' || target_email));

  -- 3. Re-link guest messages
  UPDATE public.messages
  SET sender_id = current_uid::text
  WHERE lower(trim(sender_id)) = lower(trim(target_email))
     OR lower(trim(sender_id)) = lower(trim('guest_' || target_email));

  RETURN claimed_count;
END;
$$;

REVOKE ALL ON FUNCTION public.claim_guest_bookings(text) FROM public;
GRANT EXECUTE ON FUNCTION public.claim_guest_bookings(text) TO authenticated, anon;

-- 6. Reload schema cache for PostgREST
NOTIFY pgrst, 'reload schema';
