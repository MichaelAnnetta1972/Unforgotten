-- Migration: Create app_users table for admin and complimentary access management
-- Run this migration in your Supabase SQL Editor

-- Create the app_users table
CREATE TABLE IF NOT EXISTS app_users (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT NOT NULL UNIQUE,
    is_app_admin BOOLEAN NOT NULL DEFAULT FALSE,
    has_complimentary_access BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create an index on email for faster lookups
CREATE INDEX IF NOT EXISTS idx_app_users_email ON app_users(email);

-- Create an index on is_app_admin for filtering admins
CREATE INDEX IF NOT EXISTS idx_app_users_is_admin ON app_users(is_app_admin) WHERE is_app_admin = TRUE;

-- Create an index on has_complimentary_access for filtering
CREATE INDEX IF NOT EXISTS idx_app_users_complimentary ON app_users(has_complimentary_access) WHERE has_complimentary_access = TRUE;

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

-- Enable Row Level Security
ALTER TABLE app_users ENABLE ROW LEVEL SECURITY;

-- Policy: Allow authenticated users to read their own record
CREATE POLICY "Users can read own app_user record"
    ON app_users
    FOR SELECT
    USING (auth.uid() = id);

-- Policy: Allow app admins to read all records
-- Uses the security definer function to avoid recursion
CREATE POLICY "App admins can read all app_user records"
    ON app_users
    FOR SELECT
    USING (is_app_admin(auth.uid()) = TRUE);

-- Policy: Allow app admins to update any record
CREATE POLICY "App admins can update app_user records"
    ON app_users
    FOR UPDATE
    USING (is_app_admin(auth.uid()) = TRUE);

-- Policy: Allow authenticated users to insert their own record (for initial sync)
CREATE POLICY "Users can insert own app_user record"
    ON app_users
    FOR INSERT
    WITH CHECK (auth.uid() = id);

-- Create a function to automatically update updated_at timestamp
CREATE OR REPLACE FUNCTION update_app_users_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create a trigger to auto-update the updated_at column
DROP TRIGGER IF EXISTS trigger_update_app_users_updated_at ON app_users;
CREATE TRIGGER trigger_update_app_users_updated_at
    BEFORE UPDATE ON app_users
    FOR EACH ROW
    EXECUTE FUNCTION update_app_users_updated_at();

-- Comment: To manually set an initial admin after they've signed up:
-- UPDATE app_users SET is_app_admin = TRUE WHERE email = 'michael@bbad.com.au';
