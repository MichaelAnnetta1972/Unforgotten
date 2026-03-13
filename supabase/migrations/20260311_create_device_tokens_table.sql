-- Create device_tokens table for push notification delivery
CREATE TABLE IF NOT EXISTS device_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    token TEXT NOT NULL,
    platform TEXT NOT NULL DEFAULT 'ios',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(user_id, token)
);

-- Enable RLS
ALTER TABLE device_tokens ENABLE ROW LEVEL SECURITY;

-- Users can manage their own device tokens
CREATE POLICY "Users can insert own device tokens"
    ON device_tokens FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can view own device tokens"
    ON device_tokens FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can update own device tokens"
    ON device_tokens FOR UPDATE
    USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own device tokens"
    ON device_tokens FOR DELETE
    USING (auth.uid() = user_id);

-- Index for looking up tokens by user_id (used by edge function)
CREATE INDEX idx_device_tokens_user_id ON device_tokens(user_id);

-- Function to get device tokens for a list of user IDs (SECURITY DEFINER to bypass RLS)
-- Used by the edge function to send push notifications to shared members
CREATE OR REPLACE FUNCTION get_device_tokens_for_users(p_user_ids UUID[])
RETURNS TABLE(user_id UUID, token TEXT)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT dt.user_id, dt.token
    FROM device_tokens dt
    WHERE dt.user_id = ANY(p_user_ids);
END;
$$;
