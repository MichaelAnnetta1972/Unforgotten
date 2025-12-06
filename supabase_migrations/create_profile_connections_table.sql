-- Create profile_connections table
CREATE TABLE IF NOT EXISTS public.profile_connections (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    account_id UUID NOT NULL REFERENCES public.accounts(id) ON DELETE CASCADE,
    from_profile_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    to_profile_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    relationship_type TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- Ensure no duplicate connections between the same two profiles
    UNIQUE(from_profile_id, to_profile_id)
);

-- Create indexes for faster lookups
CREATE INDEX IF NOT EXISTS idx_profile_connections_from_profile
    ON public.profile_connections(from_profile_id);
CREATE INDEX IF NOT EXISTS idx_profile_connections_to_profile
    ON public.profile_connections(to_profile_id);
CREATE INDEX IF NOT EXISTS idx_profile_connections_account
    ON public.profile_connections(account_id);

-- Enable Row Level Security
ALTER TABLE public.profile_connections ENABLE ROW LEVEL SECURITY;

-- RLS Policy: Users can view connections for accounts they are members of
CREATE POLICY "Users can view connections for their accounts"
    ON public.profile_connections
    FOR SELECT
    USING (
        account_id IN (
            SELECT account_id FROM public.account_members
            WHERE user_id = auth.uid()
        )
    );

-- RLS Policy: Users can insert connections for accounts they are members of (with write access)
CREATE POLICY "Users can create connections for their accounts"
    ON public.profile_connections
    FOR INSERT
    WITH CHECK (
        account_id IN (
            SELECT account_id FROM public.account_members
            WHERE user_id = auth.uid()
            AND role IN ('owner', 'admin', 'helper')
        )
    );

-- RLS Policy: Users can delete connections for accounts they are members of (with write access)
CREATE POLICY "Users can delete connections for their accounts"
    ON public.profile_connections
    FOR DELETE
    USING (
        account_id IN (
            SELECT account_id FROM public.account_members
            WHERE user_id = auth.uid()
            AND role IN ('owner', 'admin', 'helper')
        )
    );
