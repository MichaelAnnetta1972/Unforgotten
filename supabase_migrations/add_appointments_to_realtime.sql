-- Migration: Add appointments table to supabase_realtime publication
-- This enables Realtime subscriptions on appointments so that appointment
-- changes (create/update/delete) are pushed to connected devices instantly.
--
-- Root cause of the "appointments don't sync across devices" bug:
-- The app subscribes to an "appointments" Realtime channel in
-- RealtimeSyncService.subscribeToAppointments(), but Supabase Realtime only
-- emits events for tables that are members of the supabase_realtime publication.
-- The appointments table was never added to that publication (unlike profiles,
-- profile_details, and account_members), so the subscription connected but never
-- received any events. All other synced features were already in the publication.

-- ============================================================================
-- PART 1: Add appointments to the realtime publication
-- ============================================================================

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables
        WHERE pubname = 'supabase_realtime' AND tablename = 'appointments'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE appointments;
    END IF;
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Could not add appointments to realtime: %', SQLERRM;
END $$;

-- ============================================================================
-- PART 2: Set REPLICA IDENTITY FULL for proper UPDATE/DELETE events
-- ============================================================================
-- Without REPLICA IDENTITY FULL, Realtime UPDATE events may not include all
-- column values, and DELETE events only carry the primary key. The app's
-- handleAppointmentChange() decodes the full record on UPDATE and reads the id
-- from oldRecord on DELETE, so FULL replica identity is required for both to work.

ALTER TABLE appointments REPLICA IDENTITY FULL;

-- ============================================================================
-- PART 3: Verify setup (diagnostic query)
-- ============================================================================

SELECT tablename FROM pg_publication_tables WHERE pubname = 'supabase_realtime'
AND tablename = 'appointments';
