-- Migration: Fix Important Accounts Sharing Preference
-- 1. The update_sharing_preference() RPC was missing 'important_accounts' in its
--    category CASE statement, causing toggles to fail with "Unknown category" error.
--    Important accounts don't use profile_details (they have their own table),
--    so the detail_categories array is empty like profile_fields.
-- 2. Add sharing_important_accounts column to account_invitations table so the
--    invite-time preference is stored and used during acceptance.

-- ============================================================================
-- PART 1: Update update_sharing_preference() to handle 'important_accounts'
-- ============================================================================

CREATE OR REPLACE FUNCTION update_sharing_preference(
    p_profile_id UUID,
    p_category TEXT,
    p_is_shared BOOLEAN,
    p_target_user_id UUID DEFAULT NULL
) RETURNS JSON AS $$
DECLARE
    v_profile RECORD;
    v_sync RECORD;
    v_detail RECORD;
    v_target_profile_id UUID;
    v_target_account_id UUID;
    v_new_detail_id UUID;
    v_detail_categories TEXT[];
    v_actual_target_user_id UUID;
BEGIN
    PERFORM set_config('row_security', 'off', true);

    -- Get the profile
    SELECT * INTO v_profile FROM profiles WHERE id = p_profile_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Profile not found';
    END IF;

    -- Map sharing category to detail categories
    CASE p_category
        WHEN 'medical' THEN v_detail_categories := ARRAY['medical_condition', 'allergy'];
        WHEN 'gift_idea' THEN v_detail_categories := ARRAY['gift_idea'];
        WHEN 'clothing' THEN v_detail_categories := ARRAY['clothing'];
        WHEN 'hobby' THEN v_detail_categories := ARRAY['hobby'];
        WHEN 'activity_idea' THEN v_detail_categories := ARRAY['activity_idea'];
        WHEN 'profile_fields' THEN v_detail_categories := ARRAY[]::TEXT[];
        WHEN 'important_accounts' THEN v_detail_categories := ARRAY[]::TEXT[];
        ELSE RAISE EXCEPTION 'Unknown category: %', p_category;
    END CASE;

    IF p_target_user_id IS NOT NULL THEN
        -- ===== PER-USER MODE =====
        v_actual_target_user_id := p_target_user_id;

        -- Upsert the sharing preference for this specific target user
        INSERT INTO profile_sharing_preferences (profile_id, user_id, target_user_id, category, is_shared)
        VALUES (p_profile_id, COALESCE(v_profile.linked_user_id, auth.uid()), v_actual_target_user_id, p_category, p_is_shared)
        ON CONFLICT (profile_id, target_user_id, category)
        DO UPDATE SET is_shared = p_is_shared, updated_at = NOW();

        -- Find the specific sync connection for this target user
        FOR v_sync IN
            SELECT * FROM profile_syncs
            WHERE status = 'active'
              AND (
                  (inviter_source_profile_id = p_profile_id AND acceptor_user_id = v_actual_target_user_id)
                  OR
                  (acceptor_source_profile_id = p_profile_id AND inviter_user_id = v_actual_target_user_id)
              )
        LOOP
            -- Determine the target synced profile
            IF v_sync.inviter_source_profile_id = p_profile_id THEN
                v_target_profile_id := v_sync.acceptor_synced_profile_id;
                v_target_account_id := v_sync.acceptor_account_id;
            ELSE
                v_target_profile_id := v_sync.inviter_synced_profile_id;
                v_target_account_id := v_sync.inviter_account_id;
            END IF;

            IF NOT p_is_shared THEN
                -- Delete synced detail copies for this category on this specific connection
                IF array_length(v_detail_categories, 1) > 0 AND v_target_profile_id IS NOT NULL THEN
                    DELETE FROM profile_details
                    WHERE id IN (
                        SELECT pds.synced_detail_id
                        FROM profile_detail_syncs pds
                        JOIN profile_details pd ON pd.id = pds.source_detail_id
                        WHERE pds.sync_connection_id = v_sync.id
                          AND pd.profile_id = p_profile_id
                          AND pd.category = ANY(v_detail_categories)
                    );

                    DELETE FROM profile_detail_syncs
                    WHERE sync_connection_id = v_sync.id
                      AND source_detail_id IN (
                          SELECT id FROM profile_details
                          WHERE profile_id = p_profile_id
                            AND category = ANY(v_detail_categories)
                      );
                END IF;

                -- Handle profile_fields
                IF p_category = 'profile_fields' AND v_target_profile_id IS NOT NULL THEN
                    UPDATE profiles SET
                        address = NULL, phone = NULL, photo_url = NULL, updated_at = NOW()
                    WHERE id = v_target_profile_id
                      AND source_user_id IS NOT NULL;
                END IF;
            ELSE
                -- Re-sync details for this specific connection
                IF v_target_profile_id IS NOT NULL THEN
                    IF p_category = 'profile_fields' THEN
                        UPDATE profiles SET
                            address = v_profile.address, phone = v_profile.phone,
                            photo_url = v_profile.photo_url, updated_at = NOW()
                        WHERE id = v_target_profile_id
                          AND source_user_id IS NOT NULL;
                    END IF;

                    IF array_length(v_detail_categories, 1) > 0 THEN
                        FOR v_detail IN
                            SELECT * FROM profile_details
                            WHERE profile_id = p_profile_id
                              AND category = ANY(v_detail_categories)
                              AND id NOT IN (
                                  SELECT source_detail_id FROM profile_detail_syncs
                                  WHERE sync_connection_id = v_sync.id
                              )
                        LOOP
                            INSERT INTO profile_details (
                                account_id, profile_id, category, label, value,
                                status, occasion, metadata
                            ) VALUES (
                                v_target_account_id, v_target_profile_id, v_detail.category,
                                v_detail.label, v_detail.value, v_detail.status,
                                v_detail.occasion, v_detail.metadata
                            ) RETURNING id INTO v_new_detail_id;

                            INSERT INTO profile_detail_syncs (sync_connection_id, source_detail_id, synced_detail_id)
                            VALUES (v_sync.id, v_detail.id, v_new_detail_id);
                        END LOOP;
                    END IF;
                END IF;
            END IF;
        END LOOP;
    ELSE
        -- ===== LEGACY MODE (no target user specified) =====
        -- Apply to ALL connections (backward compatible)

        FOR v_sync IN
            SELECT * FROM profile_syncs
            WHERE status = 'active'
              AND (inviter_source_profile_id = p_profile_id OR acceptor_source_profile_id = p_profile_id)
        LOOP
            IF v_sync.inviter_source_profile_id = p_profile_id THEN
                v_actual_target_user_id := v_sync.acceptor_user_id;
                v_target_profile_id := v_sync.acceptor_synced_profile_id;
                v_target_account_id := v_sync.acceptor_account_id;
            ELSE
                v_actual_target_user_id := v_sync.inviter_user_id;
                v_target_profile_id := v_sync.inviter_synced_profile_id;
                v_target_account_id := v_sync.inviter_account_id;
            END IF;

            INSERT INTO profile_sharing_preferences (profile_id, user_id, target_user_id, category, is_shared)
            VALUES (p_profile_id, COALESCE(v_profile.linked_user_id, auth.uid()), v_actual_target_user_id, p_category, p_is_shared)
            ON CONFLICT (profile_id, target_user_id, category)
            DO UPDATE SET is_shared = p_is_shared, updated_at = NOW();

            IF NOT p_is_shared THEN
                IF array_length(v_detail_categories, 1) > 0 AND v_target_profile_id IS NOT NULL THEN
                    DELETE FROM profile_details
                    WHERE id IN (
                        SELECT pds.synced_detail_id
                        FROM profile_detail_syncs pds
                        JOIN profile_details pd ON pd.id = pds.source_detail_id
                        WHERE pds.sync_connection_id = v_sync.id
                          AND pd.profile_id = p_profile_id
                          AND pd.category = ANY(v_detail_categories)
                    );
                    DELETE FROM profile_detail_syncs
                    WHERE sync_connection_id = v_sync.id
                      AND source_detail_id IN (
                          SELECT id FROM profile_details
                          WHERE profile_id = p_profile_id
                            AND category = ANY(v_detail_categories)
                      );
                END IF;

                IF p_category = 'profile_fields' AND v_target_profile_id IS NOT NULL THEN
                    UPDATE profiles SET
                        address = NULL, phone = NULL, photo_url = NULL, updated_at = NOW()
                    WHERE id = v_target_profile_id AND source_user_id IS NOT NULL;
                END IF;
            ELSE
                IF v_target_profile_id IS NOT NULL THEN
                    IF p_category = 'profile_fields' THEN
                        UPDATE profiles SET
                            address = v_profile.address, phone = v_profile.phone,
                            photo_url = v_profile.photo_url, updated_at = NOW()
                        WHERE id = v_target_profile_id AND source_user_id IS NOT NULL;
                    END IF;

                    IF array_length(v_detail_categories, 1) > 0 THEN
                        FOR v_detail IN
                            SELECT * FROM profile_details
                            WHERE profile_id = p_profile_id
                              AND category = ANY(v_detail_categories)
                              AND id NOT IN (
                                  SELECT source_detail_id FROM profile_detail_syncs
                                  WHERE sync_connection_id = v_sync.id
                              )
                        LOOP
                            INSERT INTO profile_details (
                                account_id, profile_id, category, label, value,
                                status, occasion, metadata
                            ) VALUES (
                                v_target_account_id, v_target_profile_id, v_detail.category,
                                v_detail.label, v_detail.value, v_detail.status,
                                v_detail.occasion, v_detail.metadata
                            ) RETURNING id INTO v_new_detail_id;

                            INSERT INTO profile_detail_syncs (sync_connection_id, source_detail_id, synced_detail_id)
                            VALUES (v_sync.id, v_detail.id, v_new_detail_id);
                        END LOOP;
                    END IF;
                END IF;
            END IF;
        END LOOP;
    END IF;

    RETURN json_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- PART 2: Add sharing_important_accounts column to account_invitations
-- ============================================================================

ALTER TABLE account_invitations
ADD COLUMN IF NOT EXISTS sharing_important_accounts BOOLEAN NOT NULL DEFAULT TRUE;
