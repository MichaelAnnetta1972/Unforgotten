-- Migration: Populate app_users table with existing auth users
-- Run this in your Supabase SQL Editor

-- First, check what's currently in app_users
SELECT * FROM app_users ORDER BY created_at;

-- Check what users exist in auth.users
SELECT id, email, created_at FROM auth.users ORDER BY created_at;

-- Insert any auth users that don't exist in app_users yet
-- This will populate the table with all existing users
INSERT INTO app_users (id, email, is_app_admin, has_complimentary_access, created_at, updated_at)
SELECT
    au.id,
    LOWER(au.email),
    CASE WHEN LOWER(au.email) = 'michael@bbad.com.au' THEN TRUE ELSE FALSE END,
    FALSE,
    au.created_at,
    NOW()
FROM auth.users au
WHERE NOT EXISTS (
    SELECT 1 FROM app_users ap WHERE ap.id = au.id
)
AND au.email IS NOT NULL;

-- Verify the results
SELECT * FROM app_users ORDER BY created_at;

-- Make sure you're set as admin
UPDATE app_users SET is_app_admin = TRUE WHERE LOWER(email) = 'michael@bbad.com.au';
