-- Migration: Add DELETE policies for conversations and messages
-- Description: Enables users and detailers to delete individual messages and entire conversations.

-- 1. CONVERSATIONS
ALTER TABLE IF EXISTS public.conversations ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow delete on conversations" ON public.conversations;
CREATE POLICY "Allow delete on conversations" ON public.conversations FOR DELETE USING (true);

-- 2. MESSAGES
ALTER TABLE IF EXISTS public.messages ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow delete on messages" ON public.messages;
CREATE POLICY "Allow delete on messages" ON public.messages FOR DELETE USING (true);
