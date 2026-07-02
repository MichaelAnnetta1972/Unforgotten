-- Migration: Useful Contact Photos storage bucket + column + RLS policies
--
-- Adds photo support to Useful Contacts:
--   1. `photo_url` column on the useful_contacts table (nullable storage path)
--   2. A private `useful-contact-photos` storage bucket
--   3. Storage RLS policies mirroring the other photo buckets — path convention
--      `useful-contacts/<contact_id>/photo.jpg`, authorized against the owning
--      contact's account via has_account_access / can_write_to_account.
--
-- The app uploads to path "useful-contacts/<contactId>/photo.jpg" and stores the
-- returned storage path in useful_contacts.photo_url; reads use signed URLs.

-- ============================================================================
-- PART 1: Add photo_url column to useful_contacts
-- ============================================================================

ALTER TABLE useful_contacts
    ADD COLUMN IF NOT EXISTS photo_url TEXT;

-- ============================================================================
-- PART 2: Create the private storage bucket (idempotent)
-- ============================================================================

INSERT INTO storage.buckets (id, name, public)
VALUES ('useful-contact-photos', 'useful-contact-photos', false)
ON CONFLICT (id) DO NOTHING;

-- ============================================================================
-- PART 3: Storage RLS policies
-- Path convention: useful-contacts/<contact_id>/photo.jpg
--   foldername[1] = 'useful-contacts'
--   foldername[2] = <contact_id>
-- NOTE 1: UUID comparison is wrapped in LOWER() on both sides. Swift's
-- .uuidString is UPPERCASE while Postgres uuid::text is lowercase, so a plain
-- string compare never matches and RLS silently denies the upload (same issue
-- fixed for the other buckets in storage_hardening_case_fix.sql).
--
-- NOTE 2: the storage object path MUST be referenced as storage.objects.name
-- inside the EXISTS subquery, NOT bare `name`. useful_contacts also has a `name`
-- column, so an unqualified `name` inside the correlated subquery binds to
-- useful_contacts.name (the contact's display name) instead of the file path —
-- so foldername() gets the wrong value and every upload is silently denied.
-- The other buckets avoid this only because their tables have no `name` column.
-- ============================================================================

DROP POLICY IF EXISTS "useful_contact_photos_select" ON storage.objects;
CREATE POLICY "useful_contact_photos_select"
ON storage.objects FOR SELECT TO authenticated
USING (
  bucket_id = 'useful-contact-photos'
  AND (storage.foldername(name))[1] = 'useful-contacts'
  AND EXISTS (
    SELECT 1 FROM useful_contacts c
    WHERE LOWER(c.id::text) = LOWER((storage.foldername(storage.objects.name))[2])
      AND has_account_access(c.account_id)
  )
);

DROP POLICY IF EXISTS "useful_contact_photos_insert" ON storage.objects;
CREATE POLICY "useful_contact_photos_insert"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'useful-contact-photos'
  AND (storage.foldername(name))[1] = 'useful-contacts'
  AND EXISTS (
    SELECT 1 FROM useful_contacts c
    WHERE LOWER(c.id::text) = LOWER((storage.foldername(storage.objects.name))[2])
      AND can_write_to_account(c.account_id)
  )
);

DROP POLICY IF EXISTS "useful_contact_photos_update" ON storage.objects;
CREATE POLICY "useful_contact_photos_update"
ON storage.objects FOR UPDATE TO authenticated
USING (
  bucket_id = 'useful-contact-photos'
  AND (storage.foldername(name))[1] = 'useful-contacts'
  AND EXISTS (
    SELECT 1 FROM useful_contacts c
    WHERE LOWER(c.id::text) = LOWER((storage.foldername(storage.objects.name))[2])
      AND can_write_to_account(c.account_id)
  )
)
WITH CHECK (
  bucket_id = 'useful-contact-photos'
  AND (storage.foldername(name))[1] = 'useful-contacts'
  AND EXISTS (
    SELECT 1 FROM useful_contacts c
    WHERE LOWER(c.id::text) = LOWER((storage.foldername(storage.objects.name))[2])
      AND can_write_to_account(c.account_id)
  )
);

DROP POLICY IF EXISTS "useful_contact_photos_delete" ON storage.objects;
CREATE POLICY "useful_contact_photos_delete"
ON storage.objects FOR DELETE TO authenticated
USING (
  bucket_id = 'useful-contact-photos'
  AND (storage.foldername(name))[1] = 'useful-contacts'
  AND EXISTS (
    SELECT 1 FROM useful_contacts c
    WHERE LOWER(c.id::text) = LOWER((storage.foldername(storage.objects.name))[2])
      AND can_write_to_account(c.account_id)
  )
);

-- ============================================================================
-- PART 4: Verify
-- ============================================================================

SELECT column_name FROM information_schema.columns
WHERE table_name = 'useful_contacts' AND column_name = 'photo_url';

SELECT id, public FROM storage.buckets WHERE id = 'useful-contact-photos';

-- Confirm the insert policy references storage.objects.name (not c.name):
-- the with_check text should contain "storage.foldername(objects.name)".
SELECT policyname, with_check FROM pg_policies
WHERE schemaname = 'storage' AND tablename = 'objects'
  AND policyname LIKE 'useful_contact_photos_%'
ORDER BY policyname;
