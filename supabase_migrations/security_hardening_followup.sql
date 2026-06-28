-- ============================================================================
-- SECURITY HARDENING FOLLOW-UP
-- Date: 2026-05-12
--
-- Cleans up three categories of Supabase Security Advisor warnings:
--   (a) 4 functions missing SET search_path
--   (b) 3 internal/admin functions exposed to the anon role unnecessarily
--   (c) p_user_id parameter trust in 5 RPCs (Section 6 of the original audit)
--
-- Part (c) is at the bottom of this file and is COMMENTED OUT — it requires
-- the full function bodies, which I'll provide once you paste the output of
-- the pg_get_functiondef query.
--
-- Rollback: security_hardening_followup_rollback.sql
-- ============================================================================


-- ============================================================================
-- (a) ADD search_path TO 4 FUNCTIONS
-- ============================================================================

ALTER FUNCTION cleanup_todo_list_shares() SET search_path = public;
ALTER FUNCTION get_sharing_category_key(text) SET search_path = public;
ALTER FUNCTION grant_review_account_access() SET search_path = public;
-- (update_sharing_preference has two overloads; only one was missing search_path)
ALTER FUNCTION update_sharing_preference(uuid, text, boolean) SET search_path = public;


-- ============================================================================
-- (b) REVOKE EXECUTE FROM anon ON INTERNAL/ADMIN FUNCTIONS
--
-- These three are never meant to be called by clients. They run server-side
-- (cron jobs, triggers, manual admin work). Anon and authenticated should
-- not be able to invoke them via the REST API.
-- ============================================================================

REVOKE EXECUTE ON FUNCTION rls_auto_enable() FROM anon, authenticated;
REVOKE EXECUTE ON FUNCTION get_morning_briefing_recipients() FROM anon, authenticated;
REVOKE EXECUTE ON FUNCTION get_device_tokens_for_users(uuid[]) FROM anon, authenticated;


-- ============================================================================
-- (c) RPC PARAMETER HARDENING — adds an auth.uid() check at the top of each
--
-- DEFERRED. I'll fill these in once you paste the function bodies — I need to
-- preserve the rest of each function exactly, only inserting a single guard
-- statement near the top.
--
-- The pattern is:
--
--   IF p_user_id IS DISTINCT FROM auth.uid() THEN
--     RAISE EXCEPTION 'p_user_id must match authenticated user';
--   END IF;
--
-- Functions awaiting this fix:
--   accept_invitation(p_invitation_id uuid, p_user_id uuid)
--   accept_invitation_with_sync(p_invitation_id uuid, p_user_id uuid, ...)
--   update_member_role(p_member_id uuid, p_new_role text, p_user_id uuid)
--   revoke_invitation_with_cleanup(p_invitation_id uuid, p_user_id uuid)
--   sever_profile_sync(p_sync_id uuid, p_user_id uuid)
-- ============================================================================
