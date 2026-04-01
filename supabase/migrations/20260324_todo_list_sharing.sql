-- To Do List Sharing Migration
-- Created: 2026-03-24
-- Description: Adds RLS policies so that to-do lists shared via family_calendar_shares
-- are fully accessible (read/write) to the shared members.
-- Also adds a cleanup trigger to remove shares when a to-do list is deleted.

-- ============================================================================
-- STEP 1: Add RLS policies for shared to-do list access
-- ============================================================================

-- Allow shared members to SELECT todo_lists they've been shared on
CREATE POLICY "Shared members can view shared todo lists"
ON todo_lists FOR SELECT
USING (
    id IN (
        SELECT fcs.event_id
        FROM family_calendar_shares fcs
        JOIN family_calendar_share_members fcsm ON fcsm.share_id = fcs.id
        WHERE fcs.event_type = 'todo_list'
        AND fcsm.member_user_id = auth.uid()
    )
);

-- Allow shared members to UPDATE todo_lists they've been shared on
CREATE POLICY "Shared members can update shared todo lists"
ON todo_lists FOR UPDATE
USING (
    id IN (
        SELECT fcs.event_id
        FROM family_calendar_shares fcs
        JOIN family_calendar_share_members fcsm ON fcsm.share_id = fcs.id
        WHERE fcs.event_type = 'todo_list'
        AND fcsm.member_user_id = auth.uid()
    )
);

-- Allow shared members to SELECT items on shared todo lists
CREATE POLICY "Shared members can view items on shared todo lists"
ON todo_items FOR SELECT
USING (
    list_id IN (
        SELECT fcs.event_id
        FROM family_calendar_shares fcs
        JOIN family_calendar_share_members fcsm ON fcsm.share_id = fcs.id
        WHERE fcs.event_type = 'todo_list'
        AND fcsm.member_user_id = auth.uid()
    )
);

-- Allow shared members to INSERT items on shared todo lists
CREATE POLICY "Shared members can insert items on shared todo lists"
ON todo_items FOR INSERT
WITH CHECK (
    list_id IN (
        SELECT fcs.event_id
        FROM family_calendar_shares fcs
        JOIN family_calendar_share_members fcsm ON fcsm.share_id = fcs.id
        WHERE fcs.event_type = 'todo_list'
        AND fcsm.member_user_id = auth.uid()
    )
);

-- Allow shared members to UPDATE items on shared todo lists
CREATE POLICY "Shared members can update items on shared todo lists"
ON todo_items FOR UPDATE
USING (
    list_id IN (
        SELECT fcs.event_id
        FROM family_calendar_shares fcs
        JOIN family_calendar_share_members fcsm ON fcsm.share_id = fcs.id
        WHERE fcs.event_type = 'todo_list'
        AND fcsm.member_user_id = auth.uid()
    )
);

-- Allow shared members to DELETE items on shared todo lists
CREATE POLICY "Shared members can delete items on shared todo lists"
ON todo_items FOR DELETE
USING (
    list_id IN (
        SELECT fcs.event_id
        FROM family_calendar_shares fcs
        JOIN family_calendar_share_members fcsm ON fcsm.share_id = fcs.id
        WHERE fcs.event_type = 'todo_list'
        AND fcsm.member_user_id = auth.uid()
    )
);

-- ============================================================================
-- STEP 2: RPC to fetch shared to-do list IDs for a user
-- Uses SECURITY DEFINER to bypass RLS on family_calendar_share_members
-- ============================================================================

CREATE OR REPLACE FUNCTION get_shared_todo_list_ids(p_user_id UUID)
RETURNS SETOF UUID
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT DISTINCT fcs.event_id
    FROM family_calendar_shares fcs
    JOIN family_calendar_share_members fcsm ON fcsm.share_id = fcs.id
    WHERE fcs.event_type = 'todo_list'
    AND fcsm.member_user_id = p_user_id;
$$;

-- ============================================================================
-- STEP 3: Cleanup trigger - remove shares when a to-do list is deleted
-- ============================================================================

CREATE OR REPLACE FUNCTION cleanup_todo_list_shares()
RETURNS TRIGGER AS $$
BEGIN
    DELETE FROM family_calendar_shares
    WHERE event_type = 'todo_list' AND event_id = OLD.id;
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER cleanup_todo_list_shares_trigger
    BEFORE DELETE ON todo_lists
    FOR EACH ROW
    EXECUTE FUNCTION cleanup_todo_list_shares();

-- ============================================================================
-- STEP 4: Index for performance on share lookups
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_family_calendar_shares_todo_list
ON family_calendar_shares(event_id)
WHERE event_type = 'todo_list';
