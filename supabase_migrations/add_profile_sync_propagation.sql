-- Migration: Add Profile Change Propagation Triggers
-- This migration adds triggers to automatically propagate profile changes to synced copies
-- Run this in your Supabase SQL Editor

-- ============================================================================
-- PART 1: Profile Change Propagation Trigger Function
-- ============================================================================

-- This function is called whenever a profile is updated.
-- It checks if this profile is a "source" profile (i.e., other profiles are synced from it)
-- and propagates the syncable field changes to all synced copies.

CREATE OR REPLACE FUNCTION propagate_profile_changes()
RETURNS TRIGGER AS $$
DECLARE
    v_syncable_fields TEXT[] := ARRAY[
        'full_name', 'preferred_name', 'birthday',
        'address', 'phone', 'email', 'photo_url'
    ];
    v_synced_profile RECORD;
    v_sync_record RECORD;
BEGIN
    -- Skip if this profile is itself a synced copy (has source_user_id set and not local_only)
    -- This prevents infinite recursion
    IF NEW.source_user_id IS NOT NULL AND NEW.is_local_only = FALSE THEN
        RETURN NEW;
    END IF;

    -- Find all profile_syncs records where this profile is a source
    -- Case 1: This is the inviter's source profile
    FOR v_sync_record IN
        SELECT ps.*, 'inviter' as source_side
        FROM profile_syncs ps
        WHERE ps.inviter_source_profile_id = NEW.id
          AND ps.status = 'active'
          AND ps.acceptor_synced_profile_id IS NOT NULL
    LOOP
        -- Update the acceptor's synced copy of this profile
        UPDATE profiles
        SET
            full_name = NEW.full_name,
            preferred_name = NEW.preferred_name,
            birthday = NEW.birthday,
            address = NEW.address,
            phone = NEW.phone,
            email = NEW.email,
            photo_url = NEW.photo_url,
            is_deceased = NEW.is_deceased,
            updated_at = NOW()
        WHERE id = v_sync_record.acceptor_synced_profile_id
          AND source_user_id IS NOT NULL
          AND is_local_only = FALSE;
    END LOOP;

    -- Case 2: This is the acceptor's source profile
    FOR v_sync_record IN
        SELECT ps.*, 'acceptor' as source_side
        FROM profile_syncs ps
        WHERE ps.acceptor_source_profile_id = NEW.id
          AND ps.status = 'active'
          AND ps.inviter_synced_profile_id IS NOT NULL
    LOOP
        -- Update the inviter's synced copy of this profile
        UPDATE profiles
        SET
            full_name = NEW.full_name,
            preferred_name = NEW.preferred_name,
            birthday = NEW.birthday,
            address = NEW.address,
            phone = NEW.phone,
            email = NEW.email,
            photo_url = NEW.photo_url,
            is_deceased = NEW.is_deceased,
            updated_at = NOW()
        WHERE id = v_sync_record.inviter_synced_profile_id
          AND source_user_id IS NOT NULL
          AND is_local_only = FALSE;
    END LOOP;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create the trigger on profiles table
DROP TRIGGER IF EXISTS trigger_propagate_profile_changes ON profiles;
CREATE TRIGGER trigger_propagate_profile_changes
    AFTER UPDATE ON profiles
    FOR EACH ROW
    EXECUTE FUNCTION propagate_profile_changes();

-- ============================================================================
-- PART 2: Profile Details Change Propagation Trigger Function
-- ============================================================================

-- This function propagates profile detail changes (INSERT, UPDATE, DELETE)
-- to the synced copies via the profile_detail_syncs tracking table.

CREATE OR REPLACE FUNCTION propagate_profile_detail_changes()
RETURNS TRIGGER AS $$
DECLARE
    v_sync_mapping RECORD;
    v_source_profile RECORD;
    v_sync_record RECORD;
    v_new_detail_id UUID;
BEGIN
    IF TG_OP = 'DELETE' THEN
        -- When a source detail is deleted, delete all synced copies
        FOR v_sync_mapping IN
            SELECT pds.synced_detail_id
            FROM profile_detail_syncs pds
            WHERE pds.source_detail_id = OLD.id
        LOOP
            DELETE FROM profile_details WHERE id = v_sync_mapping.synced_detail_id;
        END LOOP;

        -- Clean up the sync mappings
        DELETE FROM profile_detail_syncs WHERE source_detail_id = OLD.id;

        RETURN OLD;

    ELSIF TG_OP = 'UPDATE' THEN
        -- When a source detail is updated, update all synced copies
        FOR v_sync_mapping IN
            SELECT pds.synced_detail_id
            FROM profile_detail_syncs pds
            WHERE pds.source_detail_id = NEW.id
        LOOP
            UPDATE profile_details
            SET
                category = NEW.category,
                label = NEW.label,
                value = NEW.value,
                status = NEW.status,
                occasion = NEW.occasion,
                metadata = NEW.metadata,
                updated_at = NOW()
            WHERE id = v_sync_mapping.synced_detail_id;
        END LOOP;

        RETURN NEW;

    ELSIF TG_OP = 'INSERT' THEN
        -- When a new detail is added to a source profile, copy it to synced profiles
        -- First, check if this profile is a source profile in any active sync

        -- Get the profile this detail belongs to
        SELECT * INTO v_source_profile
        FROM profiles
        WHERE id = NEW.profile_id;

        -- Skip if the profile is itself a synced copy
        IF v_source_profile.source_user_id IS NOT NULL AND v_source_profile.is_local_only = FALSE THEN
            RETURN NEW;
        END IF;

        -- Case 1: Profile is inviter's source profile
        FOR v_sync_record IN
            SELECT ps.*
            FROM profile_syncs ps
            WHERE ps.inviter_source_profile_id = NEW.profile_id
              AND ps.status = 'active'
              AND ps.acceptor_synced_profile_id IS NOT NULL
        LOOP
            -- Get the synced profile's account_id
            INSERT INTO profile_details (
                account_id, profile_id, category, label, value,
                status, occasion, metadata
            )
            SELECT
                p.account_id, v_sync_record.acceptor_synced_profile_id, NEW.category,
                NEW.label, NEW.value, NEW.status, NEW.occasion, NEW.metadata
            FROM profiles p
            WHERE p.id = v_sync_record.acceptor_synced_profile_id
            RETURNING id INTO v_new_detail_id;

            -- Track the sync relationship
            IF v_new_detail_id IS NOT NULL THEN
                INSERT INTO profile_detail_syncs (sync_connection_id, source_detail_id, synced_detail_id)
                VALUES (v_sync_record.id, NEW.id, v_new_detail_id);
            END IF;
        END LOOP;

        -- Case 2: Profile is acceptor's source profile
        FOR v_sync_record IN
            SELECT ps.*
            FROM profile_syncs ps
            WHERE ps.acceptor_source_profile_id = NEW.profile_id
              AND ps.status = 'active'
              AND ps.inviter_synced_profile_id IS NOT NULL
        LOOP
            -- Get the synced profile's account_id
            INSERT INTO profile_details (
                account_id, profile_id, category, label, value,
                status, occasion, metadata
            )
            SELECT
                p.account_id, v_sync_record.inviter_synced_profile_id, NEW.category,
                NEW.label, NEW.value, NEW.status, NEW.occasion, NEW.metadata
            FROM profiles p
            WHERE p.id = v_sync_record.inviter_synced_profile_id
            RETURNING id INTO v_new_detail_id;

            -- Track the sync relationship
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

-- Create the trigger on profile_details table
DROP TRIGGER IF EXISTS trigger_propagate_profile_detail_changes ON profile_details;
CREATE TRIGGER trigger_propagate_profile_detail_changes
    AFTER INSERT OR UPDATE OR DELETE ON profile_details
    FOR EACH ROW
    EXECUTE FUNCTION propagate_profile_detail_changes();

-- ============================================================================
-- PART 3: Grant necessary permissions
-- ============================================================================

-- The trigger functions run as SECURITY DEFINER, so they have full access.
-- No additional grants needed.

-- ============================================================================
-- VERIFICATION QUERIES (Run these to debug sync issues)
-- ============================================================================

-- 1. Check that triggers exist:
-- SELECT trigger_name, event_manipulation, action_statement
-- FROM information_schema.triggers
-- WHERE trigger_schema = 'public'
--   AND trigger_name LIKE '%propagate%';

-- 2. Check profile_syncs records (shows active sync connections):
-- SELECT
--     id,
--     status,
--     inviter_source_profile_id,
--     inviter_synced_profile_id,
--     acceptor_source_profile_id,
--     acceptor_synced_profile_id
-- FROM profile_syncs
-- WHERE status = 'active';

-- 3. Check which profiles are synced copies (have source_user_id):
-- SELECT id, full_name, source_user_id, is_local_only, sync_connection_id, account_id
-- FROM profiles
-- WHERE source_user_id IS NOT NULL;

-- 4. Check which profiles are source profiles (referenced in profile_syncs):
-- SELECT p.id, p.full_name, p.account_id,
--        ps.id as sync_id,
--        CASE
--          WHEN ps.inviter_source_profile_id = p.id THEN 'inviter_source'
--          WHEN ps.acceptor_source_profile_id = p.id THEN 'acceptor_source'
--        END as role
-- FROM profiles p
-- JOIN profile_syncs ps ON (ps.inviter_source_profile_id = p.id OR ps.acceptor_source_profile_id = p.id)
-- WHERE ps.status = 'active';

-- 5. Test the trigger manually (replace UUID):
-- UPDATE profiles SET full_name = full_name || ' (test)' WHERE id = 'your-source-profile-uuid';
-- Then check if the synced copy was updated:
-- SELECT id, full_name, updated_at FROM profiles WHERE source_user_id IS NOT NULL;
