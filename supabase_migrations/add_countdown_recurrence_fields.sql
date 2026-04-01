-- Migration: Add recurrence_unit, recurrence_interval, and recurrence_end_date columns to countdowns table
-- Extends the existing is_recurring boolean to support flexible recurrence patterns:
-- week, fortnight, month, year with a configurable interval (e.g. every 2 weeks)

ALTER TABLE countdowns
ADD COLUMN IF NOT EXISTS recurrence_unit TEXT DEFAULT NULL,
ADD COLUMN IF NOT EXISTS recurrence_interval INTEGER DEFAULT NULL,
ADD COLUMN IF NOT EXISTS recurrence_end_date TIMESTAMPTZ DEFAULT NULL;

-- Backfill existing recurring countdowns to use 'year' with interval 1
UPDATE countdowns
SET recurrence_unit = 'year', recurrence_interval = 1
WHERE is_recurring = true
  AND recurrence_unit IS NULL;

COMMENT ON COLUMN countdowns.recurrence_unit IS 'Recurrence frequency: week, fortnight, month, year';
COMMENT ON COLUMN countdowns.recurrence_interval IS 'How many units between recurrences (e.g. 2 = every 2 weeks)';
COMMENT ON COLUMN countdowns.recurrence_end_date IS 'Optional date after which recurrence stops';
