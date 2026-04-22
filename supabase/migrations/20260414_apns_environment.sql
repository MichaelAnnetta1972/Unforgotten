-- =============================================================================
-- APNs environment tracking for Live Activity tokens
--
-- Push tokens are environment-specific: tokens minted by Xcode debug builds are
-- valid only against api.sandbox.push.apple.com, and tokens minted by TestFlight
-- / App Store builds are valid only against api.push.apple.com. The edge
-- function that sends the morning briefing push-to-start needs to know which
-- environment to use per token.
--
-- Existing rows default to 'production' because the vast majority of current
-- testers are on TestFlight. Debug builds will overwrite their own row with
-- 'sandbox' on next launch via observePushToStartToken().
-- =============================================================================

ALTER TABLE live_activity_tokens
    ADD COLUMN IF NOT EXISTS apns_environment TEXT NOT NULL DEFAULT 'production'
        CHECK (apns_environment IN ('sandbox', 'production'));

DROP FUNCTION IF EXISTS get_morning_briefing_recipients();
CREATE OR REPLACE FUNCTION get_morning_briefing_recipients()
RETURNS TABLE (
    user_id UUID,
    push_to_start_token TEXT,
    apns_environment TEXT,
    content_state JSONB
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT
        lat.user_id,
        lat.token AS push_to_start_token,
        lat.apns_environment,
        mbc.content_state
    FROM live_activity_tokens lat
    INNER JOIN morning_briefing_cache mbc ON mbc.user_id = lat.user_id
    WHERE lat.token_type = 'push_to_start'
      AND mbc.target_date BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '2 days';
$$;
