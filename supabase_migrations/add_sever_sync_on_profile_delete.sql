-- Migration: Auto-sever sync when a synced profile is deleted
-- Date: 2026-03-30
--
-- When a synced profile is soft-deleted (deleted_at set) or hard-deleted,
-- automatically sever the sync connection so the other user's device
-- also reflects the disconnection.
--
-- Without this, deleting a synced profile leaves the profile_syncs record
-- as 'active', and the other user's synced profile still shows as connected.

CREATE OR REPLACE FUNCTION sever_sync_on_profile_delete()
RETURNS TRIGGER AS $$
DECLARE
    v_sync_id UUID;
    v_sync RECORD;
BEGIN
    IF TG_OP = 'DELETE' THEN
        -- Hard delete: sever sync if profile had a sync connection
        v_sync_id := OLD.sync_connection_id;
    ELSIF TG_OP = 'UPDATE' THEN
        -- Soft delete: sever sync when deleted_at transitions from NULL to a value
        IF OLD.deleted_at IS NULL AND NEW.deleted_at IS NOT NULL AND NEW.sync_connection_id IS NOT NULL THEN
            v_sync_id := NEW.sync_connection_id;
        END IF;
    END IF;

    IF v_sync_id IS NOT NULL THEN
        -- Get the sync record before updating it
        SELECT * INTO v_sync FROM profile_syncs WHERE id = v_sync_id AND status = 'active';

        IF v_sync.id IS NOT NULL THEN
            -- Mark the sync as severed
            UPDATE profile_syncs
            SET status = 'severed',
                severed_at = NOW(),
                updated_at = NOW()
            WHERE id = v_sync_id;

            -- Mark ALL synced profiles on this connection as local-only
            -- This affects both the deleted profile and the counterpart on the other user's device
            UPDATE profiles
            SET is_local_only = true,
                source_user_id = NULL,
                synced_fields = NULL,
                updated_at = NOW()
            WHERE sync_connection_id = v_sync_id
              AND is_local_only = false;

            -- Remove reciprocal account memberships
            -- Remove acceptor from inviter's account (unless they are the owner)
            DELETE FROM account_members
            WHERE account_id = v_sync.inviter_account_id
              AND user_id = v_sync.acceptor_user_id
              AND role != 'owner';

            -- Remove inviter from acceptor's account (unless they are the owner)
            IF v_sync.acceptor_account_id IS NOT NULL THEN
                DELETE FROM account_members
                WHERE account_id = v_sync.acceptor_account_id
                  AND user_id = v_sync.inviter_user_id
                  AND role != 'owner';
            END IF;
        END IF;
    END IF;

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    ELSE
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger for soft-delete (UPDATE where deleted_at changes)
DROP TRIGGER IF EXISTS trigger_sever_sync_on_profile_soft_delete ON profiles;
CREATE TRIGGER trigger_sever_sync_on_profile_soft_delete
    AFTER UPDATE ON profiles
    FOR EACH ROW
    WHEN (OLD.deleted_at IS NULL AND NEW.deleted_at IS NOT NULL)
    EXECUTE FUNCTION sever_sync_on_profile_delete();

-- Trigger for hard-delete (DELETE)
DROP TRIGGER IF EXISTS trigger_sever_sync_on_profile_hard_delete ON profiles;
CREATE TRIGGER trigger_sever_sync_on_profile_hard_delete
    BEFORE DELETE ON profiles
    FOR EACH ROW
    WHEN (OLD.sync_connection_id IS NOT NULL)
    EXECUTE FUNCTION sever_sync_on_profile_delete();
