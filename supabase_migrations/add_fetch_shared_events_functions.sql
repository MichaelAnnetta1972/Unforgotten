-- Migration: SECURITY DEFINER functions for shared events + cascade cleanup
-- Run this in your Supabase SQL Editor
--
-- Root cause: When a countdown/appointment is deleted, the corresponding
-- family_calendar_shares record is NOT cleaned up, leaving stale references.
-- This migration:
-- 1. Cleans up existing stale share records
-- 2. Adds triggers to auto-delete shares when events are deleted
-- 3. Creates/recreates the SECURITY DEFINER fetch functions

-- ============================================================================
-- STEP 1: Clean up stale share records (shares pointing to deleted events)
-- ============================================================================

DELETE FROM family_calendar_shares
WHERE event_type = 'countdown'
AND event_id NOT IN (SELECT id FROM countdowns);

DELETE FROM family_calendar_shares
WHERE event_type = 'appointment'
AND event_id NOT IN (SELECT id FROM appointments);

-- ============================================================================
-- STEP 2: Auto-cleanup triggers — delete shares when events are deleted
-- ============================================================================

-- Trigger function for countdowns
CREATE OR REPLACE FUNCTION cleanup_countdown_shares()
RETURNS TRIGGER AS $$
BEGIN
    DELETE FROM family_calendar_shares
    WHERE event_type = 'countdown' AND event_id = OLD.id;
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_cleanup_countdown_shares ON countdowns;
CREATE TRIGGER trg_cleanup_countdown_shares
    BEFORE DELETE ON countdowns
    FOR EACH ROW EXECUTE FUNCTION cleanup_countdown_shares();

-- Trigger function for appointments
CREATE OR REPLACE FUNCTION cleanup_appointment_shares()
RETURNS TRIGGER AS $$
BEGIN
    DELETE FROM family_calendar_shares
    WHERE event_type = 'appointment' AND event_id = OLD.id;
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_cleanup_appointment_shares ON appointments;
CREATE TRIGGER trg_cleanup_appointment_shares
    BEFORE DELETE ON appointments
    FOR EACH ROW EXECUTE FUNCTION cleanup_appointment_shares();

-- ============================================================================
-- STEP 3: Drop and recreate SECURITY DEFINER fetch functions
-- ============================================================================

DROP FUNCTION IF EXISTS get_shared_countdowns(UUID);
DROP FUNCTION IF EXISTS get_shared_appointments(UUID);

CREATE OR REPLACE FUNCTION get_shared_countdowns(p_user_id UUID)
RETURNS SETOF countdowns AS $$
    SELECT c.*
    FROM countdowns c
    INNER JOIN family_calendar_shares fcs ON fcs.event_id = c.id AND fcs.event_type = 'countdown'
    INNER JOIN family_calendar_share_members fcsm ON fcsm.share_id = fcs.id
    WHERE fcsm.member_user_id = p_user_id;
$$ LANGUAGE sql SECURITY DEFINER STABLE;

CREATE OR REPLACE FUNCTION get_shared_appointments(p_user_id UUID)
RETURNS SETOF appointments AS $$
    SELECT a.*
    FROM appointments a
    INNER JOIN family_calendar_shares fcs ON fcs.event_id = a.id AND fcs.event_type = 'appointment'
    INNER JOIN family_calendar_share_members fcsm ON fcsm.share_id = fcs.id
    WHERE fcsm.member_user_id = p_user_id;
$$ LANGUAGE sql SECURITY DEFINER STABLE;
