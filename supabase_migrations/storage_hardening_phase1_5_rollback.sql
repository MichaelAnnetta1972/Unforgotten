-- ============================================================================
-- STORAGE HARDENING PHASE 1.5 - ROLLBACK
--
-- Recreates the legacy storage policies that Phase 1.5 dropped. These are
-- restored exactly as they were (overly permissive — that's the point of a
-- rollback, to return to prior state).
--
-- Only use this if dropping them in Phase 1.5 broke something unexpectedly.
-- Most likely you won't need this — the new policies cover all legitimate
-- operations.
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
