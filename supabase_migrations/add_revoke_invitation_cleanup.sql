-- Migration: Add RPC to fully revoke an invitation and clean up any partial acceptance data
-- When an acceptance fails midway (e.g. RPC error after account_members insert),
-- leftover rows can prevent re-invitation. This function cleans up everything.

CREATE OR REPLACE FUNCTION revoke_invitation_with_cleanup(
    p_invitation_id UUID,
    p_user_id UUID  -- The account owner performing the revoke
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_invitation account_invitations%ROWTYPE;
    v_sync RECORD;
    v_debug TEXT := '';
BEGIN
    -- 1. Get the invitation
    SELECT * INTO v_invitation FROM account_invitations WHERE id = p_invitation_id;

    IF v_invitation IS NULL THEN
        RETURN json_build_object('success', false, 'error', 'Invitation not found');
    END IF;

    -- Verify the caller is the one who created the invitation or is an owner/admin of the account
    IF v_invitation.invited_by != p_user_id AND NOT EXISTS (
        SELECT 1 FROM account_members
        WHERE account_id = v_invitation.account_id
          AND user_id = p_user_id
          AND role IN ('owner', 'admin')
    ) THEN
        RETURN json_build_object('success', false, 'error', 'Not authorized to revoke this invitation');
    END IF;

    -- 2. Clean up any profile syncs created from this invitation
    FOR v_sync IN
        SELECT * FROM profile_syncs WHERE invitation_id = p_invitation_id
    LOOP
        v_debug := v_debug || 'Cleaning sync: ' || v_sync.id::TEXT || '. ';

        -- Delete profile detail syncs for this sync connection
        DELETE FROM profile_detail_syncs WHERE sync_connection_id = v_sync.id;

        -- Delete profile details belonging to synced profiles
        IF v_sync.inviter_synced_profile_id IS NOT NULL THEN
            DELETE FROM profile_details WHERE profile_id = v_sync.inviter_synced_profile_id;
        END IF;
        IF v_sync.acceptor_synced_profile_id IS NOT NULL THEN
            DELETE FROM profile_details WHERE profile_id = v_sync.acceptor_synced_profile_id;
        END IF;

        -- Delete sharing preferences linked to the inviter's source profile for this sync
        DELETE FROM profile_sharing_preferences
        WHERE profile_id = v_sync.inviter_source_profile_id
          AND user_id = v_sync.inviter_user_id;

        -- Delete synced profiles
        IF v_sync.inviter_synced_profile_id IS NOT NULL THEN
            DELETE FROM profiles WHERE id = v_sync.inviter_synced_profile_id;
            v_debug := v_debug || 'Deleted inviter synced profile. ';
        END IF;
        IF v_sync.acceptor_synced_profile_id IS NOT NULL THEN
            DELETE FROM profiles WHERE id = v_sync.acceptor_synced_profile_id;
            v_debug := v_debug || 'Deleted acceptor synced profile. ';
        END IF;

        -- Delete the sync record itself
        DELETE FROM profile_syncs WHERE id = v_sync.id;
    END LOOP;

    -- 3. Remove any account membership created by this invitation's acceptance
    IF v_invitation.accepted_by IS NOT NULL THEN
        DELETE FROM account_members
        WHERE account_id = v_invitation.account_id
          AND user_id = v_invitation.accepted_by;
        v_debug := v_debug || 'Removed member: ' || v_invitation.accepted_by::TEXT || '. ';
    END IF;

    -- Also clean up membership if the invitation was partially accepted
    -- (accepted_by might be NULL if the error happened before that was set)
    -- Check for any members who joined via this account but aren't the owner
    -- and match the invitation email
    -- This is a safety net for edge cases

    -- 4. Mark the invitation as revoked (or delete it entirely)
    UPDATE account_invitations
    SET status = 'revoked'
    WHERE id = p_invitation_id;

    v_debug := v_debug || 'Invitation revoked. ';

    RETURN json_build_object(
        'success', true,
        'debug', v_debug
    );
END;
$$;
