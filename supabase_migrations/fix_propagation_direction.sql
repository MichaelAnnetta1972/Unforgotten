-- Migration: Fix Propagation Direction
-- CRITICAL BUG FIX: The propagation triggers had the synced profile IDs swapped.
--
-- The profile_syncs table naming convention:
--   inviter_source_profile_id  = inviter's PRIMARY profile (source of truth)
--   inviter_synced_profile_id  = copy of the INVITER in the ACCEPTOR's account
--   acceptor_source_profile_id = acceptor's PRIMARY profile (source of truth)
--   acceptor_synced_profile_id = copy of the ACCEPTOR in the INVITER's account
--
-- BEFORE (WRONG):
--   When inviter's source changes → updated acceptor_synced_profile_id (acceptor's copy!)
--   When acceptor's source changes → updated inviter_synced_profile_id (inviter's copy!)
--
-- AFTER (CORRECT):
--   When inviter's source changes → update inviter_synced_profile_id (inviter's copy in acceptor's account)
--   When acceptor's source changes → update acceptor_synced_profile_id (acceptor's copy in inviter's account)
--
-- This bug caused:
--   - YOUR data (hobbies, medical, etc.) appearing on the connected user's synced profile in YOUR account
--   - Connected user's data appearing on YOUR synced profile in THEIR account

-- ============================================================================
-- PART 1: Fix propagate_profile_changes trigger
-- ============================================================================

CREATE OR REPLACE FUNCTION propagate_profile_changes()
RETURNS TRIGGER AS $$
DECLARE
    v_sync_record RECORD;
    v_share_profile_fields BOOLEAN;
    v_target_user_id UUID;
BEGIN
    -- Skip if this profile is itself a synced copy
    IF NEW.source_user_id IS NOT NULL AND NEW.is_local_only = FALSE THEN
        RETURN NEW;
    END IF;

    -- Case 1: This is the inviter's source profile
    -- Update the copy of the INVITER in the ACCEPTOR's account
    FOR v_sync_record IN
        SELECT ps.*
        FROM profile_syncs ps
        WHERE ps.inviter_source_profile_id = NEW.id
          AND ps.status = 'active'
          AND ps.inviter_synced_profile_id IS NOT NULL
    LOOP
        v_target_user_id := v_sync_record.acceptor_user_id;
        v_share_profile_fields := is_category_shared(NEW.id, 'profile_fields', v_target_user_id);

        UPDATE profiles
        SET
            full_name = NEW.full_name,
            preferred_name = NEW.preferred_name,
            birthday = NEW.birthday,
            email = NEW.email,
            is_deceased = NEW.is_deceased,
            date_of_death = NEW.date_of_death,
            address = CASE WHEN v_share_profile_fields THEN NEW.address ELSE address END,
            phone = CASE WHEN v_share_profile_fields THEN NEW.phone ELSE phone END,
            photo_url = CASE WHEN v_share_profile_fields THEN NEW.photo_url ELSE photo_url END,
            updated_at = NOW()
        WHERE id = v_sync_record.inviter_synced_profile_id
          AND source_user_id IS NOT NULL
          AND is_local_only = FALSE;
    END LOOP;

    -- Case 2: This is the acceptor's source profile
    -- Update the copy of the ACCEPTOR in the INVITER's account
    FOR v_sync_record IN
        SELECT ps.*
        FROM profile_syncs ps
        WHERE ps.acceptor_source_profile_id = NEW.id
          AND ps.status = 'active'
          AND ps.acceptor_synced_profile_id IS NOT NULL
    LOOP
        v_target_user_id := v_sync_record.inviter_user_id;
        v_share_profile_fields := is_category_shared(NEW.id, 'profile_fields', v_target_user_id);

        UPDATE profiles
        SET
            full_name = NEW.full_name,
            preferred_name = NEW.preferred_name,
            birthday = NEW.birthday,
            email = NEW.email,
            is_deceased = NEW.is_deceased,
            date_of_death = NEW.date_of_death,
            address = CASE WHEN v_share_profile_fields THEN NEW.address ELSE address END,
            phone = CASE WHEN v_share_profile_fields THEN NEW.phone ELSE phone END,
            photo_url = CASE WHEN v_share_profile_fields THEN NEW.photo_url ELSE photo_url END,
            updated_at = NOW()
        WHERE id = v_sync_record.acceptor_synced_profile_id
          AND source_user_id IS NOT NULL
          AND is_local_only = FALSE;
    END LOOP;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Re-create the trigger
DROP TRIGGER IF EXISTS trigger_propagate_profile_changes ON profiles;
CREATE TRIGGER trigger_propagate_profile_changes
    AFTER UPDATE ON profiles
    FOR EACH ROW
    EXECUTE FUNCTION propagate_profile_changes();

-- ============================================================================
-- PART 2: Fix propagate_profile_detail_changes trigger (INSERT case)
-- ============================================================================

CREATE OR REPLACE FUNCTION propagate_profile_detail_changes()
RETURNS TRIGGER AS $$
DECLARE
    v_sync_mapping RECORD;
    v_source_profile RECORD;
    v_sync_record RECORD;
    v_new_detail_id UUID;
    v_sharing_key TEXT;
    v_target_user_id UUID;
BEGIN
    IF TG_OP = 'DELETE' THEN
        FOR v_sync_mapping IN
            SELECT pds.synced_detail_id
            FROM profile_detail_syncs pds
            WHERE pds.source_detail_id = OLD.id
        LOOP
            DELETE FROM profile_details WHERE id = v_sync_mapping.synced_detail_id;
        END LOOP;
        DELETE FROM profile_detail_syncs WHERE source_detail_id = OLD.id;
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

-- ============================================================================
-- PART 3: Clean up contaminated data from existing syncs
-- ============================================================================
-- Delete profile_details that were incorrectly synced (inviter's data on acceptor's
-- synced profile, and vice versa). These are entries in profile_detail_syncs where
-- the source profile and synced profile belong to DIFFERENT people.

-- Delete the incorrectly synced detail rows and their sync mappings
DELETE FROM profile_details
WHERE id IN (
    SELECT pds.synced_detail_id
    FROM profile_detail_syncs pds
    JOIN profile_details src ON src.id = pds.source_detail_id
    JOIN profile_syncs ps ON ps.id = pds.sync_connection_id
    WHERE (
        -- Case: source is inviter's profile but synced to acceptor's synced copy (WRONG)
        -- Should have synced to inviter_synced_profile_id instead
        (src.profile_id = ps.inviter_source_profile_id
         AND pds.synced_detail_id IN (
             SELECT pd.id FROM profile_details pd
             WHERE pd.profile_id = ps.acceptor_synced_profile_id
         ))
        OR
        -- Case: source is acceptor's profile but synced to inviter's synced copy (WRONG)
        -- Should have synced to acceptor_synced_profile_id instead
        (src.profile_id = ps.acceptor_source_profile_id
         AND pds.synced_detail_id IN (
             SELECT pd.id FROM profile_details pd
             WHERE pd.profile_id = ps.inviter_synced_profile_id
         ))
    )
);

-- Clean up orphaned profile_detail_syncs entries
DELETE FROM profile_detail_syncs
WHERE synced_detail_id NOT IN (SELECT id FROM profile_details);

-- Also delete duplicate profile_detail_syncs (same source_detail_id + sync_connection_id)
DELETE FROM profile_detail_syncs a
USING profile_detail_syncs b
WHERE a.id > b.id
  AND a.source_detail_id = b.source_detail_id
  AND a.sync_connection_id = b.sync_connection_id;

-- ============================================================================
-- PART 4: Verify the fix
-- ============================================================================

-- This should now return 0 rows (no cross-contaminated syncs)
SELECT COUNT(*) as contaminated_count
FROM profile_detail_syncs pds
JOIN profile_details src ON src.id = pds.source_detail_id
JOIN profile_syncs ps ON ps.id = pds.sync_connection_id
WHERE (
    (src.profile_id = ps.inviter_source_profile_id
     AND pds.synced_detail_id IN (
         SELECT pd.id FROM profile_details pd
         WHERE pd.profile_id = ps.acceptor_synced_profile_id
     ))
    OR
    (src.profile_id = ps.acceptor_source_profile_id
     AND pds.synced_detail_id IN (
         SELECT pd.id FROM profile_details pd
         WHERE pd.profile_id = ps.inviter_synced_profile_id
     ))
);
