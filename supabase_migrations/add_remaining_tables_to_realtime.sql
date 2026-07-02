-- Migration: Add remaining subscribed tables to supabase_realtime publication
--
-- The app's RealtimeSyncService subscribes to 14 tables, but only a handful were
-- ever added to the supabase_realtime publication. Supabase Realtime only emits
-- Postgres change events for published tables, so any subscribed-but-unpublished
-- table connects successfully yet never receives events. Those features still
-- appear to "sync" only because of the on-app-active refreshDataFromRemote() pull,
-- not because of live realtime push.
--
-- Already published (verified via pg_publication_tables):
--   account_members, profiles, profile_details, appointments, user_preferences
--
-- This migration adds the remaining subscribed tables so live cross-device push
-- works for every synced feature:
--   medications, useful_contacts, countdowns, sticky_reminders,
--   todo_lists, todo_items, recipes, planned_meals,
--   mood_entries, important_accounts
--
-- Each table is also set to REPLICA IDENTITY FULL so UPDATE events carry all
-- column values and DELETE events carry the full old row (the app reads
-- record/oldRecord fields in several change handlers).

-- ============================================================================
-- PART 1: Add tables to the realtime publication (idempotent)
-- ============================================================================

DO $$
DECLARE
    tbl TEXT;
    tables TEXT[] := ARRAY[
        'medications',
        'useful_contacts',
        'countdowns',
        'sticky_reminders',
        'todo_lists',
        'todo_items',
        'recipes',
        'planned_meals',
        'mood_entries',
        'important_accounts'
    ];
BEGIN
    FOREACH tbl IN ARRAY tables LOOP
        IF NOT EXISTS (
            SELECT 1 FROM pg_publication_tables
            WHERE pubname = 'supabase_realtime' AND tablename = tbl
        ) THEN
            EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE %I', tbl);
            RAISE NOTICE 'Added % to supabase_realtime', tbl;
        ELSE
            RAISE NOTICE '% already in supabase_realtime', tbl;
        END IF;
    END LOOP;
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Error adding tables to realtime: %', SQLERRM;
END $$;

-- ============================================================================
-- PART 2: Set REPLICA IDENTITY FULL for proper UPDATE/DELETE events
-- ============================================================================

ALTER TABLE medications REPLICA IDENTITY FULL;
ALTER TABLE useful_contacts REPLICA IDENTITY FULL;
ALTER TABLE countdowns REPLICA IDENTITY FULL;
ALTER TABLE sticky_reminders REPLICA IDENTITY FULL;
ALTER TABLE todo_lists REPLICA IDENTITY FULL;
ALTER TABLE todo_items REPLICA IDENTITY FULL;
ALTER TABLE recipes REPLICA IDENTITY FULL;
ALTER TABLE planned_meals REPLICA IDENTITY FULL;
ALTER TABLE mood_entries REPLICA IDENTITY FULL;
ALTER TABLE important_accounts REPLICA IDENTITY FULL;

-- ============================================================================
-- PART 3: Verify setup (diagnostic query)
-- ============================================================================
-- After running, this should list all 15 tables the app relies on for realtime.

SELECT tablename FROM pg_publication_tables
WHERE pubname = 'supabase_realtime'
ORDER BY tablename;
