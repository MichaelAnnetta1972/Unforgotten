-- Add connected_to_profile_id column to profiles table for family tree connections
-- This field links a profile to another profile to establish family tree relationships
-- For example: Emma (Granddaughter) -> connected_to: John (Son) means Emma is John's daughter

ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS connected_to_profile_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL;

-- Create index for faster lookups when building family trees
CREATE INDEX IF NOT EXISTS idx_profiles_connected_to
    ON public.profiles(connected_to_profile_id)
    WHERE connected_to_profile_id IS NOT NULL;

-- Add a comment to document the field's purpose
COMMENT ON COLUMN public.profiles.connected_to_profile_id IS
    'Optional link to another profile for family tree relationships. The relationship type combined with this link determines the family tree structure.';
