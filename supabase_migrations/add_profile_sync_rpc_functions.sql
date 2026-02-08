-- Migration: Add Profile Sync RPC Functions and Triggers
-- This migration adds the server-side logic for profile syncing
-- Run this migration in your Supabase SQL Editor AFTER add_profile_sync_tables.sql

-- ============================================================================
-- PART 1: Accept Invitation With Sync RPC Function
-- ============================================================================

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
BEGIN
    -- Bypass RLS for this function (requires SECURITY DEFINER)
    -- This allows us to read profiles from other users' accounts
    PERFORM set_config('row_security', 'off', true);

    -- Define which fields to sync (viewer-visible fields)
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

    -- Get inviter's primary profile (the person who sent the invitation)
    SELECT * INTO v_inviter_profile
    FROM profiles
    WHERE account_id = v_invitation.account_id
      AND type = 'primary'
      AND linked_user_id = v_invitation.invited_by
    LIMIT 1;

    -- If no profile found with linked_user_id, try just the primary profile
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

        -- Try to find acceptor's primary profile from their own account
        -- First try with linked_user_id match (preferred)
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
            -- Fallback: find any primary profile in an account they own (handles legacy profiles without linked_user_id)
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
            -- Acceptor doesn't have their own account, they're joining this one
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

        -- Create synced profile for acceptor (copy of inviter's profile in acceptor's account)
        -- Only if acceptor has their own separate account
        IF v_acceptor_account_id IS NOT NULL AND v_acceptor_account_id != v_invitation.account_id THEN
            INSERT INTO profiles (
                account_id, type, full_name, preferred_name, birthday,
                address, phone, email, photo_url, relationship,
                source_user_id, synced_fields, sync_connection_id,
                include_in_family_tree, is_deceased, is_favourite
            ) VALUES (
                v_acceptor_account_id, 'relative',
                v_inviter_profile.full_name, v_inviter_profile.preferred_name, v_inviter_profile.birthday,
                v_inviter_profile.address, v_inviter_profile.phone, v_inviter_profile.email, v_inviter_profile.photo_url,
                NULL, -- relationship is local-only
                v_invitation.invited_by, v_syncable_fields, v_sync_id,
                TRUE, COALESCE(v_inviter_profile.is_deceased, FALSE), FALSE
            ) RETURNING id INTO v_acceptor_synced_profile_id;

            -- Copy profile details for the synced profile
            FOR v_detail IN
                SELECT * FROM profile_details
                WHERE profile_id = v_inviter_profile.id
            LOOP
                INSERT INTO profile_details (
                    account_id, profile_id, category, label, value,
                    status, occasion, metadata
                ) VALUES (
                    v_acceptor_account_id, v_acceptor_synced_profile_id, v_detail.category,
                    v_detail.label, v_detail.value, v_detail.status, v_detail.occasion, v_detail.metadata
                ) RETURNING id INTO v_synced_detail_id;

                -- Track the detail sync relationship
                INSERT INTO profile_detail_syncs (sync_connection_id, source_detail_id, synced_detail_id)
                VALUES (v_sync_id, v_detail.id, v_synced_detail_id);
            END LOOP;

            UPDATE profile_syncs SET acceptor_synced_profile_id = v_acceptor_synced_profile_id
            WHERE id = v_sync_id;
        END IF;

        -- Create synced profile for inviter (copy of acceptor's profile in inviter's account)
        IF v_acceptor_profile.id IS NOT NULL AND v_acceptor_account_id != v_invitation.account_id THEN
            INSERT INTO profiles (
                account_id, type, full_name, preferred_name, birthday,
                address, phone, email, photo_url, relationship,
                source_user_id, synced_fields, sync_connection_id,
                include_in_family_tree, is_deceased, is_favourite
            ) VALUES (
                v_invitation.account_id, 'relative',
                v_acceptor_profile.full_name, v_acceptor_profile.preferred_name, v_acceptor_profile.birthday,
                v_acceptor_profile.address, v_acceptor_profile.phone, v_acceptor_profile.email, v_acceptor_profile.photo_url,
                NULL, -- relationship is local-only
                p_user_id, v_syncable_fields, v_sync_id,
                TRUE, COALESCE(v_acceptor_profile.is_deceased, FALSE), FALSE
            ) RETURNING id INTO v_inviter_synced_profile_id;

            -- Copy profile details for the synced profile
            FOR v_detail IN
                SELECT * FROM profile_details
                WHERE profile_id = v_acceptor_profile.id
            LOOP
                INSERT INTO profile_details (
                    account_id, profile_id, category, label, value,
                    status, occasion, metadata
                ) VALUES (
                    v_invitation.account_id, v_inviter_synced_profile_id, v_detail.category,
                    v_detail.label, v_detail.value, v_detail.status, v_detail.occasion, v_detail.metadata
                ) RETURNING id INTO v_synced_detail_id;

                -- Track the detail sync relationship
                INSERT INTO profile_detail_syncs (sync_connection_id, source_detail_id, synced_detail_id)
                VALUES (v_sync_id, v_detail.id, v_synced_detail_id);
            END LOOP;

            UPDATE profile_syncs SET inviter_synced_profile_id = v_inviter_synced_profile_id
            WHERE id = v_sync_id;
        END IF;
    END IF;

    -- Add final debug info
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

-- ============================================================================
-- PART 2: Propagate Profile Changes Trigger
-- ============================================================================

CREATE OR REPLACE FUNCTION propagate_profile_changes() RETURNS TRIGGER AS $$
DECLARE
    v_sync RECORD;
    v_synced_profile_id UUID;
BEGIN
    -- Only propagate if this is a source profile (not a synced copy)
    IF NEW.source_user_id IS NOT NULL THEN
        RETURN NEW; -- This is already a synced profile, don't propagate further
    END IF;

    -- Find all sync relationships where this profile is the source
    FOR v_sync IN
        SELECT * FROM profile_syncs
        WHERE status = 'active'
          AND (inviter_source_profile_id = NEW.id OR acceptor_source_profile_id = NEW.id)
    LOOP
        -- Determine which synced profile to update
        IF v_sync.inviter_source_profile_id = NEW.id THEN
            v_synced_profile_id := v_sync.acceptor_synced_profile_id;
        ELSE
            v_synced_profile_id := v_sync.inviter_synced_profile_id;
        END IF;

        IF v_synced_profile_id IS NOT NULL THEN
            -- Update only the synced fields (not relationship, notes, or other local fields)
            UPDATE profiles SET
                full_name = NEW.full_name,
                preferred_name = NEW.preferred_name,
                birthday = NEW.birthday,
                address = NEW.address,
                phone = NEW.phone,
                email = NEW.email,
                photo_url = NEW.photo_url,
                is_deceased = NEW.is_deceased,
                date_of_death = NEW.date_of_death,
                updated_at = NOW()
            WHERE id = v_synced_profile_id
              AND source_user_id IS NOT NULL; -- Safety check: only update synced profiles
        END IF;
    END LOOP;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_propagate_profile_changes ON profiles;
CREATE TRIGGER trigger_propagate_profile_changes
    AFTER UPDATE ON profiles
    FOR EACH ROW
    EXECUTE FUNCTION propagate_profile_changes();

-- ============================================================================
-- PART 3: Propagate Profile Detail Changes Trigger
-- ============================================================================

CREATE OR REPLACE FUNCTION propagate_profile_detail_changes() RETURNS TRIGGER AS $$
DECLARE
    v_source_profile RECORD;
    v_detail_sync RECORD;
    v_new_detail_id UUID;
BEGIN
    -- Handle INSERT: Create synced copies of new details
    IF TG_OP = 'INSERT' THEN
        -- Check if this detail belongs to a source profile (not a synced copy)
        SELECT p.* INTO v_source_profile
        FROM profiles p
        WHERE p.id = NEW.profile_id
          AND p.source_user_id IS NULL; -- Only source profiles

        IF FOUND THEN
            -- Find all profile_syncs where this profile is the source
            FOR v_detail_sync IN
                SELECT ps.*, pds.synced_detail_id
                FROM profile_syncs ps
                LEFT JOIN profile_detail_syncs pds ON pds.sync_connection_id = ps.id AND pds.source_detail_id = NEW.id
                WHERE ps.status = 'active'
                  AND (ps.inviter_source_profile_id = NEW.profile_id OR ps.acceptor_source_profile_id = NEW.profile_id)
                  AND pds.id IS NULL -- No existing sync for this detail
            LOOP
                -- Determine the target synced profile
                DECLARE
                    v_target_profile_id UUID;
                    v_target_account_id UUID;
                BEGIN
                    IF v_detail_sync.inviter_source_profile_id = NEW.profile_id THEN
                        v_target_profile_id := v_detail_sync.acceptor_synced_profile_id;
                        v_target_account_id := v_detail_sync.acceptor_account_id;
                    ELSE
                        v_target_profile_id := v_detail_sync.inviter_synced_profile_id;
                        v_target_account_id := v_detail_sync.inviter_account_id;
                    END IF;

                    IF v_target_profile_id IS NOT NULL THEN
                        -- Create the synced detail
                        INSERT INTO profile_details (
                            account_id, profile_id, category, label, value,
                            status, occasion, metadata
                        ) VALUES (
                            v_target_account_id, v_target_profile_id, NEW.category,
                            NEW.label, NEW.value, NEW.status, NEW.occasion, NEW.metadata
                        ) RETURNING id INTO v_new_detail_id;

                        -- Track the sync relationship
                        INSERT INTO profile_detail_syncs (sync_connection_id, source_detail_id, synced_detail_id)
                        VALUES (v_detail_sync.id, NEW.id, v_new_detail_id);
                    END IF;
                END;
            END LOOP;
        END IF;

        RETURN NEW;

    -- Handle UPDATE: Update synced copies
    ELSIF TG_OP = 'UPDATE' THEN
        -- Find and update all synced copies of this detail
        FOR v_detail_sync IN
            SELECT pds.synced_detail_id
            FROM profile_detail_syncs pds
            JOIN profile_syncs ps ON ps.id = pds.sync_connection_id
            WHERE pds.source_detail_id = NEW.id
              AND ps.status = 'active'
        LOOP
            UPDATE profile_details SET
                label = NEW.label,
                value = NEW.value,
                status = NEW.status,
                occasion = NEW.occasion,
                metadata = NEW.metadata,
                updated_at = NOW()
            WHERE id = v_detail_sync.synced_detail_id;
        END LOOP;

        RETURN NEW;

    -- Handle DELETE: Delete synced copies
    ELSIF TG_OP = 'DELETE' THEN
        -- Delete all synced copies of this detail
        DELETE FROM profile_details
        WHERE id IN (
            SELECT pds.synced_detail_id
            FROM profile_detail_syncs pds
            JOIN profile_syncs ps ON ps.id = pds.sync_connection_id
            WHERE pds.source_detail_id = OLD.id
              AND ps.status = 'active'
        );

        -- Clean up the sync tracking records
        DELETE FROM profile_detail_syncs WHERE source_detail_id = OLD.id;

        RETURN OLD;
    END IF;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_propagate_profile_detail_changes ON profile_details;
CREATE TRIGGER trigger_propagate_profile_detail_changes
    AFTER INSERT OR UPDATE OR DELETE ON profile_details
    FOR EACH ROW
    EXECUTE FUNCTION propagate_profile_detail_changes();

-- ============================================================================
-- PART 4: Sever Profile Sync RPC Function
-- ============================================================================

CREATE OR REPLACE FUNCTION sever_profile_sync(
    p_sync_id UUID,
    p_user_id UUID
) RETURNS JSON AS $$
DECLARE
    v_sync RECORD;
BEGIN
    -- Get the sync record and verify authorization
    SELECT * INTO v_sync
    FROM profile_syncs
    WHERE id = p_sync_id
      AND (inviter_user_id = p_user_id OR acceptor_user_id = p_user_id);

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Sync not found or not authorized';
    END IF;

    IF v_sync.status = 'severed' THEN
        RETURN json_build_object('success', true, 'message', 'Sync already severed');
    END IF;

    -- Mark sync as severed
    UPDATE profile_syncs
    SET status = 'severed',
        severed_at = NOW(),
        severed_by = p_user_id,
        updated_at = NOW()
    WHERE id = p_sync_id;

    -- Update synced profiles to be local-only (preserves data but stops syncing)
    UPDATE profiles
    SET is_local_only = true,
        source_user_id = NULL,
        synced_fields = NULL,
        updated_at = NOW()
    WHERE sync_connection_id = p_sync_id;

    RETURN json_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- PART 5: Helper function to check if a detail is synced
-- ============================================================================

CREATE OR REPLACE FUNCTION is_detail_synced(p_detail_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM profile_detail_syncs pds
        JOIN profile_syncs ps ON ps.id = pds.sync_connection_id
        WHERE pds.synced_detail_id = p_detail_id
          AND ps.status = 'active'
    );
END;
$$ LANGUAGE plpgsql STABLE;
