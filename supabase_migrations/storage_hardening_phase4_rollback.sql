-- ============================================================================
-- STORAGE HARDENING PHASE 4 - ROLLBACK
-- Date: 2026-05-10
--
-- Reverses Phase 4 — flips buckets back to public, restores legacy permissive
-- policies, and reconstructs full URLs from paths.
--
-- USE THIS IF: after applying Phase 4, the app is broken in some way you can't
-- fix quickly, and you need to restore the working public-bucket state to keep
-- testers unblocked while you diagnose.
--
-- ORDER MATTERS — apply the steps in this order, or photos will appear broken
-- during the transition.
-- ============================================================================


-- ============================================================================
-- STEP 1: FLIP BUCKETS BACK TO PUBLIC
-- (Photos become world-readable again — accept this as the cost of rolling back)
-- ============================================================================

UPDATE storage.buckets SET public = true WHERE id = 'profile-photos';
UPDATE storage.buckets SET public = true WHERE id = 'medication-photos';
UPDATE storage.buckets SET public = true WHERE id = 'appointment-photos';
UPDATE storage.buckets SET public = true WHERE id = 'countdown-photos';
UPDATE storage.buckets SET public = true WHERE id = 'recipe-photos';
UPDATE storage.buckets SET public = true WHERE id = 'account-photos';


-- ============================================================================
-- STEP 2: RESTORE THE LEGACY PERMISSIVE STORAGE POLICIES
-- (Required so older app builds, if any, can read photos.)
-- ============================================================================

CREATE POLICY "Allow public reads yndkpx_0"
ON storage.objects FOR SELECT
USING (true);

CREATE POLICY "Allow authenticated uploads yndkpx_0"
ON storage.objects FOR INSERT
WITH CHECK (true);

CREATE POLICY "Anyone can view medication photos"
ON storage.objects FOR SELECT
USING (bucket_id = 'medication-photos');

CREATE POLICY "Anyone can view profile photos"
ON storage.objects FOR SELECT
USING (bucket_id = 'profile-photos');

CREATE POLICY "Public read access for account photos"
ON storage.objects FOR SELECT
USING (bucket_id = 'account-photos');

CREATE POLICY "Public read access for appointment photos"
ON storage.objects FOR SELECT
USING (bucket_id = 'appointment-photos');

CREATE POLICY "Public read access for event photos 77eu8t_0"
ON storage.objects FOR SELECT
USING (bucket_id = 'countdown-photos');

CREATE POLICY "Public read access for recipe photos"
ON storage.objects FOR SELECT
USING (bucket_id = 'recipe-photos');

CREATE POLICY "Authenticated users can delete account photos"
ON storage.objects FOR DELETE
USING (bucket_id = 'account-photos');

CREATE POLICY "Authenticated users can delete appointment photos"
ON storage.objects FOR DELETE
USING (bucket_id = 'appointment-photos');

CREATE POLICY "Authenticated users can delete event photos 77eu8t_0"
ON storage.objects FOR DELETE
USING (bucket_id = 'countdown-photos');

CREATE POLICY "Authenticated users can delete event photos 77eu8t_1"
ON storage.objects FOR SELECT
USING (bucket_id = 'countdown-photos');

CREATE POLICY "Authenticated users can update account photos"
ON storage.objects FOR UPDATE
USING (bucket_id = 'account-photos');

CREATE POLICY "Authenticated users can update appointment photos"
ON storage.objects FOR UPDATE
USING (bucket_id = 'appointment-photos');

CREATE POLICY "Authenticated users can update event photos 77eu8t_0"
ON storage.objects FOR UPDATE
USING (bucket_id = 'countdown-photos');

CREATE POLICY "Authenticated users can update event photos 77eu8t_1"
ON storage.objects FOR SELECT
USING (bucket_id = 'countdown-photos');

CREATE POLICY "Authenticated users can update recipe photos"
ON storage.objects FOR UPDATE
USING (bucket_id = 'recipe-photos');

CREATE POLICY "Authenticated users can upload account photos"
ON storage.objects FOR INSERT
WITH CHECK (bucket_id = 'account-photos');

CREATE POLICY "Authenticated users can upload appointment photos"
ON storage.objects FOR INSERT
WITH CHECK (bucket_id = 'appointment-photos');

CREATE POLICY "Authenticated users can upload event photos 77eu8t_0"
ON storage.objects FOR INSERT
WITH CHECK (bucket_id = 'countdown-photos');

CREATE POLICY "Authenticated users can upload medication photos"
ON storage.objects FOR INSERT
WITH CHECK ((bucket_id = 'medication-photos') AND (auth.role() = 'authenticated'));

CREATE POLICY "Authenticated users can upload profile photos"
ON storage.objects FOR INSERT
WITH CHECK ((bucket_id = 'profile-photos') AND (auth.role() = 'authenticated'));

CREATE POLICY "Authenticated users can upload recipe photos"
ON storage.objects FOR INSERT
WITH CHECK (bucket_id = 'recipe-photos');

CREATE POLICY "Users can delete medication photo uploads"
ON storage.objects FOR DELETE
USING ((bucket_id = 'medication-photos') AND (auth.role() = 'authenticated'));

CREATE POLICY "Users can delete their uploads"
ON storage.objects FOR DELETE
USING ((bucket_id = 'profile-photos') AND (auth.role() = 'authenticated'));

CREATE POLICY "Users can update medication photo uploads"
ON storage.objects FOR UPDATE
USING ((bucket_id = 'medication-photos') AND (auth.role() = 'authenticated'));

CREATE POLICY "Users can update their uploads"
ON storage.objects FOR UPDATE
USING ((bucket_id = 'profile-photos') AND (auth.role() = 'authenticated'));


-- ============================================================================
-- STEP 3: RECONSTRUCT FULL URLS FROM PATHS
--
-- The new iOS code is happy with both formats, but if you're rolling back
-- because users are stuck on an OLD build that only handles full URLs, this
-- step puts URLs back in the columns.
--
-- IMPORTANT: replace YOUR-PROJECT-REF below with the actual ref from your
-- Supabase project URL (the existing data showed 'qjnthlgkqjqrtbkromjx').
-- ============================================================================

UPDATE profiles SET photo_url =
  'https://qjnthlgkqjqrtbkromjx.supabase.co/storage/v1/object/public/profile-photos/' || photo_url
WHERE photo_url IS NOT NULL AND photo_url NOT LIKE 'http%';

UPDATE medications SET image_url =
  'https://qjnthlgkqjqrtbkromjx.supabase.co/storage/v1/object/public/medication-photos/' || image_url
WHERE image_url IS NOT NULL AND image_url NOT LIKE 'http%';

UPDATE appointments SET image_url =
  'https://qjnthlgkqjqrtbkromjx.supabase.co/storage/v1/object/public/appointment-photos/' || image_url
WHERE image_url IS NOT NULL AND image_url NOT LIKE 'http%';

UPDATE countdowns SET image_url =
  'https://qjnthlgkqjqrtbkromjx.supabase.co/storage/v1/object/public/countdown-photos/' || image_url
WHERE image_url IS NOT NULL AND image_url NOT LIKE 'http%';

UPDATE recipes SET image_url =
  'https://qjnthlgkqjqrtbkromjx.supabase.co/storage/v1/object/public/recipe-photos/' || image_url
WHERE image_url IS NOT NULL AND image_url NOT LIKE 'http%';

UPDATE important_accounts SET image_url =
  'https://qjnthlgkqjqrtbkromjx.supabase.co/storage/v1/object/public/account-photos/' || image_url
WHERE image_url IS NOT NULL AND image_url NOT LIKE 'http%';
