-- ============================================================================
-- SECURITY HARDENING MIGRATION
-- Date: 2026-05-09
-- Purpose: Fix RLS and permission issues identified in security audit
--
-- APPLY IN ORDER. Test the app between each numbered section.
-- If anything breaks, see security_hardening_rollback.sql for the inverse.
--
-- Sections:
--   1. search_path fixes (zero risk)
--   2. WITH CHECK additions (low risk)
--   3. account_invitations SELECT tightening (test invite flow)
--   4. app_users insert tightening (test signup)
--   5. account_members insert/update tightening (test signup + invite accept)
--   6. RPC parameter hardening (use auth.uid() not p_user_id)
--   7. Revoke anon table grants (test entire app)
-- ============================================================================


-- ============================================================================
-- 1. SEARCH_PATH FIXES (safe, no behavior change)
-- ============================================================================

ALTER FUNCTION accept_invitation_with_sync(uuid, uuid, uuid, uuid, uuid, text) SET search_path = public;
ALTER FUNCTION propagate_profile_changes() SET search_path = public;
ALTER FUNCTION propagate_profile_detail_changes() SET search_path = public;
ALTER FUNCTION cleanup_reshares_on_member_removal() SET search_path = public;
ALTER FUNCTION sever_sync_on_profile_delete() SET search_path = public;
ALTER FUNCTION update_member_role(uuid, text, uuid) SET search_path = public;
ALTER FUNCTION revoke_invitation_with_cleanup(uuid, uuid) SET search_path = public;
ALTER FUNCTION is_category_shared(uuid, text, uuid) SET search_path = public;
ALTER FUNCTION is_original_share(uuid) SET search_path = public;
ALTER FUNCTION can_reshare_event(uuid, text, uuid) SET search_path = public;
ALTER FUNCTION get_account_name_for_invitation(text) SET search_path = public;
ALTER FUNCTION get_device_tokens_for_users(uuid[]) SET search_path = public;
ALTER FUNCTION get_shared_important_accounts(text) SET search_path = public;
ALTER FUNCTION get_source_share_id(uuid, text, uuid) SET search_path = public;


-- ============================================================================
-- 2. ADD WITH CHECK TO UPDATE POLICIES (prevents row "moving" between accounts)
-- ============================================================================

ALTER POLICY "Users can update profiles in their accounts" ON profiles
WITH CHECK (
  EXISTS (
    SELECT 1 FROM account_members
    WHERE account_members.account_id = profiles.account_id
      AND account_members.user_id = (SELECT auth.uid())
  )
);

ALTER POLICY "Writers can update appointments" ON appointments
WITH CHECK (can_write_to_account(account_id));

ALTER POLICY "Writers can update medications" ON medications
WITH CHECK (can_write_to_account(account_id));

ALTER POLICY "Writers can update medication logs" ON medication_logs
WITH CHECK (can_write_to_account(account_id));

ALTER POLICY "Writers can update medication schedules" ON medication_schedules
WITH CHECK (can_write_to_account(account_id));

ALTER POLICY "Writers can update profile details" ON profile_details
WITH CHECK (can_write_to_account(account_id));

ALTER POLICY "Writers can update useful contacts" ON useful_contacts
WITH CHECK (can_write_to_account(account_id));

ALTER POLICY "Users can update their own profile syncs" ON profile_syncs
WITH CHECK (
  (SELECT auth.uid()) = inviter_user_id
  OR (SELECT auth.uid()) = acceptor_user_id
);

ALTER POLICY "Users can update countdowns in their accounts" ON countdowns
WITH CHECK (
  account_id IN (
    SELECT account_id FROM account_members
    WHERE user_id = (SELECT auth.uid())
  )
);

ALTER POLICY "Users can update planned meals for their accounts" ON planned_meals
WITH CHECK (
  account_id IN (
    SELECT account_id FROM account_members
    WHERE user_id = (SELECT auth.uid())
  )
);

ALTER POLICY "Users can update recipes for their accounts" ON recipes
WITH CHECK (
  account_id IN (
    SELECT account_id FROM account_members
    WHERE user_id = (SELECT auth.uid())
  )
);

ALTER POLICY "Users can update lists for their accounts" ON todo_lists
WITH CHECK (
  account_id IN (
    SELECT account_id FROM account_members
    WHERE user_id = (SELECT auth.uid())
  )
);

ALTER POLICY "Users can update items for their lists" ON todo_items
WITH CHECK (
  list_id IN (
    SELECT id FROM todo_lists
    WHERE account_id IN (
      SELECT account_id FROM account_members
      WHERE user_id = (SELECT auth.uid())
    )
  )
);

ALTER POLICY "Users can update accounts for profiles they have access to" ON important_accounts
WITH CHECK (
  profile_id IN (
    SELECT id FROM profiles
    WHERE account_id IN (
      SELECT account_id FROM account_members
      WHERE user_id = (SELECT auth.uid())
    )
  )
);

ALTER POLICY "Users can update their mood entries" ON mood_entries
WITH CHECK (user_id = (SELECT auth.uid()));

ALTER POLICY "Users can update their own notes" ON notes
WITH CHECK (user_id = (SELECT auth.uid()));

ALTER POLICY "Users can update sharing preferences" ON profile_sharing_preferences
WITH CHECK ((SELECT auth.uid()) = user_id);

ALTER POLICY "Owners can update accounts" ON accounts
WITH CHECK (owner_user_id = (SELECT auth.uid()));

ALTER POLICY "Re-sharers can update their re-shares" ON family_calendar_shares
WITH CHECK ((source_share_id IS NOT NULL) AND ((SELECT auth.uid()) = shared_by_user_id));

ALTER POLICY "Share creators can update shares" ON family_calendar_shares
WITH CHECK ((SELECT auth.uid()) = shared_by_user_id);

ALTER POLICY "Admins can update invitations" ON account_invitations
WITH CHECK (
  account_id IN (
    SELECT account_id FROM account_members
    WHERE user_id = (SELECT auth.uid())
      AND role = ANY (ARRAY['owner'::text, 'admin'::text])
  )
);


-- ============================================================================
-- 3. TIGHTEN ACCOUNT_INVITATIONS SELECT
-- The "Anyone can lookup invitation by code" policy allowed any authenticated
-- (or anon) user to read every invitation. Replace with scoped policy.
-- The pre-auth lookup-by-code flow goes through get_account_name_for_invitation
-- which is SECURITY DEFINER and bypasses RLS.
-- ============================================================================

DROP POLICY IF EXISTS "Anyone can lookup invitation by code" ON account_invitations;

CREATE POLICY "Users can read invitations addressed to them or their accounts"
ON account_invitations FOR SELECT TO authenticated
USING (
  -- Invitee can see invitations sent to their email
  invited_email = (SELECT auth.jwt() ->> 'email')
  -- Account members can see invitations for their accounts
  OR account_id IN (SELECT get_user_account_ids((SELECT auth.uid())))
);

-- Allow the anon role to call the pre-auth lookup function
GRANT EXECUTE ON FUNCTION get_account_name_for_invitation(text) TO anon;


-- ============================================================================
-- 4. TIGHTEN APP_USERS INSERT
-- Prevent users from self-promoting to is_app_admin = true on insert
-- ============================================================================

DROP POLICY IF EXISTS "Users can insert own app_user record" ON app_users;

CREATE POLICY "Users can insert own app_user record" ON app_users
FOR INSERT TO authenticated
WITH CHECK (
  (SELECT auth.uid()) = id
  AND COALESCE(is_app_admin, false) = false
  AND COALESCE(has_complimentary_access, false) = false
);

-- Also add WITH CHECK to admin update so it's symmetric
ALTER POLICY "App admins can update app_user records" ON app_users
WITH CHECK (is_app_admin((SELECT auth.uid())) = true);


-- ============================================================================
-- 5. TIGHTEN ACCOUNT_MEMBERS POLICIES
-- a) Block self-insert (anyone could join any account by knowing its UUID)
-- b) Block self-update (viewer could promote themselves to owner)
-- ============================================================================

-- Verify there's a trigger that auto-creates the owner row when an account
-- is created. If not, signup will break. Run this BEFORE applying section 5:
--
--   SELECT trigger_name, action_statement
--   FROM information_schema.triggers
--   WHERE event_object_table = 'accounts';
--
-- If no such trigger exists, create one:
--
--   CREATE OR REPLACE FUNCTION add_account_owner_on_create()
--   RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
--   BEGIN
--     INSERT INTO account_members (account_id, user_id, role)
--     VALUES (NEW.id, NEW.owner_user_id, 'owner');
--     RETURN NEW;
--   END;
--   $$;
--   CREATE TRIGGER trigger_add_account_owner
--     AFTER INSERT ON accounts
--     FOR EACH ROW EXECUTE FUNCTION add_account_owner_on_create();

DROP POLICY IF EXISTS "Users can insert account members" ON account_members;

CREATE POLICY "Owners and admins can add members" ON account_members
FOR INSERT TO authenticated
WITH CHECK (is_owner_or_admin(account_id));

DROP POLICY IF EXISTS "Users can update account members" ON account_members;

CREATE POLICY "Owners can update account members" ON account_members
FOR UPDATE TO authenticated
USING (get_user_role(account_id) = 'owner')
WITH CHECK (get_user_role(account_id) = 'owner');


-- ============================================================================
-- 6. RPC PARAMETER HARDENING (advisory note, requires careful refactor)
-- ============================================================================
--
-- These functions take p_user_id as a parameter and trust the caller:
--   - accept_invitation(p_invitation_id, p_user_id)
--   - accept_invitation_with_sync(p_invitation_id, p_user_id, ...)
--   - update_member_role(p_member_id, p_new_role, p_user_id)
--   - revoke_invitation_with_cleanup(p_invitation_id, p_user_id)
--   - sever_profile_sync(p_sync_id, p_user_id)
--
-- An attacker can call these with another user's UUID. Inside the function,
-- authorization is checked using p_user_id, not auth.uid() — so the attacker
-- can act AS that user.
--
-- Fix pattern (apply manually inside each function body):
--   At the top of the function, add:
--     IF p_user_id IS DISTINCT FROM auth.uid() THEN
--       RAISE EXCEPTION 'p_user_id must match authenticated user';
--     END IF;
--
-- Or replace every reference to p_user_id with auth.uid() in authorization
-- branches. Do not modify the data-writing branches that legitimately need
-- the value.
--
-- This requires reviewing each function body individually. Not included in
-- this migration — handle as a follow-up.


-- ============================================================================
-- 7. REVOKE ANON TABLE ACCESS (HIGHEST IMPACT - APPLY LAST, TEST CAREFULLY)
-- The anon role currently has full access to many public tables. Anyone with
-- the public anon key (shipped in your iOS app) can attempt operations.
-- RLS blocks them in most cases, but this is fail-closed by accident, not
-- design. Revoke and grant only what's needed.
-- ============================================================================

REVOKE ALL ON ALL TABLES IN SCHEMA public FROM anon;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM anon;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA public FROM anon;

GRANT USAGE ON SCHEMA public TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO authenticated;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO authenticated;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO authenticated;

ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE ALL ON TABLES FROM anon;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO authenticated;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT EXECUTE ON FUNCTIONS TO authenticated;

-- Re-grant the specific functions anon needs (pre-auth invitation lookup)
GRANT EXECUTE ON FUNCTION get_account_name_for_invitation(text) TO anon;


-- ============================================================================
-- VERIFICATION QUERIES (run after migration to confirm)
-- ============================================================================

-- Confirm no UPDATE policies are missing WITH CHECK:
--   SELECT tablename, policyname FROM pg_policies
--   WHERE schemaname = 'public' AND cmd = 'UPDATE' AND with_check IS NULL;
--
-- Confirm anon has no table grants:
--   SELECT table_name, privilege_type FROM information_schema.role_table_grants
--   WHERE grantee = 'anon' AND table_schema = 'public';
--
-- Confirm all SECURITY DEFINER functions have search_path set:
--   SELECT p.proname, p.proconfig FROM pg_proc p
--   JOIN pg_namespace n ON n.oid = p.pronamespace
--   WHERE n.nspname = 'public' AND p.prosecdef = true AND p.proconfig IS NULL;
