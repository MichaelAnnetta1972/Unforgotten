-- Create profile_pins table
-- Stores per-user pinned profiles so that pinning persists across devices,
-- reinstalls, and app updates (previously stored only in UserDefaults).
-- Each member of an account can pin profiles independently.
CREATE TABLE IF NOT EXISTS public.profile_pins (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    profile_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    pinned_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- A user can only pin a given profile once
    UNIQUE(user_id, profile_id)
);

-- Indexes for fast lookup by user (the common access pattern: load all pins for the signed-in user)
CREATE INDEX IF NOT EXISTS idx_profile_pins_user
    ON public.profile_pins(user_id);
CREATE INDEX IF NOT EXISTS idx_profile_pins_profile
    ON public.profile_pins(profile_id);

-- Enable Row Level Security
ALTER TABLE public.profile_pins ENABLE ROW LEVEL SECURITY;

-- RLS Policy: Users can view only their own pins
CREATE POLICY "Users can view their own pins"
    ON public.profile_pins
    FOR SELECT
    USING (user_id = auth.uid());

-- RLS Policy: Users can create pins only for themselves, and only for profiles
-- belonging to an account they are a member of
CREATE POLICY "Users can create their own pins"
    ON public.profile_pins
    FOR INSERT
    WITH CHECK (
        user_id = auth.uid()
        AND profile_id IN (
            SELECT p.id FROM public.profiles p
            JOIN public.account_members am ON am.account_id = p.account_id
            WHERE am.user_id = auth.uid()
        )
    );

-- RLS Policy: Users can delete only their own pins
CREATE POLICY "Users can delete their own pins"
    ON public.profile_pins
    FOR DELETE
    USING (user_id = auth.uid());
