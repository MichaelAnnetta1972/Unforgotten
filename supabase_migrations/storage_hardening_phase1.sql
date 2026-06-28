-- ============================================================================
-- STORAGE HARDENING - PHASE 1
-- Date: 2026-05-09
--
-- This phase prepares the database for private storage buckets but does NOT
-- yet flip the buckets to private. Buckets remain public-readable until
-- Phase 4 — that gives us a window to ship updated iOS code first.
--
-- After running this phase:
--   - Storage RLS policies exist (but have no effect while buckets are public)
--   - photo_url / image_url columns are migrated to paths only
--   - The app will BREAK when displaying images, because the columns no longer
--     contain valid URLs. Existing iOS builds expect full URLs.
--
-- THEREFORE: only run Phase 1 IMMEDIATELY before deploying updated iOS code.
-- The migrated paths only become useful once iOS knows how to convert them
-- to signed URLs.
--
-- If this is a problem (e.g., you want to keep the app working between
-- phases), defer the column migration until Phase 4 instead.
--
-- Rollback: storage_hardening_phase1_rollback.sql
-- ============================================================================


-- ============================================================================
-- 1. STORAGE RLS POLICIES
-- Pattern: a user can read/write a photo if they have account access to the
-- parent record. Path layout: <subfolder>/<parent_record_uuid>/photo.jpg
-- ============================================================================

-- ---- profile-photos ----

CREATE POLICY "profile_photos_select"
ON storage.objects FOR SELECT TO authenticated
USING (
  bucket_id = 'profile-photos'
  AND (storage.foldername(name))[1] = 'profiles'
  AND EXISTS (
    SELECT 1 FROM profiles p
    WHERE p.id::text = (storage.foldername(name))[2]
      AND has_account_access(p.account_id)
  )
);

CREATE POLICY "profile_photos_insert"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'profile-photos'
  AND (storage.foldername(name))[1] = 'profiles'
  AND EXISTS (
    SELECT 1 FROM profiles p
    WHERE p.id::text = (storage.foldername(name))[2]
      AND can_write_to_account(p.account_id)
  )
);

CREATE POLICY "profile_photos_update"
ON storage.objects FOR UPDATE TO authenticated
USING (
  bucket_id = 'profile-photos'
  AND (storage.foldername(name))[1] = 'profiles'
  AND EXISTS (
    SELECT 1 FROM profiles p
    WHERE p.id::text = (storage.foldername(name))[2]
      AND can_write_to_account(p.account_id)
  )
)
WITH CHECK (
  bucket_id = 'profile-photos'
  AND (storage.foldername(name))[1] = 'profiles'
  AND EXISTS (
    SELECT 1 FROM profiles p
    WHERE p.id::text = (storage.foldername(name))[2]
      AND can_write_to_account(p.account_id)
  )
);

CREATE POLICY "profile_photos_delete"
ON storage.objects FOR DELETE TO authenticated
USING (
  bucket_id = 'profile-photos'
  AND (storage.foldername(name))[1] = 'profiles'
  AND EXISTS (
    SELECT 1 FROM profiles p
    WHERE p.id::text = (storage.foldername(name))[2]
      AND can_write_to_account(p.account_id)
  )
);

-- ---- medication-photos ----

CREATE POLICY "medication_photos_select"
ON storage.objects FOR SELECT TO authenticated
USING (
  bucket_id = 'medication-photos'
  AND (storage.foldername(name))[1] = 'medications'
  AND EXISTS (
    SELECT 1 FROM medications m
    WHERE m.id::text = (storage.foldername(name))[2]
      AND has_account_access(m.account_id)
  )
);

CREATE POLICY "medication_photos_insert"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'medication-photos'
  AND (storage.foldername(name))[1] = 'medications'
  AND EXISTS (
    SELECT 1 FROM medications m
    WHERE m.id::text = (storage.foldername(name))[2]
      AND can_write_to_account(m.account_id)
  )
);

CREATE POLICY "medication_photos_update"
ON storage.objects FOR UPDATE TO authenticated
USING (
  bucket_id = 'medication-photos'
  AND (storage.foldername(name))[1] = 'medications'
  AND EXISTS (
    SELECT 1 FROM medications m
    WHERE m.id::text = (storage.foldername(name))[2]
      AND can_write_to_account(m.account_id)
  )
)
WITH CHECK (
  bucket_id = 'medication-photos'
  AND (storage.foldername(name))[1] = 'medications'
  AND EXISTS (
    SELECT 1 FROM medications m
    WHERE m.id::text = (storage.foldername(name))[2]
      AND can_write_to_account(m.account_id)
  )
);

CREATE POLICY "medication_photos_delete"
ON storage.objects FOR DELETE TO authenticated
USING (
  bucket_id = 'medication-photos'
  AND (storage.foldername(name))[1] = 'medications'
  AND EXISTS (
    SELECT 1 FROM medications m
    WHERE m.id::text = (storage.foldername(name))[2]
      AND can_write_to_account(m.account_id)
  )
);

-- ---- appointment-photos ----

CREATE POLICY "appointment_photos_select"
ON storage.objects FOR SELECT TO authenticated
USING (
  bucket_id = 'appointment-photos'
  AND (storage.foldername(name))[1] = 'appointments'
  AND EXISTS (
    SELECT 1 FROM appointments a
    WHERE a.id::text = (storage.foldername(name))[2]
      AND has_account_access(a.account_id)
  )
);

CREATE POLICY "appointment_photos_insert"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'appointment-photos'
  AND (storage.foldername(name))[1] = 'appointments'
  AND EXISTS (
    SELECT 1 FROM appointments a
    WHERE a.id::text = (storage.foldername(name))[2]
      AND can_write_to_account(a.account_id)
  )
);

CREATE POLICY "appointment_photos_update"
ON storage.objects FOR UPDATE TO authenticated
USING (
  bucket_id = 'appointment-photos'
  AND (storage.foldername(name))[1] = 'appointments'
  AND EXISTS (
    SELECT 1 FROM appointments a
    WHERE a.id::text = (storage.foldername(name))[2]
      AND can_write_to_account(a.account_id)
  )
)
WITH CHECK (
  bucket_id = 'appointment-photos'
  AND (storage.foldername(name))[1] = 'appointments'
  AND EXISTS (
    SELECT 1 FROM appointments a
    WHERE a.id::text = (storage.foldername(name))[2]
      AND can_write_to_account(a.account_id)
  )
);

CREATE POLICY "appointment_photos_delete"
ON storage.objects FOR DELETE TO authenticated
USING (
  bucket_id = 'appointment-photos'
  AND (storage.foldername(name))[1] = 'appointments'
  AND EXISTS (
    SELECT 1 FROM appointments a
    WHERE a.id::text = (storage.foldername(name))[2]
      AND can_write_to_account(a.account_id)
  )
);

-- ---- countdown-photos ----

CREATE POLICY "countdown_photos_select"
ON storage.objects FOR SELECT TO authenticated
USING (
  bucket_id = 'countdown-photos'
  AND (storage.foldername(name))[1] = 'countdowns'
  AND EXISTS (
    SELECT 1 FROM countdowns c
    WHERE c.id::text = (storage.foldername(name))[2]
      AND has_account_access(c.account_id)
  )
);

CREATE POLICY "countdown_photos_insert"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'countdown-photos'
  AND (storage.foldername(name))[1] = 'countdowns'
  AND EXISTS (
    SELECT 1 FROM countdowns c
    WHERE c.id::text = (storage.foldername(name))[2]
      AND can_write_to_account(c.account_id)
  )
);

CREATE POLICY "countdown_photos_update"
ON storage.objects FOR UPDATE TO authenticated
USING (
  bucket_id = 'countdown-photos'
  AND (storage.foldername(name))[1] = 'countdowns'
  AND EXISTS (
    SELECT 1 FROM countdowns c
    WHERE c.id::text = (storage.foldername(name))[2]
      AND can_write_to_account(c.account_id)
  )
)
WITH CHECK (
  bucket_id = 'countdown-photos'
  AND (storage.foldername(name))[1] = 'countdowns'
  AND EXISTS (
    SELECT 1 FROM countdowns c
    WHERE c.id::text = (storage.foldername(name))[2]
      AND can_write_to_account(c.account_id)
  )
);

CREATE POLICY "countdown_photos_delete"
ON storage.objects FOR DELETE TO authenticated
USING (
  bucket_id = 'countdown-photos'
  AND (storage.foldername(name))[1] = 'countdowns'
  AND EXISTS (
    SELECT 1 FROM countdowns c
    WHERE c.id::text = (storage.foldername(name))[2]
      AND can_write_to_account(c.account_id)
  )
);

-- ---- recipe-photos ----

CREATE POLICY "recipe_photos_select"
ON storage.objects FOR SELECT TO authenticated
USING (
  bucket_id = 'recipe-photos'
  AND (storage.foldername(name))[1] = 'recipes'
  AND EXISTS (
    SELECT 1 FROM recipes r
    WHERE r.id::text = (storage.foldername(name))[2]
      AND has_account_access(r.account_id)
  )
);

CREATE POLICY "recipe_photos_insert"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'recipe-photos'
  AND (storage.foldername(name))[1] = 'recipes'
  AND EXISTS (
    SELECT 1 FROM recipes r
    WHERE r.id::text = (storage.foldername(name))[2]
      AND has_account_access(r.account_id)
  )
);

CREATE POLICY "recipe_photos_update"
ON storage.objects FOR UPDATE TO authenticated
USING (
  bucket_id = 'recipe-photos'
  AND (storage.foldername(name))[1] = 'recipes'
  AND EXISTS (
    SELECT 1 FROM recipes r
    WHERE r.id::text = (storage.foldername(name))[2]
      AND has_account_access(r.account_id)
  )
)
WITH CHECK (
  bucket_id = 'recipe-photos'
  AND (storage.foldername(name))[1] = 'recipes'
  AND EXISTS (
    SELECT 1 FROM recipes r
    WHERE r.id::text = (storage.foldername(name))[2]
      AND has_account_access(r.account_id)
  )
);

CREATE POLICY "recipe_photos_delete"
ON storage.objects FOR DELETE TO authenticated
USING (
  bucket_id = 'recipe-photos'
  AND (storage.foldername(name))[1] = 'recipes'
  AND EXISTS (
    SELECT 1 FROM recipes r
    WHERE r.id::text = (storage.foldername(name))[2]
      AND has_account_access(r.account_id)
  )
);

-- ---- account-photos (for important_accounts table) ----

CREATE POLICY "account_photos_select"
ON storage.objects FOR SELECT TO authenticated
USING (
  bucket_id = 'account-photos'
  AND (storage.foldername(name))[1] = 'accounts'
  AND EXISTS (
    SELECT 1 FROM important_accounts ia
    JOIN profiles p ON p.id = ia.profile_id
    WHERE ia.id::text = (storage.foldername(name))[2]
      AND has_account_access(p.account_id)
  )
);

CREATE POLICY "account_photos_insert"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'account-photos'
  AND (storage.foldername(name))[1] = 'accounts'
  AND EXISTS (
    SELECT 1 FROM important_accounts ia
    JOIN profiles p ON p.id = ia.profile_id
    WHERE ia.id::text = (storage.foldername(name))[2]
      AND has_account_access(p.account_id)
  )
);

CREATE POLICY "account_photos_update"
ON storage.objects FOR UPDATE TO authenticated
USING (
  bucket_id = 'account-photos'
  AND (storage.foldername(name))[1] = 'accounts'
  AND EXISTS (
    SELECT 1 FROM important_accounts ia
    JOIN profiles p ON p.id = ia.profile_id
    WHERE ia.id::text = (storage.foldername(name))[2]
      AND has_account_access(p.account_id)
  )
)
WITH CHECK (
  bucket_id = 'account-photos'
  AND (storage.foldername(name))[1] = 'accounts'
  AND EXISTS (
    SELECT 1 FROM important_accounts ia
    JOIN profiles p ON p.id = ia.profile_id
    WHERE ia.id::text = (storage.foldername(name))[2]
      AND has_account_access(p.account_id)
  )
);

CREATE POLICY "account_photos_delete"
ON storage.objects FOR DELETE TO authenticated
USING (
  bucket_id = 'account-photos'
  AND (storage.foldername(name))[1] = 'accounts'
  AND EXISTS (
    SELECT 1 FROM important_accounts ia
    JOIN profiles p ON p.id = ia.profile_id
    WHERE ia.id::text = (storage.foldername(name))[2]
      AND has_account_access(p.account_id)
  )
);


-- ============================================================================
-- IMPORTANT - DO NOT RUN THE COLUMN MIGRATION YET.
--
-- The URL-to-path migration below is intentionally commented out. It must run
-- AT THE SAME TIME the iOS update is deployed, because once the columns hold
-- paths instead of URLs, the old app build cannot display images.
--
-- This will run as part of Phase 4. For now, just creating the policies above
-- is sufficient — they have no effect while the buckets remain public.
-- ============================================================================

-- Phase 4 will run something like this (DO NOT RUN NOW):
--
-- UPDATE profiles SET photo_url = regexp_replace(
--   photo_url,
--   '^https://[^/]+/storage/v1/object/public/profile-photos/',
--   ''
-- ) WHERE photo_url IS NOT NULL;
-- UPDATE profiles SET photo_url = regexp_replace(photo_url, '\?t=\d+$', '')
--   WHERE photo_url IS NOT NULL;
--
-- (And similar for medications, appointments, countdowns, recipes,
--  important_accounts.)


-- ============================================================================
-- VERIFICATION
-- ============================================================================

-- List all storage policies (should show 24 — 4 commands × 6 buckets):
--
--   SELECT policyname, cmd FROM pg_policies
--   WHERE schemaname = 'storage' AND tablename = 'objects'
--   ORDER BY policyname;

-- Confirm buckets are still public (we haven't flipped them yet):
--
--   SELECT name, public FROM storage.buckets ORDER BY name;
