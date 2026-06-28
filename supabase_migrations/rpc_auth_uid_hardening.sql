-- ============================================================================
-- RPC AUTH.UID() HARDENING (Section 6 of original audit)
-- Date: 2026-05-12
--
-- These 5 SECURITY DEFINER functions accept a p_user_id parameter from the
-- client and use it for authorization checks. An attacker could pass another
-- user's UUID and the function would act as that user.
--
-- This migration adds a single guard at the top of each function:
--
--   IF p_user_id IS DISTINCT FROM auth.uid() THEN
--     RAISE EXCEPTION 'p_user_id must match authenticated user';
--   END IF;
--
-- Effect: callers can still pass p_user_id (preserving the existing API), but
-- only when it matches their own JWT identity. The rest of each function is
-- unchanged.
--
-- Rollback: rpc_auth_uid_hardening_rollback.sql
-- ============================================================================


-- ============================================================================
-- 1. accept_invitation
-- ============================================================================

CREATE OR REPLACE FUNCTION public.accept_invitation(p_invitation_id uuid, p_user_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_invitation RECORD;
BEGIN
    -- AUTHORIZATION GUARD: p_user_id must match the authenticated caller
    IF p_user_id IS DISTINCT FROM auth.uid() THEN
        RAISE EXCEPTION 'p_user_id must match authenticated user';
    END IF;

    SELECT * INTO v_invitation
    FROM account_invitations
    WHERE id = p_invitation_id;

    IF v_invitation IS NULL THEN
        RAISE EXCEPTION 'Invitation not found';
    END IF;

    IF v_invitation.status != 'pending' THEN
        RAISE EXCEPTION 'Invitation is not pending';
    END IF;

    IF v_invitation.expires_at < NOW() THEN
        RAISE EXCEPTION 'Invitation has expired';
    END IF;

    IF EXISTS (
        SELECT 1 FROM account_members
        WHERE account_id = v_invitation.account_id
        AND user_id = p_user_id
    ) THEN
        RAISE EXCEPTION 'User is already a member of this account';
    END IF;

    INSERT INTO account_members (account_id, user_id, role)
    VALUES (v_invitation.account_id, p_user_id, v_invitation.role);

    UPDATE account_invitations
    SET
        status = 'accepted',
        accepted_at = NOW(),
        accepted_by = p_user_id
    WHERE id = p_invitation_id;
END;
$function$;


-- ============================================================================
-- 2. revoke_invitation_with_cleanup
-- ============================================================================

CREATE OR REPLACE FUNCTION public.revoke_invitation_with_cleanup(p_invitation_id uuid, p_user_id uuid)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_invitation account_invitations%ROWTYPE;
    v_sync RECORD;
    v_debug TEXT := '';
BEGIN
    -- AUTHORIZATION GUARD: p_user_id must match the authenticated caller
    IF p_user_id IS DISTINCT FROM auth.uid() THEN
        RAISE EXCEPTION 'p_user_id must match authenticated user';
    END IF;

    -- 1. Get the invitation
    SELECT * INTO v_invitation FROM account_invitations WHERE id = p_invitation_id;

    IF v_invitation IS NULL THEN
        RETURN json_build_object('success', false, 'error', 'Invitation not found');
    END IF;

    -- Verify the caller is the one who created the invitation or is an owner/admin of the account
    IF v_invitation.invited_by != p_user_id AND NOT EXISTS (
        SELECT 1 FROM account_members
        WHERE account_id = v_invitation.account_id
          AND user_id = p_user_id
          AND role IN ('owner', 'admin')
    ) THEN
        RETURN json_build_object('success', false, 'error', 'Not authorized to revoke this invitation');
    END IF;

    -- 2. Clean up any profile syncs created from this invitation
    FOR v_sync IN
        SELECT * FROM profile_syncs WHERE invitation_id = p_invitation_id
    LOOP
        v_debug := v_debug || 'Cleaning sync: ' || v_sync.id::TEXT || '. ';

        DELETE FROM profile_detail_syncs WHERE sync_connection_id = v_sync.id;

        IF v_sync.inviter_synced_profile_id IS NOT NULL THEN
            DELETE FROM profile_details WHERE profile_id = v_sync.inviter_synced_profile_id;
        END IF;
        IF v_sync.acceptor_synced_profile_id IS NOT NULL THEN
            DELETE FROM profile_details WHERE profile_id = v_sync.acceptor_synced_profile_id;
        END IF;

        DELETE FROM profile_sharing_preferences
        WHERE profile_id = v_sync.inviter_source_profile_id
          AND user_id = v_sync.inviter_user_id;

        IF v_sync.inviter_synced_profile_id IS NOT NULL THEN
            DELETE FROM profiles WHERE id = v_sync.inviter_synced_profile_id;
            v_debug := v_debug || 'Deleted inviter synced profile. ';
        END IF;
        IF v_sync.acceptor_synced_profile_id IS NOT NULL THEN
            DELETE FROM profiles WHERE id = v_sync.acceptor_synced_profile_id;
            v_debug := v_debug || 'Deleted acceptor synced profile. ';
        END IF;

        DELETE FROM profile_syncs WHERE id = v_sync.id;
    END LOOP;

    -- 3. Remove any account membership created by this invitation's acceptance
    IF v_invitation.accepted_by IS NOT NULL THEN
        DELETE FROM account_members
        WHERE account_id = v_invitation.account_id
          AND user_id = v_invitation.accepted_by;
        v_debug := v_debug || 'Removed member: ' || v_invitation.accepted_by::TEXT || '. ';
    END IF;

    -- 4. Mark the invitation as revoked
    UPDATE account_invitations
    SET status = 'revoked'
    WHERE id = p_invitation_id;

    v_debug := v_debug || 'Invitation revoked. ';

    RETURN json_build_object(
        'success', true,
        'debug', v_debug
    );
END;
$function$;


-- ============================================================================
-- 3. sever_profile_sync
-- ============================================================================

CREATE OR REPLACE FUNCTION public.sever_profile_sync(p_sync_id uuid, p_user_id uuid)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_sync RECORD;
BEGIN
    -- AUTHORIZATION GUARD: p_user_id must match the authenticated caller
    IF p_user_id IS DISTINCT FROM auth.uid() THEN
        RAISE EXCEPTION 'p_user_id must match authenticated user';
    END IF;

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

    UPDATE profile_syncs
    SET status = 'severed',
        severed_at = NOW(),
        severed_by = p_user_id,
        updated_at = NOW()
    WHERE id = p_sync_id;

    UPDATE profiles
    SET is_local_only = true,
        source_user_id = NULL,
        synced_fields = NULL,
        updated_at = NOW()
    WHERE sync_connection_id = p_sync_id;

    RETURN json_build_object('success', true);
END;
$function$;


-- ============================================================================
-- 4. update_member_role
-- ============================================================================

CREATE OR REPLACE FUNCTION public.update_member_role(p_member_id uuid, p_new_role text, p_user_id uuid)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_member RECORD;
    v_caller_role TEXT;
BEGIN
    -- AUTHORIZATION GUARD: p_user_id must match the authenticated caller
    IF p_user_id IS DISTINCT FROM auth.uid() THEN
        RAISE EXCEPTION 'p_user_id must match authenticated user';
    END IF;

    -- 1. Get the member record to update
    SELECT * INTO v_member FROM account_members WHERE id = p_member_id;

    IF v_member IS NULL THEN
        RETURN json_build_object('success', false, 'error', 'Member not found');
    END IF;

    -- 2. Verify the caller is an owner or admin of this account
    SELECT role INTO v_caller_role
    FROM account_members
    WHERE account_id = v_member.account_id
      AND user_id = p_user_id;

    IF v_caller_role IS NULL OR v_caller_role NOT IN ('owner', 'admin') THEN
        RETURN json_build_object('success', false, 'error', 'Not authorized to update roles');
    END IF;

    -- 3. Prevent changing the owner's role
    IF v_member.role = 'owner' THEN
        RETURN json_build_object('success', false, 'error', 'Cannot change the owner role');
    END IF;

    -- 4. Prevent setting someone to owner
    IF p_new_role = 'owner' THEN
        RETURN json_build_object('success', false, 'error', 'Cannot assign owner role');
    END IF;

    -- 5. Update the role
    UPDATE account_members
    SET role = p_new_role, updated_at = NOW()
    WHERE id = p_member_id;

    -- 6. Return the updated member
    RETURN json_build_object(
        'success', true,
        'member_id', v_member.id,
        'account_id', v_member.account_id,
        'user_id', v_member.user_id,
        'role', p_new_role
    );
END;
$function$;


-- ============================================================================
-- 5. accept_invitation_with_sync
-- (The big one. Identical body to current, just adds the guard at the top.)
-- ============================================================================

CREATE OR REPLACE FUNCTION public.accept_invitation_with_sync(p_invitation_id uuid, p_user_id uuid, p_acceptor_profile_id uuid DEFAULT NULL::uuid, p_acceptor_account_id uuid DEFAULT NULL::uuid, p_existing_profile_id uuid DEFAULT NULL::uuid, p_acceptor_sharing_prefs text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_invitation account_invitations%ROWTYPE;
    v_inviter_profile profiles%ROWTYPE;
    v_acceptor_profile profiles%ROWTYPE;
    v_sync_id UUID;
    v_inviter_synced_profile_id UUID;
    v_acceptor_synced_profile_id UUID;
    v_resolved_existing_profile_id UUID;
    v_resolved_acceptor_account_id UUID;
    v_acceptor_prefs JSONB;
    v_debug TEXT := '';
    v_category TEXT;
    v_is_shared BOOLEAN;
    v_acceptor_is_shared BOOLEAN;
    v_sharing_categories TEXT[] := ARRAY['profile_fields', 'medical', 'gift_idea', 'clothing', 'hobby', 'activity_idea', 'important_accounts'];
    v_detail RECORD;
    v_synced_detail_id UUID;
    v_new_profile_created BOOLEAN := FALSE;
BEGIN
    -- AUTHORIZATION GUARD: p_user_id must match the authenticated caller
    IF p_user_id IS DISTINCT FROM auth.uid() THEN
        RAISE EXCEPTION 'p_user_id must match authenticated user';
    END IF;

    -- Parse acceptor sharing prefs from TEXT to JSONB
    IF p_acceptor_sharing_prefs IS NOT NULL AND p_acceptor_sharing_prefs != '' THEN
        BEGIN
            v_acceptor_prefs := p_acceptor_sharing_prefs::JSONB;
        EXCEPTION WHEN OTHERS THEN
            v_acceptor_prefs := NULL;
        END;
    END IF;

    -- 1. VALIDATE INVITATION
    SELECT * INTO v_invitation FROM account_invitations WHERE id = p_invitation_id;

    IF v_invitation IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Invitation not found');
    END IF;

    IF v_invitation.status != 'pending' THEN
        RETURN jsonb_build_object('success', false, 'error', 'Invitation is no longer pending');
    END IF;

    IF v_invitation.expires_at < NOW() THEN
        RETURN jsonb_build_object('success', false, 'error', 'Invitation has expired');
    END IF;

    v_debug := v_debug || 'Invitation validated. ';

    -- 2. RESOLVE ACCEPTOR'S ACCOUNT
    v_resolved_acceptor_account_id := p_acceptor_account_id;

    IF v_resolved_acceptor_account_id IS NULL THEN
        SELECT account_id INTO v_resolved_acceptor_account_id
        FROM account_members
        WHERE user_id = p_user_id AND role = 'owner'
        LIMIT 1;
    END IF;

    IF v_resolved_acceptor_account_id IS NULL THEN
        SELECT account_id INTO v_resolved_acceptor_account_id
        FROM account_members
        WHERE user_id = p_user_id
        LIMIT 1;
    END IF;

    IF v_resolved_acceptor_account_id IS NULL AND p_acceptor_profile_id IS NOT NULL THEN
        SELECT account_id INTO v_resolved_acceptor_account_id
        FROM profiles WHERE id = p_acceptor_profile_id LIMIT 1;
    END IF;

    v_debug := v_debug || 'Acceptor account: ' || COALESCE(v_resolved_acceptor_account_id::TEXT, 'unknown') || '. ';

    -- 3. ACCEPT INVITATION - ADD MEMBERSHIPS
    IF NOT EXISTS (SELECT 1 FROM account_members WHERE account_id = v_invitation.account_id AND user_id = p_user_id) THEN
        INSERT INTO account_members (account_id, user_id, role)
        VALUES (v_invitation.account_id, p_user_id, v_invitation.role);
        v_debug := v_debug || 'Acceptor member added. ';
    ELSE
        v_debug := v_debug || 'Acceptor already member (re-invitation). ';
    END IF;

    IF v_resolved_acceptor_account_id IS NOT NULL THEN
        INSERT INTO account_members (account_id, user_id, role)
        VALUES (v_resolved_acceptor_account_id, v_invitation.invited_by, 'viewer')
        ON CONFLICT (account_id, user_id) DO NOTHING;
        v_debug := v_debug || 'Reciprocal member added. ';
    END IF;

    UPDATE account_invitations
    SET status = 'accepted', accepted_at = NOW(), accepted_by = p_user_id
    WHERE id = p_invitation_id;

    v_debug := v_debug || 'Member added. ';

    -- 4. GET SOURCE PROFILES
    SELECT * INTO v_inviter_profile
    FROM profiles
    WHERE account_id = v_invitation.account_id
      AND type = 'primary'
    LIMIT 1;

    IF v_inviter_profile IS NULL THEN
        RETURN jsonb_build_object(
            'success', true,
            'error', NULL,
            'sync_id', NULL,
            'inviter_synced_profile_id', NULL,
            'acceptor_synced_profile_id', NULL,
            'new_profile_created', false,
            'debug', v_debug || 'No inviter primary profile found. Skipping sync.'
        );
    END IF;

    v_debug := v_debug || 'Inviter profile: ' || v_inviter_profile.id::TEXT || '. ';

    IF p_acceptor_profile_id IS NOT NULL THEN
        SELECT * INTO v_acceptor_profile FROM profiles WHERE id = p_acceptor_profile_id;
        IF v_acceptor_profile.id IS NOT NULL THEN
            v_debug := v_debug || 'Acceptor profile found: ' || v_acceptor_profile.id::TEXT || '. ';
        ELSE
            v_debug := v_debug || 'Acceptor profile ID given but not found! ';
        END IF;
    ELSIF v_resolved_acceptor_account_id IS NOT NULL THEN
        SELECT * INTO v_acceptor_profile
        FROM profiles
        WHERE account_id = v_resolved_acceptor_account_id AND type = 'primary'
        LIMIT 1;
        IF v_acceptor_profile.id IS NOT NULL THEN
            v_debug := v_debug || 'Acceptor profile auto-found: ' || v_acceptor_profile.id::TEXT || '. ';
        ELSE
            v_debug := v_debug || 'No acceptor primary profile in account. ';
        END IF;
    ELSE
        v_debug := v_debug || 'No acceptor account ID available. ';
    END IF;

    -- 5. RESOLVE EXISTING PROFILE TO LINK
    v_resolved_existing_profile_id := p_existing_profile_id;

    IF v_resolved_existing_profile_id IS NULL AND v_invitation.linked_profile_id IS NOT NULL THEN
        SELECT id INTO v_resolved_existing_profile_id
        FROM profiles
        WHERE id = v_invitation.linked_profile_id
          AND account_id = v_invitation.account_id
          AND deleted_at IS NULL
          AND (sync_connection_id IS NULL OR is_local_only = true);

        IF v_resolved_existing_profile_id IS NOT NULL THEN
            v_debug := v_debug || 'Linked via invitation profile link: ' || v_resolved_existing_profile_id::TEXT || '. ';
        END IF;
    END IF;

    IF v_resolved_existing_profile_id IS NULL AND v_invitation.email IS NOT NULL AND v_invitation.email != '' THEN
        SELECT id INTO v_resolved_existing_profile_id
        FROM profiles
        WHERE account_id = v_invitation.account_id
          AND lower(email) = lower(v_invitation.email)
          AND deleted_at IS NULL
          AND (sync_connection_id IS NULL OR is_local_only = true)
        LIMIT 1;

        IF v_resolved_existing_profile_id IS NOT NULL THEN
            v_debug := v_debug || 'Auto-detected existing profile by email: ' || v_resolved_existing_profile_id::TEXT || '. ';
        END IF;
    END IF;

    -- 6. CREATE PROFILE SYNC RECORD
    v_sync_id := gen_random_uuid();

    INSERT INTO profile_syncs (
        id, invitation_id,
        inviter_user_id, inviter_account_id, inviter_source_profile_id,
        acceptor_user_id, acceptor_account_id,
        acceptor_source_profile_id,
        status
    ) VALUES (
        v_sync_id, p_invitation_id,
        v_invitation.invited_by, v_invitation.account_id, v_inviter_profile.id,
        p_user_id, v_resolved_acceptor_account_id,
        CASE WHEN v_acceptor_profile.id IS NOT NULL THEN v_acceptor_profile.id ELSE p_acceptor_profile_id END,
        'active'
    );

    v_debug := v_debug || 'Sync created: ' || v_sync_id::TEXT || '. ';

    -- 7. CREATE/LINK SYNCED PROFILE OF ACCEPTOR IN INVITER'S ACCOUNT
    IF v_resolved_existing_profile_id IS NOT NULL THEN
        UPDATE profiles SET
            source_user_id = p_user_id,
            linked_user_id = p_user_id,
            sync_connection_id = v_sync_id,
            is_local_only = false,
            synced_fields = ARRAY['full_name', 'preferred_name', 'email', 'birthday', 'is_deceased'],
            full_name = COALESCE(v_acceptor_profile.full_name, full_name),
            preferred_name = COALESCE(v_acceptor_profile.preferred_name, preferred_name),
            email = COALESCE(v_acceptor_profile.email, email),
            birthday = COALESCE(v_acceptor_profile.birthday, birthday),
            is_deceased = COALESCE(v_acceptor_profile.is_deceased, is_deceased),
            address = CASE WHEN v_invitation.sharing_profile_fields THEN COALESCE(v_acceptor_profile.address, address) ELSE address END,
            phone = CASE WHEN v_invitation.sharing_profile_fields THEN COALESCE(v_acceptor_profile.phone, phone) ELSE phone END,
            photo_url = CASE WHEN v_invitation.sharing_profile_fields THEN COALESCE(v_acceptor_profile.photo_url, photo_url) ELSE photo_url END,
            updated_at = NOW()
        WHERE id = v_resolved_existing_profile_id;

        v_acceptor_synced_profile_id := v_resolved_existing_profile_id;
        v_debug := v_debug || 'Linked to existing profile: ' || v_resolved_existing_profile_id::TEXT || '. ';
    ELSE
        v_new_profile_created := TRUE;
        v_acceptor_synced_profile_id := gen_random_uuid();

        INSERT INTO profiles (
            id, account_id, type, full_name, preferred_name, birthday, email,
            address, phone, photo_url, is_deceased, is_favourite, sort_order,
            source_user_id, linked_user_id, sync_connection_id, is_local_only,
            synced_fields, include_in_family_tree
        ) VALUES (
            v_acceptor_synced_profile_id,
            v_invitation.account_id,
            'relative',
            COALESCE(v_acceptor_profile.full_name, 'Connected User'),
            v_acceptor_profile.preferred_name,
            v_acceptor_profile.birthday,
            v_acceptor_profile.email,
            CASE WHEN v_invitation.sharing_profile_fields THEN v_acceptor_profile.address ELSE NULL END,
            CASE WHEN v_invitation.sharing_profile_fields THEN v_acceptor_profile.phone ELSE NULL END,
            CASE WHEN v_invitation.sharing_profile_fields THEN v_acceptor_profile.photo_url ELSE NULL END,
            COALESCE(v_acceptor_profile.is_deceased, false),
            false, 0,
            p_user_id, p_user_id, v_sync_id, false,
            ARRAY['full_name', 'preferred_name', 'email', 'birthday', 'is_deceased'],
            true
        );

        v_debug := v_debug || 'Acceptor synced profile created: ' || v_acceptor_synced_profile_id::TEXT || '. ';
    END IF;

    UPDATE profile_syncs
    SET acceptor_synced_profile_id = v_acceptor_synced_profile_id,
        new_profile_created = v_new_profile_created
    WHERE id = v_sync_id;

    -- 8. CREATE SYNCED PROFILE OF INVITER IN ACCEPTOR'S ACCOUNT
    IF v_resolved_acceptor_account_id IS NOT NULL THEN
        SELECT id INTO v_inviter_synced_profile_id
        FROM profiles
        WHERE account_id = v_resolved_acceptor_account_id
          AND linked_user_id = v_invitation.invited_by
          AND deleted_at IS NULL
          AND (sync_connection_id IS NULL OR is_local_only = true)
        LIMIT 1;

        IF v_inviter_synced_profile_id IS NULL AND v_inviter_profile.email IS NOT NULL AND v_inviter_profile.email != '' THEN
            SELECT id INTO v_inviter_synced_profile_id
            FROM profiles
            WHERE account_id = v_resolved_acceptor_account_id
              AND lower(email) = lower(v_inviter_profile.email)
              AND deleted_at IS NULL
              AND (sync_connection_id IS NULL OR is_local_only = true)
            LIMIT 1;
        END IF;

        IF v_inviter_synced_profile_id IS NOT NULL THEN
            UPDATE profiles SET
                source_user_id = v_invitation.invited_by,
                linked_user_id = v_invitation.invited_by,
                sync_connection_id = v_sync_id,
                is_local_only = false,
                synced_fields = ARRAY['full_name', 'preferred_name', 'email', 'birthday', 'is_deceased'],
                full_name = COALESCE(v_inviter_profile.full_name, full_name),
                preferred_name = COALESCE(v_inviter_profile.preferred_name, preferred_name),
                email = COALESCE(v_inviter_profile.email, email),
                birthday = COALESCE(v_inviter_profile.birthday, birthday),
                is_deceased = COALESCE(v_inviter_profile.is_deceased, is_deceased),
                address = CASE WHEN v_invitation.sharing_profile_fields THEN COALESCE(v_inviter_profile.address, address) ELSE address END,
                phone = CASE WHEN v_invitation.sharing_profile_fields THEN COALESCE(v_inviter_profile.phone, phone) ELSE phone END,
                photo_url = CASE WHEN v_invitation.sharing_profile_fields THEN COALESCE(v_inviter_profile.photo_url, photo_url) ELSE photo_url END,
                updated_at = NOW()
            WHERE id = v_inviter_synced_profile_id;

            v_debug := v_debug || 'Re-linked existing inviter profile: ' || v_inviter_synced_profile_id::TEXT || '. ';
        ELSE
            v_inviter_synced_profile_id := gen_random_uuid();

            INSERT INTO profiles (
                id, account_id, type, full_name, preferred_name, birthday, email,
                address, phone, photo_url, is_deceased, is_favourite, sort_order,
                source_user_id, linked_user_id, sync_connection_id, is_local_only,
                synced_fields, include_in_family_tree
            ) VALUES (
                v_inviter_synced_profile_id,
                v_resolved_acceptor_account_id,
                'relative',
                v_inviter_profile.full_name,
                v_inviter_profile.preferred_name,
                v_inviter_profile.birthday,
                v_inviter_profile.email,
                CASE WHEN v_invitation.sharing_profile_fields THEN v_inviter_profile.address ELSE NULL END,
                CASE WHEN v_invitation.sharing_profile_fields THEN v_inviter_profile.phone ELSE NULL END,
                CASE WHEN v_invitation.sharing_profile_fields THEN v_inviter_profile.photo_url ELSE NULL END,
                COALESCE(v_inviter_profile.is_deceased, false),
                false, 0,
                v_invitation.invited_by, v_invitation.invited_by, v_sync_id, false,
                ARRAY['full_name', 'preferred_name', 'email', 'birthday', 'is_deceased'],
                true
            );

            v_debug := v_debug || 'Inviter synced profile created: ' || v_inviter_synced_profile_id::TEXT || '. ';
        END IF;

        UPDATE profile_syncs SET inviter_synced_profile_id = v_inviter_synced_profile_id WHERE id = v_sync_id;
    ELSE
        v_debug := v_debug || 'SKIP inviter profile (no acceptor account). ';
    END IF;

    -- 9. CREATE SHARING PREFERENCES
    BEGIN
        FOREACH v_category IN ARRAY v_sharing_categories LOOP
            v_is_shared := CASE v_category
                WHEN 'profile_fields' THEN COALESCE(v_invitation.sharing_profile_fields, TRUE)
                WHEN 'medical' THEN COALESCE(v_invitation.sharing_medical, TRUE)
                WHEN 'gift_idea' THEN COALESCE(v_invitation.sharing_gift_idea, TRUE)
                WHEN 'clothing' THEN COALESCE(v_invitation.sharing_clothing, TRUE)
                WHEN 'hobby' THEN COALESCE(v_invitation.sharing_hobby, TRUE)
                WHEN 'activity_idea' THEN COALESCE(v_invitation.sharing_activity_idea, TRUE)
                WHEN 'important_accounts' THEN COALESCE(v_invitation.sharing_important_accounts, FALSE)
            END;

            INSERT INTO profile_sharing_preferences (profile_id, user_id, target_user_id, category, is_shared)
            VALUES (v_inviter_profile.id, v_invitation.invited_by, p_user_id, v_category, v_is_shared)
            ON CONFLICT (profile_id, target_user_id, category)
            DO UPDATE SET is_shared = v_is_shared, updated_at = NOW();

            IF v_acceptor_profile.id IS NOT NULL THEN
                IF v_acceptor_prefs IS NOT NULL THEN
                    v_acceptor_is_shared := COALESCE((v_acceptor_prefs ->> v_category)::BOOLEAN,
                        CASE WHEN v_category = 'important_accounts' THEN FALSE ELSE TRUE END);
                ELSE
                    v_acceptor_is_shared := CASE WHEN v_category = 'important_accounts' THEN FALSE ELSE TRUE END;
                END IF;

                INSERT INTO profile_sharing_preferences (profile_id, user_id, target_user_id, category, is_shared)
                VALUES (v_acceptor_profile.id, p_user_id, v_invitation.invited_by, v_category, v_acceptor_is_shared)
                ON CONFLICT (profile_id, target_user_id, category)
                DO UPDATE SET is_shared = v_acceptor_is_shared, updated_at = NOW();
            END IF;
        END LOOP;

        v_debug := v_debug || 'Sharing prefs set. ';
    EXCEPTION WHEN OTHERS THEN
        v_debug := v_debug || 'SHARING PREFS FAILED: ' || SQLERRM || '. ';
    END;

    -- 10. COPY EXISTING PROFILE DETAILS
    ALTER TABLE profile_details DISABLE TRIGGER trigger_propagate_profile_detail_changes;

    BEGIN
        IF v_acceptor_profile.id IS NOT NULL AND v_acceptor_synced_profile_id IS NOT NULL THEN
            FOR v_detail IN
                SELECT * FROM profile_details
                WHERE profile_id = v_acceptor_profile.id
            LOOP
                v_acceptor_is_shared := TRUE;
                CASE v_detail.category
                    WHEN 'medical_condition' THEN
                        IF v_acceptor_prefs IS NOT NULL THEN
                            v_acceptor_is_shared := COALESCE((v_acceptor_prefs ->>'medical')::BOOLEAN, TRUE);
                        END IF;
                    WHEN 'allergy' THEN
                        IF v_acceptor_prefs IS NOT NULL THEN
                            v_acceptor_is_shared := COALESCE((v_acceptor_prefs ->>'medical')::BOOLEAN, TRUE);
                        END IF;
                    WHEN 'gift_idea' THEN
                        IF v_acceptor_prefs IS NOT NULL THEN
                            v_acceptor_is_shared := COALESCE((v_acceptor_prefs ->>'gift_idea')::BOOLEAN, TRUE);
                        END IF;
                    WHEN 'clothing' THEN
                        IF v_acceptor_prefs IS NOT NULL THEN
                            v_acceptor_is_shared := COALESCE((v_acceptor_prefs ->>'clothing')::BOOLEAN, TRUE);
                        END IF;
                    WHEN 'hobby' THEN
                        IF v_acceptor_prefs IS NOT NULL THEN
                            v_acceptor_is_shared := COALESCE((v_acceptor_prefs ->>'hobby')::BOOLEAN, TRUE);
                        END IF;
                    WHEN 'activity_idea' THEN
                        IF v_acceptor_prefs IS NOT NULL THEN
                            v_acceptor_is_shared := COALESCE((v_acceptor_prefs ->>'activity_idea')::BOOLEAN, TRUE);
                        END IF;
                    WHEN 'important_account' THEN
                        IF v_acceptor_prefs IS NOT NULL THEN
                            v_acceptor_is_shared := COALESCE((v_acceptor_prefs ->>'important_accounts')::BOOLEAN, FALSE);
                        ELSE
                            v_acceptor_is_shared := FALSE;
                        END IF;
                    ELSE
                        v_acceptor_is_shared := TRUE;
                END CASE;

                IF v_acceptor_is_shared THEN
                    INSERT INTO profile_details (
                        account_id, profile_id, category, label, value,
                        status, occasion, metadata
                    ) VALUES (
                        v_invitation.account_id, v_acceptor_synced_profile_id, v_detail.category,
                        v_detail.label, v_detail.value, v_detail.status, v_detail.occasion, v_detail.metadata
                    ) RETURNING id INTO v_synced_detail_id;

                    INSERT INTO profile_detail_syncs (sync_connection_id, source_detail_id, synced_detail_id)
                    VALUES (v_sync_id, v_detail.id, v_synced_detail_id);
                END IF;
            END LOOP;

            v_debug := v_debug || 'Acceptor details copied. ';
        END IF;
    EXCEPTION WHEN OTHERS THEN
        v_debug := v_debug || 'ACCEPTOR DETAIL COPY FAILED: ' || SQLERRM || '. ';
    END;

    BEGIN
        IF v_inviter_synced_profile_id IS NOT NULL THEN
            FOR v_detail IN
                SELECT * FROM profile_details
                WHERE profile_id = v_inviter_profile.id
            LOOP
                v_is_shared := TRUE;
                CASE v_detail.category
                    WHEN 'medical_condition' THEN v_is_shared := COALESCE(v_invitation.sharing_medical, TRUE);
                    WHEN 'allergy' THEN v_is_shared := COALESCE(v_invitation.sharing_medical, TRUE);
                    WHEN 'gift_idea' THEN v_is_shared := COALESCE(v_invitation.sharing_gift_idea, TRUE);
                    WHEN 'clothing' THEN v_is_shared := COALESCE(v_invitation.sharing_clothing, TRUE);
                    WHEN 'hobby' THEN v_is_shared := COALESCE(v_invitation.sharing_hobby, TRUE);
                    WHEN 'activity_idea' THEN v_is_shared := COALESCE(v_invitation.sharing_activity_idea, TRUE);
                    WHEN 'important_account' THEN v_is_shared := COALESCE(v_invitation.sharing_important_accounts, FALSE);
                    ELSE v_is_shared := TRUE;
                END CASE;

                IF v_is_shared THEN
                    INSERT INTO profile_details (
                        account_id, profile_id, category, label, value,
                        status, occasion, metadata
                    ) VALUES (
                        v_resolved_acceptor_account_id, v_inviter_synced_profile_id, v_detail.category,
                        v_detail.label, v_detail.value, v_detail.status, v_detail.occasion, v_detail.metadata
                    ) RETURNING id INTO v_synced_detail_id;

                    INSERT INTO profile_detail_syncs (sync_connection_id, source_detail_id, synced_detail_id)
                    VALUES (v_sync_id, v_detail.id, v_synced_detail_id);
                END IF;
            END LOOP;

            v_debug := v_debug || 'Inviter details copied. ';
        END IF;
    EXCEPTION WHEN OTHERS THEN
        v_debug := v_debug || 'INVITER DETAIL COPY FAILED: ' || SQLERRM || '. ';
    END;

    ALTER TABLE profile_details ENABLE TRIGGER trigger_propagate_profile_detail_changes;

    -- 11. RETURN RESULT
    RETURN jsonb_build_object(
        'success', true,
        'error', NULL,
        'sync_id', v_sync_id,
        'inviter_synced_profile_id', v_inviter_synced_profile_id,
        'acceptor_synced_profile_id', v_acceptor_synced_profile_id,
        'new_profile_created', v_new_profile_created,
        'debug', v_debug
    );
END;
$function$;
