-- Migration: Fix Multiple Permissive Policies Warnings
-- Date: 2026-02-22
--
-- Removes duplicate/redundant permissive RLS policies that cause PostgreSQL
-- to evaluate multiple policies per query unnecessarily.
--
-- Two approaches used:
-- 1. DROP redundant old policies where a newer policy covers the same access
-- 2. MERGE overlapping policies into a single combined policy where both are needed
--
-- NOTE: Some tables intentionally have multiple SELECT policies for different
-- access paths (e.g. app_users: own record vs admin access). These are left
-- as-is because merging them would make the policies harder to maintain and
-- the performance impact is negligible on small tables.

BEGIN;

-- ============================================================================
-- profile_sharing_preferences: Drop old "own" policies (superseded by per-user policies)
-- Old: "Users can X own sharing preferences" — checks user_id = auth.uid()
-- New: "Users can X sharing preferences" — checks user_id OR target_user_id
-- The new policies are strictly more permissive for SELECT and identical for
-- INSERT/UPDATE/DELETE, so the old ones are redundant.
-- ============================================================================

DROP POLICY IF EXISTS "Users can read own sharing preferences" ON profile_sharing_preferences;
DROP POLICY IF EXISTS "Users can insert own sharing preferences" ON profile_sharing_preferences;
DROP POLICY IF EXISTS "Users can update own sharing preferences" ON profile_sharing_preferences;
DROP POLICY IF EXISTS "Users can delete own sharing preferences" ON profile_sharing_preferences;

-- ============================================================================
-- accounts: Drop redundant SELECT policy
-- "Users can view their accounts" uses has_account_access(id)
-- "Users can read their own accounts" uses owner_user_id OR EXISTS(account_members)
-- These cover the same access. Keep the direct one (no function call overhead).
-- ============================================================================

DROP POLICY IF EXISTS "Users can view their accounts" ON accounts;

-- ============================================================================
-- account_members: Merge duplicate policies per action
-- ============================================================================

-- SELECT: "Users can read their own memberships" (user_id = auth.uid())
--       + "Users can view account members" (has_account_access(account_id))
-- Keep the direct one, drop the helper-function one (same access, less overhead)
DROP POLICY IF EXISTS "Users can view account members" ON account_members;

-- INSERT: "Users can insert themselves as members" (user_id = auth.uid())
--        + "Owners and admins can add members" (is_owner_or_admin(account_id))
-- These serve different purposes — self-insert vs admin-add-others.
-- Merge into single policy.
DROP POLICY IF EXISTS "Users can insert themselves as members" ON account_members;
DROP POLICY IF EXISTS "Owners and admins can add members" ON account_members;
CREATE POLICY "Users can insert account members"
    ON account_members FOR INSERT
    WITH CHECK (
        user_id = (select auth.uid())
        OR is_owner_or_admin(account_id)
    );

-- UPDATE: "Users can update account members" (user_id = auth.uid())
--        + "Owners can update member roles" (get_user_role(account_id) = 'owner')
-- Merge into single policy.
DROP POLICY IF EXISTS "Users can update account members" ON account_members;
DROP POLICY IF EXISTS "Owners can update member roles" ON account_members;
CREATE POLICY "Users can update account members"
    ON account_members FOR UPDATE
    USING (
        user_id = (select auth.uid())
        OR get_user_role(account_id) = 'owner'
    );

-- DELETE: "Users can delete account members" (user_id = auth.uid())
--        + "Owners can remove members or self-remove" (get_user_role = 'owner' OR user_id = auth.uid())
-- "Owners can remove" already includes user_id = auth.uid(), so the other is redundant.
DROP POLICY IF EXISTS "Users can delete account members" ON account_members;

-- ============================================================================
-- profiles: Drop redundant helper-function policies
-- Keep the direct auth.uid() policies (already optimized with select wrapper).
-- Drop the helper-function duplicates.
-- ============================================================================

-- SELECT: "Users can read profiles in their accounts" (EXISTS + auth.uid())
--        + "Users can view profiles" (has_account_access)
DROP POLICY IF EXISTS "Users can view profiles" ON profiles;

-- INSERT: "Users can create profiles in their accounts" (EXISTS + auth.uid())
--        + "Writers can create profiles" (can_write_to_account)
DROP POLICY IF EXISTS "Writers can create profiles" ON profiles;

-- UPDATE: "Users can update profiles in their accounts" (EXISTS + auth.uid())
--        + "Writers can update profiles" (can_write_to_account)
DROP POLICY IF EXISTS "Writers can update profiles" ON profiles;

-- DELETE: "Users can delete profiles in their accounts" (EXISTS + auth.uid())
--        + "Owners and admins can delete profiles" (is_owner_or_admin)
-- These have different access levels — the first allows any member to delete,
-- the second restricts to owners/admins. Both exist so any member can delete.
-- Drop the more restrictive one since the broader one already allows access.
DROP POLICY IF EXISTS "Owners and admins can delete profiles" ON profiles;

-- ============================================================================
-- countdowns: Merge two SELECT policies into one
-- "Users can view countdowns in their accounts" (account_members subquery)
-- + "Users can read countdowns shared with them" (get_shared_event_ids)
-- ============================================================================

DROP POLICY IF EXISTS "Users can view countdowns in their accounts" ON countdowns;
DROP POLICY IF EXISTS "Users can read countdowns shared with them" ON countdowns;
CREATE POLICY "Users can view countdowns"
    ON countdowns FOR SELECT
    USING (
        account_id IN (
            SELECT account_id FROM account_members
            WHERE user_id = (select auth.uid())
        )
        OR id IN (SELECT get_shared_event_ids((select auth.uid()), 'countdown'))
    );

-- ============================================================================
-- appointments: Merge two SELECT policies into one
-- "Users can view appointments" (has_account_access)
-- + "Users can read appointments shared with them" (get_shared_event_ids)
-- ============================================================================

DROP POLICY IF EXISTS "Users can view appointments" ON appointments;
DROP POLICY IF EXISTS "Users can read appointments shared with them" ON appointments;
CREATE POLICY "Users can view appointments"
    ON appointments FOR SELECT
    USING (
        has_account_access(account_id)
        OR id IN (SELECT get_shared_event_ids((select auth.uid()), 'appointment'))
    );

-- ============================================================================
-- family_calendar_shares: Merge two SELECT policies into one
-- "Account members can view shares" (EXISTS + account_members)
-- + "Users can view shares they are members of" (is_share_member)
-- ============================================================================

DROP POLICY IF EXISTS "Account members can view shares" ON family_calendar_shares;
DROP POLICY IF EXISTS "Users can view shares they are members of" ON family_calendar_shares;
CREATE POLICY "Users can view shares"
    ON family_calendar_shares FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM account_members am
            WHERE am.account_id = family_calendar_shares.account_id
            AND am.user_id = (select auth.uid())
        )
        OR is_share_member(id, (select auth.uid()))
    );

-- ============================================================================
-- family_calendar_share_members: Merge two SELECT policies into one
-- "Users can view their own memberships" (auth.uid() = member_user_id)
-- + "Account members can view share members" (is_share_account_member)
-- ============================================================================

DROP POLICY IF EXISTS "Users can view their own memberships" ON family_calendar_share_members;
DROP POLICY IF EXISTS "Account members can view share members" ON family_calendar_share_members;
CREATE POLICY "Users can view share members"
    ON family_calendar_share_members FOR SELECT
    USING (
        (select auth.uid()) = member_user_id
        OR is_share_account_member(share_id, (select auth.uid()))
    );

-- ============================================================================
-- account_invitations: Merge two SELECT policies into one
-- "Anyone can lookup invitation by code" (true — allows all)
-- + "Users can view invitations for their accounts" (account_members subquery)
-- Since "Anyone can lookup" uses USING(true), it already allows everything.
-- The other policy is redundant. Keep only the broad one.
-- ============================================================================

DROP POLICY IF EXISTS "Users can view invitations for their accounts" ON account_invitations;

-- ============================================================================
-- app_users: Merge two SELECT policies into one
-- "Users can read own app_user record" (auth.uid() = id)
-- + "App admins can read all app_user records" (is_app_admin)
-- ============================================================================

DROP POLICY IF EXISTS "Users can read own app_user record" ON app_users;
DROP POLICY IF EXISTS "App admins can read all app_user records" ON app_users;
CREATE POLICY "Users can read app_user records"
    ON app_users FOR SELECT
    USING (
        (select auth.uid()) = id
        OR is_app_admin((select auth.uid())) = true
    );

COMMIT;
