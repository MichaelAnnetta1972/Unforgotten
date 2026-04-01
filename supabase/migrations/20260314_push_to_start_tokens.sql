-- =============================================================================
-- Push-to-Start Token Support for Morning Briefing Live Activity
-- Adds token_type column to distinguish per-activity tokens from push-to-start tokens
-- =============================================================================

-- 1. Add token_type column to live_activity_tokens
ALTER TABLE live_activity_tokens
    ADD COLUMN IF NOT EXISTS token_type TEXT NOT NULL DEFAULT 'activity';

-- 2. Drop the old unique constraint and create a new one that includes token_type
ALTER TABLE live_activity_tokens DROP CONSTRAINT IF EXISTS live_activity_tokens_user_id_token_key;
ALTER TABLE live_activity_tokens ADD CONSTRAINT live_activity_tokens_user_id_token_key UNIQUE(user_id, token);

-- 3. Drop and recreate the function (return type changed)
DROP FUNCTION IF EXISTS get_morning_briefing_recipients();
CREATE OR REPLACE FUNCTION get_morning_briefing_recipients()
RETURNS TABLE (
    user_id UUID,
    push_to_start_token TEXT,
    content_state JSONB
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT
        lat.user_id,
        lat.token AS push_to_start_token,
        mbc.content_state
    FROM live_activity_tokens lat
    INNER JOIN morning_briefing_cache mbc ON mbc.user_id = lat.user_id
    WHERE lat.token_type = 'push_to_start'
      AND mbc.target_date BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '2 days';
$$;
