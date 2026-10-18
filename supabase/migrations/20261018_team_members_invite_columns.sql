-- ============================================================================
-- Migration: 20261018_team_members_invite_columns.sql
-- Purpose: Ensure team_members table has all staff credential, invite token,
--          and permission columns so cross-device staff invitations work.
-- ============================================================================

ALTER TABLE public.team_members
  ADD COLUMN IF NOT EXISTS is_founder BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS can_edit_inventory BOOLEAN DEFAULT true,
  ADD COLUMN IF NOT EXISTS can_view_pricing BOOLEAN DEFAULT true,
  ADD COLUMN IF NOT EXISTS can_manage_team BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS can_view_all_team_calendar BOOLEAN DEFAULT true,
  ADD COLUMN IF NOT EXISTS email TEXT,
  ADD COLUMN IF NOT EXISTS pin TEXT,
  ADD COLUMN IF NOT EXISTS password TEXT,
  ADD COLUMN IF NOT EXISTS invite_token TEXT,
  ADD COLUMN IF NOT EXISTS invite_status TEXT DEFAULT 'none',
  ADD COLUMN IF NOT EXISTS invite_sent_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS allowed_hub_sections JSONB,
  ADD COLUMN IF NOT EXISTS custom_weekly_schedule JSONB;
