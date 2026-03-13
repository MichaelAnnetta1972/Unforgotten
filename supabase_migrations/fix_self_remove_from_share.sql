-- Migration: Allow users to remove themselves from shared events
-- Run this in your Supabase SQL Editor
--
-- Problem: When a user tries to remove a shared appointment/countdown from their view,
-- the DELETE on family_calendar_share_members fails silently because the only DELETE
-- policy ("Share creators can remove share members") requires the user to be the share
-- creator. Recipients cannot remove their own membership.
--
-- Fix: Add a DELETE policy allowing users to delete their own membership rows.

-- Allow users to remove their own membership from a share
CREATE POLICY "Users can remove their own memberships"
    ON family_calendar_share_members
    FOR DELETE
    USING (auth.uid() = member_user_id);
