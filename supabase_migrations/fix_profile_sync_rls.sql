-- Fix: Accept invitation with profile sync - Trust passed profile and account IDs
-- Run this in Supabase SQL Editor to apply the fix
--
-- Key change: Accept the acceptor's account_id directly from Swift to ensure
-- we always have the correct account for creating the synced profile.

CREATE OR REPLACE FUNCTION accept_invitation_with_sync(
    p_invitation_id UUID,
    p_user_id UUID,
    p_acceptor_profile_id UUID DEFAULT NULL,
    p_acceptor_account_id UUID DEFAULT NULL
) RETURNS JSON AS $$
DECLARE
    v_invitation RECORD;
    v_inviter_profile RECORD;
    v_acceptor_profile RECORD;
    v_sync_id UUID;
    v_inviter_synced_profile_id UUID;
    v_acceptor_synced_profile_id UUID;
    v_syncable_fields TEXT[];
    v_acceptor_account_id UUID;
    v_detail RECORD;
    v_synced_detail_id UUID;
    v_debug TEXT := '';
BEGIN
    -- Define which fields to sync (viewer-visible fields)
    v_syncable_fields := ARRAY[
        'full_name', 'preferred_name', 'birthday',
        'address', 'phone', 'email', 'photo_url'
    ];

    -- Get invitation details
    SELECT * INTO v_invitation
    FROM account_invitations
    WHERE id = p_invitation_id AND status = 'pending';

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Invalid or expired invitation';
    END IF;

    -- Mark invitation as accepted
    UPDATE account_invitations
    SET status = 'accepted',
        accepted_at = NOW(),
        accepted_by = p_user_id
    WHERE id = p_invitation_id;

    -- Add user as account member
    INSERT INTO account_members (account_id, user_id, role)
    VALUES (v_invitation.account_id, p_user_id, v_invitation.role)
    ON CONFLICT (account_id, user_id) DO NOTHING;

    -- Get inviter's primary profile (the person who sent the invitation)
    SELECT * INTO v_inviter_profile
    FROM profiles
    WHERE account_id = v_invitation.account_id
      AND type = 'primary'
      AND linked_user_id = v_invitation.invited_by
    LIMIT 1;

    -- If no profile found with linked_user_id, try just the primary profile
    IF NOT FOUND THEN
        SELECT * INTO v_inviter_profile
        FROM profiles
        WHERE account_id = v_invitation.account_id
          AND type = 'primary'
        LIMIT 1;
    END IF;

    v_debug := v_debug || 'inviter_profile=' || COALESCE(v_inviter_profile.id::text, 'NULL') || '; ';

    -- Use the passed acceptor_account_id if provided, otherwise try to find it
    IF p_acceptor_account_id IS NOT NULL THEN
        v_acceptor_account_id := p_acceptor_account_id;
        v_debug := v_debug || 'Using passed acceptor_account_id: ' || v_acceptor_account_id::text || '; ';
    ELSE
        -- Fallback: Find the acceptor's account from account_members
        SELECT am.account_id INTO v_acceptor_account_id
        FROM account_members am
        WHERE am.user_id = p_user_id
          AND am.role = 'owner'
          AND am.account_id != v_invitation.account_id
        LIMIT 1;

        IF v_acceptor_account_id IS NOT NULL THEN
            v_debug := v_debug || 'Found acceptor account via account_members: ' || v_acceptor_account_id::text || '; ';
        ELSE
            v_debug := v_debug || 'Could not find acceptor account; ';
        END IF;
    END IF;

    -- Get acceptor's profile data if we have the profile ID
    IF p_acceptor_profile_id IS NOT NULL AND v_acceptor_account_id IS NOT NULL THEN
        SELECT * INTO v_acceptor_profile
        FROM profiles
        WHERE id = p_acceptor_profile_id
          AND account_id = v_acceptor_account_id;

        IF NOT FOUND THEN
            v_debug := v_debug || 'Profile lookup failed (RLS), will create one-way sync only; ';
            v_acceptor_profile.id := NULL;
            v_acceptor_profile.account_id := v_acceptor_account_id;
        ELSE
            v_debug := v_debug || 'Found acceptor profile: ' || v_acceptor_profile.id::text || '; ';
        END IF;
    ELSIF v_acceptor_account_id IS NOT NULL THEN
        v_debug := v_debug || 'No acceptor_profile_id provided; ';

        -- Try to find their primary profile
        SELECT * INTO v_acceptor_profile
        FROM profiles
        WHERE account_id = v_acceptor_account_id
          AND type = 'primary'
        LIMIT 1;

        IF FOUND THEN
            v_debug := v_debug || 'Found acceptor profile via account search: ' || v_acceptor_profile.id::text || '; ';
        ELSE
            v_debug := v_debug || 'Could not find acceptor profile in account ' || v_acceptor_account_id::text || '; ';
        END IF;
    ELSE
        v_debug := v_debug || 'No acceptor account found; ';
    END IF;

    -- Only create sync records if inviter has a profile
    IF v_inviter_profile.id IS NOT NULL THEN
        -- Create profile sync record
        INSERT INTO profile_syncs (
            invitation_id,
            inviter_user_id, inviter_account_id, inviter_source_profile_id,
            acceptor_user_id, acceptor_account_id, acceptor_source_profile_id
        ) VALUES (
            p_invitation_id,
            v_invitation.invited_by, v_invitation.account_id, v_inviter_profile.id,
            p_user_id,
            COALESCE(v_acceptor_account_id, v_invitation.account_id),
            v_acceptor_profile.id  -- May be NULL, which is allowed
        ) RETURNING id INTO v_sync_id;

        v_debug := v_debug || 'Created sync record: ' || v_sync_id::text || '; ';

        -- Create synced profile for acceptor (copy of inviter's profile in acceptor's account)
        -- Only if acceptor has their own separate account
        IF v_acceptor_account_id IS NOT NULL AND v_acceptor_account_id != v_invitation.account_id THEN
            v_debug := v_debug || 'Creating synced profile in acceptor account; ';

            INSERT INTO profiles (
                account_id, type, full_name, preferred_name, birthday,
                address, phone, email, photo_url, relationship,
                source_user_id, synced_fields, sync_connection_id,
                include_in_family_tree, is_deceased, is_favourite
            ) VALUES (
                v_acceptor_account_id, 'relative',
                v_inviter_profile.full_name, v_inviter_profile.preferred_name, v_inviter_profile.birthday,
                v_inviter_profile.address, v_inviter_profile.phone, v_inviter_profile.email, v_inviter_profile.photo_url,
                NULL, -- relationship is local-only
                v_invitation.invited_by, v_syncable_fields, v_sync_id,
                TRUE, COALESCE(v_inviter_profile.is_deceased, FALSE), FALSE
            ) RETURNING id INTO v_acceptor_synced_profile_id;

            v_debug := v_debug || 'Created acceptor synced profile: ' || v_acceptor_synced_profile_id::text || '; ';

            -- Copy profile details for the synced profile
            FOR v_detail IN
                SELECT * FROM profile_details
                WHERE profile_id = v_inviter_profile.id
            LOOP
                INSERT INTO profile_details (
                    account_id, profile_id, category, label, value,
                    status, occasion, metadata
                ) VALUES (
                    v_acceptor_account_id, v_acceptor_synced_profile_id, v_detail.category,
                    v_detail.label, v_detail.value, v_detail.status, v_detail.occasion, v_detail.metadata
                ) RETURNING id INTO v_synced_detail_id;

                -- Track the detail sync relationship
                INSERT INTO profile_detail_syncs (sync_connection_id, source_detail_id, synced_detail_id)
                VALUES (v_sync_id, v_detail.id, v_synced_detail_id);
            END LOOP;

            UPDATE profile_syncs SET acceptor_synced_profile_id = v_acceptor_synced_profile_id
            WHERE id = v_sync_id;
        ELSE
            v_debug := v_debug || 'Skipped acceptor synced profile (no separate account or same account); ';
        END IF;

        -- Create synced profile for inviter (copy of acceptor's profile in inviter's account)
        IF v_acceptor_profile.id IS NOT NULL AND v_acceptor_account_id IS NOT NULL AND v_acceptor_account_id != v_invitation.account_id THEN
            v_debug := v_debug || 'Creating synced profile in inviter account; ';

            INSERT INTO profiles (
                account_id, type, full_name, preferred_name, birthday,
                address, phone, email, photo_url, relationship,
                source_user_id, synced_fields, sync_connection_id,
                include_in_family_tree, is_deceased, is_favourite
            ) VALUES (
                v_invitation.account_id, 'relative',
                v_acceptor_profile.full_name, v_acceptor_profile.preferred_name, v_acceptor_profile.birthday,
                v_acceptor_profile.address, v_acceptor_profile.phone, v_acceptor_profile.email, v_acceptor_profile.photo_url,
                NULL, -- relationship is local-only
                p_user_id, v_syncable_fields, v_sync_id,
                TRUE, COALESCE(v_acceptor_profile.is_deceased, FALSE), FALSE
            ) RETURNING id INTO v_inviter_synced_profile_id;

            v_debug := v_debug || 'Created inviter synced profile: ' || v_inviter_synced_profile_id::text || '; ';

            -- Copy profile details for the synced profile
            FOR v_detail IN
                SELECT * FROM profile_details
                WHERE profile_id = v_acceptor_profile.id
            LOOP
                INSERT INTO profile_details (
                    account_id, profile_id, category, label, value,
                    status, occasion, metadata
                ) VALUES (
                    v_invitation.account_id, v_inviter_synced_profile_id, v_detail.category,
                    v_detail.label, v_detail.value, v_detail.status, v_detail.occasion, v_detail.metadata
                ) RETURNING id INTO v_synced_detail_id;

                -- Track the detail sync relationship
                INSERT INTO profile_detail_syncs (sync_connection_id, source_detail_id, synced_detail_id)
                VALUES (v_sync_id, v_detail.id, v_synced_detail_id);
            END LOOP;

            UPDATE profile_syncs SET inviter_synced_profile_id = v_inviter_synced_profile_id
            WHERE id = v_sync_id;
        ELSE
            v_debug := v_debug || 'Skipped inviter synced profile; ';
        END IF;
    ELSE
        v_debug := v_debug || 'No inviter profile found, skipping sync; ';
    END IF;

    RETURN json_build_object(
        'success', true,
        'sync_id', v_sync_id,
        'inviter_synced_profile_id', v_inviter_synced_profile_id,
        'acceptor_synced_profile_id', v_acceptor_synced_profile_id,
        'debug', v_debug
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
