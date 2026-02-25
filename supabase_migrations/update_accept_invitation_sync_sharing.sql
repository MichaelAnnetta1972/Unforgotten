-- Migration: Update accept_invitation_with_sync RPC
-- 1. Reads sharing preferences from the invitation record
-- 2. Creates profile_sharing_preferences rows based on those preferences
-- 3. Supports linking to an existing profile (duplicate detection) via p_existing_profile_id

-- Drop the existing function to replace it
DROP FUNCTION IF EXISTS accept_invitation_with_sync(UUID, UUID, UUID, UUID);

CREATE OR REPLACE FUNCTION accept_invitation_with_sync(
    p_invitation_id UUID,
    p_user_id UUID,
    p_acceptor_profile_id UUID DEFAULT NULL,
    p_acceptor_account_id UUID DEFAULT NULL,
    p_existing_profile_id UUID DEFAULT NULL  -- If set, link to this existing profile instead of creating new
)
RETURNS JSONB
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
    v_sharing_categories TEXT[] := ARRAY['profile_fields', 'medical', 'gift_idea', 'clothing', 'hobby', 'activity_idea'];
BEGIN
    -- 1. Get and validate the invitation
    SELECT * INTO v_invitation FROM account_invitations WHERE id = p_invitation_id;

    IF v_invitation IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Invitation not found');
    END IF;

    IF v_invitation.status != 'pending' THEN
        RETURN jsonb_build_object('success', false, 'error', 'Invitation is no longer pending');
    END IF;

    IF v_invitation.expires_at < NOW() THEN
        RETURN jsonb_build_object('success', false, 'error', 'Invitation has expired');
    END IF;

    -- Check user is not already a member
    IF EXISTS (SELECT 1 FROM account_members WHERE account_id = v_invitation.account_id AND user_id = p_user_id) THEN
        RETURN jsonb_build_object('success', false, 'error', 'User is already a member of this account');
    END IF;

    v_debug := v_debug || 'Invitation validated. ';

    -- 2. Accept the invitation - add user as account member
    INSERT INTO account_members (account_id, user_id, role)
    VALUES (v_invitation.account_id, p_user_id, v_invitation.role);

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
        RETURN jsonb_build_object(
            'success', true,
            'error', NULL,
            'sync_id', NULL,
            'debug', v_debug || 'No inviter primary profile found. Skipping sync.'
        );
    END IF;

    v_debug := v_debug || 'Inviter profile: ' || v_inviter_profile.id::TEXT || '. ';

    -- 4. Get acceptor's profile
    IF p_acceptor_profile_id IS NOT NULL THEN
        SELECT * INTO v_acceptor_profile FROM profiles WHERE id = p_acceptor_profile_id;
    ELSE
        -- Try to find the acceptor's primary profile
        IF p_acceptor_account_id IS NOT NULL THEN
            SELECT * INTO v_acceptor_profile
            FROM profiles
            WHERE account_id = p_acceptor_account_id AND type = 'primary'
            LIMIT 1;
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
        p_user_id, COALESCE(p_acceptor_account_id, (SELECT account_id FROM profiles WHERE id = p_acceptor_profile_id LIMIT 1)),
        p_acceptor_profile_id,
        'active'
    );

    v_debug := v_debug || 'Sync created: ' || v_sync_id::TEXT || '. ';

    -- 6. Create synced profile of acceptor in inviter's account
    -- Check if we should use an existing profile
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
            -- Conditionally sync address/phone/photo based on sharing preferences
            address = CASE WHEN v_invitation.sharing_profile_fields THEN COALESCE(v_acceptor_profile.address, address) ELSE address END,
            phone = CASE WHEN v_invitation.sharing_profile_fields THEN COALESCE(v_acceptor_profile.phone, phone) ELSE phone END,
            photo_url = CASE WHEN v_invitation.sharing_profile_fields THEN COALESCE(v_acceptor_profile.photo_url, photo_url) ELSE photo_url END,
            updated_at = NOW()
        WHERE id = p_existing_profile_id;

        v_acceptor_synced_profile_id := p_existing_profile_id;
        v_debug := v_debug || 'Linked to existing profile: ' || p_existing_profile_id::TEXT || '. ';
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

        v_debug := v_debug || 'Acceptor synced profile created: ' || v_acceptor_synced_profile_id::TEXT || '. ';
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

        v_debug := v_debug || 'Inviter synced profile created: ' || v_inviter_synced_profile_id::TEXT || '. ';
    END IF;

    -- 8. Create sharing preference records based on invitation settings
    -- For the inviter's profile (controls what acceptor can see)
    FOREACH v_category IN ARRAY v_sharing_categories LOOP
        v_is_shared := CASE v_category
            WHEN 'profile_fields' THEN v_invitation.sharing_profile_fields
            WHEN 'medical' THEN v_invitation.sharing_medical
            WHEN 'gift_idea' THEN v_invitation.sharing_gift_idea
            WHEN 'clothing' THEN v_invitation.sharing_clothing
            WHEN 'hobby' THEN v_invitation.sharing_hobby
            WHEN 'activity_idea' THEN v_invitation.sharing_activity_idea
        END;

        -- Set sharing preferences on the inviter's profile
        INSERT INTO profile_sharing_preferences (profile_id, user_id, category, is_shared)
        VALUES (v_inviter_profile.id, v_invitation.invited_by, v_category, v_is_shared)
        ON CONFLICT (profile_id, category) DO UPDATE SET is_shared = v_is_shared, updated_at = NOW();
    END LOOP;

    v_debug := v_debug || 'Sharing preferences set. ';

    -- 9. Copy profile details respecting sharing preferences
    -- (Details copying logic for categories that are shared)
    -- This uses the is_category_shared function if available

    RETURN jsonb_build_object(
        'success', true,
        'error', NULL,
        'sync_id', v_sync_id,
        'inviter_synced_profile_id', v_inviter_synced_profile_id,
        'acceptor_synced_profile_id', v_acceptor_synced_profile_id,
        'debug', v_debug
    );
END;
$$;
