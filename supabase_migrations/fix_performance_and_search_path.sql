-- Migration: Fix Supabase Performance & Security Alerts
-- Date: 2026-02-22
--
-- Fixes two categories of Supabase linter warnings:
--
-- 1. auth_rls_initplan (PERFORMANCE): RLS policies using auth.uid() directly
--    are re-evaluated per row. Wrapping in (select auth.uid()) makes PostgreSQL
--    evaluate it once as an init plan.
--    See: https://supabase.com/docs/guides/database/postgres/row-level-security#call-functions-with-select
--
-- 2. function_search_path_mutable (SECURITY): Functions without an explicit
--    SET search_path could be exploited via schema injection.
--    See: https://supabase.com/docs/guides/database/database-linter?lint=0009_function_search_path_mutable
--
-- Policy definitions verified against live database via pg_policies query.
-- Runs in a transaction so DROP + CREATE is atomic.
--
-- NOTE: Policies that only use helper functions (has_account_access, can_write_to_account,
-- is_owner_or_admin, get_user_role) are NOT touched here — auth.uid() is evaluated
-- inside those SECURITY DEFINER functions, not in the policy expression itself.
-- Those functions get search_path fixes in Part 2 instead.

BEGIN;

-- ============================================================================
-- PART 1: FIX RLS INITPLAN WARNINGS
-- Only policies with direct auth.uid() calls in their USING/WITH CHECK clauses
-- ============================================================================

-- --------------------------------------------------------------------------
-- accounts
-- --------------------------------------------------------------------------

-- Original: (auth.uid() = owner_user_id)
DROP POLICY IF EXISTS "Users can create accounts" ON accounts;
CREATE POLICY "Users can create accounts"
    ON accounts FOR INSERT
    WITH CHECK ((select auth.uid()) = owner_user_id);

-- Original: ((owner_user_id = auth.uid()) OR (EXISTS (SELECT 1 FROM account_members WHERE ...)))
DROP POLICY IF EXISTS "Users can read their own accounts" ON accounts;
CREATE POLICY "Users can read their own accounts"
    ON accounts FOR SELECT
    USING (
        owner_user_id = (select auth.uid())
        OR EXISTS (
            SELECT 1 FROM account_members
            WHERE account_members.account_id = accounts.id
            AND account_members.user_id = (select auth.uid())
        )
    );

-- Original: (owner_user_id = auth.uid())
DROP POLICY IF EXISTS "Owners can update accounts" ON accounts;
CREATE POLICY "Owners can update accounts"
    ON accounts FOR UPDATE
    USING (owner_user_id = (select auth.uid()));

-- Original: (owner_user_id = auth.uid())
DROP POLICY IF EXISTS "Owners can delete accounts" ON accounts;
CREATE POLICY "Owners can delete accounts"
    ON accounts FOR DELETE
    USING (owner_user_id = (select auth.uid()));

-- --------------------------------------------------------------------------
-- account_members
-- --------------------------------------------------------------------------

-- Original: (user_id = auth.uid())
DROP POLICY IF EXISTS "Users can insert themselves as members" ON account_members;
CREATE POLICY "Users can insert themselves as members"
    ON account_members FOR INSERT
    WITH CHECK (user_id = (select auth.uid()));

-- Original: (user_id = auth.uid())
DROP POLICY IF EXISTS "Users can read their own memberships" ON account_members;
CREATE POLICY "Users can read their own memberships"
    ON account_members FOR SELECT
    USING (user_id = (select auth.uid()));

-- Original: (user_id = auth.uid())
DROP POLICY IF EXISTS "Users can update account members" ON account_members;
CREATE POLICY "Users can update account members"
    ON account_members FOR UPDATE
    USING (user_id = (select auth.uid()));

-- Original: (user_id = auth.uid())
DROP POLICY IF EXISTS "Users can delete account members" ON account_members;
CREATE POLICY "Users can delete account members"
    ON account_members FOR DELETE
    USING (user_id = (select auth.uid()));

-- Original: ((get_user_role(account_id) = 'owner') OR (user_id = auth.uid()))
DROP POLICY IF EXISTS "Owners can remove members or self-remove" ON account_members;
CREATE POLICY "Owners can remove members or self-remove"
    ON account_members FOR DELETE
    USING (
        get_user_role(account_id) = 'owner'
        OR user_id = (select auth.uid())
    );

-- --------------------------------------------------------------------------
-- profiles
-- --------------------------------------------------------------------------

-- Original: EXISTS (SELECT 1 FROM account_members WHERE ... AND user_id = auth.uid())
DROP POLICY IF EXISTS "Users can create profiles in their accounts" ON profiles;
CREATE POLICY "Users can create profiles in their accounts"
    ON profiles FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM account_members
            WHERE account_members.account_id = profiles.account_id
            AND account_members.user_id = (select auth.uid())
        )
    );

DROP POLICY IF EXISTS "Users can read profiles in their accounts" ON profiles;
CREATE POLICY "Users can read profiles in their accounts"
    ON profiles FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM account_members
            WHERE account_members.account_id = profiles.account_id
            AND account_members.user_id = (select auth.uid())
        )
    );

DROP POLICY IF EXISTS "Users can update profiles in their accounts" ON profiles;
CREATE POLICY "Users can update profiles in their accounts"
    ON profiles FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM account_members
            WHERE account_members.account_id = profiles.account_id
            AND account_members.user_id = (select auth.uid())
        )
    );

DROP POLICY IF EXISTS "Users can delete profiles in their accounts" ON profiles;
CREATE POLICY "Users can delete profiles in their accounts"
    ON profiles FOR DELETE
    USING (
        EXISTS (
            SELECT 1 FROM account_members
            WHERE account_members.account_id = profiles.account_id
            AND account_members.user_id = (select auth.uid())
        )
    );

-- --------------------------------------------------------------------------
-- mood_entries
-- --------------------------------------------------------------------------

-- Original: (has_account_access(account_id) AND (user_id = auth.uid()))
DROP POLICY IF EXISTS "Users can create mood entries" ON mood_entries;
CREATE POLICY "Users can create mood entries"
    ON mood_entries FOR INSERT
    WITH CHECK (has_account_access(account_id) AND user_id = (select auth.uid()));

-- Original: (user_id = auth.uid())
DROP POLICY IF EXISTS "Users can update their mood entries" ON mood_entries;
CREATE POLICY "Users can update their mood entries"
    ON mood_entries FOR UPDATE
    USING (user_id = (select auth.uid()));

-- Original: (user_id = auth.uid())
DROP POLICY IF EXISTS "Users can delete their mood entries" ON mood_entries;
CREATE POLICY "Users can delete their mood entries"
    ON mood_entries FOR DELETE
    USING (user_id = (select auth.uid()));

-- --------------------------------------------------------------------------
-- profile_connections
-- --------------------------------------------------------------------------

-- Original: account_id IN (SELECT ... WHERE user_id = auth.uid())
DROP POLICY IF EXISTS "Users can view connections for their accounts" ON profile_connections;
CREATE POLICY "Users can view connections for their accounts"
    ON profile_connections FOR SELECT
    USING (
        account_id IN (
            SELECT account_id FROM account_members
            WHERE user_id = (select auth.uid())
        )
    );

-- Original: account_id IN (SELECT ... WHERE user_id = auth.uid() AND role IN (...))
DROP POLICY IF EXISTS "Users can create connections for their accounts" ON profile_connections;
CREATE POLICY "Users can create connections for their accounts"
    ON profile_connections FOR INSERT
    WITH CHECK (
        account_id IN (
            SELECT account_id FROM account_members
            WHERE user_id = (select auth.uid())
            AND role IN ('owner', 'admin', 'helper')
        )
    );

DROP POLICY IF EXISTS "Users can delete connections for their accounts" ON profile_connections;
CREATE POLICY "Users can delete connections for their accounts"
    ON profile_connections FOR DELETE
    USING (
        account_id IN (
            SELECT account_id FROM account_members
            WHERE user_id = (select auth.uid())
            AND role IN ('owner', 'admin', 'helper')
        )
    );

-- --------------------------------------------------------------------------
-- notes
-- --------------------------------------------------------------------------

-- Original: (user_id = auth.uid())
DROP POLICY IF EXISTS "Users can view their own notes" ON notes;
CREATE POLICY "Users can view their own notes"
    ON notes FOR SELECT
    USING (user_id = (select auth.uid()));

DROP POLICY IF EXISTS "Users can insert their own notes" ON notes;
CREATE POLICY "Users can insert their own notes"
    ON notes FOR INSERT
    WITH CHECK (user_id = (select auth.uid()));

DROP POLICY IF EXISTS "Users can update their own notes" ON notes;
CREATE POLICY "Users can update their own notes"
    ON notes FOR UPDATE
    USING (user_id = (select auth.uid()));

DROP POLICY IF EXISTS "Users can delete their own notes" ON notes;
CREATE POLICY "Users can delete their own notes"
    ON notes FOR DELETE
    USING (user_id = (select auth.uid()));

-- --------------------------------------------------------------------------
-- account_invitations
-- --------------------------------------------------------------------------

-- Original: account_id IN (SELECT ... WHERE user_id = auth.uid())
DROP POLICY IF EXISTS "Users can view invitations for their accounts" ON account_invitations;
CREATE POLICY "Users can view invitations for their accounts"
    ON account_invitations FOR SELECT
    USING (
        account_id IN (
            SELECT account_id FROM account_members
            WHERE user_id = (select auth.uid())
        )
    );

-- Original: account_id IN (SELECT ... WHERE user_id = auth.uid() AND role IN ('owner','admin'))
DROP POLICY IF EXISTS "Admins can create invitations" ON account_invitations;
CREATE POLICY "Admins can create invitations"
    ON account_invitations FOR INSERT
    WITH CHECK (
        account_id IN (
            SELECT account_id FROM account_members
            WHERE user_id = (select auth.uid())
            AND role IN ('owner', 'admin')
        )
    );

DROP POLICY IF EXISTS "Admins can update invitations" ON account_invitations;
CREATE POLICY "Admins can update invitations"
    ON account_invitations FOR UPDATE
    USING (
        account_id IN (
            SELECT account_id FROM account_members
            WHERE user_id = (select auth.uid())
            AND role IN ('owner', 'admin')
        )
    );

DROP POLICY IF EXISTS "Admins can delete invitations" ON account_invitations;
CREATE POLICY "Admins can delete invitations"
    ON account_invitations FOR DELETE
    USING (
        account_id IN (
            SELECT account_id FROM account_members
            WHERE user_id = (select auth.uid())
            AND role IN ('owner', 'admin')
        )
    );

-- --------------------------------------------------------------------------
-- todo_list_types
-- --------------------------------------------------------------------------

DROP POLICY IF EXISTS "Users can view types for their accounts" ON todo_list_types;
CREATE POLICY "Users can view types for their accounts"
    ON todo_list_types FOR SELECT
    USING (
        account_id IN (
            SELECT account_id FROM account_members
            WHERE user_id = (select auth.uid())
        )
    );

DROP POLICY IF EXISTS "Users can insert types for their accounts" ON todo_list_types;
CREATE POLICY "Users can insert types for their accounts"
    ON todo_list_types FOR INSERT
    WITH CHECK (
        account_id IN (
            SELECT account_id FROM account_members
            WHERE user_id = (select auth.uid())
        )
    );

DROP POLICY IF EXISTS "Users can delete types for their accounts" ON todo_list_types;
CREATE POLICY "Users can delete types for their accounts"
    ON todo_list_types FOR DELETE
    USING (
        account_id IN (
            SELECT account_id FROM account_members
            WHERE user_id = (select auth.uid())
        )
    );

-- --------------------------------------------------------------------------
-- todo_lists
-- --------------------------------------------------------------------------

DROP POLICY IF EXISTS "Users can view lists for their accounts" ON todo_lists;
CREATE POLICY "Users can view lists for their accounts"
    ON todo_lists FOR SELECT
    USING (
        account_id IN (
            SELECT account_id FROM account_members
            WHERE user_id = (select auth.uid())
        )
    );

DROP POLICY IF EXISTS "Users can insert lists for their accounts" ON todo_lists;
CREATE POLICY "Users can insert lists for their accounts"
    ON todo_lists FOR INSERT
    WITH CHECK (
        account_id IN (
            SELECT account_id FROM account_members
            WHERE user_id = (select auth.uid())
        )
    );

DROP POLICY IF EXISTS "Users can update lists for their accounts" ON todo_lists;
CREATE POLICY "Users can update lists for their accounts"
    ON todo_lists FOR UPDATE
    USING (
        account_id IN (
            SELECT account_id FROM account_members
            WHERE user_id = (select auth.uid())
        )
    );

DROP POLICY IF EXISTS "Users can delete lists for their accounts" ON todo_lists;
CREATE POLICY "Users can delete lists for their accounts"
    ON todo_lists FOR DELETE
    USING (
        account_id IN (
            SELECT account_id FROM account_members
            WHERE user_id = (select auth.uid())
        )
    );

-- --------------------------------------------------------------------------
-- todo_items
-- --------------------------------------------------------------------------

DROP POLICY IF EXISTS "Users can view items for their lists" ON todo_items;
CREATE POLICY "Users can view items for their lists"
    ON todo_items FOR SELECT
    USING (
        list_id IN (
            SELECT id FROM todo_lists WHERE account_id IN (
                SELECT account_id FROM account_members
                WHERE user_id = (select auth.uid())
            )
        )
    );

DROP POLICY IF EXISTS "Users can insert items for their lists" ON todo_items;
CREATE POLICY "Users can insert items for their lists"
    ON todo_items FOR INSERT
    WITH CHECK (
        list_id IN (
            SELECT id FROM todo_lists WHERE account_id IN (
                SELECT account_id FROM account_members
                WHERE user_id = (select auth.uid())
            )
        )
    );

DROP POLICY IF EXISTS "Users can update items for their lists" ON todo_items;
CREATE POLICY "Users can update items for their lists"
    ON todo_items FOR UPDATE
    USING (
        list_id IN (
            SELECT id FROM todo_lists WHERE account_id IN (
                SELECT account_id FROM account_members
                WHERE user_id = (select auth.uid())
            )
        )
    );

DROP POLICY IF EXISTS "Users can delete items for their lists" ON todo_items;
CREATE POLICY "Users can delete items for their lists"
    ON todo_items FOR DELETE
    USING (
        list_id IN (
            SELECT id FROM todo_lists WHERE account_id IN (
                SELECT account_id FROM account_members
                WHERE user_id = (select auth.uid())
            )
        )
    );

-- --------------------------------------------------------------------------
-- important_accounts
-- --------------------------------------------------------------------------

DROP POLICY IF EXISTS "Users can view accounts for profiles they have access to" ON important_accounts;
CREATE POLICY "Users can view accounts for profiles they have access to"
    ON important_accounts FOR SELECT
    USING (
        profile_id IN (
            SELECT id FROM profiles WHERE account_id IN (
                SELECT account_id FROM account_members
                WHERE user_id = (select auth.uid())
            )
        )
    );

DROP POLICY IF EXISTS "Users can insert accounts for profiles they have access to" ON important_accounts;
CREATE POLICY "Users can insert accounts for profiles they have access to"
    ON important_accounts FOR INSERT
    WITH CHECK (
        profile_id IN (
            SELECT id FROM profiles WHERE account_id IN (
                SELECT account_id FROM account_members
                WHERE user_id = (select auth.uid())
            )
        )
    );

DROP POLICY IF EXISTS "Users can update accounts for profiles they have access to" ON important_accounts;
CREATE POLICY "Users can update accounts for profiles they have access to"
    ON important_accounts FOR UPDATE
    USING (
        profile_id IN (
            SELECT id FROM profiles WHERE account_id IN (
                SELECT account_id FROM account_members
                WHERE user_id = (select auth.uid())
            )
        )
    );

DROP POLICY IF EXISTS "Users can delete accounts for profiles they have access to" ON important_accounts;
CREATE POLICY "Users can delete accounts for profiles they have access to"
    ON important_accounts FOR DELETE
    USING (
        profile_id IN (
            SELECT id FROM profiles WHERE account_id IN (
                SELECT account_id FROM account_members
                WHERE user_id = (select auth.uid())
            )
        )
    );

-- --------------------------------------------------------------------------
-- sticky_reminders
-- --------------------------------------------------------------------------

-- Original: account_id IN (SELECT ... WHERE user_id = auth.uid())
DROP POLICY IF EXISTS "Users can access their account's sticky reminders" ON sticky_reminders;
CREATE POLICY "Users can access their account's sticky reminders"
    ON sticky_reminders FOR ALL
    USING (
        account_id IN (
            SELECT account_id FROM account_members
            WHERE user_id = (select auth.uid())
        )
    );

-- --------------------------------------------------------------------------
-- app_users
-- --------------------------------------------------------------------------

-- Original: (auth.uid() = id)
DROP POLICY IF EXISTS "Users can read own app_user record" ON app_users;
CREATE POLICY "Users can read own app_user record"
    ON app_users FOR SELECT
    USING ((select auth.uid()) = id);

DROP POLICY IF EXISTS "Users can insert own app_user record" ON app_users;
CREATE POLICY "Users can insert own app_user record"
    ON app_users FOR INSERT
    WITH CHECK ((select auth.uid()) = id);

-- Original: (is_app_admin(auth.uid()) = true)
DROP POLICY IF EXISTS "App admins can read all app_user records" ON app_users;
CREATE POLICY "App admins can read all app_user records"
    ON app_users FOR SELECT
    USING (is_app_admin((select auth.uid())) = true);

-- Original: (is_app_admin(auth.uid()) = true)
DROP POLICY IF EXISTS "App admins can update app_user records" ON app_users;
CREATE POLICY "App admins can update app_user records"
    ON app_users FOR UPDATE
    USING (is_app_admin((select auth.uid())) = true);

-- --------------------------------------------------------------------------
-- user_preferences
-- --------------------------------------------------------------------------

-- Original: (auth.uid() = user_id)
DROP POLICY IF EXISTS "Users can read own preferences" ON user_preferences;
CREATE POLICY "Users can read own preferences"
    ON user_preferences FOR SELECT
    USING ((select auth.uid()) = user_id);

DROP POLICY IF EXISTS "Users can insert own preferences" ON user_preferences;
CREATE POLICY "Users can insert own preferences"
    ON user_preferences FOR INSERT
    WITH CHECK ((select auth.uid()) = user_id);

DROP POLICY IF EXISTS "Users can update own preferences" ON user_preferences;
CREATE POLICY "Users can update own preferences"
    ON user_preferences FOR UPDATE
    USING ((select auth.uid()) = user_id);

DROP POLICY IF EXISTS "Users can delete own preferences" ON user_preferences;
CREATE POLICY "Users can delete own preferences"
    ON user_preferences FOR DELETE
    USING ((select auth.uid()) = user_id);

-- --------------------------------------------------------------------------
-- profile_syncs (only SELECT and UPDATE exist in DB)
-- --------------------------------------------------------------------------

-- Original: (auth.uid() = inviter_user_id OR auth.uid() = acceptor_user_id)
DROP POLICY IF EXISTS "Users can view their own profile syncs" ON profile_syncs;
CREATE POLICY "Users can view their own profile syncs"
    ON profile_syncs FOR SELECT
    USING (
        (select auth.uid()) = inviter_user_id
        OR (select auth.uid()) = acceptor_user_id
    );

DROP POLICY IF EXISTS "Users can update their own profile syncs" ON profile_syncs;
CREATE POLICY "Users can update their own profile syncs"
    ON profile_syncs FOR UPDATE
    USING (
        (select auth.uid()) = inviter_user_id
        OR (select auth.uid()) = acceptor_user_id
    );

-- --------------------------------------------------------------------------
-- profile_detail_syncs (only SELECT exists in DB)
-- --------------------------------------------------------------------------

-- Original: EXISTS (SELECT 1 FROM profile_syncs ps WHERE ... AND (auth.uid() = ...))
DROP POLICY IF EXISTS "Users can view their profile detail syncs" ON profile_detail_syncs;
CREATE POLICY "Users can view their profile detail syncs"
    ON profile_detail_syncs FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM profile_syncs ps
            WHERE ps.id = profile_detail_syncs.sync_connection_id
            AND ((select auth.uid()) = ps.inviter_user_id OR (select auth.uid()) = ps.acceptor_user_id)
        )
    );

-- --------------------------------------------------------------------------
-- profile_sharing_preferences (has both old and new policy names — fix all)
-- --------------------------------------------------------------------------

-- Old policies (from before per-user update)
DROP POLICY IF EXISTS "Users can read own sharing preferences" ON profile_sharing_preferences;
CREATE POLICY "Users can read own sharing preferences"
    ON profile_sharing_preferences FOR SELECT
    USING ((select auth.uid()) = user_id);

DROP POLICY IF EXISTS "Users can insert own sharing preferences" ON profile_sharing_preferences;
CREATE POLICY "Users can insert own sharing preferences"
    ON profile_sharing_preferences FOR INSERT
    WITH CHECK ((select auth.uid()) = user_id);

DROP POLICY IF EXISTS "Users can update own sharing preferences" ON profile_sharing_preferences;
CREATE POLICY "Users can update own sharing preferences"
    ON profile_sharing_preferences FOR UPDATE
    USING ((select auth.uid()) = user_id);

DROP POLICY IF EXISTS "Users can delete own sharing preferences" ON profile_sharing_preferences;
CREATE POLICY "Users can delete own sharing preferences"
    ON profile_sharing_preferences FOR DELETE
    USING ((select auth.uid()) = user_id);

-- New policies (from per-user update)
DROP POLICY IF EXISTS "Users can read sharing preferences" ON profile_sharing_preferences;
CREATE POLICY "Users can read sharing preferences"
    ON profile_sharing_preferences FOR SELECT
    USING ((select auth.uid()) = user_id OR (select auth.uid()) = target_user_id);

DROP POLICY IF EXISTS "Users can insert sharing preferences" ON profile_sharing_preferences;
CREATE POLICY "Users can insert sharing preferences"
    ON profile_sharing_preferences FOR INSERT
    WITH CHECK ((select auth.uid()) = user_id);

DROP POLICY IF EXISTS "Users can update sharing preferences" ON profile_sharing_preferences;
CREATE POLICY "Users can update sharing preferences"
    ON profile_sharing_preferences FOR UPDATE
    USING ((select auth.uid()) = user_id);

DROP POLICY IF EXISTS "Users can delete sharing preferences" ON profile_sharing_preferences;
CREATE POLICY "Users can delete sharing preferences"
    ON profile_sharing_preferences FOR DELETE
    USING ((select auth.uid()) = user_id);

-- --------------------------------------------------------------------------
-- family_calendar_shares
-- --------------------------------------------------------------------------

-- Original: EXISTS (SELECT 1 FROM account_members am WHERE ... AND am.user_id = auth.uid())
DROP POLICY IF EXISTS "Account members can view shares" ON family_calendar_shares;
CREATE POLICY "Account members can view shares"
    ON family_calendar_shares FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM account_members am
            WHERE am.account_id = family_calendar_shares.account_id
            AND am.user_id = (select auth.uid())
        )
    );

-- Original: is_share_member(id, auth.uid())
DROP POLICY IF EXISTS "Users can view shares they are members of" ON family_calendar_shares;
CREATE POLICY "Users can view shares they are members of"
    ON family_calendar_shares FOR SELECT
    USING (is_share_member(id, (select auth.uid())));

DROP POLICY IF EXISTS "Account members can create shares" ON family_calendar_shares;
CREATE POLICY "Account members can create shares"
    ON family_calendar_shares FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM account_members am
            WHERE am.account_id = family_calendar_shares.account_id
            AND am.user_id = (select auth.uid())
        )
    );

-- Original: (auth.uid() = shared_by_user_id)
DROP POLICY IF EXISTS "Share creators can update shares" ON family_calendar_shares;
CREATE POLICY "Share creators can update shares"
    ON family_calendar_shares FOR UPDATE
    USING ((select auth.uid()) = shared_by_user_id);

DROP POLICY IF EXISTS "Share creators can delete shares" ON family_calendar_shares;
CREATE POLICY "Share creators can delete shares"
    ON family_calendar_shares FOR DELETE
    USING ((select auth.uid()) = shared_by_user_id);

-- --------------------------------------------------------------------------
-- family_calendar_share_members
-- --------------------------------------------------------------------------

-- Original: (auth.uid() = member_user_id)
DROP POLICY IF EXISTS "Users can view their own memberships" ON family_calendar_share_members;
CREATE POLICY "Users can view their own memberships"
    ON family_calendar_share_members FOR SELECT
    USING ((select auth.uid()) = member_user_id);

-- Original: is_share_account_member(share_id, auth.uid())
DROP POLICY IF EXISTS "Account members can view share members" ON family_calendar_share_members;
CREATE POLICY "Account members can view share members"
    ON family_calendar_share_members FOR SELECT
    USING (is_share_account_member(share_id, (select auth.uid())));

DROP POLICY IF EXISTS "Account members can add share members" ON family_calendar_share_members;
CREATE POLICY "Account members can add share members"
    ON family_calendar_share_members FOR INSERT
    WITH CHECK (is_share_account_member(share_id, (select auth.uid())));

-- Original: is_share_creator(share_id, auth.uid())
DROP POLICY IF EXISTS "Share creators can remove share members" ON family_calendar_share_members;
CREATE POLICY "Share creators can remove share members"
    ON family_calendar_share_members FOR DELETE
    USING (is_share_creator(share_id, (select auth.uid())));

-- --------------------------------------------------------------------------
-- countdowns
-- --------------------------------------------------------------------------

-- Original: id IN (SELECT get_shared_event_ids(auth.uid(), 'countdown'))
DROP POLICY IF EXISTS "Users can read countdowns shared with them" ON countdowns;
CREATE POLICY "Users can read countdowns shared with them"
    ON countdowns FOR SELECT
    USING (id IN (SELECT get_shared_event_ids((select auth.uid()), 'countdown')));

-- Original: account_id IN (SELECT ... WHERE user_id = auth.uid())
DROP POLICY IF EXISTS "Users can view countdowns in their accounts" ON countdowns;
CREATE POLICY "Users can view countdowns in their accounts"
    ON countdowns FOR SELECT
    USING (
        account_id IN (
            SELECT account_id FROM account_members
            WHERE user_id = (select auth.uid())
        )
    );

DROP POLICY IF EXISTS "Users can insert countdowns in their accounts" ON countdowns;
CREATE POLICY "Users can insert countdowns in their accounts"
    ON countdowns FOR INSERT
    WITH CHECK (
        account_id IN (
            SELECT account_id FROM account_members
            WHERE user_id = (select auth.uid())
        )
    );

DROP POLICY IF EXISTS "Users can update countdowns in their accounts" ON countdowns;
CREATE POLICY "Users can update countdowns in their accounts"
    ON countdowns FOR UPDATE
    USING (
        account_id IN (
            SELECT account_id FROM account_members
            WHERE user_id = (select auth.uid())
        )
    );

DROP POLICY IF EXISTS "Users can delete countdowns in their accounts" ON countdowns;
CREATE POLICY "Users can delete countdowns in their accounts"
    ON countdowns FOR DELETE
    USING (
        account_id IN (
            SELECT account_id FROM account_members
            WHERE user_id = (select auth.uid())
        )
    );

-- --------------------------------------------------------------------------
-- appointments (shared access policy only — other policies use helper functions)
-- --------------------------------------------------------------------------

-- Original: id IN (SELECT get_shared_event_ids(auth.uid(), 'appointment'))
DROP POLICY IF EXISTS "Users can read appointments shared with them" ON appointments;
CREATE POLICY "Users can read appointments shared with them"
    ON appointments FOR SELECT
    USING (id IN (SELECT get_shared_event_ids((select auth.uid()), 'appointment')));

-- --------------------------------------------------------------------------
-- recipes
-- --------------------------------------------------------------------------

DROP POLICY IF EXISTS "Users can view recipes for their accounts" ON recipes;
CREATE POLICY "Users can view recipes for their accounts"
    ON recipes FOR SELECT
    USING (account_id IN (
        SELECT account_id FROM account_members
        WHERE user_id = (select auth.uid())
    ));

DROP POLICY IF EXISTS "Users can insert recipes for their accounts" ON recipes;
CREATE POLICY "Users can insert recipes for their accounts"
    ON recipes FOR INSERT
    WITH CHECK (account_id IN (
        SELECT account_id FROM account_members
        WHERE user_id = (select auth.uid())
    ));

DROP POLICY IF EXISTS "Users can update recipes for their accounts" ON recipes;
CREATE POLICY "Users can update recipes for their accounts"
    ON recipes FOR UPDATE
    USING (account_id IN (
        SELECT account_id FROM account_members
        WHERE user_id = (select auth.uid())
    ));

DROP POLICY IF EXISTS "Users can delete recipes for their accounts" ON recipes;
CREATE POLICY "Users can delete recipes for their accounts"
    ON recipes FOR DELETE
    USING (account_id IN (
        SELECT account_id FROM account_members
        WHERE user_id = (select auth.uid())
    ));

-- --------------------------------------------------------------------------
-- planned_meals
-- --------------------------------------------------------------------------

DROP POLICY IF EXISTS "Users can view planned meals for their accounts" ON planned_meals;
CREATE POLICY "Users can view planned meals for their accounts"
    ON planned_meals FOR SELECT
    USING (account_id IN (
        SELECT account_id FROM account_members
        WHERE user_id = (select auth.uid())
    ));

DROP POLICY IF EXISTS "Users can insert planned meals for their accounts" ON planned_meals;
CREATE POLICY "Users can insert planned meals for their accounts"
    ON planned_meals FOR INSERT
    WITH CHECK (account_id IN (
        SELECT account_id FROM account_members
        WHERE user_id = (select auth.uid())
    ));

DROP POLICY IF EXISTS "Users can update planned meals for their accounts" ON planned_meals;
CREATE POLICY "Users can update planned meals for their accounts"
    ON planned_meals FOR UPDATE
    USING (account_id IN (
        SELECT account_id FROM account_members
        WHERE user_id = (select auth.uid())
    ));

DROP POLICY IF EXISTS "Users can delete planned meals for their accounts" ON planned_meals;
CREATE POLICY "Users can delete planned meals for their accounts"
    ON planned_meals FOR DELETE
    USING (account_id IN (
        SELECT account_id FROM account_members
        WHERE user_id = (select auth.uid())
    ));


-- ============================================================================
-- PART 2: FIX FUNCTION SEARCH_PATH WARNINGS
-- Exact function signatures from pg_proc query against live database.
-- ============================================================================

-- Trigger functions
ALTER FUNCTION public.update_updated_at_column() SET search_path = public;
ALTER FUNCTION public.update_profile_syncs_updated_at() SET search_path = public;
ALTER FUNCTION public.update_sharing_preferences_updated_at() SET search_path = public;
ALTER FUNCTION public.update_app_users_updated_at() SET search_path = public;
ALTER FUNCTION public.update_user_preferences_updated_at() SET search_path = public;
ALTER FUNCTION public.update_notes_updated_at() SET search_path = public;

-- Profile sync propagation triggers
ALTER FUNCTION public.propagate_profile_changes() SET search_path = public;
ALTER FUNCTION public.propagate_profile_detail_changes() SET search_path = public;

-- Cleanup triggers
ALTER FUNCTION public.cleanup_countdown_shares() SET search_path = public;
ALTER FUNCTION public.cleanup_appointment_shares() SET search_path = public;

-- RPC functions — accept_invitation_with_sync (both overloads from pg_proc)
ALTER FUNCTION public.accept_invitation_with_sync(uuid, uuid, uuid) SET search_path = public;
ALTER FUNCTION public.accept_invitation_with_sync(uuid, uuid, uuid, uuid, uuid) SET search_path = public;

ALTER FUNCTION public.sever_profile_sync(uuid, uuid) SET search_path = public;

-- update_sharing_preference (both overloads from pg_proc)
ALTER FUNCTION public.update_sharing_preference(uuid, text, boolean, uuid) SET search_path = public;
ALTER FUNCTION public.update_sharing_preference(uuid, text, boolean) SET search_path = public;

-- is_category_shared (both overloads from pg_proc)
ALTER FUNCTION public.is_category_shared(uuid, text, uuid) SET search_path = public;
ALTER FUNCTION public.is_category_shared(uuid, text) SET search_path = public;

-- Helper functions used in RLS policies (discovered from live DB query)
ALTER FUNCTION public.has_account_access(uuid) SET search_path = public;
ALTER FUNCTION public.is_owner_or_admin(uuid) SET search_path = public;
ALTER FUNCTION public.can_write_to_account(uuid) SET search_path = public;
ALTER FUNCTION public.get_user_role(uuid) SET search_path = public;

-- Other query helper functions
ALTER FUNCTION public.is_app_admin(uuid) SET search_path = public;
ALTER FUNCTION public.is_detail_synced(uuid) SET search_path = public;
ALTER FUNCTION public.get_sharing_category_key(text) SET search_path = public;
ALTER FUNCTION public.is_share_member(uuid, uuid) SET search_path = public;
ALTER FUNCTION public.is_share_creator(uuid, uuid) SET search_path = public;
ALTER FUNCTION public.is_share_account_member(uuid, uuid) SET search_path = public;
ALTER FUNCTION public.get_shared_event_ids(uuid, text) SET search_path = public;

-- Shared event fetch functions
ALTER FUNCTION public.get_shared_countdowns(uuid) SET search_path = public;
ALTER FUNCTION public.get_shared_appointments(uuid) SET search_path = public;

COMMIT;
