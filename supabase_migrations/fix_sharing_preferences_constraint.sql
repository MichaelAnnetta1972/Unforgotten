-- Migration: Fix unique constraint on profile_sharing_preferences
-- The previous constraint was (profile_id, category) but the update_sharing_preference
-- RPC uses ON CONFLICT (profile_id, target_user_id, category), so we need a 3-column constraint.

-- Drop the incorrect constraint (added previously)
ALTER TABLE profile_sharing_preferences
DROP CONSTRAINT IF EXISTS profile_sharing_preferences_profile_id_category_key;

-- Add the correct 3-column unique constraint matching the RPC's ON CONFLICT clause
-- (skip if it already exists)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'profile_sharing_preferences_profile_target_category_key'
    ) THEN
        ALTER TABLE profile_sharing_preferences
        ADD CONSTRAINT profile_sharing_preferences_profile_target_category_key
        UNIQUE (profile_id, target_user_id, category);
    END IF;
END $$;
