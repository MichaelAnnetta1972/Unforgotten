-- Migration: Fix Cross-Device Sync
-- This migration ensures all components needed for cross-device profile syncing are in place:
-- 1. Enables Realtime for profiles and profile_details tables
-- 2. Sets REPLICA IDENTITY FULL so UPDATE/DELETE events include full row data
-- 3. Drops any stale is_category_shared overloads
-- 4. Re-deploys the latest propagation triggers
-- 5. Re-deploys the latest is_category_shared and get_sharing_category_key functions

-- ============================================================================
-- PART 1: Enable Realtime for profiles and profile_details
-- ============================================================================
-- Supabase Realtime only sends events for tables in the supabase_realtime publication.
-- If these tables aren't added, the app's Realtime subscriptions will never fire.

DO $$
BEGIN
    -- Add profiles to realtime publication if not already there
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables
        WHERE pubname = 'supabase_realtime' AND tablename = 'profiles'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE profiles;
    END IF;
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Could not add profiles to realtime: %', SQLERRM;
END $$;

DO $$
BEGIN
    -- Add profile_details to realtime publication if not already there
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables
        WHERE pubname = 'supabase_realtime' AND tablename = 'profile_details'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE profile_details;
    END IF;
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Could not add profile_details to realtime: %', SQLERRM;
END $$;

-- ============================================================================
-- PART 2: Set REPLICA IDENTITY FULL for proper UPDATE/DELETE events
-- ============================================================================
-- Without REPLICA IDENTITY FULL, Realtime UPDATE events may not include
-- all column values, causing the app to miss important changes.

ALTER TABLE profiles REPLICA IDENTITY FULL;
ALTER TABLE profile_details REPLICA IDENTITY FULL;

-- ============================================================================
-- PART 3: Drop stale is_category_shared overload (2-param version)
-- ============================================================================
-- The old 2-param version causes "function is not unique" errors when
-- the propagation trigger calls is_category_shared(uuid, text, uuid) with NULL.

DROP FUNCTION IF EXISTS is_category_shared(UUID, TEXT);

-- ============================================================================
-- PART 4: Ensure get_sharing_category_key function exists
-- ============================================================================

CREATE OR REPLACE FUNCTION get_sharing_category_key(
    p_detail_category TEXT
) RETURNS TEXT AS $$
BEGIN
    CASE p_detail_category
        WHEN 'medical_condition' THEN RETURN 'medical';
        WHEN 'allergy' THEN RETURN 'medical';
        WHEN 'gift_idea' THEN RETURN 'gift_idea';
        WHEN 'clothing' THEN RETURN 'clothing';
        WHEN 'hobby' THEN RETURN 'hobby';
        WHEN 'activity_idea' THEN RETURN 'activity_idea';
        ELSE RETURN NULL;
    END CASE;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- ============================================================================
-- PART 5: Ensure is_category_shared function (3-param version only)
-- ============================================================================

CREATE OR REPLACE FUNCTION is_category_shared(
    p_profile_id UUID,
    p_category TEXT,
    p_target_user_id UUID DEFAULT NULL
) RETURNS BOOLEAN AS $$
DECLARE
    v_is_shared BOOLEAN;
BEGIN
    IF p_target_user_id IS NOT NULL THEN
        SELECT is_shared INTO v_is_shared
        FROM profile_sharing_preferences
        WHERE profile_id = p_profile_id
          AND target_user_id = p_target_user_id
          AND category = p_category;
    ELSE
        SELECT is_shared INTO v_is_shared
        FROM profile_sharing_preferences
        WHERE profile_id = p_profile_id
          AND category = p_category
        LIMIT 1;
    END IF;

    IF NOT FOUND THEN
        RETURN TRUE;
    END IF;

    RETURN v_is_shared;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- ============================================================================
-- PART 6: Re-deploy propagate_profile_changes trigger
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
-- PART 7: Re-deploy propagate_profile_detail_changes trigger
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
-- PART 8: Verify setup (diagnostic query)
-- ============================================================================

-- Check that tables are in the realtime publication
SELECT tablename FROM pg_publication_tables WHERE pubname = 'supabase_realtime'
AND tablename IN ('profiles', 'profile_details')
ORDER BY tablename;

-- Check that triggers exist
SELECT trigger_name, event_manipulation, action_timing
FROM information_schema.triggers
WHERE event_object_table IN ('profiles', 'profile_details')
  AND trigger_name LIKE 'trigger_propagate%'
ORDER BY event_object_table, trigger_name;

-- Check for stale is_category_shared overloads (should show only 1 row)
SELECT p.oid, p.proname, pg_get_function_arguments(p.oid) as args
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE p.proname = 'is_category_shared'
  AND n.nspname = 'public';
