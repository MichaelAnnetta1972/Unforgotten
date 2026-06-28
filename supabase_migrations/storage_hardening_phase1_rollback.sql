-- ============================================================================
-- STORAGE HARDENING PHASE 1 - ROLLBACK
-- Removes all storage RLS policies created by Phase 1.
-- Buckets remain public (we never flipped them in Phase 1).
-- Safe to run any time — these policies have no effect while buckets are
-- public, so removing them changes nothing user-visible.
-- ============================================================================

DROP POLICY IF EXISTS "profile_photos_select" ON storage.objects;
DROP POLICY IF EXISTS "profile_photos_insert" ON storage.objects;
DROP POLICY IF EXISTS "profile_photos_update" ON storage.objects;
DROP POLICY IF EXISTS "profile_photos_delete" ON storage.objects;

DROP POLICY IF EXISTS "medication_photos_select" ON storage.objects;
DROP POLICY IF EXISTS "medication_photos_insert" ON storage.objects;
DROP POLICY IF EXISTS "medication_photos_update" ON storage.objects;
DROP POLICY IF EXISTS "medication_photos_delete" ON storage.objects;

DROP POLICY IF EXISTS "appointment_photos_select" ON storage.objects;
DROP POLICY IF EXISTS "appointment_photos_insert" ON storage.objects;
DROP POLICY IF EXISTS "appointment_photos_update" ON storage.objects;
DROP POLICY IF EXISTS "appointment_photos_delete" ON storage.objects;

DROP POLICY IF EXISTS "countdown_photos_select" ON storage.objects;
DROP POLICY IF EXISTS "countdown_photos_insert" ON storage.objects;
DROP POLICY IF EXISTS "countdown_photos_update" ON storage.objects;
DROP POLICY IF EXISTS "countdown_photos_delete" ON storage.objects;

DROP POLICY IF EXISTS "recipe_photos_select" ON storage.objects;
DROP POLICY IF EXISTS "recipe_photos_insert" ON storage.objects;
DROP POLICY IF EXISTS "recipe_photos_update" ON storage.objects;
DROP POLICY IF EXISTS "recipe_photos_delete" ON storage.objects;

DROP POLICY IF EXISTS "account_photos_select" ON storage.objects;
DROP POLICY IF EXISTS "account_photos_insert" ON storage.objects;
DROP POLICY IF EXISTS "account_photos_update" ON storage.objects;
DROP POLICY IF EXISTS "account_photos_delete" ON storage.objects;
