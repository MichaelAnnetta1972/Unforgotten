-- ============================================================================
-- STORAGE POLICY CASE-SENSITIVITY FIX
-- Date: 2026-05-10
--
-- The Phase 1 storage policies compared `(storage.foldername(name))[2]` against
-- `<table>.id::text`. Swift's UUID().uuidString returns UPPERCASE, while
-- Postgres uuid::text always returns LOWERCASE — so the string comparison
-- never matched and all reads were denied after the bucket flip.
--
-- Fix: wrap both sides of every UUID comparison in LOWER().
-- Safe to run on a live system; no data is modified, only policies.
-- ============================================================================

-- ---- profile-photos ----

DROP POLICY IF EXISTS "profile_photos_select" ON storage.objects;
CREATE POLICY "profile_photos_select"
ON storage.objects FOR SELECT TO authenticated
USING (
  bucket_id = 'profile-photos'
  AND (storage.foldername(name))[1] = 'profiles'
  AND EXISTS (
    SELECT 1 FROM profiles p
    WHERE LOWER(p.id::text) = LOWER((storage.foldername(name))[2])
      AND has_account_access(p.account_id)
  )
);

DROP POLICY IF EXISTS "profile_photos_insert" ON storage.objects;
CREATE POLICY "profile_photos_insert"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'profile-photos'
  AND (storage.foldername(name))[1] = 'profiles'
  AND EXISTS (
    SELECT 1 FROM profiles p
    WHERE LOWER(p.id::text) = LOWER((storage.foldername(name))[2])
      AND can_write_to_account(p.account_id)
  )
);

DROP POLICY IF EXISTS "profile_photos_update" ON storage.objects;
CREATE POLICY "profile_photos_update"
ON storage.objects FOR UPDATE TO authenticated
USING (
  bucket_id = 'profile-photos'
  AND (storage.foldername(name))[1] = 'profiles'
  AND EXISTS (
    SELECT 1 FROM profiles p
    WHERE LOWER(p.id::text) = LOWER((storage.foldername(name))[2])
      AND can_write_to_account(p.account_id)
  )
)
WITH CHECK (
  bucket_id = 'profile-photos'
  AND (storage.foldername(name))[1] = 'profiles'
  AND EXISTS (
    SELECT 1 FROM profiles p
    WHERE LOWER(p.id::text) = LOWER((storage.foldername(name))[2])
      AND can_write_to_account(p.account_id)
  )
);

DROP POLICY IF EXISTS "profile_photos_delete" ON storage.objects;
CREATE POLICY "profile_photos_delete"
ON storage.objects FOR DELETE TO authenticated
USING (
  bucket_id = 'profile-photos'
  AND (storage.foldername(name))[1] = 'profiles'
  AND EXISTS (
    SELECT 1 FROM profiles p
    WHERE LOWER(p.id::text) = LOWER((storage.foldername(name))[2])
      AND can_write_to_account(p.account_id)
  )
);

-- ---- medication-photos ----

DROP POLICY IF EXISTS "medication_photos_select" ON storage.objects;
CREATE POLICY "medication_photos_select"
ON storage.objects FOR SELECT TO authenticated
USING (
  bucket_id = 'medication-photos'
  AND (storage.foldername(name))[1] = 'medications'
  AND EXISTS (
    SELECT 1 FROM medications m
    WHERE LOWER(m.id::text) = LOWER((storage.foldername(name))[2])
      AND has_account_access(m.account_id)
  )
);

DROP POLICY IF EXISTS "medication_photos_insert" ON storage.objects;
CREATE POLICY "medication_photos_insert"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'medication-photos'
  AND (storage.foldername(name))[1] = 'medications'
  AND EXISTS (
    SELECT 1 FROM medications m
    WHERE LOWER(m.id::text) = LOWER((storage.foldername(name))[2])
      AND can_write_to_account(m.account_id)
  )
);

DROP POLICY IF EXISTS "medication_photos_update" ON storage.objects;
CREATE POLICY "medication_photos_update"
ON storage.objects FOR UPDATE TO authenticated
USING (
  bucket_id = 'medication-photos'
  AND (storage.foldername(name))[1] = 'medications'
  AND EXISTS (
    SELECT 1 FROM medications m
    WHERE LOWER(m.id::text) = LOWER((storage.foldername(name))[2])
      AND can_write_to_account(m.account_id)
  )
)
WITH CHECK (
  bucket_id = 'medication-photos'
  AND (storage.foldername(name))[1] = 'medications'
  AND EXISTS (
    SELECT 1 FROM medications m
    WHERE LOWER(m.id::text) = LOWER((storage.foldername(name))[2])
      AND can_write_to_account(m.account_id)
  )
);

DROP POLICY IF EXISTS "medication_photos_delete" ON storage.objects;
CREATE POLICY "medication_photos_delete"
ON storage.objects FOR DELETE TO authenticated
USING (
  bucket_id = 'medication-photos'
  AND (storage.foldername(name))[1] = 'medications'
  AND EXISTS (
    SELECT 1 FROM medications m
    WHERE LOWER(m.id::text) = LOWER((storage.foldername(name))[2])
      AND can_write_to_account(m.account_id)
  )
);

-- ---- appointment-photos ----

DROP POLICY IF EXISTS "appointment_photos_select" ON storage.objects;
CREATE POLICY "appointment_photos_select"
ON storage.objects FOR SELECT TO authenticated
USING (
  bucket_id = 'appointment-photos'
  AND (storage.foldername(name))[1] = 'appointments'
  AND EXISTS (
    SELECT 1 FROM appointments a
    WHERE LOWER(a.id::text) = LOWER((storage.foldername(name))[2])
      AND has_account_access(a.account_id)
  )
);

DROP POLICY IF EXISTS "appointment_photos_insert" ON storage.objects;
CREATE POLICY "appointment_photos_insert"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'appointment-photos'
  AND (storage.foldername(name))[1] = 'appointments'
  AND EXISTS (
    SELECT 1 FROM appointments a
    WHERE LOWER(a.id::text) = LOWER((storage.foldername(name))[2])
      AND can_write_to_account(a.account_id)
  )
);

DROP POLICY IF EXISTS "appointment_photos_update" ON storage.objects;
CREATE POLICY "appointment_photos_update"
ON storage.objects FOR UPDATE TO authenticated
USING (
  bucket_id = 'appointment-photos'
  AND (storage.foldername(name))[1] = 'appointments'
  AND EXISTS (
    SELECT 1 FROM appointments a
    WHERE LOWER(a.id::text) = LOWER((storage.foldername(name))[2])
      AND can_write_to_account(a.account_id)
  )
)
WITH CHECK (
  bucket_id = 'appointment-photos'
  AND (storage.foldername(name))[1] = 'appointments'
  AND EXISTS (
    SELECT 1 FROM appointments a
    WHERE LOWER(a.id::text) = LOWER((storage.foldername(name))[2])
      AND can_write_to_account(a.account_id)
  )
);

DROP POLICY IF EXISTS "appointment_photos_delete" ON storage.objects;
CREATE POLICY "appointment_photos_delete"
ON storage.objects FOR DELETE TO authenticated
USING (
  bucket_id = 'appointment-photos'
  AND (storage.foldername(name))[1] = 'appointments'
  AND EXISTS (
    SELECT 1 FROM appointments a
    WHERE LOWER(a.id::text) = LOWER((storage.foldername(name))[2])
      AND can_write_to_account(a.account_id)
  )
);

-- ---- countdown-photos ----

DROP POLICY IF EXISTS "countdown_photos_select" ON storage.objects;
CREATE POLICY "countdown_photos_select"
ON storage.objects FOR SELECT TO authenticated
USING (
  bucket_id = 'countdown-photos'
  AND (storage.foldername(name))[1] = 'countdowns'
  AND EXISTS (
    SELECT 1 FROM countdowns c
    WHERE LOWER(c.id::text) = LOWER((storage.foldername(name))[2])
      AND has_account_access(c.account_id)
  )
);

DROP POLICY IF EXISTS "countdown_photos_insert" ON storage.objects;
CREATE POLICY "countdown_photos_insert"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'countdown-photos'
  AND (storage.foldername(name))[1] = 'countdowns'
  AND EXISTS (
    SELECT 1 FROM countdowns c
    WHERE LOWER(c.id::text) = LOWER((storage.foldername(name))[2])
      AND can_write_to_account(c.account_id)
  )
);

DROP POLICY IF EXISTS "countdown_photos_update" ON storage.objects;
CREATE POLICY "countdown_photos_update"
ON storage.objects FOR UPDATE TO authenticated
USING (
  bucket_id = 'countdown-photos'
  AND (storage.foldername(name))[1] = 'countdowns'
  AND EXISTS (
    SELECT 1 FROM countdowns c
    WHERE LOWER(c.id::text) = LOWER((storage.foldername(name))[2])
      AND can_write_to_account(c.account_id)
  )
)
WITH CHECK (
  bucket_id = 'countdown-photos'
  AND (storage.foldername(name))[1] = 'countdowns'
  AND EXISTS (
    SELECT 1 FROM countdowns c
    WHERE LOWER(c.id::text) = LOWER((storage.foldername(name))[2])
      AND can_write_to_account(c.account_id)
  )
);

DROP POLICY IF EXISTS "countdown_photos_delete" ON storage.objects;
CREATE POLICY "countdown_photos_delete"
ON storage.objects FOR DELETE TO authenticated
USING (
  bucket_id = 'countdown-photos'
  AND (storage.foldername(name))[1] = 'countdowns'
  AND EXISTS (
    SELECT 1 FROM countdowns c
    WHERE LOWER(c.id::text) = LOWER((storage.foldername(name))[2])
      AND can_write_to_account(c.account_id)
  )
);

-- ---- recipe-photos ----

DROP POLICY IF EXISTS "recipe_photos_select" ON storage.objects;
CREATE POLICY "recipe_photos_select"
ON storage.objects FOR SELECT TO authenticated
USING (
  bucket_id = 'recipe-photos'
  AND (storage.foldername(name))[1] = 'recipes'
  AND EXISTS (
    SELECT 1 FROM recipes r
    WHERE LOWER(r.id::text) = LOWER((storage.foldername(name))[2])
      AND has_account_access(r.account_id)
  )
);

DROP POLICY IF EXISTS "recipe_photos_insert" ON storage.objects;
CREATE POLICY "recipe_photos_insert"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'recipe-photos'
  AND (storage.foldername(name))[1] = 'recipes'
  AND EXISTS (
    SELECT 1 FROM recipes r
    WHERE LOWER(r.id::text) = LOWER((storage.foldername(name))[2])
      AND has_account_access(r.account_id)
  )
);

DROP POLICY IF EXISTS "recipe_photos_update" ON storage.objects;
CREATE POLICY "recipe_photos_update"
ON storage.objects FOR UPDATE TO authenticated
USING (
  bucket_id = 'recipe-photos'
  AND (storage.foldername(name))[1] = 'recipes'
  AND EXISTS (
    SELECT 1 FROM recipes r
    WHERE LOWER(r.id::text) = LOWER((storage.foldername(name))[2])
      AND has_account_access(r.account_id)
  )
)
WITH CHECK (
  bucket_id = 'recipe-photos'
  AND (storage.foldername(name))[1] = 'recipes'
  AND EXISTS (
    SELECT 1 FROM recipes r
    WHERE LOWER(r.id::text) = LOWER((storage.foldername(name))[2])
      AND has_account_access(r.account_id)
  )
);

DROP POLICY IF EXISTS "recipe_photos_delete" ON storage.objects;
CREATE POLICY "recipe_photos_delete"
ON storage.objects FOR DELETE TO authenticated
USING (
  bucket_id = 'recipe-photos'
  AND (storage.foldername(name))[1] = 'recipes'
  AND EXISTS (
    SELECT 1 FROM recipes r
    WHERE LOWER(r.id::text) = LOWER((storage.foldername(name))[2])
      AND has_account_access(r.account_id)
  )
);

-- ---- account-photos (for important_accounts table) ----

DROP POLICY IF EXISTS "account_photos_select" ON storage.objects;
CREATE POLICY "account_photos_select"
ON storage.objects FOR SELECT TO authenticated
USING (
  bucket_id = 'account-photos'
  AND (storage.foldername(name))[1] = 'accounts'
  AND EXISTS (
    SELECT 1 FROM important_accounts ia
    JOIN profiles p ON p.id = ia.profile_id
    WHERE LOWER(ia.id::text) = LOWER((storage.foldername(name))[2])
      AND has_account_access(p.account_id)
  )
);

DROP POLICY IF EXISTS "account_photos_insert" ON storage.objects;
CREATE POLICY "account_photos_insert"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'account-photos'
  AND (storage.foldername(name))[1] = 'accounts'
  AND EXISTS (
    SELECT 1 FROM important_accounts ia
    JOIN profiles p ON p.id = ia.profile_id
    WHERE LOWER(ia.id::text) = LOWER((storage.foldername(name))[2])
      AND has_account_access(p.account_id)
  )
);

DROP POLICY IF EXISTS "account_photos_update" ON storage.objects;
CREATE POLICY "account_photos_update"
ON storage.objects FOR UPDATE TO authenticated
USING (
  bucket_id = 'account-photos'
  AND (storage.foldername(name))[1] = 'accounts'
  AND EXISTS (
    SELECT 1 FROM important_accounts ia
    JOIN profiles p ON p.id = ia.profile_id
    WHERE LOWER(ia.id::text) = LOWER((storage.foldername(name))[2])
      AND has_account_access(p.account_id)
  )
)
WITH CHECK (
  bucket_id = 'account-photos'
  AND (storage.foldername(name))[1] = 'accounts'
  AND EXISTS (
    SELECT 1 FROM important_accounts ia
    JOIN profiles p ON p.id = ia.profile_id
    WHERE LOWER(ia.id::text) = LOWER((storage.foldername(name))[2])
      AND has_account_access(p.account_id)
  )
);

DROP POLICY IF EXISTS "account_photos_delete" ON storage.objects;
CREATE POLICY "account_photos_delete"
ON storage.objects FOR DELETE TO authenticated
USING (
  bucket_id = 'account-photos'
  AND (storage.foldername(name))[1] = 'accounts'
  AND EXISTS (
    SELECT 1 FROM important_accounts ia
    JOIN profiles p ON p.id = ia.profile_id
    WHERE LOWER(ia.id::text) = LOWER((storage.foldername(name))[2])
      AND has_account_access(p.account_id)
  )
);
