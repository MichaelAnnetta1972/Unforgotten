-- Meal Planner Tables
-- Creates recipes and planned_meals tables for the Meal Planner feature

-- Recipes table: stores favourite recipe names with optional website links
CREATE TABLE IF NOT EXISTS recipes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    account_id UUID NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    website_url TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Planned Meals table: links recipes to specific dates and meal types
CREATE TABLE IF NOT EXISTS planned_meals (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    account_id UUID NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    recipe_id UUID NOT NULL REFERENCES recipes(id) ON DELETE CASCADE,
    date DATE NOT NULL,
    meal_type TEXT NOT NULL CHECK (meal_type IN ('breakfast', 'lunch', 'dinner')),
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_recipes_account_id ON recipes(account_id);
CREATE INDEX IF NOT EXISTS idx_planned_meals_account_id ON planned_meals(account_id);
CREATE INDEX IF NOT EXISTS idx_planned_meals_date ON planned_meals(account_id, date);
CREATE INDEX IF NOT EXISTS idx_planned_meals_recipe_id ON planned_meals(recipe_id);

-- Enable RLS
ALTER TABLE recipes ENABLE ROW LEVEL SECURITY;
ALTER TABLE planned_meals ENABLE ROW LEVEL SECURITY;

-- RLS Policies for recipes
CREATE POLICY "Users can view recipes for their accounts"
    ON recipes FOR SELECT
    USING (account_id IN (
        SELECT account_id FROM account_members WHERE user_id = auth.uid()
    ));

CREATE POLICY "Users can insert recipes for their accounts"
    ON recipes FOR INSERT
    WITH CHECK (account_id IN (
        SELECT account_id FROM account_members WHERE user_id = auth.uid()
    ));

CREATE POLICY "Users can update recipes for their accounts"
    ON recipes FOR UPDATE
    USING (account_id IN (
        SELECT account_id FROM account_members WHERE user_id = auth.uid()
    ));

CREATE POLICY "Users can delete recipes for their accounts"
    ON recipes FOR DELETE
    USING (account_id IN (
        SELECT account_id FROM account_members WHERE user_id = auth.uid()
    ));

-- RLS Policies for planned_meals
CREATE POLICY "Users can view planned meals for their accounts"
    ON planned_meals FOR SELECT
    USING (account_id IN (
        SELECT account_id FROM account_members WHERE user_id = auth.uid()
    ));

CREATE POLICY "Users can insert planned meals for their accounts"
    ON planned_meals FOR INSERT
    WITH CHECK (account_id IN (
        SELECT account_id FROM account_members WHERE user_id = auth.uid()
    ));

CREATE POLICY "Users can update planned meals for their accounts"
    ON planned_meals FOR UPDATE
    USING (account_id IN (
        SELECT account_id FROM account_members WHERE user_id = auth.uid()
    ));

CREATE POLICY "Users can delete planned meals for their accounts"
    ON planned_meals FOR DELETE
    USING (account_id IN (
        SELECT account_id FROM account_members WHERE user_id = auth.uid()
    ));

-- Updated_at trigger function (reuse if already exists)
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Auto-update updated_at
CREATE TRIGGER update_recipes_updated_at
    BEFORE UPDATE ON recipes
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_planned_meals_updated_at
    BEFORE UPDATE ON planned_meals
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();
