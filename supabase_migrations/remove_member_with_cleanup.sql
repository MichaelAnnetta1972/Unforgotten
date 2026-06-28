-- ============================================================================
-- REMOVE MEMBER WITH CLEANUP
-- Date: 2026-05-13
--
-- New RPC that fully severs a connection when an owner/admin removes a member
-- via the Manage Members screen. The previous direct DELETE on account_members
-- left orphaned state: profile_syncs stayed active, synced profiles kept
-- propagating, and the reciprocal membership remained in the removed user's
-- account.
--
-- This RPC:
--   1. Verifies the caller is an owner or admin of the account
--   2. Finds all active profile_syncs between the two users involving this
--      account, and severs them (marks status='severed', synced profiles
--      become local-only)
--   3. Removes the reciprocal membership the removed user holds in caller's
--      universe (caller's viewer membership in the removed user's account)
--   4. Deletes the requested account_members row
--
-- Idempotent: re-running with the same arguments after a successful removal
-- is a no-op.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.remove_member_with_cleanup(p_member_id uuid)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_member RECORD;
    v_caller_id UUID;
    v_caller_role TEXT;
    v_sync RECORD;
    v_removed_user_id UUID;
    v_account_id UUID;
    v_debug TEXT := '';
BEGIN
    v_caller_id := auth.uid();

    -- 1. Fetch the membership row being removed
    SELECT * INTO v_member FROM account_members WHERE id = p_member_id;
    IF v_member IS NULL THEN
        RETURN json_build_object('success', false, 'error', 'Member not found');
    END IF;

    v_removed_user_id := v_member.user_id;
    v_account_id := v_member.account_id;

    -- 2. Authorize: caller must be owner or admin of the same account,
    --    OR the member being removed is themselves (self-removal)
    SELECT role INTO v_caller_role
    FROM account_members
    WHERE account_id = v_account_id AND user_id = v_caller_id;

    IF v_caller_role IS NULL OR (v_caller_role NOT IN ('owner', 'admin') AND v_caller_id IS DISTINCT FROM v_removed_user_id) THEN
        RETURN json_build_object('success', false, 'error', 'Not authorized to remove this member');
    END IF;

    -- 3. Prevent removing the account owner
    IF v_member.role = 'owner' THEN
        RETURN json_build_object('success', false, 'error', 'Cannot remove the account owner');
    END IF;

    -- 4. Find and sever any active profile_syncs between the two users that
    --    involve this account. There are two cases:
    --      a) Caller's account is the inviter_account_id (caller invited the removed user)
    --      b) Caller's account is the acceptor_account_id (removed user invited caller)
    FOR v_sync IN
        SELECT * FROM profile_syncs
        WHERE status = 'active'
          AND (
            (inviter_account_id = v_account_id AND acceptor_user_id = v_removed_user_id)
            OR
            (acceptor_account_id = v_account_id AND inviter_user_id = v_removed_user_id)
          )
    LOOP
        v_debug := v_debug || 'Severing sync ' || v_sync.id::TEXT || '. ';

        UPDATE profile_syncs
        SET status = 'severed',
            severed_at = NOW(),
            severed_by = v_caller_id,
            updated_at = NOW()
        WHERE id = v_sync.id;

        -- Mark synced profile copies as local-only (preserves data, stops syncing)
        UPDATE profiles
        SET is_local_only = true,
            source_user_id = NULL,
            synced_fields = NULL,
            updated_at = NOW()
        WHERE sync_connection_id = v_sync.id;
    END LOOP;

    -- 5. Remove the reciprocal membership. When two users are connected, each
    --    holds a row in the other's account_members. Removing one side leaves
    --    the other dangling — so clean both up.
    --    Find any account owned by the removed user that has the caller as a member:
    DELETE FROM account_members am
    USING accounts a
    WHERE am.account_id = a.id
      AND a.owner_user_id = v_removed_user_id
      AND am.user_id = v_caller_id;

    IF FOUND THEN
        v_debug := v_debug || 'Removed reciprocal membership. ';
    END IF;

    -- 6. Finally, delete the requested account_members row
    DELETE FROM account_members WHERE id = p_member_id;
    v_debug := v_debug || 'Removed member row. ';

    RETURN json_build_object('success', true, 'debug', v_debug);
END;
$function$;

-- Grant execute to authenticated users (the function does its own auth check)
GRANT EXECUTE ON FUNCTION public.remove_member_with_cleanup(uuid) TO authenticated;
