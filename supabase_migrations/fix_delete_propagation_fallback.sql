-- Migration: Add fallback delete propagation for unmapped synced details
--
-- The current DELETE trigger only finds synced copies via profile_detail_syncs.
-- If a mapping is missing (orphaned detail), the delete silently fails.
--
-- This fix adds a fallback: after checking mappings, also look for matching
-- details on synced profiles via profile_syncs (same category + label + value).

CREATE OR REPLACE FUNCTION propagate_profile_detail_changes()
RETURNS TRIGGER AS $$
DECLARE
    v_sync_mapping RECORD;
    v_source_profile RECORD;
    v_sync_record RECORD;
    v_new_detail_id UUID;
    v_sharing_key TEXT;
    v_target_user_id UUID;
    v_synced_profile_id UUID;
    v_found_via_mapping BOOLEAN := FALSE;
BEGIN
    IF TG_OP = 'DELETE' THEN
        -- Primary path: delete via profile_detail_syncs mappings
        FOR v_sync_mapping IN
            SELECT pds.synced_detail_id
            FROM profile_detail_syncs pds
            WHERE pds.source_detail_id = OLD.id
        LOOP
            DELETE FROM profile_details WHERE id = v_sync_mapping.synced_detail_id;
            v_found_via_mapping := TRUE;
        END LOOP;
        DELETE FROM profile_detail_syncs WHERE source_detail_id = OLD.id;

        -- Fallback: if no mapping found, try to find synced copies by matching
        -- category+label+value on the synced profile via profile_syncs
        IF NOT v_found_via_mapping THEN
            -- Check if source is inviter's profile
            FOR v_sync_record IN
                SELECT ps.inviter_synced_profile_id as synced_pid
                FROM profile_syncs ps
                WHERE ps.inviter_source_profile_id = OLD.profile_id
                  AND ps.status = 'active'
                  AND ps.inviter_synced_profile_id IS NOT NULL
            LOOP
                DELETE FROM profile_details
                WHERE profile_id = v_sync_record.synced_pid
                  AND category = OLD.category
                  AND label IS NOT DISTINCT FROM OLD.label
                  AND value IS NOT DISTINCT FROM OLD.value;
            END LOOP;

            -- Check if source is acceptor's profile
            FOR v_sync_record IN
                SELECT ps.acceptor_synced_profile_id as synced_pid
                FROM profile_syncs ps
                WHERE ps.acceptor_source_profile_id = OLD.profile_id
                  AND ps.status = 'active'
                  AND ps.acceptor_synced_profile_id IS NOT NULL
            LOOP
                DELETE FROM profile_details
                WHERE profile_id = v_sync_record.synced_pid
                  AND category = OLD.category
                  AND label IS NOT DISTINCT FROM OLD.label
                  AND value IS NOT DISTINCT FROM OLD.value;
            END LOOP;
        END IF;

        RETURN OLD;

    ELSIF TG_OP = 'UPDATE' THEN
        FOR v_sync_mapping IN
            SELECT pds.synced_detail_id
            FROM profile_detail_syncs pds
            WHERE pds.source_detail_id = NEW.id
        LOOP
            UPDATE profile_details
            SET category = NEW.category, label = NEW.label, value = NEW.value,
                status = NEW.status, occasion = NEW.occasion,
                metadata = NEW.metadata, updated_at = NOW()
            WHERE id = v_sync_mapping.synced_detail_id;
        END LOOP;
        RETURN NEW;

    ELSIF TG_OP = 'INSERT' THEN
        SELECT * INTO v_source_profile FROM profiles WHERE id = NEW.profile_id;

        -- Skip if this detail belongs to a synced copy (not a source profile)
        IF v_source_profile.source_user_id IS NOT NULL AND v_source_profile.is_local_only = FALSE THEN
            RETURN NEW;
        END IF;

        v_sharing_key := get_sharing_category_key(NEW.category);

        -- Case 1: Profile is inviter's source profile
        -- Copy detail to the INVITER's synced copy in the ACCEPTOR's account
        FOR v_sync_record IN
            SELECT ps.*
            FROM profile_syncs ps
            WHERE ps.inviter_source_profile_id = NEW.profile_id
              AND ps.status = 'active'
              AND ps.inviter_synced_profile_id IS NOT NULL
        LOOP
            v_target_user_id := v_sync_record.acceptor_user_id;

            IF v_sharing_key IS NOT NULL AND NOT is_category_shared(NEW.profile_id, v_sharing_key, v_target_user_id) THEN
                CONTINUE;
            END IF;

            INSERT INTO profile_details (
                account_id, profile_id, category, label, value,
                status, occasion, metadata
            )
            SELECT p.account_id, v_sync_record.inviter_synced_profile_id, NEW.category,
                   NEW.label, NEW.value, NEW.status, NEW.occasion, NEW.metadata
            FROM profiles p WHERE p.id = v_sync_record.inviter_synced_profile_id
            RETURNING id INTO v_new_detail_id;

            IF v_new_detail_id IS NOT NULL THEN
                INSERT INTO profile_detail_syncs (sync_connection_id, source_detail_id, synced_detail_id)
                VALUES (v_sync_record.id, NEW.id, v_new_detail_id);
            END IF;
        END LOOP;

        -- Case 2: Profile is acceptor's source profile
        -- Copy detail to the ACCEPTOR's synced copy in the INVITER's account
        FOR v_sync_record IN
            SELECT ps.*
            FROM profile_syncs ps
            WHERE ps.acceptor_source_profile_id = NEW.profile_id
              AND ps.status = 'active'
              AND ps.acceptor_synced_profile_id IS NOT NULL
        LOOP
            v_target_user_id := v_sync_record.inviter_user_id;

            IF v_sharing_key IS NOT NULL AND NOT is_category_shared(NEW.profile_id, v_sharing_key, v_target_user_id) THEN
                CONTINUE;
            END IF;

            INSERT INTO profile_details (
                account_id, profile_id, category, label, value,
                status, occasion, metadata
            )
            SELECT p.account_id, v_sync_record.acceptor_synced_profile_id, NEW.category,
                   NEW.label, NEW.value, NEW.status, NEW.occasion, NEW.metadata
            FROM profiles p WHERE p.id = v_sync_record.acceptor_synced_profile_id
            RETURNING id INTO v_new_detail_id;

            IF v_new_detail_id IS NOT NULL THEN
                INSERT INTO profile_detail_syncs (sync_connection_id, source_detail_id, synced_detail_id)
                VALUES (v_sync_record.id, NEW.id, v_new_detail_id);
            END IF;
        END LOOP;

        RETURN NEW;
    END IF;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Re-create the trigger
DROP TRIGGER IF EXISTS trigger_propagate_profile_detail_changes ON profile_details;
CREATE TRIGGER trigger_propagate_profile_detail_changes
    AFTER INSERT OR UPDATE OR DELETE ON profile_details
    FOR EACH ROW
    EXECUTE FUNCTION propagate_profile_detail_changes();
