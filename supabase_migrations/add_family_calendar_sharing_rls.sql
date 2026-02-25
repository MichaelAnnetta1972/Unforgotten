-- Migration: Add RLS policies for cross-account family calendar sharing
-- Run this in your Supabase SQL Editor
--
-- Problem: When User A shares a countdown/appointment with User B (different account),
-- User B cannot see the shared events because RLS policies restrict reads to the
-- user's own account. This migration adds SELECT policies so users can read:
-- 1. family_calendar_shares where they are the sharer or a member
-- 2. family_calendar_share_members where they are the member
-- 3. countdowns/appointments that have been shared with them

-- ============================================================================
-- PART 1: Ensure RLS is enabled on family calendar tables
-- ============================================================================

ALTER TABLE family_calendar_shares ENABLE ROW LEVEL SECURITY;
ALTER TABLE family_calendar_share_members ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- PART 2: family_calendar_shares policies
-- ============================================================================

-- Drop existing policies if any to avoid conflicts
DROP POLICY IF EXISTS "Users can view shares they created" ON family_calendar_shares;
DROP POLICY IF EXISTS "Users can view shares they are members of" ON family_calendar_shares;
DROP POLICY IF EXISTS "Users can create shares" ON family_calendar_shares;
DROP POLICY IF EXISTS "Users can delete their own shares" ON family_calendar_shares;
DROP POLICY IF EXISTS "Users can update their own shares" ON family_calendar_shares;

-- Users can read shares they created
CREATE POLICY "Users can view shares they created"
    ON family_calendar_shares
    FOR SELECT
    USING (auth.uid() = shared_by_user_id);

-- Users can read shares where they are a member (cross-account visibility)
CREATE POLICY "Users can view shares they are members of"
    ON family_calendar_shares
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM family_calendar_share_members fcsm
            WHERE fcsm.share_id = family_calendar_shares.id
            AND fcsm.member_user_id = auth.uid()
        )
    );

-- Users can create shares (for their own account)
CREATE POLICY "Users can create shares"
    ON family_calendar_shares
    FOR INSERT
    WITH CHECK (auth.uid() = shared_by_user_id);

-- Users can delete their own shares
CREATE POLICY "Users can delete their own shares"
    ON family_calendar_shares
    FOR DELETE
    USING (auth.uid() = shared_by_user_id);

-- Users can update their own shares
CREATE POLICY "Users can update their own shares"
    ON family_calendar_shares
    FOR UPDATE
    USING (auth.uid() = shared_by_user_id);

-- ============================================================================
-- PART 3: family_calendar_share_members policies
-- ============================================================================

-- Drop existing policies if any
DROP POLICY IF EXISTS "Users can view their own memberships" ON family_calendar_share_members;
DROP POLICY IF EXISTS "Share creators can view members" ON family_calendar_share_members;
DROP POLICY IF EXISTS "Share creators can manage members" ON family_calendar_share_members;
DROP POLICY IF EXISTS "Share creators can add members" ON family_calendar_share_members;
DROP POLICY IF EXISTS "Share creators can remove members" ON family_calendar_share_members;

-- Users can see memberships where they are the member
CREATE POLICY "Users can view their own memberships"
    ON family_calendar_share_members
    FOR SELECT
    USING (auth.uid() = member_user_id);

-- Share creators can view all members of their shares
CREATE POLICY "Share creators can view members"
    ON family_calendar_share_members
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM family_calendar_shares fcs
            WHERE fcs.id = family_calendar_share_members.share_id
            AND fcs.shared_by_user_id = auth.uid()
        )
    );

-- Share creators can add members
CREATE POLICY "Share creators can add members"
    ON family_calendar_share_members
    FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM family_calendar_shares fcs
            WHERE fcs.id = family_calendar_share_members.share_id
            AND fcs.shared_by_user_id = auth.uid()
        )
    );

-- Share creators can remove members
CREATE POLICY "Share creators can remove members"
    ON family_calendar_share_members
    FOR DELETE
    USING (
        EXISTS (
            SELECT 1 FROM family_calendar_shares fcs
            WHERE fcs.id = family_calendar_share_members.share_id
            AND fcs.shared_by_user_id = auth.uid()
        )
    );

-- ============================================================================
-- PART 4: Allow reading shared countdowns across accounts
-- ============================================================================

-- Drop existing policy if any
DROP POLICY IF EXISTS "Users can read countdowns shared with them" ON countdowns;

-- Users can read countdowns that have been shared with them via family calendar
CREATE POLICY "Users can read countdowns shared with them"
    ON countdowns
    FOR SELECT
    USING (
        id IN (
            SELECT fcs.event_id
            FROM family_calendar_shares fcs
            INNER JOIN family_calendar_share_members fcsm ON fcsm.share_id = fcs.id
            WHERE fcs.event_type = 'countdown'
            AND fcsm.member_user_id = auth.uid()
        )
    );

-- ============================================================================
-- PART 5: Allow reading shared appointments across accounts
-- ============================================================================

-- Drop existing policy if any
DROP POLICY IF EXISTS "Users can read appointments shared with them" ON appointments;

-- Users can read appointments that have been shared with them via family calendar
CREATE POLICY "Users can read appointments shared with them"
    ON appointments
    FOR SELECT
    USING (
        id IN (
            SELECT fcs.event_id
            FROM family_calendar_shares fcs
            INNER JOIN family_calendar_share_members fcsm ON fcsm.share_id = fcs.id
            WHERE fcs.event_type = 'appointment'
            AND fcsm.member_user_id = auth.uid()
        )
    );

-- ============================================================================
-- PART 6: Indexes for performance
-- ============================================================================

-- Index on share_members for faster membership lookups by user
CREATE INDEX IF NOT EXISTS idx_family_calendar_share_members_user
    ON family_calendar_share_members(member_user_id);

-- Index on share_members for faster lookups by share
CREATE INDEX IF NOT EXISTS idx_family_calendar_share_members_share
    ON family_calendar_share_members(share_id);

-- Index on shares for faster lookups by sharer
CREATE INDEX IF NOT EXISTS idx_family_calendar_shares_shared_by
    ON family_calendar_shares(shared_by_user_id);

-- Index on shares for event lookups
CREATE INDEX IF NOT EXISTS idx_family_calendar_shares_event
    ON family_calendar_shares(event_type, event_id);
