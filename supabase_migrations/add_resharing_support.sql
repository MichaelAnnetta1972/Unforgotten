-- Migration: Add re-sharing support for family calendar events
-- Allows recipients of shared events to re-share with their own family members (one level deep).
--
-- Design:
-- - Recipients create their OWN share record pointing to the same event_id
-- - Original owner's share is untouched
-- - Re-shares are limited to one level: only direct recipients of the original
--   owner can re-share (not recipients of re-shares)
-- - When the original owner revokes a recipient, that recipient's re-shares
--   are automatically cleaned up

-- ============================================================================
-- STEP 1: Add source_share_id column to track re-shares
-- ============================================================================
-- NULL = original share, non-NULL = re-share (points to the share that granted access)

ALTER TABLE family_calendar_shares
ADD COLUMN IF NOT EXISTS source_share_id UUID REFERENCES family_calendar_shares(id) ON DELETE CASCADE;

-- Index for efficient lookups of re-shares by source
CREATE INDEX IF NOT EXISTS idx_family_calendar_shares_source
    ON family_calendar_shares(source_share_id)
    WHERE source_share_id IS NOT NULL;

-- ============================================================================
-- STEP 2: RLS policy for re-sharing (INSERT)
-- ============================================================================
-- Allow a user to create a share if:
--   1. They are a member of an existing share for the same event (they received the event)
--   2. That existing share is an original share (source_share_id IS NULL) — one level deep
--   3. The new share's source_share_id references the original share

-- Helper: does this share exist and is it an original (not itself a re-share)?
-- SECURITY DEFINER so it bypasses RLS on family_calendar_shares and avoids recursion
-- when used from a policy ON family_calendar_shares.
CREATE OR REPLACE FUNCTION is_original_share(p_share_id UUID)
RETURNS BOOLEAN AS $$
    SELECT EXISTS (
        SELECT 1 FROM family_calendar_shares
        WHERE id = p_share_id
          AND source_share_id IS NULL
    );
$$ LANGUAGE sql SECURITY DEFINER STABLE;

DROP POLICY IF EXISTS "Members can re-share events" ON family_calendar_shares;
CREATE POLICY "Members can re-share events"
    ON family_calendar_shares
    FOR INSERT
    WITH CHECK (
        -- Must be a re-share (source_share_id is set)
        family_calendar_shares.source_share_id IS NOT NULL
        -- The user creating the re-share must be the shared_by_user_id
        AND auth.uid() = family_calendar_shares.shared_by_user_id
        -- The source share must be an original share (not itself a re-share).
        -- Uses SECURITY DEFINER helper to bypass RLS and avoid recursion.
        AND is_original_share(family_calendar_shares.source_share_id)
        -- The user must be a member of the source share.
        -- is_share_member is defined in fix_family_calendar_sharing_rls.sql.
        AND is_share_member(family_calendar_shares.source_share_id, auth.uid())
    );

-- ============================================================================
-- STEP 3: Allow re-sharers to manage their own re-share members
-- ============================================================================
-- The existing "Share creators can add members" and "Share creators can remove members"
-- policies already check shared_by_user_id = auth.uid(), which will work for re-shares
-- since the re-sharer is the shared_by_user_id on their re-share record.

-- Allow re-sharers to delete their own re-shares
DROP POLICY IF EXISTS "Re-sharers can delete their re-shares" ON family_calendar_shares;
CREATE POLICY "Re-sharers can delete their re-shares"
    ON family_calendar_shares
    FOR DELETE
    USING (
        source_share_id IS NOT NULL
        AND auth.uid() = shared_by_user_id
    );

-- Allow re-sharers to update their own re-shares
DROP POLICY IF EXISTS "Re-sharers can update their re-shares" ON family_calendar_shares;
CREATE POLICY "Re-sharers can update their re-shares"
    ON family_calendar_shares
    FOR UPDATE
    USING (
        source_share_id IS NOT NULL
        AND auth.uid() = shared_by_user_id
    );

-- ============================================================================
-- STEP 4: Cascade cleanup — when a member is removed from original share,
-- delete any re-shares they created from that share
-- ============================================================================

CREATE OR REPLACE FUNCTION cleanup_reshares_on_member_removal()
RETURNS TRIGGER AS $$
BEGIN
    -- When a member is removed from a share, delete any re-shares they created
    -- that reference the share they were removed from
    DELETE FROM family_calendar_shares
    WHERE source_share_id = OLD.share_id
    AND shared_by_user_id = OLD.member_user_id;

    RETURN OLD;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_cleanup_reshares_on_member_removal ON family_calendar_share_members;
CREATE TRIGGER trg_cleanup_reshares_on_member_removal
    AFTER DELETE ON family_calendar_share_members
    FOR EACH ROW EXECUTE FUNCTION cleanup_reshares_on_member_removal();

-- ============================================================================
-- STEP 5: Function to check if an event can be re-shared by a user
-- Returns true if the user is a direct recipient of an original share
-- ============================================================================

CREATE OR REPLACE FUNCTION can_reshare_event(
    p_user_id UUID,
    p_event_type TEXT,
    p_event_id UUID
)
RETURNS BOOLEAN AS $$
    SELECT EXISTS (
        SELECT 1
        FROM family_calendar_shares fcs
        INNER JOIN family_calendar_share_members fcsm ON fcsm.share_id = fcs.id
        WHERE fcs.event_type = p_event_type
        AND fcs.event_id = p_event_id
        AND fcs.source_share_id IS NULL  -- must be original share
        AND fcsm.member_user_id = p_user_id
    );
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- ============================================================================
-- STEP 6: Function to get the source share id for re-sharing
-- Returns the original share ID that granted the user access
-- ============================================================================

CREATE OR REPLACE FUNCTION get_source_share_id(
    p_user_id UUID,
    p_event_type TEXT,
    p_event_id UUID
)
RETURNS UUID AS $$
    SELECT fcs.id
    FROM family_calendar_shares fcs
    INNER JOIN family_calendar_share_members fcsm ON fcsm.share_id = fcs.id
    WHERE fcs.event_type = p_event_type
    AND fcs.event_id = p_event_id
    AND fcs.source_share_id IS NULL  -- must be original share
    AND fcsm.member_user_id = p_user_id
    LIMIT 1;
$$ LANGUAGE sql SECURITY DEFINER STABLE;
