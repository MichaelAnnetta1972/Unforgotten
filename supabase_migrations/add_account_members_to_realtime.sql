-- Migration: Add account_members table to supabase_realtime publication
-- This enables Realtime subscriptions on account_members so that role changes
-- are pushed to connected devices instantly (no need to log out and back in).

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables
        WHERE pubname = 'supabase_realtime' AND tablename = 'account_members'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE account_members;
    END IF;
END $$;

-- Verify
SELECT tablename FROM pg_publication_tables WHERE pubname = 'supabase_realtime'
AND tablename = 'account_members';
