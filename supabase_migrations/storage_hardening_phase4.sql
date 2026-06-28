-- ============================================================================
-- STORAGE HARDENING - PHASE 4 (FINAL)
-- Date: 2026-05-10
--
-- This is the breaking step. Apply in order, all in one go (the steps
-- depend on each other for the app to keep working).
--
-- PRECONDITIONS:
--   - Phase 1 applied (new storage RLS policies exist)
--   - iOS Phase 2 + Phase 3 changes built and shipped to all active testers
--   - Every tester is running the updated build
--
-- After running this:
--   - Photos in the database are stored as paths (not URLs)
--   - Legacy permissive storage policies are gone
--   - Buckets are private — only signed URLs from authenticated users work
--
-- Rollback: storage_hardening_phase4_rollback.sql
-- ============================================================================


-- ============================================================================
-- STEP 1: MIGRATE photo_url / image_url COLUMNS FROM URLS TO PATHS
--
-- The URL format we're stripping:
--   https://<project>.supabase.co/storage/v1/object/public/<bucket>/<path>?t=<timestamp>
--
-- We strip the prefix up to and including '/public/<bucket>/' and the
-- '?t=<timestamp>' suffix, leaving just the path (e.g. 'medications/<uuid>/photo.jpg').
--
-- Rows that already hold paths (no http prefix) are left unchanged.
-- Rows holding non-storage URLs are also left unchanged.
-- ============================================================================

-- profiles.photo_url → profile-photos paths
UPDATE profiles
SET photo_url = regexp_replace(
  regexp_replace(photo_url, '^https://[^/]+/storage/v1/object/public/profile-photos/', ''),
  '\?t=\d+$',
  ''
)
WHERE photo_url LIKE 'https://%/storage/v1/object/public/profile-photos/%';

-- medications.image_url → medication-photos paths
UPDATE medications
SET image_url = regexp_replace(
  regexp_replace(image_url, '^https://[^/]+/storage/v1/object/public/medication-photos/', ''),
  '\?t=\d+$',
  ''
)
WHERE image_url LIKE 'https://%/storage/v1/object/public/medication-photos/%';

-- appointments.image_url → appointment-photos paths
UPDATE appointments
SET image_url = regexp_replace(
  regexp_replace(image_url, '^https://[^/]+/storage/v1/object/public/appointment-photos/', ''),
  '\?t=\d+$',
  ''
)
WHERE image_url LIKE 'https://%/storage/v1/object/public/appointment-photos/%';

-- countdowns.image_url → countdown-photos paths
UPDATE countdowns
SET image_url = regexp_replace(
  regexp_replace(image_url, '^https://[^/]+/storage/v1/object/public/countdown-photos/', ''),
  '\?t=\d+$',
  ''
)
WHERE image_url LIKE 'https://%/storage/v1/object/public/countdown-photos/%';

-- recipes.image_url → recipe-photos paths
UPDATE recipes
SET image_url = regexp_replace(
  regexp_replace(image_url, '^https://[^/]+/storage/v1/object/public/recipe-photos/', ''),
  '\?t=\d+$',
  ''
)
WHERE image_url LIKE 'https://%/storage/v1/object/public/recipe-photos/%';

-- important_accounts.image_url → account-photos paths
UPDATE important_accounts
SET image_url = regexp_replace(
  regexp_replace(image_url, '^https://[^/]+/storage/v1/object/public/account-photos/', ''),
  '\?t=\d+$',
  ''
)
WHERE image_url LIKE 'https://%/storage/v1/object/public/account-photos/%';


-- ============================================================================
-- STEP 2: DROP LEGACY PERMISSIVE STORAGE POLICIES
-- (The deferred Phase 1.5 work)
-- ============================================================================

DROP POLICY IF EXISTS "Allow public reads yndkpx_0" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated uploads yndkpx_0" ON storage.objects;

DROP POLICY IF EXISTS "Anyone can view medication photos" ON storage.objects;
DROP POLICY IF EXISTS "Anyone can view profile photos" ON storage.objects;

DROP POLICY IF EXISTS "Public read access for account photos" ON storage.objects;
DROP POLICY IF EXISTS "Public read access for appointment photos" ON storage.objects;
DROP POLICY IF EXISTS "Public read access for event photos 77eu8t_0" ON storage.objects;
DROP POLICY IF EXISTS "Public read access for recipe photos" ON storage.objects;

DROP POLICY IF EXISTS "Authenticated users can delete event photos 77eu8t_1" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can update event photos 77eu8t_1" ON storage.objects;

DROP POLICY IF EXISTS "Authenticated users can delete account photos" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can delete appointment photos" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can delete event photos 77eu8t_0" ON storage.objects;

DROP POLICY IF EXISTS "Authenticated users can update account photos" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can update appointment photos" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can update event photos 77eu8t_0" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can update recipe photos" ON storage.objects;

DROP POLICY IF EXISTS "Authenticated users can upload account photos" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can upload appointment photos" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can upload event photos 77eu8t_0" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can upload medication photos" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can upload profile photos" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can upload recipe photos" ON storage.objects;

DROP POLICY IF EXISTS "Users can delete medication photo uploads" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete their uploads" ON storage.objects;
DROP POLICY IF EXISTS "Users can update medication photo uploads" ON storage.objects;
DROP POLICY IF EXISTS "Users can update their uploads" ON storage.objects;


-- ============================================================================
-- STEP 3: FLIP BUCKETS TO PRIVATE
-- ============================================================================

UPDATE storage.buckets SET public = false WHERE id = 'profile-photos';
UPDATE storage.buckets SET public = false WHERE id = 'medication-photos';
UPDATE storage.buckets SET public = false WHERE id = 'appointment-photos';
UPDATE storage.buckets SET public = false WHERE id = 'countdown-photos';
UPDATE storage.buckets SET public = false WHERE id = 'recipe-photos';
UPDATE storage.buckets SET public = false WHERE id = 'account-photos';


-- ============================================================================
-- VERIFICATION QUERIES — RUN THESE AFTER MIGRATION
-- ============================================================================

-- 1. All buckets should be private:
--   SELECT name, public FROM storage.buckets ORDER BY name;
-- Expected: every row shows public = false.

-- 2. No legacy storage policies remain — only the 24 new ones from Phase 1:
--   SELECT policyname, cmd FROM pg_policies
--   WHERE schemaname = 'storage' AND tablename = 'objects'
--   ORDER BY policyname;
-- Expected: 24 rows, all named like profile_photos_*, medication_photos_*, etc.

-- 3. No URL-format values remain in any photo column:
--   SELECT 'profiles' AS source, COUNT(*) FROM profiles WHERE photo_url LIKE 'https://%'
--   UNION ALL SELECT 'medications', COUNT(*) FROM medications WHERE image_url LIKE 'https://%'
--   UNION ALL SELECT 'appointments', COUNT(*) FROM appointments WHERE image_url LIKE 'https://%'
--   UNION ALL SELECT 'countdowns', COUNT(*) FROM countdowns WHERE image_url LIKE 'https://%'
--   UNION ALL SELECT 'recipes', COUNT(*) FROM recipes WHERE image_url LIKE 'https://%'
--   UNION ALL SELECT 'important_accounts', COUNT(*) FROM important_accounts WHERE image_url LIKE 'https://%';
-- Expected: every count is 0. (Or non-zero only for non-Supabase URLs, if any.)

-- 4. Sample some path values to confirm format:
--   SELECT photo_url FROM profiles WHERE photo_url IS NOT NULL LIMIT 3;
-- Expected: values like 'profiles/<uuid>/photo.jpg', no http prefix, no ?t= suffix.
