-- Add optional due_date column to todo_lists
ALTER TABLE todo_lists ADD COLUMN IF NOT EXISTS due_date DATE;

-- Index for calendar queries filtering by due_date
CREATE INDEX IF NOT EXISTS idx_todo_lists_due_date ON todo_lists(account_id, due_date) WHERE due_date IS NOT NULL;
