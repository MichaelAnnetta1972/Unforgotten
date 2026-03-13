-- Migration: Fix Sharing Preference Direction + Initial Detail Copy
--
-- ISSUE 1: update_sharing_preference() had the SAME swapped synced profile ID bug
-- as the propagation triggers (fixed in fix_propagation_direction.sql).
-- When inviter_source_profile_id matched, it was targeting acceptor_synced_profile_id
-- (acceptor's copy in inviter's account) instead of inviter_synced_profile_id
-- (inviter's copy in acceptor's account). This caused:
--   - Toggle OFF worked (deletes from wrong profile, but still removes data)
--   - Toggle ON failed to appear on acceptor's device (re-synced to wrong profile)
--   - Re-sync put inviter's data on acceptor's synced profile
--
-- ISSUE 2: accept_invitation_with_sync() step 9 copies acceptor's details correctly,
-- but the detail INSERT fires propagate_profile_detail_changes trigger. Although the
-- trigger should skip synced profiles, the profile_syncs record is already set up at
-- that point. We add an explicit guard: disable the trigger during bulk copy operations
-- within the RPC, then re-enable after.
--
-- ISSUE 3: Step 10's category filter was missing 'important_accounts' mapping.
-- Categories like 'important_account' in profile_details fell through to ELSE
-- which defaults to v_is_shared := TRUE, but the actual detail category name
-- needs to be checked.

-- ============================================================================
-- PART 1: Fix update_sharing_preference() - correct synced profile ID mapping
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
            -- FIXED: Correct direction mapping
            -- When inviter's source profile changes → target is inviter_synced_profile_id
            --   (the copy of the inviter in the acceptor's account)
            -- When acceptor's source profile changes → target is acceptor_synced_profile_id
            --   (the copy of the acceptor in the inviter's account)
            IF v_sync.inviter_source_profile_id = p_profile_id THEN
                v_target_profile_id := v_sync.inviter_synced_profile_id;
                v_target_account_id := v_sync.acceptor_account_id;
            ELSE
                v_target_profile_id := v_sync.acceptor_synced_profile_id;
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
                        -- Temporarily disable the propagation trigger to prevent cascading
                        ALTER TABLE profile_details DISABLE TRIGGER trigger_propagate_profile_detail_changes;

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

                        -- Re-enable the propagation trigger
                        ALTER TABLE profile_details ENABLE TRIGGER trigger_propagate_profile_detail_changes;
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
            -- FIXED: Correct direction mapping (same fix as per-user mode)
            IF v_sync.inviter_source_profile_id = p_profile_id THEN
                v_actual_target_user_id := v_sync.acceptor_user_id;
                v_target_profile_id := v_sync.inviter_synced_profile_id;
                v_target_account_id := v_sync.acceptor_account_id;
            ELSE
                v_actual_target_user_id := v_sync.inviter_user_id;
                v_target_profile_id := v_sync.acceptor_synced_profile_id;
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
                        -- Temporarily disable the propagation trigger to prevent cascading
                        ALTER TABLE profile_details DISABLE TRIGGER trigger_propagate_profile_detail_changes;

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

                        -- Re-enable the propagation trigger
                        ALTER TABLE profile_details ENABLE TRIGGER trigger_propagate_profile_detail_changes;
                    END IF;
                END IF;
            END IF;
        END LOOP;
    END IF;

    RETURN json_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- PART 2: Fix accept_invitation_with_sync() - disable trigger during bulk copy
-- ============================================================================
-- The propagation trigger fires on each INSERT in steps 9 and 10.
-- Even though it should skip synced profiles, we disable it for safety
-- and to prevent any cascading issues.

CREATE OR REPLACE FUNCTION accept_invitation_with_sync(
    p_invitation_id UUID,
    p_user_id UUID,
    p_acceptor_profile_id UUID DEFAULT NULL,
    p_acceptor_account_id UUID DEFAULT NULL,
    p_existing_profile_id UUID DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_invitation account_invitations%ROWTYPE;
    v_inviter_profile profiles%ROWTYPE;
    v_acceptor_profile profiles%ROWTYPE;
    v_sync_id UUID;
    v_inviter_synced_profile_id UUID;
    v_acceptor_synced_profile_id UUID;
    v_debug TEXT := '';
    v_category TEXT;
    v_is_shared BOOLEAN;
    v_sharing_categories TEXT[] := ARRAY['profile_fields', 'medical', 'gift_idea', 'clothing', 'hobby', 'activity_idea', 'important_accounts'];
    v_detail RECORD;
    v_synced_detail_id UUID;
BEGIN
    -- 1. Get and validate the invitation
    SELECT * INTO v_invitation FROM account_invitations WHERE id = p_invitation_id;

    IF v_invitation IS NULL THEN
        RETURN json_build_object('success', false, 'error', 'Invitation not found');
    END IF;

    IF v_invitation.status != 'pending' THEN
        RETURN json_build_object('success', false, 'error', 'Invitation is no longer pending');
    END IF;

    IF v_invitation.expires_at < NOW() THEN
        RETURN json_build_object('success', false, 'error', 'Invitation has expired');
    END IF;

    -- Check user is not already a member
    IF EXISTS (SELECT 1 FROM account_members WHERE account_id = v_invitation.account_id AND user_id = p_user_id) THEN
        RETURN json_build_object('success', false, 'error', 'User is already a member of this account');
    END IF;

    v_debug := v_debug || 'Validated. ';

    -- 2. Accept the invitation - add user as account member
    INSERT INTO account_members (account_id, user_id, role)
    VALUES (v_invitation.account_id, p_user_id, v_invitation.role);

    -- 2b. Add inviter as viewer in acceptor's account (reciprocal membership)
    IF p_acceptor_account_id IS NOT NULL THEN
        INSERT INTO account_members (account_id, user_id, role)
        VALUES (p_acceptor_account_id, v_invitation.invited_by, 'viewer')
        ON CONFLICT (account_id, user_id) DO NOTHING;
    END IF;

    -- Mark invitation as accepted
    UPDATE account_invitations
    SET status = 'accepted', accepted_at = NOW(), accepted_by = p_user_id
    WHERE id = p_invitation_id;

    v_debug := v_debug || 'Member added. ';

    -- 3. Get inviter's primary profile
    SELECT * INTO v_inviter_profile
    FROM profiles
    WHERE account_id = v_invitation.account_id
      AND type = 'primary'
    LIMIT 1;

    IF v_inviter_profile IS NULL THEN
        v_debug := v_debug || 'No inviter primary profile. ';
        RETURN json_build_object(
            'success', true,
            'error', NULL,
            'sync_id', NULL,
            'inviter_synced_profile_id', NULL,
            'acceptor_synced_profile_id', NULL,
            'debug', v_debug
        );
    END IF;

    v_debug := v_debug || 'Inviter profile found. ';

    -- 4. Get acceptor's profile
    IF p_acceptor_profile_id IS NOT NULL THEN
        SELECT * INTO v_acceptor_profile FROM profiles WHERE id = p_acceptor_profile_id;
        IF v_acceptor_profile.id IS NOT NULL THEN
            v_debug := v_debug || 'Acceptor profile found. ';
        ELSE
            v_debug := v_debug || 'Acceptor profile ID given but not found! ';
        END IF;
    ELSE
        -- Try to find the acceptor's primary profile
        IF p_acceptor_account_id IS NOT NULL THEN
            SELECT * INTO v_acceptor_profile
            FROM profiles
            WHERE account_id = p_acceptor_account_id AND type = 'primary'
            LIMIT 1;
            IF v_acceptor_profile.id IS NOT NULL THEN
                v_debug := v_debug || 'Acceptor profile auto-found. ';
            ELSE
                v_debug := v_debug || 'No acceptor primary profile in account. ';
            END IF;
        ELSE
            v_debug := v_debug || 'No acceptor account ID provided. ';
        END IF;
    END IF;

    -- 5. Create the profile sync record
    v_sync_id := gen_random_uuid();

    INSERT INTO profile_syncs (
        id, invitation_id,
        inviter_user_id, inviter_account_id, inviter_source_profile_id,
        acceptor_user_id, acceptor_account_id,
        acceptor_source_profile_id,
        status
    ) VALUES (
        v_sync_id, p_invitation_id,
        v_invitation.invited_by, v_invitation.account_id, v_inviter_profile.id,
        p_user_id, p_acceptor_account_id,
        CASE WHEN v_acceptor_profile.id IS NOT NULL THEN v_acceptor_profile.id ELSE p_acceptor_profile_id END,
        'active'
    );

    v_debug := v_debug || 'Sync created. ';

    -- 6. Create synced profile of acceptor in inviter's account
    IF p_existing_profile_id IS NOT NULL THEN
        -- Link to existing profile instead of creating new
        UPDATE profiles SET
            source_user_id = p_user_id,
            linked_user_id = p_user_id,
            sync_connection_id = v_sync_id,
            is_local_only = false,
            synced_fields = ARRAY['full_name', 'preferred_name', 'email', 'birthday', 'is_deceased'],
            full_name = COALESCE(v_acceptor_profile.full_name, full_name),
            preferred_name = COALESCE(v_acceptor_profile.preferred_name, preferred_name),
            email = COALESCE(v_acceptor_profile.email, email),
            birthday = COALESCE(v_acceptor_profile.birthday, birthday),
            is_deceased = COALESCE(v_acceptor_profile.is_deceased, is_deceased),
            address = CASE WHEN v_invitation.sharing_profile_fields THEN COALESCE(v_acceptor_profile.address, address) ELSE address END,
            phone = CASE WHEN v_invitation.sharing_profile_fields THEN COALESCE(v_acceptor_profile.phone, phone) ELSE phone END,
            photo_url = CASE WHEN v_invitation.sharing_profile_fields THEN COALESCE(v_acceptor_profile.photo_url, photo_url) ELSE photo_url END,
            updated_at = NOW()
        WHERE id = p_existing_profile_id;

        v_acceptor_synced_profile_id := p_existing_profile_id;
        v_debug := v_debug || 'Linked existing. ';
    ELSE
        -- Create new synced profile
        v_acceptor_synced_profile_id := gen_random_uuid();

        INSERT INTO profiles (
            id, account_id, type, full_name, preferred_name, birthday, email,
            address, phone, photo_url, is_deceased, is_favourite, sort_order,
            source_user_id, linked_user_id, sync_connection_id, is_local_only,
            synced_fields, include_in_family_tree
        ) VALUES (
            v_acceptor_synced_profile_id,
            v_invitation.account_id,
            'relative',
            COALESCE(v_acceptor_profile.full_name, 'Connected User'),
            v_acceptor_profile.preferred_name,
            v_acceptor_profile.birthday,
            v_acceptor_profile.email,
            CASE WHEN v_invitation.sharing_profile_fields THEN v_acceptor_profile.address ELSE NULL END,
            CASE WHEN v_invitation.sharing_profile_fields THEN v_acceptor_profile.phone ELSE NULL END,
            CASE WHEN v_invitation.sharing_profile_fields THEN v_acceptor_profile.photo_url ELSE NULL END,
            COALESCE(v_acceptor_profile.is_deceased, false),
            false,
            0,
            p_user_id,
            p_user_id,
            v_sync_id,
            false,
            ARRAY['full_name', 'preferred_name', 'email', 'birthday', 'is_deceased'],
            true
        );

        v_debug := v_debug || 'Acceptor synced profile created. ';
    END IF;

    -- Update sync record with the acceptor synced profile id
    UPDATE profile_syncs SET acceptor_synced_profile_id = v_acceptor_synced_profile_id WHERE id = v_sync_id;

    -- 7. Create synced profile of inviter in acceptor's account (if acceptor has an account)
    IF p_acceptor_account_id IS NOT NULL THEN
        v_inviter_synced_profile_id := gen_random_uuid();

        INSERT INTO profiles (
            id, account_id, type, full_name, preferred_name, birthday, email,
            address, phone, photo_url, is_deceased, is_favourite, sort_order,
            source_user_id, linked_user_id, sync_connection_id, is_local_only,
            synced_fields, include_in_family_tree
        ) VALUES (
            v_inviter_synced_profile_id,
            p_acceptor_account_id,
            'relative',
            v_inviter_profile.full_name,
            v_inviter_profile.preferred_name,
            v_inviter_profile.birthday,
            v_inviter_profile.email,
            CASE WHEN v_invitation.sharing_profile_fields THEN v_inviter_profile.address ELSE NULL END,
            CASE WHEN v_invitation.sharing_profile_fields THEN v_inviter_profile.phone ELSE NULL END,
            CASE WHEN v_invitation.sharing_profile_fields THEN v_inviter_profile.photo_url ELSE NULL END,
            COALESCE(v_inviter_profile.is_deceased, false),
            false,
            0,
            v_invitation.invited_by,
            v_invitation.invited_by,
            v_sync_id,
            false,
            ARRAY['full_name', 'preferred_name', 'email', 'birthday', 'is_deceased'],
            true
        );

        -- Update sync record
        UPDATE profile_syncs SET inviter_synced_profile_id = v_inviter_synced_profile_id WHERE id = v_sync_id;

        v_debug := v_debug || 'Inviter synced profile created. ';
    ELSE
        v_debug := v_debug || 'SKIP inviter profile (no acceptor account). ';
    END IF;

    -- 8. Create sharing preference records (wrapped in exception handler)
    BEGIN
        FOREACH v_category IN ARRAY v_sharing_categories LOOP
            v_is_shared := CASE v_category
                WHEN 'profile_fields' THEN v_invitation.sharing_profile_fields
                WHEN 'medical' THEN v_invitation.sharing_medical
                WHEN 'gift_idea' THEN v_invitation.sharing_gift_idea
                WHEN 'clothing' THEN v_invitation.sharing_clothing
                WHEN 'hobby' THEN v_invitation.sharing_hobby
                WHEN 'activity_idea' THEN v_invitation.sharing_activity_idea
                WHEN 'important_accounts' THEN COALESCE(v_invitation.sharing_important_accounts, FALSE)
            END;

            INSERT INTO profile_sharing_preferences (profile_id, user_id, target_user_id, category, is_shared)
            VALUES (v_inviter_profile.id, v_invitation.invited_by, p_user_id, v_category, v_is_shared)
            ON CONFLICT (profile_id, target_user_id, category)
            DO UPDATE SET is_shared = v_is_shared, updated_at = NOW();
        END LOOP;

        v_debug := v_debug || 'Sharing prefs set. ';
    EXCEPTION WHEN OTHERS THEN
        v_debug := v_debug || 'SHARING PREFS FAILED: ' || SQLERRM || '. ';
    END;

    -- *** DISABLE propagation trigger before bulk detail copy ***
    -- This prevents the trigger from firing on each INSERT and potentially
    -- causing cascading copies or duplicate entries.
    ALTER TABLE profile_details DISABLE TRIGGER trigger_propagate_profile_detail_changes;

    -- 9. Copy existing profile details from acceptor to synced copy in inviter's account
    BEGIN
        IF v_acceptor_profile.id IS NOT NULL AND v_acceptor_synced_profile_id IS NOT NULL THEN
            FOR v_detail IN
                SELECT * FROM profile_details
                WHERE profile_id = v_acceptor_profile.id
            LOOP
                v_is_shared := TRUE;
                CASE v_detail.category
                    WHEN 'medical_condition' THEN v_is_shared := v_invitation.sharing_medical;
                    WHEN 'allergy' THEN v_is_shared := v_invitation.sharing_medical;
                    WHEN 'gift_idea' THEN v_is_shared := v_invitation.sharing_gift_idea;
                    WHEN 'clothing' THEN v_is_shared := v_invitation.sharing_clothing;
                    WHEN 'hobby' THEN v_is_shared := v_invitation.sharing_hobby;
                    WHEN 'activity_idea' THEN v_is_shared := v_invitation.sharing_activity_idea;
                    WHEN 'important_account' THEN v_is_shared := COALESCE(v_invitation.sharing_important_accounts, FALSE);
                    ELSE v_is_shared := TRUE;
                END CASE;

                IF v_is_shared THEN
                    INSERT INTO profile_details (
                        account_id, profile_id, category, label, value,
                        status, occasion, metadata
                    ) VALUES (
                        v_invitation.account_id, v_acceptor_synced_profile_id, v_detail.category,
                        v_detail.label, v_detail.value, v_detail.status, v_detail.occasion, v_detail.metadata
                    ) RETURNING id INTO v_synced_detail_id;

                    INSERT INTO profile_detail_syncs (sync_connection_id, source_detail_id, synced_detail_id)
                    VALUES (v_sync_id, v_detail.id, v_synced_detail_id);
                END IF;
            END LOOP;

            v_debug := v_debug || 'Acceptor details copied. ';
        END IF;
    EXCEPTION WHEN OTHERS THEN
        v_debug := v_debug || 'ACCEPTOR DETAIL COPY FAILED: ' || SQLERRM || '. ';
    END;

    -- 10. Copy existing profile details from inviter to synced copy in acceptor's account
    BEGIN
        IF v_inviter_synced_profile_id IS NOT NULL THEN
            FOR v_detail IN
                SELECT * FROM profile_details
                WHERE profile_id = v_inviter_profile.id
            LOOP
                v_is_shared := TRUE;
                CASE v_detail.category
                    WHEN 'medical_condition' THEN v_is_shared := v_invitation.sharing_medical;
                    WHEN 'allergy' THEN v_is_shared := v_invitation.sharing_medical;
                    WHEN 'gift_idea' THEN v_is_shared := v_invitation.sharing_gift_idea;
                    WHEN 'clothing' THEN v_is_shared := v_invitation.sharing_clothing;
                    WHEN 'hobby' THEN v_is_shared := v_invitation.sharing_hobby;
                    WHEN 'activity_idea' THEN v_is_shared := v_invitation.sharing_activity_idea;
                    WHEN 'important_account' THEN v_is_shared := COALESCE(v_invitation.sharing_important_accounts, FALSE);
                    ELSE v_is_shared := TRUE;
                END CASE;

                IF v_is_shared THEN
                    INSERT INTO profile_details (
                        account_id, profile_id, category, label, value,
                        status, occasion, metadata
                    ) VALUES (
                        p_acceptor_account_id, v_inviter_synced_profile_id, v_detail.category,
                        v_detail.label, v_detail.value, v_detail.status, v_detail.occasion, v_detail.metadata
                    ) RETURNING id INTO v_synced_detail_id;

                    INSERT INTO profile_detail_syncs (sync_connection_id, source_detail_id, synced_detail_id)
                    VALUES (v_sync_id, v_detail.id, v_synced_detail_id);
                END IF;
            END LOOP;

            v_debug := v_debug || 'Inviter details copied. ';
        END IF;
    EXCEPTION WHEN OTHERS THEN
        v_debug := v_debug || 'INVITER DETAIL COPY FAILED: ' || SQLERRM || '. ';
    END;

    -- *** RE-ENABLE propagation trigger after bulk copy ***
    ALTER TABLE profile_details ENABLE TRIGGER trigger_propagate_profile_detail_changes;

    RETURN json_build_object(
        'success', true,
        'error', NULL,
        'sync_id', v_sync_id,
        'inviter_synced_profile_id', v_inviter_synced_profile_id,
        'acceptor_synced_profile_id', v_acceptor_synced_profile_id,
        'debug', v_debug
    );
END;
$$;

-- ============================================================================
-- PART 3: Clean up any contaminated data from the swapped update_sharing_preference
-- ============================================================================
-- Same cleanup as fix_propagation_direction.sql, run again in case
-- sharing preference toggles re-introduced contamination

-- Delete profile_details that were incorrectly synced
DELETE FROM profile_details
WHERE id IN (
    SELECT pds.synced_detail_id
    FROM profile_detail_syncs pds
    JOIN profile_details src ON src.id = pds.source_detail_id
    JOIN profile_syncs ps ON ps.id = pds.sync_connection_id
    WHERE (
        -- Case: source is inviter's profile but synced to acceptor's synced copy (WRONG)
        (src.profile_id = ps.inviter_source_profile_id
         AND pds.synced_detail_id IN (
             SELECT pd.id FROM profile_details pd
             WHERE pd.profile_id = ps.acceptor_synced_profile_id
         ))
        OR
        -- Case: source is acceptor's profile but synced to inviter's synced copy (WRONG)
        (src.profile_id = ps.acceptor_source_profile_id
         AND pds.synced_detail_id IN (
             SELECT pd.id FROM profile_details pd
             WHERE pd.profile_id = ps.inviter_synced_profile_id
         ))
    )
);

-- Clean up orphaned profile_detail_syncs entries
DELETE FROM profile_detail_syncs
WHERE synced_detail_id NOT IN (SELECT id FROM profile_details);

-- Remove duplicate profile_detail_syncs (same source + connection)
DELETE FROM profile_detail_syncs a
USING profile_detail_syncs b
WHERE a.id > b.id
  AND a.source_detail_id = b.source_detail_id
  AND a.sync_connection_id = b.sync_connection_id;

-- ============================================================================
-- PART 4: Verify
-- ============================================================================

-- Should return 0
SELECT COUNT(*) as contaminated_count
FROM profile_detail_syncs pds
JOIN profile_details src ON src.id = pds.source_detail_id
JOIN profile_syncs ps ON ps.id = pds.sync_connection_id
WHERE (
    (src.profile_id = ps.inviter_source_profile_id
     AND pds.synced_detail_id IN (
         SELECT pd.id FROM profile_details pd
         WHERE pd.profile_id = ps.acceptor_synced_profile_id
     ))
    OR
    (src.profile_id = ps.acceptor_source_profile_id
     AND pds.synced_detail_id IN (
         SELECT pd.id FROM profile_details pd
         WHERE pd.profile_id = ps.inviter_synced_profile_id
     ))
);
