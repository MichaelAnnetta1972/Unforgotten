-- Migration: Add Profile Sync Tables and Columns
-- This migration adds support for automatic profile syncing between connected users
-- Run this migration in your Supabase SQL Editor

-- ============================================================================
-- PART 1: Add new columns to profiles table
-- ============================================================================

-- source_user_id: When set, indicates this profile is a synced copy from another user
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS source_user_id UUID REFERENCES auth.users(id);

-- synced_fields: Array of field names that are synced from the source profile
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS synced_fields TEXT[];

-- is_local_only: True when sync was severed but profile data should be preserved
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS is_local_only BOOLEAN DEFAULT FALSE;

-- sync_connection_id: Links to the profile_syncs record that created this synced profile
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS sync_connection_id UUID;

-- Create index for faster lookups of synced profiles
CREATE INDEX IF NOT EXISTS idx_profiles_source_user_id ON profiles(source_user_id) WHERE source_user_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_profiles_sync_connection_id ON profiles(sync_connection_id) WHERE sync_connection_id IS NOT NULL;

-- ============================================================================
-- PART 2: Create profile_syncs table
-- ============================================================================

CREATE TABLE IF NOT EXISTS profile_syncs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    invitation_id UUID REFERENCES account_invitations(id),

    -- Inviter side (the user who sent the invitation)
    inviter_user_id UUID NOT NULL REFERENCES auth.users(id),
    inviter_account_id UUID NOT NULL REFERENCES accounts(id),
    inviter_source_profile_id UUID NOT NULL REFERENCES profiles(id),
    inviter_synced_profile_id UUID REFERENCES profiles(id),

    -- Acceptor side (the user who accepted the invitation)
    acceptor_user_id UUID NOT NULL REFERENCES auth.users(id),
    acceptor_account_id UUID NOT NULL REFERENCES accounts(id),
    acceptor_source_profile_id UUID REFERENCES profiles(id),
    acceptor_synced_profile_id UUID REFERENCES profiles(id),

    -- Status tracking
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'severed')),
    severed_at TIMESTAMPTZ,
    severed_by UUID REFERENCES auth.users(id),

    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for profile_syncs
CREATE INDEX IF NOT EXISTS idx_profile_syncs_inviter_user ON profile_syncs(inviter_user_id);
CREATE INDEX IF NOT EXISTS idx_profile_syncs_acceptor_user ON profile_syncs(acceptor_user_id);
CREATE INDEX IF NOT EXISTS idx_profile_syncs_invitation ON profile_syncs(invitation_id);
CREATE INDEX IF NOT EXISTS idx_profile_syncs_status ON profile_syncs(status) WHERE status = 'active';

-- Add foreign key constraint for sync_connection_id now that profile_syncs exists
ALTER TABLE profiles DROP CONSTRAINT IF EXISTS profiles_sync_connection_id_fkey;
ALTER TABLE profiles ADD CONSTRAINT profiles_sync_connection_id_fkey
    FOREIGN KEY (sync_connection_id) REFERENCES profile_syncs(id) ON DELETE SET NULL;

-- ============================================================================
-- PART 3: Create profile_detail_syncs table
-- ============================================================================

CREATE TABLE IF NOT EXISTS profile_detail_syncs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sync_connection_id UUID NOT NULL REFERENCES profile_syncs(id) ON DELETE CASCADE,
    source_detail_id UUID NOT NULL REFERENCES profile_details(id) ON DELETE CASCADE,
    synced_detail_id UUID NOT NULL REFERENCES profile_details(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),

    -- Ensure unique mapping per sync connection
    UNIQUE(sync_connection_id, source_detail_id)
);

-- Indexes for profile_detail_syncs
CREATE INDEX IF NOT EXISTS idx_profile_detail_syncs_connection ON profile_detail_syncs(sync_connection_id);
CREATE INDEX IF NOT EXISTS idx_profile_detail_syncs_source ON profile_detail_syncs(source_detail_id);
CREATE INDEX IF NOT EXISTS idx_profile_detail_syncs_synced ON profile_detail_syncs(synced_detail_id);

-- ============================================================================
-- PART 4: Row Level Security (RLS) Policies
-- ============================================================================

-- Enable RLS on new tables
ALTER TABLE profile_syncs ENABLE ROW LEVEL SECURITY;
ALTER TABLE profile_detail_syncs ENABLE ROW LEVEL SECURITY;

-- profile_syncs policies: Users can view/update syncs they're part of
CREATE POLICY "Users can view their own profile syncs" ON profile_syncs
    FOR SELECT USING (
        auth.uid() = inviter_user_id OR auth.uid() = acceptor_user_id
    );

CREATE POLICY "Users can update their own profile syncs" ON profile_syncs
    FOR UPDATE USING (
        auth.uid() = inviter_user_id OR auth.uid() = acceptor_user_id
    );

-- profile_detail_syncs policies: Users can view detail syncs for their profile syncs
CREATE POLICY "Users can view their profile detail syncs" ON profile_detail_syncs
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM profile_syncs ps
            WHERE ps.id = profile_detail_syncs.sync_connection_id
            AND (auth.uid() = ps.inviter_user_id OR auth.uid() = ps.acceptor_user_id)
        )
    );

-- ============================================================================
-- PART 5: Updated_at trigger for profile_syncs
-- ============================================================================

CREATE OR REPLACE FUNCTION update_profile_syncs_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_profile_syncs_updated_at ON profile_syncs;
CREATE TRIGGER trigger_update_profile_syncs_updated_at
    BEFORE UPDATE ON profile_syncs
    FOR EACH ROW
    EXECUTE FUNCTION update_profile_syncs_updated_at();
