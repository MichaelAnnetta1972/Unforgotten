-- Migration: Backfill Missing Synced Details
--
-- After cleaning up stale sync connections, the kept (most recent) sync
-- may be missing copies of older profile details that were only present
-- on the now-deleted stale syncs. This script copies any source details
-- that don't yet have a profile_detail_syncs mapping for the active sync.

-- ============================================================================
-- STEP 1: Diagnostic — show what's missing
-- ============================================================================

-- Show source details that have no synced copy for their active sync connection
SELECT
    ps.id as sync_id,
    CASE
        WHEN pd.profile_id = ps.inviter_source_profile_id THEN 'inviter→acceptor'
        ELSE 'acceptor→inviter'
    END as direction,
    src_p.full_name as source_name,
    pd.category,
    pd.label,
    pd.value
FROM profile_syncs ps
-- Join inviter's source details
JOIN profile_details pd ON (
    pd.profile_id = ps.inviter_source_profile_id
    OR pd.profile_id = ps.acceptor_source_profile_id
)
JOIN profiles src_p ON src_p.id = pd.profile_id
WHERE ps.status = 'active'
  AND pd.id NOT IN (
      SELECT source_detail_id FROM profile_detail_syncs
      WHERE sync_connection_id = ps.id
  )
ORDER BY src_p.full_name, pd.category, pd.label;

-- ============================================================================
-- STEP 2: Copy missing inviter source details to inviter's synced profile
-- (inviter's data → copy in acceptor's account)
-- ============================================================================

-- Disable trigger to prevent cascading during bulk copy
ALTER TABLE profile_details DISABLE TRIGGER trigger_propagate_profile_detail_changes;

DO $$
DECLARE
    v_sync RECORD;
    v_detail RECORD;
    v_new_id UUID;
    v_sharing_key TEXT;
    v_is_shared BOOLEAN;
    v_target_user_id UUID;
    v_count INT := 0;
BEGIN
    FOR v_sync IN
        SELECT * FROM profile_syncs WHERE status = 'active'
    LOOP
        -- Copy inviter's source details → inviter_synced_profile_id (in acceptor's account)
        IF v_sync.inviter_synced_profile_id IS NOT NULL AND v_sync.inviter_source_profile_id IS NOT NULL THEN
            v_target_user_id := v_sync.acceptor_user_id;

            FOR v_detail IN
                SELECT * FROM profile_details
                WHERE profile_id = v_sync.inviter_source_profile_id
                  AND id NOT IN (
                      SELECT source_detail_id FROM profile_detail_syncs
                      WHERE sync_connection_id = v_sync.id
                  )
            LOOP
                -- Check sharing preferences
                v_sharing_key := get_sharing_category_key(v_detail.category);
                IF v_sharing_key IS NOT NULL THEN
                    v_is_shared := is_category_shared(v_sync.inviter_source_profile_id, v_sharing_key, v_target_user_id);
                    IF NOT v_is_shared THEN
                        CONTINUE;
                    END IF;
                END IF;

                INSERT INTO profile_details (
                    account_id, profile_id, category, label, value,
                    status, occasion, metadata
                )
                SELECT p.account_id, v_sync.inviter_synced_profile_id,
                       v_detail.category, v_detail.label, v_detail.value,
                       v_detail.status, v_detail.occasion, v_detail.metadata
                FROM profiles p WHERE p.id = v_sync.inviter_synced_profile_id
                RETURNING id INTO v_new_id;

                IF v_new_id IS NOT NULL THEN
                    INSERT INTO profile_detail_syncs (sync_connection_id, source_detail_id, synced_detail_id)
                    VALUES (v_sync.id, v_detail.id, v_new_id);
                    v_count := v_count + 1;
                END IF;
            END LOOP;
        END IF;

        -- Copy acceptor's source details → acceptor_synced_profile_id (in inviter's account)
        IF v_sync.acceptor_synced_profile_id IS NOT NULL AND v_sync.acceptor_source_profile_id IS NOT NULL THEN
            v_target_user_id := v_sync.inviter_user_id;

            FOR v_detail IN
                SELECT * FROM profile_details
                WHERE profile_id = v_sync.acceptor_source_profile_id
                  AND id NOT IN (
                      SELECT source_detail_id FROM profile_detail_syncs
                      WHERE sync_connection_id = v_sync.id
                  )
            LOOP
                -- Check sharing preferences
                v_sharing_key := get_sharing_category_key(v_detail.category);
                IF v_sharing_key IS NOT NULL THEN
                    v_is_shared := is_category_shared(v_sync.acceptor_source_profile_id, v_sharing_key, v_target_user_id);
                    IF NOT v_is_shared THEN
                        CONTINUE;
                    END IF;
                END IF;

                INSERT INTO profile_details (
                    account_id, profile_id, category, label, value,
                    status, occasion, metadata
                )
                SELECT p.account_id, v_sync.acceptor_synced_profile_id,
                       v_detail.category, v_detail.label, v_detail.value,
                       v_detail.status, v_detail.occasion, v_detail.metadata
                FROM profiles p WHERE p.id = v_sync.acceptor_synced_profile_id
                RETURNING id INTO v_new_id;

                IF v_new_id IS NOT NULL THEN
                    INSERT INTO profile_detail_syncs (sync_connection_id, source_detail_id, synced_detail_id)
                    VALUES (v_sync.id, v_detail.id, v_new_id);
                    v_count := v_count + 1;
                END IF;
            END LOOP;
        END IF;
    END LOOP;

    RAISE NOTICE 'Backfilled % missing synced details', v_count;
END $$;

-- Re-enable trigger
ALTER TABLE profile_details ENABLE TRIGGER trigger_propagate_profile_detail_changes;

-- ============================================================================
-- STEP 3: Verify — should return no rows (all source details now have synced copies)
-- ============================================================================

SELECT
    ps.id as sync_id,
    CASE
        WHEN pd.profile_id = ps.inviter_source_profile_id THEN 'inviter→acceptor'
        ELSE 'acceptor→inviter'
    END as direction,
    src_p.full_name as source_name,
    pd.category,
    pd.label
FROM profile_syncs ps
JOIN profile_details pd ON (
    pd.profile_id = ps.inviter_source_profile_id
    OR pd.profile_id = ps.acceptor_source_profile_id
)
JOIN profiles src_p ON src_p.id = pd.profile_id
WHERE ps.status = 'active'
  AND pd.id NOT IN (
      SELECT source_detail_id FROM profile_detail_syncs
      WHERE sync_connection_id = ps.id
  )
ORDER BY src_p.full_name, pd.category;
