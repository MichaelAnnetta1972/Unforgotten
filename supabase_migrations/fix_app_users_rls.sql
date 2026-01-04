-- Migration: Fix app_users RLS policies to avoid infinite recursion
-- Run this in your Supabase SQL Editor

-- Drop the existing policies that cause infinite recursion
DROP POLICY IF EXISTS "App admins can read all app_user records" ON app_users;
DROP POLICY IF EXISTS "App admins can update app_user records" ON app_users;

-- Create a security definer function to check if a user is an app admin
-- This avoids infinite recursion in RLS policies
CREATE OR REPLACE FUNCTION is_app_admin(user_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
    admin_status BOOLEAN;
BEGIN
    SELECT is_app_admin INTO admin_status
    FROM app_users
    WHERE id = user_id;

    RETURN COALESCE(admin_status, FALSE);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Recreate policies using the security definer function
CREATE POLICY "App admins can read all app_user records"
    ON app_users
    FOR SELECT
    USING (is_app_admin(auth.uid()) = TRUE);

CREATE POLICY "App admins can update app_user records"
    ON app_users
    FOR UPDATE
    USING (is_app_admin(auth.uid()) = TRUE);

-- Make sure the initial admin is set correctly
UPDATE app_users SET is_app_admin = TRUE WHERE LOWER(email) = 'michael@bbad.com.au';
