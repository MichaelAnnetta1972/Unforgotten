-- Diagnostic: Check delete propagation trigger
-- Run this to verify the trigger function exists and has SECURITY DEFINER

-- 1. Check if the function exists and its security setting
SELECT
    p.proname as function_name,
    CASE p.prosecdef WHEN true THEN 'SECURITY DEFINER' ELSE 'SECURITY INVOKER' END as security,
    pg_get_functiondef(p.oid) as definition
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE p.proname = 'propagate_profile_detail_changes'
  AND n.nspname = 'public';

-- 2. Check trigger exists and is enabled
SELECT
    t.tgname as trigger_name,
    CASE t.tgenabled
        WHEN 'O' THEN 'ENABLED (origin)'
        WHEN 'D' THEN 'DISABLED'
        WHEN 'R' THEN 'ENABLED (replica)'
        WHEN 'A' THEN 'ENABLED (always)'
    END as status,
    c.relname as table_name
FROM pg_trigger t
JOIN pg_class c ON t.tgrelid = c.oid
WHERE t.tgname = 'trigger_propagate_profile_detail_changes';

-- 3. Check for any orphaned synced details (items in profile_details that should have been deleted)
-- These are profile_details on synced profiles that have NO profile_detail_syncs mapping
SELECT
    pd.id as detail_id,
    pd.category,
    pd.label,
    pd.value,
    pd.profile_id,
    p.full_name as profile_name,
    p.source_user_id,
    p.sync_connection_id
FROM profile_details pd
JOIN profiles p ON p.id = pd.profile_id
WHERE p.source_user_id IS NOT NULL  -- synced profiles only
  AND p.sync_connection_id IS NOT NULL
  AND pd.id NOT IN (
      SELECT synced_detail_id FROM profile_detail_syncs
  )
ORDER BY p.full_name, pd.category, pd.label;

-- 4. Check profile_detail_syncs entries that point to non-existent source details
-- These would indicate the source was deleted but the synced copy + mapping survived
SELECT
    pds.id as mapping_id,
    pds.sync_connection_id,
    pds.source_detail_id,
    pds.synced_detail_id,
    CASE WHEN src.id IS NULL THEN 'MISSING' ELSE 'EXISTS' END as source_status,
    CASE WHEN syn.id IS NULL THEN 'MISSING' ELSE 'EXISTS' END as synced_status,
    syn.category,
    syn.label,
    syn.value
FROM profile_detail_syncs pds
LEFT JOIN profile_details src ON src.id = pds.source_detail_id
LEFT JOIN profile_details syn ON syn.id = pds.synced_detail_id
WHERE src.id IS NULL  -- source was deleted but mapping still exists
ORDER BY pds.sync_connection_id;
