-- Cleanup: Remove ALL overloads of accept_invitation_with_sync
-- Run this BEFORE deploying update_accept_invitation_sync_sharing.sql
-- This ensures no stale JSONB-returning or old-signature versions remain

-- Drop all known parameter combinations
DROP FUNCTION IF EXISTS accept_invitation_with_sync(UUID, UUID, UUID);
DROP FUNCTION IF EXISTS accept_invitation_with_sync(UUID, UUID, UUID, UUID);
DROP FUNCTION IF EXISTS accept_invitation_with_sync(UUID, UUID, UUID, UUID, UUID);

-- Also drop the old profile_sharing_preferences constraint
ALTER TABLE profile_sharing_preferences
DROP CONSTRAINT IF EXISTS profile_sharing_preferences_profile_id_category_key;

-- Also drop old is_category_shared overload that causes trigger ambiguity
DROP FUNCTION IF EXISTS is_category_shared(UUID, TEXT);

-- Verify: list remaining overloads (should be empty after this)
SELECT p.oid, p.proname, pg_get_function_arguments(p.oid) as args,
       pg_get_function_result(p.oid) as return_type
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE p.proname = 'accept_invitation_with_sync'
  AND n.nspname = 'public';
