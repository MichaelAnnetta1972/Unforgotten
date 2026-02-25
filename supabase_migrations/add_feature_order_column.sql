-- Add feature_order column to user_preferences table
-- Stores the user's custom ordering of home screen feature cards as a JSON array of feature IDs
ALTER TABLE user_preferences
ADD COLUMN IF NOT EXISTS feature_order jsonb DEFAULT '[]'::jsonb;
