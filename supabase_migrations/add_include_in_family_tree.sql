-- Add include_in_family_tree column to profiles table
-- This field controls whether a profile appears in the family tree visualization
-- Defaults to true so existing profiles are included

ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS include_in_family_tree BOOLEAN NOT NULL DEFAULT true;

-- Add a comment to document the field's purpose
COMMENT ON COLUMN public.profiles.include_in_family_tree IS
    'Controls whether this profile is displayed in the family tree visualization. Defaults to true.';
