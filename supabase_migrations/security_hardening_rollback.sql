-- ============================================================================
-- SECURITY HARDENING ROLLBACK
-- Date: 2026-05-09
-- Purpose: Restore the policies/permissions that existed BEFORE
--          security_hardening.sql was applied.
--
-- Use this if applying the security migration breaks the app.
-- You can run sections individually — they're independent.
--
-- Sections mirror the apply file:
--   3. Restore "Anyone can lookup invitation by code"
--   4. Restore loose app_users insert
--   5. Restore self-insert / self-update on account_members
--   7. Restore anon table grants
--
-- Sections 1, 2, and 6 are not included because they have no breaking
-- consequences — sections 1 (search_path) and 2 (WITH CHECK) only block
-- malicious operations, and section 6 wasn't applied.
-- ============================================================================


-- ============================================================================
-- ROLLBACK SECTION 3: account_invitations SELECT
-- ============================================================================

DROP POLICY IF EXISTS "Users can read invitations addressed to them or their accounts" ON account_invitations;

CREATE POLICY "Anyone can lookup invitation by code"
ON account_invitations FOR SELECT
USING (true);


-- ============================================================================
-- ROLLBACK SECTION 4: app_users insert
-- ============================================================================

DROP POLICY IF EXISTS "Users can insert own app_user record" ON app_users;

CREATE POLICY "Users can insert own app_user record" ON app_users
FOR INSERT
WITH CHECK ((SELECT auth.uid()) = id);


-- ============================================================================
-- ROLLBACK SECTION 5: account_members insert/update
-- ============================================================================

DROP POLICY IF EXISTS "Owners and admins can add members" ON account_members;

CREATE POLICY "Users can insert account members" ON account_members
FOR INSERT
WITH CHECK (
  (user_id = (SELECT auth.uid())) OR is_owner_or_admin(account_id)
);

DROP POLICY IF EXISTS "Owners can update account members" ON account_members;

CREATE POLICY "Users can update account members" ON account_members
FOR UPDATE
USING (
  (user_id = (SELECT auth.uid())) OR (get_user_role(account_id) = 'owner')
);


-- ============================================================================
-- ROLLBACK SECTION 7: anon table grants
-- ============================================================================
-- WARNING: this restores anon access to all public tables. Only use if
-- absolutely necessary to unblock the app — then re-attempt section 7 with
-- proper testing.

GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO anon;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO anon;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO anon;

ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO anon;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT EXECUTE ON FUNCTIONS TO anon;
