-- Migration: Add accent_color_hex column to user_preferences
-- Replaces integer-based accent_color_index with freeform hex string storage
-- The accent_color_index column is kept for backwards compatibility with older app versions

-- Add the new column with a default matching yellow (the previous index 0 default)
ALTER TABLE user_preferences
ADD COLUMN IF NOT EXISTS accent_color_hex TEXT NOT NULL DEFAULT 'FFD60A';

-- Migrate existing data: convert accent_color_index to hex strings
UPDATE user_preferences SET accent_color_hex = CASE accent_color_index
    WHEN 0 THEN 'FFD60A'
    WHEN 1 THEN 'FF9F0A'
    WHEN 2 THEN 'FF6B6B'
    WHEN 3 THEN 'CE76B7'
    WHEN 4 THEN 'BF5AF2'
    WHEN 5 THEN '0A84FF'
    WHEN 6 THEN '64D2FF'
    WHEN 7 THEN '40C8E0'
    WHEN 8 THEN '6A863E'
    WHEN 9 THEN '63E6BE'
    WHEN 10 THEN 'FFFFFF'
    WHEN 11 THEN 'A7A7A7'
    WHEN 12 THEN '98ACA4'
    WHEN 13 THEN '7791A4'
    WHEN 14 THEN '565577'
    ELSE 'FFD60A'
END;

-- Note: accent_color_index column is intentionally kept for backwards compatibility.
-- It can be dropped in a future migration once all users have updated to the new app version.
