-- =============================================================================
-- Account deletion RPC (App Store Review Guideline 5.1.1(v))
--
-- Apple requires that any app supporting account creation must also offer
-- in-app account deletion. This function is called by the iOS client via
-- `supabase.rpc('delete_user_account')` and removes all data owned by the
-- calling authenticated user, then deletes their auth.users row.
--
-- Ownership model: every account has exactly one owner (`accounts.owner_user_id`).
-- Users invited to an account are helpers/viewers, not co-owners. Deleting the
-- caller's auth.users row cascades via `accounts.owner_user_id` and wipes every
-- account they own, which is the correct behavior.
--
-- Other users' data must NOT be affected. Their accounts are separate rows
-- with their own owner_user_id, so their `accounts` row is untouched. Profile
-- rows in other users' accounts that were synced FROM the caller (i.e. where
-- `profiles.source_user_id` = caller) are preserved by nulling the source link
-- rather than deleting the row.
--
-- The function runs SECURITY DEFINER so it can touch auth.users and other
-- tables the caller wouldn't normally be allowed to write to. It always acts
-- on auth.uid() — never on an arbitrary user id — so it cannot be used to
-- delete someone else's account.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.delete_user_account()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
    v_user_id uuid := auth.uid();
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    -- 1. Clear profile_syncs rows referencing the user. The four profile FKs
    --    and the three user FKs (inviter_user_id, acceptor_user_id, severed_by)
    --    are all NO ACTION, so anything referencing this user must go first.
    DELETE FROM profile_syncs
    WHERE inviter_user_id = v_user_id
       OR acceptor_user_id = v_user_id
       OR severed_by = v_user_id
       OR inviter_source_profile_id IN (
            SELECT id FROM profiles WHERE linked_user_id = v_user_id
       )
       OR acceptor_source_profile_id IN (
            SELECT id FROM profiles WHERE linked_user_id = v_user_id
       )
       OR inviter_synced_profile_id IN (
            SELECT p.id FROM profiles p
            JOIN account_members am ON am.account_id = p.account_id
            WHERE am.user_id = v_user_id
       )
       OR acceptor_synced_profile_id IN (
            SELECT p.id FROM profiles p
            JOIN account_members am ON am.account_id = p.account_id
            WHERE am.user_id = v_user_id
       );

    -- 1a. Family calendar share memberships. `member_user_id` is NO ACTION,
    --     so delete any share memberships for this user. `share_id` cascades
    --     from family_calendar_shares so the inverse is handled below.
    DELETE FROM family_calendar_share_members WHERE member_user_id = v_user_id;

    -- 1b. Family calendar shares owned by this user. `shared_by_user_id` is
    --     NO ACTION. Deleting the share cascades to its share_members rows.
    DELETE FROM family_calendar_shares WHERE shared_by_user_id = v_user_id;

    -- 1c. profiles.source_user_id is NO ACTION. These are synced-copy profiles
    --     in OTHER users' accounts that point back to this user as their
    --     source. Null them out so those other users keep their copy of the
    --     data — deleting the rows would wipe another user's profile entry.
    UPDATE profiles SET source_user_id = NULL WHERE source_user_id = v_user_id;

    -- 2. Remove the caller's membership from any OTHER users' accounts
    --    (accounts where they were invited as a helper/viewer). This leaves
    --    those accounts and their data completely intact for the other user.
    --    The caller's own accounts will be cascade-deleted in step 3.
    DELETE FROM account_members
    WHERE user_id = v_user_id
      AND account_id NOT IN (
          SELECT id FROM accounts WHERE owner_user_id = v_user_id
      );

    -- 3. Delete the auth.users row. This cascades to:
    --    - accounts (via owner_user_id) → wipes every account owned by this
    --      user, which in turn cascades to profiles, medications, appointments,
    --      mood_entries, notes, user_preferences, and every other account-
    --      scoped table.
    --    - app_users, device_tokens, live_activity_tokens, morning_briefing_cache,
    --      account_members (remaining rows), profile_sharing_preferences — all
    --      CASCADE on auth.users.
    --    - account_invitations.accepted_by and profiles.linked_user_id — SET NULL.
    DELETE FROM auth.users WHERE id = v_user_id;
END;
$$;

-- Allow any authenticated user to call this function on their own account.
-- The function body only ever acts on auth.uid(), so there is no way to use
-- it to delete another user.
REVOKE ALL ON FUNCTION public.delete_user_account() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.delete_user_account() TO authenticated;
