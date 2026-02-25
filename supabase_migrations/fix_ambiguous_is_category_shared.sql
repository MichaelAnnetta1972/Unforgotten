-- Fix: Drop the old 2-parameter is_category_shared function
--
-- The old version is_category_shared(UUID, TEXT) was created in add_profile_sharing_preferences.sql.
-- The new version is_category_shared(UUID, TEXT, UUID DEFAULT NULL) was created in
-- update_sharing_preferences_per_user.sql. Because they have different parameter counts,
-- CREATE OR REPLACE created a second overload instead of replacing the first.
--
-- When the propagate_profile_detail_changes trigger calls is_category_shared(uuid, text, uuid)
-- with a NULL third argument, Postgres cannot decide which overload to use, causing:
--   "function is_category_shared(uuid, text) is not unique"
--
-- This blocked ALL profile_details inserts (clothing, gifts, medical, etc.).
--
-- Fix: Drop the old 2-parameter version. The 3-parameter version already handles
-- the NULL target_user_id case internally.

DROP FUNCTION IF EXISTS is_category_shared(UUID, TEXT);
