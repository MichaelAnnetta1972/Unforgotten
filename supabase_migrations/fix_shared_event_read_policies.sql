-- Migration: Fix cross-account shared event read policies
-- Run this in your Supabase SQL Editor
--
-- Problem: The RLS policies on countdowns/appointments tables use inline subqueries
-- that hit RLS on family_calendar_share_members, causing recursive RLS evaluation
-- and silently returning no rows. This migration replaces those policies with ones
-- that use the get_shared_event_ids SECURITY DEFINER function to bypass RLS.

-- ============================================================================
-- STEP 1: Ensure the SECURITY DEFINER function exists
-- ============================================================================

CREATE OR REPLACE FUNCTION get_shared_event_ids(p_user_id UUID, p_event_type TEXT)
RETURNS SETOF UUID AS $$
    SELECT fcs.event_id
    FROM family_calendar_shares fcs
    INNER JOIN family_calendar_share_members fcsm ON fcsm.share_id = fcs.id
    WHERE fcs.event_type = p_event_type
    AND fcsm.member_user_id = p_user_id;
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- ============================================================================
-- STEP 2: Drop and recreate the countdowns policy
-- ============================================================================

DROP POLICY IF EXISTS "Users can read countdowns shared with them" ON countdowns;

CREATE POLICY "Users can read countdowns shared with them"
    ON countdowns
    FOR SELECT
    USING (id IN (SELECT get_shared_event_ids(auth.uid(), 'countdown')));

-- ============================================================================
-- STEP 3: Drop and recreate the appointments policy
-- ============================================================================

DROP POLICY IF EXISTS "Users can read appointments shared with them" ON appointments;

CREATE POLICY "Users can read appointments shared with them"
    ON appointments
    FOR SELECT
    USING (id IN (SELECT get_shared_event_ids(auth.uid(), 'appointment')));
