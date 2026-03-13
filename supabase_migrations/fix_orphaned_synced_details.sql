-- Migration: Fix Orphaned Synced Details
--
-- Problem: ~55 profile_details rows exist on synced profiles without any
-- profile_detail_syncs mapping. This means:
--   1. The propagation trigger can't find them when the source is deleted
--   2. They become stale copies that never update or delete
--
-- Root causes:
--   a) accept_invitation_with_sync() doesn't disable the propagation trigger
--      during bulk detail copy, so the trigger fires AND the explicit mapping
--      INSERT runs, risking duplicates/conflicts that silently fail
--   b) Exception handlers in the RPC swallow errors, so a failed mapping INSERT
--      leaves the detail orphaned
--
-- Fix:
--   1. Delete orphaned synced details (details on synced profiles with no mapping)
--   2. Update accept_invitation_with_sync to disable trigger during bulk copy

-- ============================================================================
-- PART 1: Clean up orphaned synced details
-- ============================================================================

-- First, let's see what we're about to delete (for audit purposes)
-- Run this SELECT first to verify, then run the DELETE

-- Preview orphaned details:
-- SELECT pd.id, pd.category, pd.label, pd.value, p.full_name, p.sync_connection_id
-- FROM profile_details pd
-- JOIN profiles p ON p.id = pd.profile_id
-- WHERE p.source_user_id IS NOT NULL
--   AND p.sync_connection_id IS NOT NULL
--   AND pd.id NOT IN (SELECT synced_detail_id FROM profile_detail_syncs)
-- ORDER BY p.full_name, pd.category;

-- Delete all orphaned synced details
DELETE FROM profile_details
WHERE id IN (
    SELECT pd.id
    FROM profile_details pd
    JOIN profiles p ON p.id = pd.profile_id
    WHERE p.source_user_id IS NOT NULL
      AND p.sync_connection_id IS NOT NULL
      AND pd.id NOT IN (
          SELECT synced_detail_id FROM profile_detail_syncs
      )
);

-- ============================================================================
-- PART 2: Update accept_invitation_with_sync to disable trigger during copy
-- ============================================================================
-- This prevents the propagation trigger from firing during the initial bulk
-- detail copy, which eliminates the race condition that creates orphans.
--
-- The pattern matches what fix_sharing_preference_direction.sql already does.

CREATE OR REPLACE FUNCTION accept_invitation_with_sync(
    p_invitation_id UUID,
    p_user_id UUID,
    p_acceptor_profile_id UUID,
    p_acceptor_account_id UUID
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_invitation RECORD;
    v_inviter_profile RECORD;
    v_acceptor_profile RECORD;
    v_sync_id UUID;
    v_inviter_synced_profile_id UUID;
    v_acceptor_synced_profile_id UUID;
    v_detail RECORD;
    v_synced_detail_id UUID;
    v_category TEXT;
    v_is_shared BOOLEAN;
    v_debug TEXT := '';
BEGIN
    -- 1. Validate and lock invitation
    SELECT * INTO v_invitation
    FROM invitations
    WHERE id = p_invitation_id
      AND status = 'pending'
    FOR UPDATE;

    IF v_invitation IS NULL THEN
        RETURN json_build_object('success', false, 'error', 'Invitation not found or not pending');
    END IF;

    -- 2. Update invitation status
    UPDATE invitations
    SET status = 'accepted',
        accepted_by = p_user_id,
        accepted_at = NOW(),
        updated_at = NOW()
    WHERE id = p_invitation_id;

    v_debug := v_debug || 'Invitation accepted. ';

    -- 3. Load profiles
    SELECT * INTO v_inviter_profile
    FROM profiles
    WHERE id = v_invitation.profile_id;

    SELECT * INTO v_acceptor_profile
    FROM profiles
    WHERE id = p_acceptor_profile_id;

    -- 4. Check for existing active sync
    SELECT id INTO v_sync_id
    FROM profile_syncs
    WHERE status = 'active'
      AND (
          (inviter_user_id = v_invitation.invited_by AND acceptor_user_id = p_user_id)
          OR
          (inviter_user_id = p_user_id AND acceptor_user_id = v_invitation.invited_by)
      )
    LIMIT 1;

    IF v_sync_id IS NOT NULL THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Active sync already exists between these users',
            'existing_sync_id', v_sync_id
        );
    END IF;

    -- 5. Create synced copy of inviter in acceptor's account
    INSERT INTO profiles (
        account_id, full_name, preferred_name, profile_type, birthday,
        email, phone, address, photo_url,
        source_user_id, is_local_only, sync_connection_id,
        is_deceased, date_of_death
    ) VALUES (
        p_acceptor_account_id, v_inviter_profile.full_name, v_inviter_profile.preferred_name,
        v_inviter_profile.profile_type, v_inviter_profile.birthday,
        v_inviter_profile.email, v_inviter_profile.phone, v_inviter_profile.address,
        v_inviter_profile.photo_url,
        v_invitation.invited_by, FALSE, NULL,
        v_inviter_profile.is_deceased, v_inviter_profile.date_of_death
    ) RETURNING id INTO v_inviter_synced_profile_id;

    v_debug := v_debug || 'Inviter synced profile created. ';

    -- 6. Create synced copy of acceptor in inviter's account
    IF v_acceptor_profile.id IS NOT NULL THEN
        INSERT INTO profiles (
            account_id, full_name, preferred_name, profile_type, birthday,
            email, phone, address, photo_url,
            source_user_id, is_local_only, sync_connection_id,
            is_deceased, date_of_death
        ) VALUES (
            v_invitation.account_id, v_acceptor_profile.full_name, v_acceptor_profile.preferred_name,
            v_acceptor_profile.profile_type, v_acceptor_profile.birthday,
            v_acceptor_profile.email, v_acceptor_profile.phone, v_acceptor_profile.address,
            v_acceptor_profile.photo_url,
            p_user_id, FALSE, NULL,
            v_acceptor_profile.is_deceased, v_acceptor_profile.date_of_death
        ) RETURNING id INTO v_acceptor_synced_profile_id;

        v_debug := v_debug || 'Acceptor synced profile created. ';
    END IF;

    -- 7. Create sync connection
    INSERT INTO profile_syncs (
        inviter_user_id, acceptor_user_id,
        inviter_source_profile_id, inviter_synced_profile_id,
        acceptor_source_profile_id, acceptor_synced_profile_id,
        invitation_id, status
    ) VALUES (
        v_invitation.invited_by, p_user_id,
        v_inviter_profile.id, v_inviter_synced_profile_id,
        p_acceptor_profile_id, v_acceptor_synced_profile_id,
        p_invitation_id, 'active'
    ) RETURNING id INTO v_sync_id;

    -- Update synced profiles with sync_connection_id
    UPDATE profiles SET sync_connection_id = v_sync_id WHERE id = v_inviter_synced_profile_id;
    IF v_acceptor_synced_profile_id IS NOT NULL THEN
        UPDATE profiles SET sync_connection_id = v_sync_id WHERE id = v_acceptor_synced_profile_id;
    END IF;

    v_debug := v_debug || 'Sync connection created. ';

    -- 8. Set up sharing preferences
    BEGIN
        FOR v_category IN
            SELECT unnest(ARRAY['medical', 'clothing', 'gift_idea', 'hobby', 'activity_idea', 'important_accounts'])
        LOOP
            v_is_shared := CASE v_category
                WHEN 'medical' THEN v_invitation.sharing_medical
                WHEN 'clothing' THEN v_invitation.sharing_clothing
                WHEN 'gift_idea' THEN v_invitation.sharing_gift_idea
                WHEN 'hobby' THEN v_invitation.sharing_hobby
                WHEN 'activity_idea' THEN v_invitation.sharing_activity_idea
                WHEN 'important_accounts' THEN COALESCE(v_invitation.sharing_important_accounts, FALSE)
            END;

            INSERT INTO profile_sharing_preferences (profile_id, user_id, target_user_id, category, is_shared)
            VALUES (v_acceptor_profile.id, p_user_id, v_invitation.invited_by, v_category, v_is_shared)
            ON CONFLICT (profile_id, target_user_id, category)
            DO UPDATE SET is_shared = v_is_shared, updated_at = NOW();

            INSERT INTO profile_sharing_preferences (profile_id, user_id, target_user_id, category, is_shared)
            VALUES (v_inviter_profile.id, v_invitation.invited_by, p_user_id, v_category, v_is_shared)
            ON CONFLICT (profile_id, target_user_id, category)
            DO UPDATE SET is_shared = v_is_shared, updated_at = NOW();
        END LOOP;

        v_debug := v_debug || 'Sharing prefs set. ';
    EXCEPTION WHEN OTHERS THEN
        v_debug := v_debug || 'SHARING PREFS FAILED: ' || SQLERRM || '. ';
    END;

    -- 9. Copy existing profile details from acceptor to synced copy in inviter's account
    -- IMPORTANT: Disable propagation trigger to prevent race condition / duplicate mappings
    BEGIN
        ALTER TABLE profile_details DISABLE TRIGGER trigger_propagate_profile_detail_changes;

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

        ALTER TABLE profile_details ENABLE TRIGGER trigger_propagate_profile_detail_changes;
    EXCEPTION WHEN OTHERS THEN
        -- Re-enable trigger even on error
        ALTER TABLE profile_details ENABLE TRIGGER trigger_propagate_profile_detail_changes;
        v_debug := v_debug || 'ACCEPTOR DETAIL COPY FAILED: ' || SQLERRM || '. ';
    END;

    -- 10. Copy existing profile details from inviter to synced copy in acceptor's account
    BEGIN
        ALTER TABLE profile_details DISABLE TRIGGER trigger_propagate_profile_detail_changes;

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

        ALTER TABLE profile_details ENABLE TRIGGER trigger_propagate_profile_detail_changes;
    EXCEPTION WHEN OTHERS THEN
        -- Re-enable trigger even on error
        ALTER TABLE profile_details ENABLE TRIGGER trigger_propagate_profile_detail_changes;
        v_debug := v_debug || 'INVITER DETAIL COPY FAILED: ' || SQLERRM || '. ';
    END;

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
