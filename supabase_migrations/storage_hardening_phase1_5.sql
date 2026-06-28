-- ============================================================================
-- STORAGE HARDENING - PHASE 1.5
-- Date: 2026-05-09
--
-- Drops legacy storage policies created via the Supabase dashboard wizards.
-- These were all overly permissive (checked only bucket_id or auth.role(),
-- never account membership or path ownership), so they need to go before
-- buckets are flipped to private in Phase 4.
--
-- IMPORTANT: While buckets are still public, dropping these policies has
-- NO USER-VISIBLE EFFECT. Public buckets serve reads regardless of policies,
-- and authenticated writes still work via the new properly-scoped policies
-- created in Phase 1.
--
-- Test the app after running this. Photos should still display, uploads
-- should still work, deletes should still work — just now constrained
-- correctly to the user's own account scope.
--
-- Rollback: storage_hardening_phase1_5_rollback.sql
-- ============================================================================

-- The two universal "world-readable / world-writable" policies (highest priority to drop)
DROP POLICY IF EXISTS "Allow public reads yndkpx_0" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated uploads yndkpx_0" ON storage.objects;

-- "Anyone can view ..." — public-read policies that bypass RLS once buckets go private
DROP POLICY IF EXISTS "Anyone can view medication photos" ON storage.objects;
DROP POLICY IF EXISTS "Anyone can view profile photos" ON storage.objects;

-- "Public read access for ..." policies — same problem as above
DROP POLICY IF EXISTS "Public read access for account photos" ON storage.objects;
DROP POLICY IF EXISTS "Public read access for appointment photos" ON storage.objects;
DROP POLICY IF EXISTS "Public read access for event photos 77eu8t_0" ON storage.objects;
DROP POLICY IF EXISTS "Public read access for recipe photos" ON storage.objects;

-- Mis-named "delete event photos" / "update event photos" policies that are
-- actually SELECT policies on countdown-photos
DROP POLICY IF EXISTS "Authenticated users can delete event photos 77eu8t_1" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can update event photos 77eu8t_1" ON storage.objects;

-- "Authenticated users can delete ..." — no account scoping
DROP POLICY IF EXISTS "Authenticated users can delete account photos" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can delete appointment photos" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can delete event photos 77eu8t_0" ON storage.objects;

-- "Authenticated users can update ..." — no account scoping
DROP POLICY IF EXISTS "Authenticated users can update account photos" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can update appointment photos" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can update event photos 77eu8t_0" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can update recipe photos" ON storage.objects;

-- "Authenticated users can upload ..." — no account scoping
DROP POLICY IF EXISTS "Authenticated users can upload account photos" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can upload appointment photos" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can upload event photos 77eu8t_0" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can upload medication photos" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can upload profile photos" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can upload recipe photos" ON storage.objects;

-- Misnamed "users can ... their uploads" policies that don't actually check ownership
DROP POLICY IF EXISTS "Users can delete medication photo uploads" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete their uploads" ON storage.objects;
DROP POLICY IF EXISTS "Users can update medication photo uploads" ON storage.objects;
DROP POLICY IF EXISTS "Users can update their uploads" ON storage.objects;


-- ============================================================================
-- VERIFICATION
-- ============================================================================

-- After running, you should see ONLY the 24 new policies created in Phase 1:
--
--   SELECT policyname, cmd FROM pg_policies
--   WHERE schemaname = 'storage' AND tablename = 'objects'
--   ORDER BY policyname;
--
-- Expected count: 24 rows. All names should start with one of:
--   profile_photos_, medication_photos_, appointment_photos_,
--   countdown_photos_, recipe_photos_, account_photos_
