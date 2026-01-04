-- Create notes table for syncing between devices
CREATE TABLE IF NOT EXISTS notes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    account_id UUID NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    user_id UUID NOT NULL,
    local_id UUID NOT NULL,
    title TEXT NOT NULL DEFAULT '',
    content BYTEA,
    content_plain_text TEXT NOT NULL DEFAULT '',
    theme TEXT NOT NULL DEFAULT 'standard',
    is_pinned BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ,
    UNIQUE(account_id, local_id)
);

-- Create indexes for efficient queries
CREATE INDEX IF NOT EXISTS idx_notes_account_id ON notes(account_id);
CREATE INDEX IF NOT EXISTS idx_notes_user_id ON notes(user_id);
CREATE INDEX IF NOT EXISTS idx_notes_updated_at ON notes(updated_at);
CREATE INDEX IF NOT EXISTS idx_notes_local_id ON notes(local_id);

-- Enable Row Level Security
ALTER TABLE notes ENABLE ROW LEVEL SECURITY;

-- Policy: Users can view their own notes
CREATE POLICY "Users can view their own notes"
ON notes FOR SELECT
USING (user_id = auth.uid());

-- Policy: Users can insert their own notes
CREATE POLICY "Users can insert their own notes"
ON notes FOR INSERT
WITH CHECK (user_id = auth.uid());

-- Policy: Users can update their own notes
CREATE POLICY "Users can update their own notes"
ON notes FOR UPDATE
USING (user_id = auth.uid());

-- Policy: Users can delete their own notes
CREATE POLICY "Users can delete their own notes"
ON notes FOR DELETE
USING (user_id = auth.uid());

-- Function to automatically update updated_at timestamp
CREATE OR REPLACE FUNCTION update_notes_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to call the function on update
DROP TRIGGER IF EXISTS trigger_notes_updated_at ON notes;
CREATE TRIGGER trigger_notes_updated_at
    BEFORE UPDATE ON notes
    FOR EACH ROW
    EXECUTE FUNCTION update_notes_updated_at();
