-- Add accepted_by column if it doesn't exist
ALTER TABLE account_invitations ADD COLUMN IF NOT EXISTS accepted_by UUID REFERENCES auth.users(id);

-- Create RPC function to accept an invitation
-- This function runs with SECURITY DEFINER to bypass RLS
CREATE OR REPLACE FUNCTION accept_invitation(
    p_invitation_id UUID,
    p_user_id UUID
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_invitation RECORD;
BEGIN
    -- Get the invitation
    SELECT * INTO v_invitation
    FROM account_invitations
    WHERE id = p_invitation_id;

    -- Check invitation exists and is pending
    IF v_invitation IS NULL THEN
        RAISE EXCEPTION 'Invitation not found';
    END IF;

    IF v_invitation.status != 'pending' THEN
        RAISE EXCEPTION 'Invitation is not pending';
    END IF;

    -- Check if invitation is expired
    IF v_invitation.expires_at < NOW() THEN
        RAISE EXCEPTION 'Invitation has expired';
    END IF;

    -- Check if user is already a member of this account
    IF EXISTS (
        SELECT 1 FROM account_members
        WHERE account_id = v_invitation.account_id
        AND user_id = p_user_id
    ) THEN
        RAISE EXCEPTION 'User is already a member of this account';
    END IF;

    -- Add user as account member
    INSERT INTO account_members (account_id, user_id, role)
    VALUES (v_invitation.account_id, p_user_id, v_invitation.role);

    -- Update invitation status
    UPDATE account_invitations
    SET
        status = 'accepted',
        accepted_at = NOW(),
        accepted_by = p_user_id
    WHERE id = p_invitation_id;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION accept_invitation(UUID, UUID) TO authenticated;
