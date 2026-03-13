-- Migration: Clean Up Stale Duplicate Sync Connections (v2)
--
-- Fixed ordering: delete profile_syncs BEFORE deleting profiles to avoid FK violations.

-- ============================================================================
-- STEP 1: Preview — show which syncs will be kept vs deleted
-- ============================================================================

WITH ranked_syncs AS (
    SELECT
        ps.*,
        inv.full_name as inviter_name,
        acc.full_name as acceptor_name,
        ROW_NUMBER() OVER (
            PARTITION BY
                LEAST(ps.inviter_user_id, ps.acceptor_user_id),
                GREATEST(ps.inviter_user_id, ps.acceptor_user_id)
            ORDER BY ps.created_at DESC
        ) as rn
    FROM profile_syncs ps
    LEFT JOIN profiles inv ON inv.id = ps.inviter_source_profile_id
    LEFT JOIN profiles acc ON acc.id = ps.acceptor_source_profile_id
    WHERE ps.status = 'active'
)
SELECT
    id,
    inviter_name,
    acceptor_name,
    created_at,
    CASE WHEN rn = 1 THEN 'KEEP' ELSE 'DELETE' END as action
FROM ranked_syncs
ORDER BY inviter_name, acceptor_name, created_at;

-- ============================================================================
-- STEP 2: Collect stale synced profile IDs before deleting the sync records
-- Store them in a temp table so we can delete the profiles after
-- ============================================================================

CREATE TEMP TABLE stale_synced_profiles AS
SELECT inviter_synced_profile_id as profile_id FROM profile_syncs
WHERE status = 'active'
  AND inviter_synced_profile_id IS NOT NULL
  AND id NOT IN (
      SELECT (array_agg(ps2.id ORDER BY ps2.created_at DESC))[1]
      FROM profile_syncs ps2
      WHERE ps2.status = 'active'
      GROUP BY LEAST(ps2.inviter_user_id, ps2.acceptor_user_id),
               GREATEST(ps2.inviter_user_id, ps2.acceptor_user_id)
  )
UNION
SELECT acceptor_synced_profile_id FROM profile_syncs
WHERE status = 'active'
  AND acceptor_synced_profile_id IS NOT NULL
  AND id NOT IN (
      SELECT (array_agg(ps2.id ORDER BY ps2.created_at DESC))[1]
      FROM profile_syncs ps2
      WHERE ps2.status = 'active'
      GROUP BY LEAST(ps2.inviter_user_id, ps2.acceptor_user_id),
               GREATEST(ps2.inviter_user_id, ps2.acceptor_user_id)
  );

-- ============================================================================
-- STEP 3: Delete profile_details on the stale synced profiles
-- ============================================================================

DELETE FROM profile_details
WHERE profile_id IN (SELECT profile_id FROM stale_synced_profiles);

-- ============================================================================
-- STEP 4: Delete profile_detail_syncs for stale sync connections
-- ============================================================================

DELETE FROM profile_detail_syncs
WHERE sync_connection_id IN (
    SELECT id FROM profile_syncs
    WHERE status = 'active'
      AND id NOT IN (
          SELECT (array_agg(ps2.id ORDER BY ps2.created_at DESC))[1]
          FROM profile_syncs ps2
          WHERE ps2.status = 'active'
          GROUP BY LEAST(ps2.inviter_user_id, ps2.acceptor_user_id),
                   GREATEST(ps2.inviter_user_id, ps2.acceptor_user_id)
      )
);

-- ============================================================================
-- STEP 5: Delete the stale profile_syncs records (BEFORE deleting profiles)
-- ============================================================================

DELETE FROM profile_syncs
WHERE status = 'active'
  AND id NOT IN (
      SELECT (array_agg(ps2.id ORDER BY ps2.created_at DESC))[1]
      FROM profile_syncs ps2
      WHERE ps2.status = 'active'
      GROUP BY LEAST(ps2.inviter_user_id, ps2.acceptor_user_id),
               GREATEST(ps2.inviter_user_id, ps2.acceptor_user_id)
  );

-- ============================================================================
-- STEP 6: Now safe to delete the stale synced profiles
-- ============================================================================

DELETE FROM profiles
WHERE id IN (SELECT profile_id FROM stale_synced_profiles);

-- Clean up temp table
DROP TABLE stale_synced_profiles;

-- ============================================================================
-- STEP 7: Clean up orphaned profile_detail_syncs
-- ============================================================================

DELETE FROM profile_detail_syncs
WHERE synced_detail_id NOT IN (SELECT id FROM profile_details);

DELETE FROM profile_detail_syncs
WHERE sync_connection_id NOT IN (SELECT id FROM profile_syncs);

-- ============================================================================
-- STEP 8: Verify — should show exactly one sync per user pair
-- ============================================================================

SELECT
    ps.id,
    ps.status,
    ps.created_at,
    inv.full_name as inviter_name,
    acc.full_name as acceptor_name,
    (SELECT COUNT(*) FROM profile_details WHERE profile_id = ps.inviter_synced_profile_id) as inviter_synced_details,
    (SELECT COUNT(*) FROM profile_details WHERE profile_id = ps.acceptor_synced_profile_id) as acceptor_synced_details
FROM profile_syncs ps
LEFT JOIN profiles inv ON inv.id = ps.inviter_source_profile_id
LEFT JOIN profiles acc ON acc.id = ps.acceptor_source_profile_id
WHERE ps.status = 'active'
ORDER BY ps.created_at;
