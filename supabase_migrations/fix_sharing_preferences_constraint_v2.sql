-- Migration: Fix profile_sharing_preferences constraint (must run!)
-- Date: 2026-03-30
--
-- The old 2-column unique constraint (profile_id, category) conflicts with the
-- 3-column ON CONFLICT (profile_id, target_user_id, category) used by all RPCs.
-- This causes "duplicate key" errors when updating sharing preferences and
-- prevents the accept_invitation_with_sync RPC from correctly storing per-user
-- sharing preferences (e.g., Important Accounts toggled off at invite time).
--
-- This migration drops the old constraint and ensures only the correct
-- 3-column constraint exists.

-- Drop the old 2-column constraint
ALTER TABLE profile_sharing_preferences
DROP CONSTRAINT IF EXISTS profile_sharing_preferences_profile_id_category_key;

-- Ensure the correct 3-column constraint exists
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'profile_sharing_preferences_profile_target_category_key'
    ) THEN
        ALTER TABLE profile_sharing_preferences
        ADD CONSTRAINT profile_sharing_preferences_profile_target_category_key
        UNIQUE(profile_id, target_user_id, category);
    END IF;
END $$;

-- Clean up any duplicate rows that may have been created under the old constraint
-- Keep the most recently updated row for each (profile_id, target_user_id, category)
DELETE FROM profile_sharing_preferences a
USING profile_sharing_preferences b
WHERE a.id < b.id
  AND a.profile_id = b.profile_id
  AND a.target_user_id = b.target_user_id
  AND a.category = b.category;
