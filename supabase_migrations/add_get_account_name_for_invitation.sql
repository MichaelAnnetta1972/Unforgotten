-- Migration: Add RPC to get account display name for an invitation
-- This bypasses RLS so that a user who hasn't yet joined an account
-- can still see the account name when validating an invite code.

CREATE OR REPLACE FUNCTION get_account_name_for_invitation(
    p_invite_code TEXT
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_account_id UUID;
    v_display_name TEXT;
BEGIN
    -- Look up the invitation by code
    SELECT account_id INTO v_account_id
    FROM account_invitations
    WHERE invite_code = UPPER(p_invite_code)
      AND status = 'pending'
    LIMIT 1;

    IF v_account_id IS NULL THEN
        RETURN json_build_object('success', false, 'error', 'Invitation not found');
    END IF;

    -- Get the account display name
    SELECT display_name INTO v_display_name
    FROM accounts
    WHERE id = v_account_id;

    RETURN json_build_object(
        'success', true,
        'display_name', COALESCE(v_display_name, 'Unknown Account')
    );
END;
$$;
