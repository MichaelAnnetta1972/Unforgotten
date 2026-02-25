-- Migration: Fix family calendar RLS policies (infinite recursion fix)
-- Run this in your Supabase SQL Editor
--
-- Uses SECURITY DEFINER functions to break the circular dependency between
-- family_calendar_shares and family_calendar_share_members RLS policies.

-- ============================================================================
-- PART 1: Ensure RLS is enabled
-- ============================================================================

ALTER TABLE family_calendar_shares ENABLE ROW LEVEL SECURITY;
ALTER TABLE family_calendar_share_members ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- PART 2: Drop ALL existing policies on both tables
-- ============================================================================

DO $$
DECLARE
    pol RECORD;
BEGIN
    FOR pol IN
        SELECT policyname FROM pg_policies WHERE tablename = 'family_calendar_shares'
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON family_calendar_shares', pol.policyname);
    END LOOP;
    FOR pol IN
        SELECT policyname FROM pg_policies WHERE tablename = 'family_calendar_share_members'
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON family_calendar_share_members', pol.policyname);
    END LOOP;
END $$;

-- ============================================================================
-- PART 3: SECURITY DEFINER helper functions (bypass RLS to break recursion)
-- ============================================================================

-- Check if a user is a member of a given share (bypasses RLS on share_members)
CREATE OR REPLACE FUNCTION is_share_member(p_share_id UUID, p_user_id UUID)
RETURNS BOOLEAN AS $$
    SELECT EXISTS (
        SELECT 1 FROM family_calendar_share_members
        WHERE share_id = p_share_id AND member_user_id = p_user_id
    );
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- Check if a user created a given share (bypasses RLS on shares)
CREATE OR REPLACE FUNCTION is_share_creator(p_share_id UUID, p_user_id UUID)
RETURNS BOOLEAN AS $$
    SELECT EXISTS (
        SELECT 1 FROM family_calendar_shares
        WHERE id = p_share_id AND shared_by_user_id = p_user_id
    );
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- Check if a user is an account member for a given share (bypasses RLS on shares)
CREATE OR REPLACE FUNCTION is_share_account_member(p_share_id UUID, p_user_id UUID)
RETURNS BOOLEAN AS $$
    SELECT EXISTS (
        SELECT 1 FROM family_calendar_shares fcs
        JOIN account_members am ON am.account_id = fcs.account_id
        WHERE fcs.id = p_share_id AND am.user_id = p_user_id
    );
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- Get shared event IDs for a user by event type (bypasses RLS)
CREATE OR REPLACE FUNCTION get_shared_event_ids(p_user_id UUID, p_event_type TEXT)
RETURNS SETOF UUID AS $$
    SELECT fcs.event_id
    FROM family_calendar_shares fcs
    INNER JOIN family_calendar_share_members fcsm ON fcsm.share_id = fcs.id
    WHERE fcs.event_type = p_event_type
    AND fcsm.member_user_id = p_user_id;
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- ============================================================================
-- PART 4: family_calendar_shares policies
-- ============================================================================

-- Account members can read shares for their account
CREATE POLICY "Account members can view shares"
    ON family_calendar_shares
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM account_members am
            WHERE am.account_id = family_calendar_shares.account_id
            AND am.user_id = auth.uid()
        )
    );

-- Cross-account: users can read shares where they are a member
-- Uses SECURITY DEFINER function to avoid recursion with share_members table
CREATE POLICY "Users can view shares they are members of"
    ON family_calendar_shares
    FOR SELECT
    USING (is_share_member(id, auth.uid()));

-- Account members can create shares for their account
CREATE POLICY "Account members can create shares"
    ON family_calendar_shares
    FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM account_members am
            WHERE am.account_id = family_calendar_shares.account_id
            AND am.user_id = auth.uid()
        )
    );

-- Share creators can update their shares
CREATE POLICY "Share creators can update shares"
    ON family_calendar_shares
    FOR UPDATE
    USING (auth.uid() = shared_by_user_id);

-- Share creators can delete their shares
CREATE POLICY "Share creators can delete shares"
    ON family_calendar_shares
    FOR DELETE
    USING (auth.uid() = shared_by_user_id);

-- ============================================================================
-- PART 5: family_calendar_share_members policies
-- ============================================================================

-- Users can see their own memberships (no cross-table lookup needed)
CREATE POLICY "Users can view their own memberships"
    ON family_calendar_share_members
    FOR SELECT
    USING (auth.uid() = member_user_id);

-- Share account members can view all members of shares in their account
-- Uses SECURITY DEFINER function to avoid recursion with shares table
CREATE POLICY "Account members can view share members"
    ON family_calendar_share_members
    FOR SELECT
    USING (is_share_account_member(share_id, auth.uid()));

-- Account members can add members to shares in their account
CREATE POLICY "Account members can add share members"
    ON family_calendar_share_members
    FOR INSERT
    WITH CHECK (is_share_account_member(share_id, auth.uid()));

-- Share creators can remove members
CREATE POLICY "Share creators can remove share members"
    ON family_calendar_share_members
    FOR DELETE
    USING (is_share_creator(share_id, auth.uid()));

-- ============================================================================
-- PART 6: Cross-account countdown/appointment read policies
-- ============================================================================

DROP POLICY IF EXISTS "Users can read countdowns shared with them" ON countdowns;

CREATE POLICY "Users can read countdowns shared with them"
    ON countdowns
    FOR SELECT
    USING (id IN (SELECT get_shared_event_ids(auth.uid(), 'countdown')));

DROP POLICY IF EXISTS "Users can read appointments shared with them" ON appointments;

CREATE POLICY "Users can read appointments shared with them"
    ON appointments
    FOR SELECT
    USING (id IN (SELECT get_shared_event_ids(auth.uid(), 'appointment')));

-- ============================================================================
-- PART 7: Indexes (idempotent)
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_family_calendar_share_members_user
    ON family_calendar_share_members(member_user_id);

CREATE INDEX IF NOT EXISTS idx_family_calendar_share_members_share
    ON family_calendar_share_members(share_id);

CREATE INDEX IF NOT EXISTS idx_family_calendar_shares_shared_by
    ON family_calendar_shares(shared_by_user_id);

CREATE INDEX IF NOT EXISTS idx_family_calendar_shares_event
    ON family_calendar_shares(event_type, event_id);

CREATE INDEX IF NOT EXISTS idx_family_calendar_shares_account
    ON family_calendar_shares(account_id);
