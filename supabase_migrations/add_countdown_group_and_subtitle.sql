-- Add group_id and subtitle columns to countdowns table
-- group_id links individual day records that belong to the same multi-day event
-- subtitle allows each day of an event to have its own description

ALTER TABLE countdowns ADD COLUMN IF NOT EXISTS group_id UUID DEFAULT NULL;
ALTER TABLE countdowns ADD COLUMN IF NOT EXISTS subtitle TEXT DEFAULT NULL;

-- Index for efficient group queries
CREATE INDEX IF NOT EXISTS idx_countdowns_group_id ON countdowns (group_id) WHERE group_id IS NOT NULL;
