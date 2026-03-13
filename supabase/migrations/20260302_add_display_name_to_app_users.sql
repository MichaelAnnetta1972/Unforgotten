-- Add display_name column to app_users table
-- This stores the user's real name (captured from Apple Sign-In or set manually)
-- so it can be displayed instead of the Apple private relay email prefix
ALTER TABLE app_users ADD COLUMN IF NOT EXISTS display_name TEXT;
