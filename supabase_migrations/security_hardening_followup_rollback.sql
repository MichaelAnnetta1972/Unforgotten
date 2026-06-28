-- ============================================================================
-- SECURITY HARDENING FOLLOW-UP - ROLLBACK
-- Date: 2026-05-12
-- ============================================================================

-- (a) Restore search_path to default (NULL = role default, which is mutable)
ALTER FUNCTION cleanup_todo_list_shares() RESET search_path;
ALTER FUNCTION get_sharing_category_key(text) RESET search_path;
ALTER FUNCTION grant_review_account_access() RESET search_path;
ALTER FUNCTION update_sharing_preference(uuid, text, boolean) RESET search_path;

-- (b) Restore EXECUTE permission on the three internal/admin functions
GRANT EXECUTE ON FUNCTION rls_auto_enable() TO anon, authenticated;
GRANT EXECUTE ON FUNCTION get_morning_briefing_recipients() TO anon, authenticated;
GRANT EXECUTE ON FUNCTION get_device_tokens_for_users(uuid[]) TO anon, authenticated;
