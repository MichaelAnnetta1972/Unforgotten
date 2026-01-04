-- To Do Lists Feature Migration
-- Created: 2025-12-18
-- Description: Creates tables for to-do lists, items, and list types

-- To Do List Types (user-defined tags)
CREATE TABLE IF NOT EXISTS todo_list_types (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    account_id UUID NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(account_id, name)
);

-- To Do Lists
CREATE TABLE IF NOT EXISTS todo_lists (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    account_id UUID NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    list_type TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- To Do Items
CREATE TABLE IF NOT EXISTS todo_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    list_id UUID NOT NULL REFERENCES todo_lists(id) ON DELETE CASCADE,
    text TEXT NOT NULL,
    is_completed BOOLEAN DEFAULT FALSE,
    sort_order INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable Row Level Security
ALTER TABLE todo_list_types ENABLE ROW LEVEL SECURITY;
ALTER TABLE todo_lists ENABLE ROW LEVEL SECURITY;
ALTER TABLE todo_items ENABLE ROW LEVEL SECURITY;

-- RLS Policies for todo_list_types
CREATE POLICY "Users can view types for their accounts"
ON todo_list_types FOR SELECT
USING (
    account_id IN (
        SELECT account_id FROM account_members WHERE user_id = auth.uid()
    )
);

CREATE POLICY "Users can insert types for their accounts"
ON todo_list_types FOR INSERT
WITH CHECK (
    account_id IN (
        SELECT account_id FROM account_members WHERE user_id = auth.uid()
    )
);

CREATE POLICY "Users can delete types for their accounts"
ON todo_list_types FOR DELETE
USING (
    account_id IN (
        SELECT account_id FROM account_members WHERE user_id = auth.uid()
    )
);

-- RLS Policies for todo_lists
CREATE POLICY "Users can view lists for their accounts"
ON todo_lists FOR SELECT
USING (
    account_id IN (
        SELECT account_id FROM account_members WHERE user_id = auth.uid()
    )
);

CREATE POLICY "Users can insert lists for their accounts"
ON todo_lists FOR INSERT
WITH CHECK (
    account_id IN (
        SELECT account_id FROM account_members WHERE user_id = auth.uid()
    )
);

CREATE POLICY "Users can update lists for their accounts"
ON todo_lists FOR UPDATE
USING (
    account_id IN (
        SELECT account_id FROM account_members WHERE user_id = auth.uid()
    )
);

CREATE POLICY "Users can delete lists for their accounts"
ON todo_lists FOR DELETE
USING (
    account_id IN (
        SELECT account_id FROM account_members WHERE user_id = auth.uid()
    )
);

-- RLS Policies for todo_items
CREATE POLICY "Users can view items for their lists"
ON todo_items FOR SELECT
USING (
    list_id IN (
        SELECT id FROM todo_lists WHERE account_id IN (
            SELECT account_id FROM account_members WHERE user_id = auth.uid()
        )
    )
);

CREATE POLICY "Users can insert items for their lists"
ON todo_items FOR INSERT
WITH CHECK (
    list_id IN (
        SELECT id FROM todo_lists WHERE account_id IN (
            SELECT account_id FROM account_members WHERE user_id = auth.uid()
        )
    )
);

CREATE POLICY "Users can update items for their lists"
ON todo_items FOR UPDATE
USING (
    list_id IN (
        SELECT id FROM todo_lists WHERE account_id IN (
            SELECT account_id FROM account_members WHERE user_id = auth.uid()
        )
    )
);

CREATE POLICY "Users can delete items for their lists"
ON todo_items FOR DELETE
USING (
    list_id IN (
        SELECT id FROM todo_lists WHERE account_id IN (
            SELECT account_id FROM account_members WHERE user_id = auth.uid()
        )
    )
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_todo_list_types_account_id ON todo_list_types(account_id);
CREATE INDEX IF NOT EXISTS idx_todo_lists_account_id ON todo_lists(account_id);
CREATE INDEX IF NOT EXISTS idx_todo_lists_list_type ON todo_lists(list_type);
CREATE INDEX IF NOT EXISTS idx_todo_items_list_id ON todo_items(list_id);
CREATE INDEX IF NOT EXISTS idx_todo_items_sort_order ON todo_items(list_id, sort_order);

-- Create function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create triggers for updated_at
CREATE TRIGGER update_todo_lists_updated_at BEFORE UPDATE ON todo_lists
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_todo_items_updated_at BEFORE UPDATE ON todo_items
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Insert default list types for existing accounts
INSERT INTO todo_list_types (account_id, name)
SELECT id, unnest(ARRAY['Shopping', 'Work', 'Home', 'Errands', 'Personal'])
FROM accounts
WHERE id NOT IN (SELECT DISTINCT account_id FROM todo_list_types);
