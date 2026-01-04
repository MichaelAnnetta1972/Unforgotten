-- Add deceased fields to profiles table
-- This migration adds support for marking profiles as deceased with an optional date of death

-- Add is_deceased column with default value of false
ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS is_deceased BOOLEAN DEFAULT FALSE NOT NULL;

-- Add date_of_death column (nullable - only set when is_deceased is true)
ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS date_of_death DATE;

-- Add a comment explaining the purpose
COMMENT ON COLUMN profiles.is_deceased IS 'Indicates if the person has passed away. Deceased profiles show a simplified memorial view.';
COMMENT ON COLUMN profiles.date_of_death IS 'Date of death if the person is deceased. Only applicable when is_deceased is true.';

-- Optional: Add a check constraint to ensure date_of_death is only set when is_deceased is true
-- ALTER TABLE profiles
-- ADD CONSTRAINT chk_deceased_date
-- CHECK (is_deceased = TRUE OR date_of_death IS NULL);
