-- ============================================================================
-- CLEAR PHOTO_URL ON SEVER
-- Date: 2026-05-13
--
-- Background: when profiles are synced between accounts, the propagate trigger
-- copies the source profile's photo_url string into the synced copy verbatim.
-- The path points at the source profile's UUID, which lives in the OTHER
-- user's account. While the sync is active and both users are mutual members,
-- the storage RLS policy passes for both sides. Once the sync is severed —
-- e.g. via Manage Members removal — the cross-account read no longer works,
-- and the synced profile's photo appears broken.
--
-- Architecturally the right fix is to copy the actual photo file to a path
-- under the synced profile's own UUID. That's deferred. For now, sever
-- operations clear photo_url on synced copies so they show the avatar
-- placeholder instead of a broken image.
--
-- This migration:
--   1. Backfills NULL photo_url on all already-severed synced profiles
--   2. Updates sever_profile_sync to clear photo_url going forward
--   3. Updates remove_member_with_cleanup to do the same
-- ============================================================================


-- ============================================================================
-- 1. BACKFILL: clear photo_url on existing severed synced profiles
-- ============================================================================

UPDATE profiles
SET photo_url = NULL, updated_at = NOW()
WHERE is_local_only = true
  AND sync_connection_id IS NOT NULL
  AND photo_url IS NOT NULL
  AND photo_url LIKE 'profiles/%';


-- ============================================================================
-- 2. UPDATE sever_profile_sync to clear photo_url
-- ============================================================================

CREATE OR REPLACE FUNCTION public.sever_profile_sync(p_sync_id uuid, p_user_id uuid)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_sync RECORD;
BEGIN
    IF p_user_id IS DISTINCT FROM auth.uid() THEN
        RAISE EXCEPTION 'p_user_id must match authenticated user';
    END IF;

    SELECT * INTO v_sync
    FROM profile_syncs
    WHERE id = p_sync_id
      AND (inviter_user_id = p_user_id OR acceptor_user_id = p_user_id);

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Sync not found or not authorized';
    END IF;

    IF v_sync.status = 'severed' THEN
        RETURN json_build_object('success', true, 'message', 'Sync already severed');
    END IF;

    UPDATE profile_syncs
    SET status = 'severed',
        severed_at = NOW(),
        severed_by = p_user_id,
        updated_at = NOW()
    WHERE id = p_sync_id;

    -- Mark synced profile copies as local-only and clear their photo_url.
    -- The photo_url points at the source profile (in the other user's account)
    -- which we can no longer read after sever.
    UPDATE profiles
    SET is_local_only = true,
        source_user_id = NULL,
        synced_fields = NULL,
        photo_url = NULL,
        updated_at = NOW()
    WHERE sync_connection_id = p_sync_id;

    RETURN json_build_object('success', true);
END;
$function$;


-- ============================================================================
-- 3. UPDATE remove_member_with_cleanup to clear photo_url
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

    SELECT * INTO v_member FROM account_members WHERE id = p_member_id;
    IF v_member IS NULL THEN
        RETURN json_build_object('success', false, 'error', 'Member not found');
    END IF;

    v_removed_user_id := v_member.user_id;
    v_account_id := v_member.account_id;

    SELECT role INTO v_caller_role
    FROM account_members
    WHERE account_id = v_account_id AND user_id = v_caller_id;

    IF v_caller_role IS NULL OR (v_caller_role NOT IN ('owner', 'admin') AND v_caller_id IS DISTINCT FROM v_removed_user_id) THEN
        RETURN json_build_object('success', false, 'error', 'Not authorized to remove this member');
    END IF;

    IF v_member.role = 'owner' THEN
        RETURN json_build_object('success', false, 'error', 'Cannot remove the account owner');
    END IF;

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

        -- Mark synced profile copies as local-only and clear photo_url
        UPDATE profiles
        SET is_local_only = true,
            source_user_id = NULL,
            synced_fields = NULL,
            photo_url = NULL,
            updated_at = NOW()
        WHERE sync_connection_id = v_sync.id;
    END LOOP;

    DELETE FROM account_members am
    USING accounts a
    WHERE am.account_id = a.id
      AND a.owner_user_id = v_removed_user_id
      AND am.user_id = v_caller_id;

    IF FOUND THEN
        v_debug := v_debug || 'Removed reciprocal membership. ';
    END IF;

    DELETE FROM account_members WHERE id = p_member_id;
    v_debug := v_debug || 'Removed member row. ';

    RETURN json_build_object('success', true, 'debug', v_debug);
END;
$function$;
