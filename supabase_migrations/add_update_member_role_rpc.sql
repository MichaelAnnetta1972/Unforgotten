-- Migration: Add RPC to update a member's role
-- This bypasses RLS so that account owners/admins can update member roles
-- even when the caller's RLS policies don't grant direct UPDATE access.

CREATE OR REPLACE FUNCTION update_member_role(
    p_member_id UUID,
    p_new_role TEXT,
    p_user_id UUID  -- The user performing the update (must be owner/admin)
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_member RECORD;
    v_caller_role TEXT;
BEGIN
    -- 1. Get the member record to update
    SELECT * INTO v_member FROM account_members WHERE id = p_member_id;

    IF v_member IS NULL THEN
        RETURN json_build_object('success', false, 'error', 'Member not found');
    END IF;

    -- 2. Verify the caller is an owner or admin of this account
    SELECT role INTO v_caller_role
    FROM account_members
    WHERE account_id = v_member.account_id
      AND user_id = p_user_id;

    IF v_caller_role IS NULL OR v_caller_role NOT IN ('owner', 'admin') THEN
        RETURN json_build_object('success', false, 'error', 'Not authorized to update roles');
    END IF;

    -- 3. Prevent changing the owner's role
    IF v_member.role = 'owner' THEN
        RETURN json_build_object('success', false, 'error', 'Cannot change the owner role');
    END IF;

    -- 4. Prevent setting someone to owner
    IF p_new_role = 'owner' THEN
        RETURN json_build_object('success', false, 'error', 'Cannot assign owner role');
    END IF;

    -- 5. Update the role
    UPDATE account_members
    SET role = p_new_role, updated_at = NOW()
    WHERE id = p_member_id;

    -- 6. Return the updated member
    RETURN json_build_object(
        'success', true,
        'member_id', v_member.id,
        'account_id', v_member.account_id,
        'user_id', v_member.user_id,
        'role', p_new_role
    );
END;
$$;
