-- Migration: Add RPC to fetch shared important accounts for synced profiles
-- Important accounts live in their own table (not profile_details), so the
-- profile_detail_syncs mechanism never copies them. Instead, when a connected
-- user views a synced profile's Important Accounts, we look up the source
-- profile via profile_syncs and return the source's important_accounts
-- directly, respecting the sharing preference for 'important_accounts'.

CREATE OR REPLACE FUNCTION get_shared_important_accounts(
    p_synced_profile_id TEXT
) RETURNS SETOF important_accounts AS $$
DECLARE
    v_synced_profile_id UUID;
    v_sync RECORD;
    v_source_profile_id UUID;
    v_current_user_id UUID;
    v_is_shared BOOLEAN;
    v_sync_connection_id UUID;
BEGIN
    v_synced_profile_id := p_synced_profile_id::UUID;
    v_current_user_id := auth.uid();

    -- Find the sync connection for this synced profile
    SELECT * INTO v_sync
    FROM profile_syncs
    WHERE status = 'active'
      AND (acceptor_synced_profile_id = v_synced_profile_id
           OR inviter_synced_profile_id = v_synced_profile_id)
    LIMIT 1;

    IF NOT FOUND THEN
        RETURN;  -- No active sync connection, return empty
    END IF;

    v_sync_connection_id := v_sync.id;

    -- Determine the source profile (the original, not the synced copy)
    IF v_sync.acceptor_synced_profile_id = v_synced_profile_id THEN
        v_source_profile_id := v_sync.inviter_source_profile_id;
    ELSIF v_sync.inviter_synced_profile_id = v_synced_profile_id THEN
        v_source_profile_id := v_sync.acceptor_source_profile_id;
    ELSE
        RETURN;  -- Should not happen
    END IF;

    -- Check the sharing preference for important_accounts
    -- Default to true (shared) if no explicit preference exists
    SELECT COALESCE(
        (SELECT is_shared
         FROM profile_sharing_preferences
         WHERE profile_id = v_source_profile_id
           AND target_user_id = v_current_user_id
           AND category = 'important_accounts'
         LIMIT 1),
        TRUE
    ) INTO v_is_shared;

    IF NOT v_is_shared THEN
        RETURN;  -- Sharing is disabled, return empty
    END IF;

    -- Return the source profile's important accounts
    RETURN QUERY
    SELECT *
    FROM important_accounts
    WHERE profile_id = v_source_profile_id
    ORDER BY account_name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
