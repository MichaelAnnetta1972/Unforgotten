-- Migration: Add Profile Sharing Preferences
-- This migration adds per-category sharing preferences for profile sync.
-- Users can choose which categories of their profile data to share with connected users.
-- Run this in your Supabase SQL Editor AFTER add_profile_sync_propagation.sql

-- ============================================================================
-- PART 1: Create profile_sharing_preferences Table
-- ============================================================================

CREATE TABLE IF NOT EXISTS profile_sharing_preferences (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    profile_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,

    -- Category key: 'profile_fields', 'medical', 'gift_idea', 'clothing', 'hobby', 'activity_idea'
    category TEXT NOT NULL,

    -- Whether sharing is enabled for this category (default TRUE)
    is_shared BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- One preference per profile per category
    UNIQUE(profile_id, category)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_sharing_prefs_profile ON profile_sharing_preferences(profile_id);
CREATE INDEX IF NOT EXISTS idx_sharing_prefs_profile_category ON profile_sharing_preferences(profile_id, category);

-- Updated_at trigger
CREATE OR REPLACE FUNCTION update_sharing_preferences_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_sharing_preferences_updated_at ON profile_sharing_preferences;
CREATE TRIGGER trigger_update_sharing_preferences_updated_at
    BEFORE UPDATE ON profile_sharing_preferences
    FOR EACH ROW
    EXECUTE FUNCTION update_sharing_preferences_updated_at();

-- ============================================================================
-- PART 2: RLS Policies
-- ============================================================================

ALTER TABLE profile_sharing_preferences ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own sharing preferences"
    ON profile_sharing_preferences FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own sharing preferences"
    ON profile_sharing_preferences FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own sharing preferences"
    ON profile_sharing_preferences FOR UPDATE
    USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own sharing preferences"
    ON profile_sharing_preferences FOR DELETE
    USING (auth.uid() = user_id);

-- ============================================================================
-- PART 3: Helper Functions
-- ============================================================================

-- Check if a category is shared for a given profile.
-- Returns TRUE if no row exists (default is shared).
CREATE OR REPLACE FUNCTION is_category_shared(
    p_profile_id UUID,
    p_category TEXT
) RETURNS BOOLEAN AS $$
DECLARE
    v_is_shared BOOLEAN;
BEGIN
    SELECT is_shared INTO v_is_shared
    FROM profile_sharing_preferences
    WHERE profile_id = p_profile_id AND category = p_category;

    -- If no row exists, default is shared (TRUE)
    IF NOT FOUND THEN
        RETURN TRUE;
    END IF;

    RETURN v_is_shared;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- Map DetailCategory raw values to sharing preference category keys.
-- Returns NULL for categories that don't have sharing control (likes, dislikes, notes).
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
-- PART 4: Update Sharing Preference RPC
-- ============================================================================

-- This function handles toggling a sharing preference on/off.
-- When turned OFF: deletes synced copies for that category from connected profiles.
-- When turned ON: re-syncs all details in that category to connected profiles.
CREATE OR REPLACE FUNCTION update_sharing_preference(
    p_profile_id UUID,
    p_category TEXT,
    p_is_shared BOOLEAN
) RETURNS JSON AS $$
DECLARE
    v_profile RECORD;
    v_sync RECORD;
    v_detail RECORD;
    v_target_profile_id UUID;
    v_target_account_id UUID;
    v_new_detail_id UUID;
    v_detail_categories TEXT[];
BEGIN
    PERFORM set_config('row_security', 'off', true);

    -- Get the profile
    SELECT * INTO v_profile FROM profiles WHERE id = p_profile_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Profile not found';
    END IF;

    -- Upsert the sharing preference
    INSERT INTO profile_sharing_preferences (profile_id, user_id, category, is_shared)
    VALUES (p_profile_id, COALESCE(v_profile.linked_user_id, auth.uid()), p_category, p_is_shared)
    ON CONFLICT (profile_id, category)
    DO UPDATE SET is_shared = p_is_shared, updated_at = NOW();

    -- Map sharing category to detail categories
    CASE p_category
        WHEN 'medical' THEN v_detail_categories := ARRAY['medical_condition', 'allergy'];
        WHEN 'gift_idea' THEN v_detail_categories := ARRAY['gift_idea'];
        WHEN 'clothing' THEN v_detail_categories := ARRAY['clothing'];
        WHEN 'hobby' THEN v_detail_categories := ARRAY['hobby'];
        WHEN 'activity_idea' THEN v_detail_categories := ARRAY['activity_idea'];
        WHEN 'profile_fields' THEN v_detail_categories := ARRAY[]::TEXT[];
        ELSE RAISE EXCEPTION 'Unknown category: %', p_category;
    END CASE;

    IF NOT p_is_shared THEN
        -- ===== SHARING TURNED OFF =====
        -- Delete synced copies and null out profile fields

        FOR v_sync IN
            SELECT * FROM profile_syncs
            WHERE status = 'active'
              AND (inviter_source_profile_id = p_profile_id OR acceptor_source_profile_id = p_profile_id)
        LOOP
            -- Determine the target synced profile
            IF v_sync.inviter_source_profile_id = p_profile_id THEN
                v_target_profile_id := v_sync.acceptor_synced_profile_id;
            ELSE
                v_target_profile_id := v_sync.inviter_synced_profile_id;
            END IF;

            -- Delete synced detail copies for this category
            IF array_length(v_detail_categories, 1) > 0 AND v_target_profile_id IS NOT NULL THEN
                -- First delete the synced detail records
                DELETE FROM profile_details
                WHERE id IN (
                    SELECT pds.synced_detail_id
                    FROM profile_detail_syncs pds
                    JOIN profile_details pd ON pd.id = pds.source_detail_id
                    WHERE pds.sync_connection_id = v_sync.id
                      AND pd.profile_id = p_profile_id
                      AND pd.category = ANY(v_detail_categories)
                );

                -- Clean up sync mapping records
                DELETE FROM profile_detail_syncs
                WHERE sync_connection_id = v_sync.id
                  AND source_detail_id IN (
                      SELECT id FROM profile_details
                      WHERE profile_id = p_profile_id
                        AND category = ANY(v_detail_categories)
                  );
            END IF;

            -- Handle profile_fields: null out address/phone/photo on synced profiles
            IF p_category = 'profile_fields' AND v_target_profile_id IS NOT NULL THEN
                UPDATE profiles SET
                    address = NULL,
                    phone = NULL,
                    photo_url = NULL,
                    updated_at = NOW()
                WHERE id = v_target_profile_id
                  AND source_user_id IS NOT NULL;
            END IF;
        END LOOP;

    ELSE
        -- ===== SHARING TURNED ON =====
        -- Re-sync details and profile fields to all connected profiles

        FOR v_sync IN
            SELECT * FROM profile_syncs
            WHERE status = 'active'
              AND (inviter_source_profile_id = p_profile_id OR acceptor_source_profile_id = p_profile_id)
        LOOP
            -- Determine the target synced profile
            IF v_sync.inviter_source_profile_id = p_profile_id THEN
                v_target_profile_id := v_sync.acceptor_synced_profile_id;
                v_target_account_id := v_sync.acceptor_account_id;
            ELSE
                v_target_profile_id := v_sync.inviter_synced_profile_id;
                v_target_account_id := v_sync.inviter_account_id;
            END IF;

            IF v_target_profile_id IS NOT NULL THEN
                -- Re-sync profile fields
                IF p_category = 'profile_fields' THEN
                    UPDATE profiles SET
                        address = v_profile.address,
                        phone = v_profile.phone,
                        photo_url = v_profile.photo_url,
                        updated_at = NOW()
                    WHERE id = v_target_profile_id
                      AND source_user_id IS NOT NULL;
                END IF;

                -- Re-sync detail categories (only details not already synced)
                IF array_length(v_detail_categories, 1) > 0 THEN
                    FOR v_detail IN
                        SELECT * FROM profile_details
                        WHERE profile_id = p_profile_id
                          AND category = ANY(v_detail_categories)
                          AND id NOT IN (
                              SELECT source_detail_id FROM profile_detail_syncs
                              WHERE sync_connection_id = v_sync.id
                          )
                    LOOP
                        INSERT INTO profile_details (
                            account_id, profile_id, category, label, value,
                            status, occasion, metadata
                        ) VALUES (
                            v_target_account_id, v_target_profile_id, v_detail.category,
                            v_detail.label, v_detail.value, v_detail.status,
                            v_detail.occasion, v_detail.metadata
                        ) RETURNING id INTO v_new_detail_id;

                        INSERT INTO profile_detail_syncs (sync_connection_id, source_detail_id, synced_detail_id)
                        VALUES (v_sync.id, v_detail.id, v_new_detail_id);
                    END LOOP;
                END IF;
            END IF;
        END LOOP;
    END IF;

    RETURN json_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- PART 5: Updated propagate_profile_changes() Trigger
-- ============================================================================

-- Now checks sharing preferences before propagating address, phone, and photo_url.
-- Name, email, birthday, and is_deceased are ALWAYS propagated.

CREATE OR REPLACE FUNCTION propagate_profile_changes()
RETURNS TRIGGER AS $$
DECLARE
    v_sync_record RECORD;
    v_share_profile_fields BOOLEAN;
BEGIN
    -- Skip if this profile is itself a synced copy
    IF NEW.source_user_id IS NOT NULL AND NEW.is_local_only = FALSE THEN
        RETURN NEW;
    END IF;

    -- Check if profile fields are shared
    v_share_profile_fields := is_category_shared(NEW.id, 'profile_fields');

    -- Case 1: This is the inviter's source profile
    FOR v_sync_record IN
        SELECT ps.*
        FROM profile_syncs ps
        WHERE ps.inviter_source_profile_id = NEW.id
          AND ps.status = 'active'
          AND ps.acceptor_synced_profile_id IS NOT NULL
    LOOP
        UPDATE profiles
        SET
            -- Always-shared fields
            full_name = NEW.full_name,
            preferred_name = NEW.preferred_name,
            birthday = NEW.birthday,
            email = NEW.email,
            is_deceased = NEW.is_deceased,
            date_of_death = NEW.date_of_death,
            -- Conditionally-shared profile fields
            address = CASE WHEN v_share_profile_fields THEN NEW.address ELSE address END,
            phone = CASE WHEN v_share_profile_fields THEN NEW.phone ELSE phone END,
            photo_url = CASE WHEN v_share_profile_fields THEN NEW.photo_url ELSE photo_url END,
            updated_at = NOW()
        WHERE id = v_sync_record.acceptor_synced_profile_id
          AND source_user_id IS NOT NULL
          AND is_local_only = FALSE;
    END LOOP;

    -- Case 2: This is the acceptor's source profile
    FOR v_sync_record IN
        SELECT ps.*
        FROM profile_syncs ps
        WHERE ps.acceptor_source_profile_id = NEW.id
          AND ps.status = 'active'
          AND ps.inviter_synced_profile_id IS NOT NULL
    LOOP
        UPDATE profiles
        SET
            -- Always-shared fields
            full_name = NEW.full_name,
            preferred_name = NEW.preferred_name,
            birthday = NEW.birthday,
            email = NEW.email,
            is_deceased = NEW.is_deceased,
            date_of_death = NEW.date_of_death,
            -- Conditionally-shared profile fields
            address = CASE WHEN v_share_profile_fields THEN NEW.address ELSE address END,
            phone = CASE WHEN v_share_profile_fields THEN NEW.phone ELSE phone END,
            photo_url = CASE WHEN v_share_profile_fields THEN NEW.photo_url ELSE photo_url END,
            updated_at = NOW()
        WHERE id = v_sync_record.inviter_synced_profile_id
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
-- PART 6: Updated propagate_profile_detail_changes() Trigger
-- ============================================================================

-- Now checks sharing preferences before creating synced copies of new details.
-- UPDATE and DELETE handlers remain unchanged (if a synced copy exists, it should
-- still be updated/deleted regardless of current sharing state).

CREATE OR REPLACE FUNCTION propagate_profile_detail_changes()
RETURNS TRIGGER AS $$
DECLARE
    v_sync_mapping RECORD;
    v_source_profile RECORD;
    v_sync_record RECORD;
    v_new_detail_id UUID;
    v_sharing_key TEXT;
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
        -- Get the profile this detail belongs to
        SELECT * INTO v_source_profile
        FROM profiles
        WHERE id = NEW.profile_id;

        -- Skip if the profile is itself a synced copy
        IF v_source_profile.source_user_id IS NOT NULL AND v_source_profile.is_local_only = FALSE THEN
            RETURN NEW;
        END IF;

        -- Check if this category is shared
        v_sharing_key := get_sharing_category_key(NEW.category);
        IF v_sharing_key IS NOT NULL AND NOT is_category_shared(NEW.profile_id, v_sharing_key) THEN
            -- Category is not shared, skip propagation
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
-- PART 7: Updated accept_invitation_with_sync() RPC
-- ============================================================================

-- Now respects sharing preferences when copying profile data during initial sync.

CREATE OR REPLACE FUNCTION accept_invitation_with_sync(
    p_invitation_id UUID,
    p_user_id UUID,
    p_acceptor_profile_id UUID DEFAULT NULL
) RETURNS JSON AS $$
DECLARE
    v_invitation RECORD;
    v_inviter_profile RECORD;
    v_acceptor_profile RECORD;
    v_sync_id UUID;
    v_inviter_synced_profile_id UUID;
    v_acceptor_synced_profile_id UUID;
    v_syncable_fields TEXT[];
    v_acceptor_account_id UUID;
    v_detail RECORD;
    v_synced_detail_id UUID;
    v_debug TEXT := '';
    v_sharing_key TEXT;
BEGIN
    PERFORM set_config('row_security', 'off', true);

    v_syncable_fields := ARRAY[
        'full_name', 'preferred_name', 'birthday',
        'address', 'phone', 'email', 'photo_url'
    ];

    -- Get invitation details
    SELECT * INTO v_invitation
    FROM account_invitations
    WHERE id = p_invitation_id AND status = 'pending';

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Invalid or expired invitation';
    END IF;

    -- Mark invitation as accepted
    UPDATE account_invitations
    SET status = 'accepted',
        accepted_at = NOW(),
        accepted_by = p_user_id
    WHERE id = p_invitation_id;

    -- Add user as account member
    INSERT INTO account_members (account_id, user_id, role)
    VALUES (v_invitation.account_id, p_user_id, v_invitation.role)
    ON CONFLICT (account_id, user_id) DO NOTHING;

    -- Get inviter's primary profile
    SELECT * INTO v_inviter_profile
    FROM profiles
    WHERE account_id = v_invitation.account_id
      AND type = 'primary'
      AND linked_user_id = v_invitation.invited_by
    LIMIT 1;

    IF NOT FOUND THEN
        SELECT * INTO v_inviter_profile
        FROM profiles
        WHERE account_id = v_invitation.account_id
          AND type = 'primary'
        LIMIT 1;
    END IF;

    -- Get acceptor's profile and account
    IF p_acceptor_profile_id IS NOT NULL THEN
        SELECT * INTO v_acceptor_profile
        FROM profiles WHERE id = p_acceptor_profile_id;
        IF FOUND THEN
            v_acceptor_account_id := v_acceptor_profile.account_id;
            v_debug := v_debug || 'Acceptor profile found by ID=' || p_acceptor_profile_id::text || '; ';
        ELSE
            v_debug := v_debug || 'Acceptor profile NOT found by ID=' || p_acceptor_profile_id::text || '; ';
        END IF;
    ELSE
        v_debug := v_debug || 'No acceptor_profile_id provided, searching... ';

        SELECT p.*, p.account_id INTO v_acceptor_profile
        FROM profiles p
        JOIN account_members am ON p.account_id = am.account_id
        WHERE am.user_id = p_user_id
          AND p.type = 'primary'
          AND p.linked_user_id = p_user_id
          AND p.account_id != v_invitation.account_id
        LIMIT 1;

        IF FOUND THEN
            v_debug := v_debug || 'Found via linked_user_id match; ';
        ELSE
            SELECT p.*, p.account_id INTO v_acceptor_profile
            FROM profiles p
            JOIN account_members am ON p.account_id = am.account_id
            WHERE am.user_id = p_user_id
              AND am.role = 'owner'
              AND p.type = 'primary'
              AND p.account_id != v_invitation.account_id
            LIMIT 1;

            IF FOUND THEN
                v_debug := v_debug || 'Found via owner role fallback; ';
            END IF;
        END IF;

        IF FOUND THEN
            v_acceptor_account_id := v_acceptor_profile.account_id;
            v_debug := v_debug || 'acceptor_account_id=' || v_acceptor_account_id::text || '; ';
        ELSE
            v_acceptor_account_id := NULL;
            v_debug := v_debug || 'No acceptor profile found, acceptor_account_id=NULL; ';
        END IF;
    END IF;

    -- Only create sync records if inviter has a profile
    IF v_inviter_profile.id IS NOT NULL THEN
        -- Create profile sync record
        INSERT INTO profile_syncs (
            invitation_id,
            inviter_user_id, inviter_account_id, inviter_source_profile_id,
            acceptor_user_id, acceptor_account_id, acceptor_source_profile_id
        ) VALUES (
            p_invitation_id,
            v_invitation.invited_by, v_invitation.account_id, v_inviter_profile.id,
            p_user_id,
            COALESCE(v_acceptor_account_id, v_invitation.account_id),
            v_acceptor_profile.id
        ) RETURNING id INTO v_sync_id;

        -- Create synced profile for acceptor (copy of inviter's profile)
        IF v_acceptor_account_id IS NOT NULL AND v_acceptor_account_id != v_invitation.account_id THEN
            INSERT INTO profiles (
                account_id, type, full_name, preferred_name, birthday,
                address, phone, email, photo_url, relationship,
                source_user_id, synced_fields, sync_connection_id,
                include_in_family_tree, is_deceased, is_favourite
            ) VALUES (
                v_acceptor_account_id, 'relative',
                v_inviter_profile.full_name, v_inviter_profile.preferred_name, v_inviter_profile.birthday,
                CASE WHEN is_category_shared(v_inviter_profile.id, 'profile_fields') THEN v_inviter_profile.address ELSE NULL END,
                CASE WHEN is_category_shared(v_inviter_profile.id, 'profile_fields') THEN v_inviter_profile.phone ELSE NULL END,
                v_inviter_profile.email,
                CASE WHEN is_category_shared(v_inviter_profile.id, 'profile_fields') THEN v_inviter_profile.photo_url ELSE NULL END,
                NULL,
                v_invitation.invited_by, v_syncable_fields, v_sync_id,
                TRUE, COALESCE(v_inviter_profile.is_deceased, FALSE), FALSE
            ) RETURNING id INTO v_acceptor_synced_profile_id;

            -- Copy profile details (respecting sharing preferences)
            FOR v_detail IN
                SELECT * FROM profile_details
                WHERE profile_id = v_inviter_profile.id
            LOOP
                v_sharing_key := get_sharing_category_key(v_detail.category);
                -- Skip if category has sharing control and sharing is disabled
                IF v_sharing_key IS NOT NULL AND NOT is_category_shared(v_inviter_profile.id, v_sharing_key) THEN
                    CONTINUE;
                END IF;

                INSERT INTO profile_details (
                    account_id, profile_id, category, label, value,
                    status, occasion, metadata
                ) VALUES (
                    v_acceptor_account_id, v_acceptor_synced_profile_id, v_detail.category,
                    v_detail.label, v_detail.value, v_detail.status, v_detail.occasion, v_detail.metadata
                ) RETURNING id INTO v_synced_detail_id;

                INSERT INTO profile_detail_syncs (sync_connection_id, source_detail_id, synced_detail_id)
                VALUES (v_sync_id, v_detail.id, v_synced_detail_id);
            END LOOP;

            UPDATE profile_syncs SET acceptor_synced_profile_id = v_acceptor_synced_profile_id
            WHERE id = v_sync_id;
        END IF;

        -- Create synced profile for inviter (copy of acceptor's profile)
        IF v_acceptor_profile.id IS NOT NULL AND v_acceptor_account_id != v_invitation.account_id THEN
            INSERT INTO profiles (
                account_id, type, full_name, preferred_name, birthday,
                address, phone, email, photo_url, relationship,
                source_user_id, synced_fields, sync_connection_id,
                include_in_family_tree, is_deceased, is_favourite
            ) VALUES (
                v_invitation.account_id, 'relative',
                v_acceptor_profile.full_name, v_acceptor_profile.preferred_name, v_acceptor_profile.birthday,
                CASE WHEN is_category_shared(v_acceptor_profile.id, 'profile_fields') THEN v_acceptor_profile.address ELSE NULL END,
                CASE WHEN is_category_shared(v_acceptor_profile.id, 'profile_fields') THEN v_acceptor_profile.phone ELSE NULL END,
                v_acceptor_profile.email,
                CASE WHEN is_category_shared(v_acceptor_profile.id, 'profile_fields') THEN v_acceptor_profile.photo_url ELSE NULL END,
                NULL,
                p_user_id, v_syncable_fields, v_sync_id,
                TRUE, COALESCE(v_acceptor_profile.is_deceased, FALSE), FALSE
            ) RETURNING id INTO v_inviter_synced_profile_id;

            -- Copy profile details (respecting sharing preferences)
            FOR v_detail IN
                SELECT * FROM profile_details
                WHERE profile_id = v_acceptor_profile.id
            LOOP
                v_sharing_key := get_sharing_category_key(v_detail.category);
                IF v_sharing_key IS NOT NULL AND NOT is_category_shared(v_acceptor_profile.id, v_sharing_key) THEN
                    CONTINUE;
                END IF;

                INSERT INTO profile_details (
                    account_id, profile_id, category, label, value,
                    status, occasion, metadata
                ) VALUES (
                    v_invitation.account_id, v_inviter_synced_profile_id, v_detail.category,
                    v_detail.label, v_detail.value, v_detail.status, v_detail.occasion, v_detail.metadata
                ) RETURNING id INTO v_synced_detail_id;

                INSERT INTO profile_detail_syncs (sync_connection_id, source_detail_id, synced_detail_id)
                VALUES (v_sync_id, v_detail.id, v_synced_detail_id);
            END LOOP;

            UPDATE profile_syncs SET inviter_synced_profile_id = v_inviter_synced_profile_id
            WHERE id = v_sync_id;
        END IF;
    END IF;

    v_debug := v_debug || 'inviter_profile_id=' || COALESCE(v_inviter_profile.id::text, 'NULL') || '; ';
    v_debug := v_debug || 'acceptor_profile_id=' || COALESCE(v_acceptor_profile.id::text, 'NULL') || '; ';
    v_debug := v_debug || 'sync_id=' || COALESCE(v_sync_id::text, 'NULL') || '; ';

    RETURN json_build_object(
        'success', true,
        'sync_id', v_sync_id,
        'inviter_synced_profile_id', v_inviter_synced_profile_id,
        'acceptor_synced_profile_id', v_acceptor_synced_profile_id,
        'debug', v_debug
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
