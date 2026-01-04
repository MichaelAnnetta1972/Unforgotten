-- Migration: Create user_preferences table for syncing appearance settings across devices
-- Run this in your Supabase SQL Editor

-- Create the user_preferences table
-- Each user has one preferences record per account they belong to
CREATE TABLE IF NOT EXISTS user_preferences (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    account_id UUID NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,

    -- Header style (style_one, style_two, style_three, style_four)
    header_style_id TEXT NOT NULL DEFAULT 'style_one',

    -- Accent color settings
    accent_color_index INTEGER NOT NULL DEFAULT 0,
    has_custom_accent_color BOOLEAN NOT NULL DEFAULT FALSE,

    -- Feature visibility as JSON object
    -- e.g. {"medications": true, "appointments": true, "notes": false}
    feature_visibility JSONB NOT NULL DEFAULT '{}'::jsonb,

    -- Timestamps
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- Ensure one preferences record per user per account
    UNIQUE(user_id, account_id)
);

-- Create indexes for faster lookups
CREATE INDEX IF NOT EXISTS idx_user_preferences_user_id ON user_preferences(user_id);
CREATE INDEX IF NOT EXISTS idx_user_preferences_account_id ON user_preferences(account_id);
CREATE INDEX IF NOT EXISTS idx_user_preferences_user_account ON user_preferences(user_id, account_id);

-- Enable Row Level Security
ALTER TABLE user_preferences ENABLE ROW LEVEL SECURITY;

-- Policy: Users can read their own preferences
CREATE POLICY "Users can read own preferences"
    ON user_preferences
    FOR SELECT
    USING (auth.uid() = user_id);

-- Policy: Users can insert their own preferences
CREATE POLICY "Users can insert own preferences"
    ON user_preferences
    FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- Policy: Users can update their own preferences
CREATE POLICY "Users can update own preferences"
    ON user_preferences
    FOR UPDATE
    USING (auth.uid() = user_id);

-- Policy: Users can delete their own preferences
CREATE POLICY "Users can delete own preferences"
    ON user_preferences
    FOR DELETE
    USING (auth.uid() = user_id);

-- Create a function to automatically update updated_at timestamp
CREATE OR REPLACE FUNCTION update_user_preferences_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create a trigger to auto-update the updated_at column
DROP TRIGGER IF EXISTS trigger_update_user_preferences_updated_at ON user_preferences;
CREATE TRIGGER trigger_update_user_preferences_updated_at
    BEFORE UPDATE ON user_preferences
    FOR EACH ROW
    EXECUTE FUNCTION update_user_preferences_updated_at();

-- Enable realtime for user_preferences (for instant sync across devices)
ALTER PUBLICATION supabase_realtime ADD TABLE user_preferences;
