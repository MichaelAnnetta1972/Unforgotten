-- Migration: Per-User Sharing Preferences
-- Changes sharing preferences from per-profile to per-profile-per-target-user.
-- This allows controlling what each connected user can see independently.

-- ============================================================================
-- PART 1: Alter Table - Add target_user_id and update unique constraint
-- ============================================================================

-- Add target_user_id column (the connected user whose access is being controlled)
ALTER TABLE profile_sharing_preferences
ADD COLUMN IF NOT EXISTS target_user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE;

-- Backfill: For existing rows, set target_user_id from the profile_syncs table.
-- If a profile has only one sync connection, copy the other user's ID.
-- For multiple connections, duplicate the row for each connection.
DO $$
DECLARE
    v_pref RECORD;
    v_sync RECORD;
    v_target UUID;
    v_found BOOLEAN := FALSE;
BEGIN
    FOR v_pref IN
        SELECT * FROM profile_sharing_preferences WHERE target_user_id IS NULL
    LOOP
        v_found := FALSE;

        -- Check if this profile_id is an inviter source
        FOR v_sync IN
            SELECT * FROM profile_syncs
            WHERE inviter_source_profile_id = v_pref.profile_id AND status = 'active'
        LOOP
            IF NOT v_found THEN
                -- Update the original row with the first target
                UPDATE profile_sharing_preferences
                SET target_user_id = v_sync.acceptor_user_id
                WHERE id = v_pref.id;
                v_found := TRUE;
            ELSE
                -- Insert additional rows for other connections
                INSERT INTO profile_sharing_preferences (profile_id, user_id, target_user_id, category, is_shared)
                VALUES (v_pref.profile_id, v_pref.user_id, v_sync.acceptor_user_id, v_pref.category, v_pref.is_shared)
                ON CONFLICT DO NOTHING;
            END IF;
        END LOOP;

        -- Check if this profile_id is an acceptor source
        FOR v_sync IN
            SELECT * FROM profile_syncs
            WHERE acceptor_source_profile_id = v_pref.profile_id AND status = 'active'
        LOOP
            IF NOT v_found THEN
                UPDATE profile_sharing_preferences
                SET target_user_id = v_sync.inviter_user_id
                WHERE id = v_pref.id;
                v_found := TRUE;
            ELSE
                INSERT INTO profile_sharing_preferences (profile_id, user_id, target_user_id, category, is_shared)
                VALUES (v_pref.profile_id, v_pref.user_id, v_sync.inviter_user_id, v_pref.category, v_pref.is_shared)
                ON CONFLICT DO NOTHING;
            END IF;
        END LOOP;

        -- If no sync found, delete the orphaned preference
        IF NOT v_found THEN
            DELETE FROM profile_sharing_preferences WHERE id = v_pref.id;
        END IF;
    END LOOP;
END $$;

-- Drop old unique constraint and create new one
ALTER TABLE profile_sharing_preferences DROP CONSTRAINT IF EXISTS profile_sharing_preferences_profile_id_category_key;
ALTER TABLE profile_sharing_preferences ADD CONSTRAINT profile_sharing_preferences_profile_target_category_key
    UNIQUE(profile_id, target_user_id, category);

-- Add index for target_user_id lookups
CREATE INDEX IF NOT EXISTS idx_sharing_prefs_target_user ON profile_sharing_preferences(target_user_id);
CREATE INDEX IF NOT EXISTS idx_sharing_prefs_profile_target ON profile_sharing_preferences(profile_id, target_user_id);

-- ============================================================================
-- PART 2: Update is_category_shared() to accept target_user_id
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
        -- Check per-user preference
        SELECT is_shared INTO v_is_shared
        FROM profile_sharing_preferences
        WHERE profile_id = p_profile_id
          AND target_user_id = p_target_user_id
          AND category = p_category;
    ELSE
        -- Fallback: check any preference for this profile+category (legacy compat)
        SELECT is_shared INTO v_is_shared
        FROM profile_sharing_preferences
        WHERE profile_id = p_profile_id
          AND category = p_category
        LIMIT 1;
    END IF;

    -- If no row exists, default is shared (TRUE)
    IF NOT FOUND THEN
        RETURN TRUE;
    END IF;

    RETURN v_is_shared;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- ============================================================================
-- PART 3: Update update_sharing_preference() RPC
-- ============================================================================

CREATE OR REPLACE FUNCTION update_sharing_preference(
    p_profile_id UUID,
    p_category TEXT,
    p_is_shared BOOLEAN,
    p_target_user_id UUID DEFAULT NULL
) RETURNS JSON AS $$
DECLARE
    v_profile RECORD;
    v_sync RECORD;
    v_detail RECORD;
    v_target_profile_id UUID;
    v_target_account_id UUID;
    v_new_detail_id UUID;
    v_detail_categories TEXT[];
    v_actual_target_user_id UUID;
BEGIN
    PERFORM set_config('row_security', 'off', true);

    -- Get the profile
    SELECT * INTO v_profile FROM profiles WHERE id = p_profile_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Profile not found';
    END IF;

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

    IF p_target_user_id IS NOT NULL THEN
        -- ===== PER-USER MODE =====
        v_actual_target_user_id := p_target_user_id;

        -- Upsert the sharing preference for this specific target user
        INSERT INTO profile_sharing_preferences (profile_id, user_id, target_user_id, category, is_shared)
        VALUES (p_profile_id, COALESCE(v_profile.linked_user_id, auth.uid()), v_actual_target_user_id, p_category, p_is_shared)
        ON CONFLICT (profile_id, target_user_id, category)
        DO UPDATE SET is_shared = p_is_shared, updated_at = NOW();

        -- Find the specific sync connection for this target user
        FOR v_sync IN
            SELECT * FROM profile_syncs
            WHERE status = 'active'
              AND (
                  (inviter_source_profile_id = p_profile_id AND acceptor_user_id = v_actual_target_user_id)
                  OR
                  (acceptor_source_profile_id = p_profile_id AND inviter_user_id = v_actual_target_user_id)
              )
        LOOP
            -- Determine the target synced profile
            IF v_sync.inviter_source_profile_id = p_profile_id THEN
                v_target_profile_id := v_sync.acceptor_synced_profile_id;
                v_target_account_id := v_sync.acceptor_account_id;
            ELSE
                v_target_profile_id := v_sync.inviter_synced_profile_id;
                v_target_account_id := v_sync.inviter_account_id;
            END IF;

            IF NOT p_is_shared THEN
                -- Delete synced detail copies for this category on this specific connection
                IF array_length(v_detail_categories, 1) > 0 AND v_target_profile_id IS NOT NULL THEN
                    DELETE FROM profile_details
                    WHERE id IN (
                        SELECT pds.synced_detail_id
                        FROM profile_detail_syncs pds
                        JOIN profile_details pd ON pd.id = pds.source_detail_id
                        WHERE pds.sync_connection_id = v_sync.id
                          AND pd.profile_id = p_profile_id
                          AND pd.category = ANY(v_detail_categories)
                    );

                    DELETE FROM profile_detail_syncs
                    WHERE sync_connection_id = v_sync.id
                      AND source_detail_id IN (
                          SELECT id FROM profile_details
                          WHERE profile_id = p_profile_id
                            AND category = ANY(v_detail_categories)
                      );
                END IF;

                -- Handle profile_fields
                IF p_category = 'profile_fields' AND v_target_profile_id IS NOT NULL THEN
                    UPDATE profiles SET
                        address = NULL, phone = NULL, photo_url = NULL, updated_at = NOW()
                    WHERE id = v_target_profile_id
                      AND source_user_id IS NOT NULL;
                END IF;
            ELSE
                -- Re-sync details for this specific connection
                IF v_target_profile_id IS NOT NULL THEN
                    IF p_category = 'profile_fields' THEN
                        UPDATE profiles SET
                            address = v_profile.address, phone = v_profile.phone,
                            photo_url = v_profile.photo_url, updated_at = NOW()
                        WHERE id = v_target_profile_id
                          AND source_user_id IS NOT NULL;
                    END IF;

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
            END IF;
        END LOOP;
    ELSE
        -- ===== LEGACY MODE (no target user specified) =====
        -- Apply to ALL connections (backward compatible)

        -- Upsert for each active connection
        FOR v_sync IN
            SELECT * FROM profile_syncs
            WHERE status = 'active'
              AND (inviter_source_profile_id = p_profile_id OR acceptor_source_profile_id = p_profile_id)
        LOOP
            IF v_sync.inviter_source_profile_id = p_profile_id THEN
                v_actual_target_user_id := v_sync.acceptor_user_id;
                v_target_profile_id := v_sync.acceptor_synced_profile_id;
                v_target_account_id := v_sync.acceptor_account_id;
            ELSE
                v_actual_target_user_id := v_sync.inviter_user_id;
                v_target_profile_id := v_sync.inviter_synced_profile_id;
                v_target_account_id := v_sync.inviter_account_id;
            END IF;

            INSERT INTO profile_sharing_preferences (profile_id, user_id, target_user_id, category, is_shared)
            VALUES (p_profile_id, COALESCE(v_profile.linked_user_id, auth.uid()), v_actual_target_user_id, p_category, p_is_shared)
            ON CONFLICT (profile_id, target_user_id, category)
            DO UPDATE SET is_shared = p_is_shared, updated_at = NOW();

            IF NOT p_is_shared THEN
                IF array_length(v_detail_categories, 1) > 0 AND v_target_profile_id IS NOT NULL THEN
                    DELETE FROM profile_details
                    WHERE id IN (
                        SELECT pds.synced_detail_id
                        FROM profile_detail_syncs pds
                        JOIN profile_details pd ON pd.id = pds.source_detail_id
                        WHERE pds.sync_connection_id = v_sync.id
                          AND pd.profile_id = p_profile_id
                          AND pd.category = ANY(v_detail_categories)
                    );
                    DELETE FROM profile_detail_syncs
                    WHERE sync_connection_id = v_sync.id
                      AND source_detail_id IN (
                          SELECT id FROM profile_details
                          WHERE profile_id = p_profile_id
                            AND category = ANY(v_detail_categories)
                      );
                END IF;

                IF p_category = 'profile_fields' AND v_target_profile_id IS NOT NULL THEN
                    UPDATE profiles SET
                        address = NULL, phone = NULL, photo_url = NULL, updated_at = NOW()
                    WHERE id = v_target_profile_id AND source_user_id IS NOT NULL;
                END IF;
            ELSE
                IF v_target_profile_id IS NOT NULL THEN
                    IF p_category = 'profile_fields' THEN
                        UPDATE profiles SET
                            address = v_profile.address, phone = v_profile.phone,
                            photo_url = v_profile.photo_url, updated_at = NOW()
                        WHERE id = v_target_profile_id AND source_user_id IS NOT NULL;
                    END IF;

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
            END IF;
        END LOOP;
    END IF;

    RETURN json_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- PART 4: Update propagation triggers to check per-user preferences
-- ============================================================================

-- Profile changes trigger: now checks per-user sharing for each connection
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
    FOR v_sync_record IN
        SELECT ps.*
        FROM profile_syncs ps
        WHERE ps.inviter_source_profile_id = NEW.id
          AND ps.status = 'active'
          AND ps.acceptor_synced_profile_id IS NOT NULL
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

-- Detail changes trigger: now checks per-user sharing for each connection
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
        FOR v_sync_record IN
            SELECT ps.*
            FROM profile_syncs ps
            WHERE ps.inviter_source_profile_id = NEW.profile_id
              AND ps.status = 'active'
              AND ps.acceptor_synced_profile_id IS NOT NULL
        LOOP
            v_target_user_id := v_sync_record.acceptor_user_id;

            -- Check per-user sharing preference
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

        -- Case 2: Profile is acceptor's source profile
        FOR v_sync_record IN
            SELECT ps.*
            FROM profile_syncs ps
            WHERE ps.acceptor_source_profile_id = NEW.profile_id
              AND ps.status = 'active'
              AND ps.inviter_synced_profile_id IS NOT NULL
        LOOP
            v_target_user_id := v_sync_record.inviter_user_id;

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
-- PART 5: Update RLS policies to include target_user_id access
-- ============================================================================

-- Drop and recreate policies to also allow profile owners to manage preferences
DROP POLICY IF EXISTS "Users can read own sharing preferences" ON profile_sharing_preferences;
DROP POLICY IF EXISTS "Users can insert own sharing preferences" ON profile_sharing_preferences;
DROP POLICY IF EXISTS "Users can update own sharing preferences" ON profile_sharing_preferences;
DROP POLICY IF EXISTS "Users can delete own sharing preferences" ON profile_sharing_preferences;

CREATE POLICY "Users can read sharing preferences"
    ON profile_sharing_preferences FOR SELECT
    USING (auth.uid() = user_id OR auth.uid() = target_user_id);

CREATE POLICY "Users can insert sharing preferences"
    ON profile_sharing_preferences FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update sharing preferences"
    ON profile_sharing_preferences FOR UPDATE
    USING (auth.uid() = user_id);

CREATE POLICY "Users can delete sharing preferences"
    ON profile_sharing_preferences FOR DELETE
    USING (auth.uid() = user_id);
