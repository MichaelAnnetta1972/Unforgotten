-- Add environment column to device_tokens to distinguish sandbox vs production APNs tokens.
-- Sandbox tokens (Xcode debug builds) must use api.sandbox.push.apple.com
-- Production tokens (TestFlight/App Store) must use api.push.apple.com
-- Sending to the wrong endpoint silently fails.

ALTER TABLE device_tokens
    ADD COLUMN IF NOT EXISTS environment TEXT NOT NULL DEFAULT 'production';

-- Update unique constraint to include environment
-- (a user could have both a sandbox and production token)
ALTER TABLE device_tokens DROP CONSTRAINT IF EXISTS device_tokens_user_id_token_key;
ALTER TABLE device_tokens ADD CONSTRAINT device_tokens_user_id_token_key UNIQUE (user_id, token);

-- Drop and recreate the RPC function with the new return type (includes environment)
DROP FUNCTION IF EXISTS get_device_tokens_for_users(uuid[]);
CREATE OR REPLACE FUNCTION get_device_tokens_for_users(p_user_ids UUID[])
RETURNS TABLE(user_id UUID, token TEXT, environment TEXT)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT dt.user_id, dt.token, dt.environment
    FROM device_tokens dt
    WHERE dt.user_id = ANY(p_user_ids);
END;
$$;
