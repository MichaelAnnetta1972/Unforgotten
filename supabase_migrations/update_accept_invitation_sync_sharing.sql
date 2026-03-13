-- Migration: Update accept_invitation_with_sync RPC
-- 1. Reads sharing preferences from the invitation record
-- 2. Creates profile_sharing_preferences rows based on those preferences
-- 3. Supports linking to an existing profile (duplicate detection) via p_existing_profile_id
-- 4. Copies existing profile details to synced profiles during acceptance
-- 5. Uses correct ON CONFLICT clause matching (profile_id, target_user_id, category) constraint
-- 6. Detail copying and sharing preferences are wrapped in exception handlers
--    so that trigger errors don't roll back profile creation

-- Drop ALL possible overloads to prevent ambiguity
-- Must list all known parameter signatures since Postgres requires params for DROP
DROP FUNCTION IF EXISTS accept_invitation_with_sync(UUID, UUID, UUID);
DROP FUNCTION IF EXISTS accept_invitation_with_sync(UUID, UUID, UUID, UUID);
DROP FUNCTION IF EXISTS accept_invitation_with_sync(UUID, UUID, UUID, UUID, UUID);
-- Also try dropping without params to catch any remaining overloads
DO $$
BEGIN
    -- Drop any remaining overloads by querying pg_proc
    PERFORM pg_catalog.pg_proc.oid
    FROM pg_catalog.pg_proc
    JOIN pg_catalog.pg_namespace ON pg_namespace.oid = pg_proc.pronamespace
    WHERE pg_proc.proname = 'accept_invitation_with_sync'
      AND pg_namespace.nspname = 'public';

    IF FOUND THEN
        EXECUTE 'DROP FUNCTION IF EXISTS public.accept_invitation_with_sync';
    END IF;
EXCEPTION WHEN OTHERS THEN
    -- Multiple overloads might prevent parameterless drop - that's OK, the typed drops above handle it
    NULL;
END $$;

CREATE OR REPLACE FUNCTION accept_invitation_with_sync(
    p_invitation_id UUID,
    p_user_id UUID,
    p_acceptor_profile_id UUID DEFAULT NULL,
    p_acceptor_account_id UUID DEFAULT NULL,
    p_existing_profile_id UUID DEFAULT NULL  -- If set, link to this existing profile instead of creating new
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
    -- If this fails, profiles are still created - sharing prefs can be set later
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

    -- 9. Copy existing profile details from acceptor to synced copy in inviter's account
    -- Wrapped in exception handler so trigger errors don't roll back profile creation
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
