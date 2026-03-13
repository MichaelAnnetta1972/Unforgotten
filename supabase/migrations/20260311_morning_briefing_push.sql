-- =============================================================================
-- Morning Briefing Push: Live Activity Tokens + Briefing Cache
-- =============================================================================

-- 1. Live Activity Tokens table
CREATE TABLE IF NOT EXISTS live_activity_tokens (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    token TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, token)
);

-- Index for lookups
CREATE INDEX IF NOT EXISTS idx_live_activity_tokens_user_id ON live_activity_tokens(user_id);

-- RLS
ALTER TABLE live_activity_tokens ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage own live activity tokens"
    ON live_activity_tokens
    FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- 2. Morning Briefing Cache table
CREATE TABLE IF NOT EXISTS morning_briefing_cache (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE,
    content_state JSONB NOT NULL,
    target_date DATE NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index
CREATE INDEX IF NOT EXISTS idx_morning_briefing_cache_user_id ON morning_briefing_cache(user_id);

-- RLS
ALTER TABLE morning_briefing_cache ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage own briefing cache"
    ON morning_briefing_cache
    FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- 3. SECURITY DEFINER function for the edge function to read tokens and briefing data
CREATE OR REPLACE FUNCTION get_morning_briefing_recipients()
RETURNS TABLE (
    user_id UUID,
    la_token TEXT,
    content_state JSONB
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT
        lat.user_id,
        lat.token AS la_token,
        mbc.content_state
    FROM live_activity_tokens lat
    INNER JOIN morning_briefing_cache mbc ON mbc.user_id = lat.user_id
    WHERE mbc.target_date = CURRENT_DATE;
$$;

-- 4. Cron job setup
-- NOTE: After running this migration, set up the cron job manually in the Supabase SQL Editor:
-- Replace YOUR_PROJECT_URL and YOUR_SERVICE_ROLE_KEY with actual values.
--
-- SELECT cron.schedule(
--     'morning-briefing-push',
--     '0 6 * * *',
--     $$
--     SELECT net.http_post(
--         url := 'YOUR_PROJECT_URL/functions/v1/send-morning-briefing',
--         headers := '{"Authorization": "Bearer YOUR_SERVICE_ROLE_KEY", "Content-Type": "application/json"}'::jsonb,
--         body := '{}'::jsonb
--     );
--     $$
-- );
