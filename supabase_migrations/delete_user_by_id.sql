-- Utility: Cleanly delete a user and all their data
-- Usage: Replace the UUID below with the target user's auth.users.id
--        Run in Supabase SQL Editor
--
-- IMPORTANT: After running this script, also delete the user from
-- Supabase Dashboard > Authentication > Users to remove the auth record.
--
-- This script handles:
-- 1. Accounts OWNED by this user (and all data within those accounts)
-- 2. Account memberships where this user is a member (not owner)
-- 3. Profile sync connections involving this user
-- 4. Direct user references (device tokens, preferences, etc.)
-- 5. The app_users record itself

DO $$
DECLARE
    v_user_id UUID := '00000000-0000-0000-0000-000000000000';  -- ← REPLACE WITH ACTUAL USER ID
    v_account RECORD;
    v_owned_account_ids UUID[];
BEGIN
    RAISE NOTICE 'Deleting user: %', v_user_id;

    -- ========================================================================
    -- 1. COLLECT ACCOUNTS OWNED BY THIS USER
    -- ========================================================================
    SELECT ARRAY_AGG(account_id) INTO v_owned_account_ids
    FROM account_members
    WHERE user_id = v_user_id AND role = 'owner';

    IF v_owned_account_ids IS NULL THEN
        v_owned_account_ids := ARRAY[]::UUID[];
    END IF;

    RAISE NOTICE 'Owned accounts: %', v_owned_account_ids;

    -- ========================================================================
    -- 2. SEVER ALL PROFILE SYNCS INVOLVING THIS USER
    --    (before deleting profiles to avoid trigger issues)
    -- ========================================================================

    -- Delete profile_detail_syncs for any sync connections involving this user
    DELETE FROM profile_detail_syncs
    WHERE sync_connection_id IN (
        SELECT id FROM profile_syncs
        WHERE inviter_user_id = v_user_id OR acceptor_user_id = v_user_id
    );

    -- Delete sharing preferences for profiles owned by this user
    DELETE FROM profile_sharing_preferences
    WHERE user_id = v_user_id
       OR profile_id IN (
            SELECT id FROM profiles WHERE account_id = ANY(v_owned_account_ids)
        );

    -- Delete the profile_syncs records
    DELETE FROM profile_syncs
    WHERE inviter_user_id = v_user_id OR acceptor_user_id = v_user_id;

    -- ========================================================================
    -- 3. DELETE ALL DATA IN OWNED ACCOUNTS
    -- ========================================================================

    -- Meal planning
    DELETE FROM planned_meals WHERE account_id = ANY(v_owned_account_ids);
    DELETE FROM recipes WHERE account_id = ANY(v_owned_account_ids);

    -- Family calendar sharing
    DELETE FROM family_calendar_share_members
    WHERE share_id IN (
        SELECT id FROM family_calendar_shares WHERE account_id = ANY(v_owned_account_ids)
    );
    DELETE FROM family_calendar_shares WHERE account_id = ANY(v_owned_account_ids);

    -- To-do lists
    DELETE FROM todo_items
    WHERE list_id IN (
        SELECT id FROM todo_lists WHERE account_id = ANY(v_owned_account_ids)
    );
    DELETE FROM todo_lists WHERE account_id = ANY(v_owned_account_ids);
    DELETE FROM todo_list_types WHERE account_id = ANY(v_owned_account_ids);

    -- Notes
    DELETE FROM notes WHERE account_id = ANY(v_owned_account_ids);

    -- Mood & reminders
    DELETE FROM mood_entries WHERE account_id = ANY(v_owned_account_ids);
    DELETE FROM sticky_reminders WHERE account_id = ANY(v_owned_account_ids);

    -- Medications
    DELETE FROM medication_logs WHERE account_id = ANY(v_owned_account_ids);
    DELETE FROM medication_schedules WHERE account_id = ANY(v_owned_account_ids);
    DELETE FROM medications WHERE account_id = ANY(v_owned_account_ids);

    -- Appointments & countdowns
    DELETE FROM appointments WHERE account_id = ANY(v_owned_account_ids);
    DELETE FROM countdowns WHERE account_id = ANY(v_owned_account_ids);

    -- Contacts & important accounts
    DELETE FROM useful_contacts WHERE account_id = ANY(v_owned_account_ids);
    DELETE FROM important_accounts
    WHERE profile_id IN (
        SELECT id FROM profiles WHERE account_id = ANY(v_owned_account_ids)
    );

    -- Profile groups
    DELETE FROM profile_group_members
    WHERE group_id IN (
        SELECT id FROM profile_groups WHERE account_id = ANY(v_owned_account_ids)
    );
    DELETE FROM profile_groups WHERE account_id = ANY(v_owned_account_ids);

    -- Profile connections
    DELETE FROM profile_connections WHERE account_id = ANY(v_owned_account_ids);

    -- Profile details (disable propagation trigger to avoid cascade issues)
    ALTER TABLE profile_details DISABLE TRIGGER trigger_propagate_profile_detail_changes;
    DELETE FROM profile_details WHERE account_id = ANY(v_owned_account_ids);
    ALTER TABLE profile_details ENABLE TRIGGER trigger_propagate_profile_detail_changes;

    -- Profiles (disable sync-sever trigger to avoid re-processing)
    DROP TRIGGER IF EXISTS trigger_sever_sync_on_profile_soft_delete ON profiles;
    DROP TRIGGER IF EXISTS trigger_sever_sync_on_profile_hard_delete ON profiles;
    DELETE FROM profiles WHERE account_id = ANY(v_owned_account_ids);
    -- Re-create triggers after deletion
    CREATE TRIGGER trigger_sever_sync_on_profile_soft_delete
        AFTER UPDATE ON profiles
        FOR EACH ROW
        WHEN (OLD.deleted_at IS NULL AND NEW.deleted_at IS NOT NULL)
        EXECUTE FUNCTION sever_sync_on_profile_delete();
    CREATE TRIGGER trigger_sever_sync_on_profile_hard_delete
        BEFORE DELETE ON profiles
        FOR EACH ROW
        WHEN (OLD.sync_connection_id IS NOT NULL)
        EXECUTE FUNCTION sever_sync_on_profile_delete();

    -- Invitations
    DELETE FROM account_invitations WHERE account_id = ANY(v_owned_account_ids);

    -- Account members (all members of owned accounts)
    DELETE FROM account_members WHERE account_id = ANY(v_owned_account_ids);

    -- Accounts
    DELETE FROM accounts WHERE id = ANY(v_owned_account_ids);

    -- ========================================================================
    -- 4. CLEAN UP USER'S MEMBERSHIPS IN OTHER ACCOUNTS
    -- ========================================================================
    DELETE FROM account_members WHERE user_id = v_user_id;

    -- Clean up invitations sent by or accepted by this user (in other accounts)
    UPDATE account_invitations SET accepted_by = NULL WHERE accepted_by = v_user_id;
    DELETE FROM account_invitations WHERE invited_by = v_user_id;

    -- Clean up family calendar share memberships in other accounts
    DELETE FROM family_calendar_share_members WHERE member_user_id = v_user_id;
    DELETE FROM family_calendar_shares WHERE shared_by_user_id = v_user_id;

    -- Clean up synced profiles in other accounts that reference this user
    UPDATE profiles
    SET source_user_id = NULL, linked_user_id = NULL, is_local_only = true,
        sync_connection_id = NULL, synced_fields = NULL
    WHERE (linked_user_id = v_user_id OR source_user_id = v_user_id)
      AND account_id != ALL(v_owned_account_ids);

    -- ========================================================================
    -- 5. DELETE DIRECT USER RECORDS
    -- ========================================================================
    DELETE FROM device_tokens WHERE user_id = v_user_id;
    DELETE FROM live_activity_tokens WHERE user_id = v_user_id;
    DELETE FROM user_preferences WHERE user_id = v_user_id;
    DELETE FROM morning_briefing_cache WHERE user_id = v_user_id;
    DELETE FROM notes WHERE user_id = v_user_id;

    -- ========================================================================
    -- 6. DELETE APP USER RECORD
    -- ========================================================================
    DELETE FROM app_users WHERE id = v_user_id;

    RAISE NOTICE 'User % deleted successfully.', v_user_id;
    RAISE NOTICE 'REMINDER: Delete the auth user from Supabase Dashboard > Authentication > Users';
END $$;
