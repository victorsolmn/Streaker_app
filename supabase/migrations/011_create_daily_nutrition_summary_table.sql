-- ============================================================================
-- MIGRATION 011: Create daily_nutrition_summary TABLE (fix VIEW issue)
-- Date: November 19, 2025
-- Purpose: Fix critical bug where daily_nutrition_summary is a VIEW, not a TABLE
--          Migration 007 expects this to be a TABLE for INSERT operations
-- ============================================================================

-- Drop the VIEW if it exists (from earlier migrations)
DROP VIEW IF EXISTS daily_nutrition_summary CASCADE;

-- Create daily_nutrition_summary as a proper TABLE
CREATE TABLE IF NOT EXISTS daily_nutrition_summary (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    date DATE NOT NULL,
    total_calories INTEGER DEFAULT 0,
    total_protein DECIMAL(10,2) DEFAULT 0,
    total_carbs DECIMAL(10,2) DEFAULT 0,
    total_fat DECIMAL(10,2) DEFAULT 0,
    calorie_target INTEGER DEFAULT 2000,
    goal_achieved BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    -- Ensure one summary per user per day
    UNIQUE(user_id, date)
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_daily_nutrition_summary_user_date
ON daily_nutrition_summary(user_id, date DESC);

CREATE INDEX IF NOT EXISTS idx_daily_nutrition_summary_goal_achieved
ON daily_nutrition_summary(user_id, goal_achieved, date DESC);

-- Enable Row Level Security
ALTER TABLE daily_nutrition_summary ENABLE ROW LEVEL SECURITY;

-- RLS Policies
DROP POLICY IF EXISTS "Users can view own nutrition summary" ON daily_nutrition_summary;
DROP POLICY IF EXISTS "Users can insert own nutrition summary" ON daily_nutrition_summary;
DROP POLICY IF EXISTS "Users can update own nutrition summary" ON daily_nutrition_summary;
DROP POLICY IF EXISTS "Service role can manage all nutrition summaries" ON daily_nutrition_summary;

CREATE POLICY "Users can view own nutrition summary"
    ON daily_nutrition_summary FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own nutrition summary"
    ON daily_nutrition_summary FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own nutrition summary"
    ON daily_nutrition_summary FOR UPDATE
    USING (auth.uid() = user_id);

CREATE POLICY "Service role can manage all nutrition summaries"
    ON daily_nutrition_summary FOR ALL
    USING (auth.jwt() ->> 'role' = 'service_role');

-- Success message
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '✅ ================================================';
    RAISE NOTICE '✅ DAILY_NUTRITION_SUMMARY TABLE CREATED!';
    RAISE NOTICE '✅ ================================================';
    RAISE NOTICE '';
    RAISE NOTICE 'Table details:';
    RAISE NOTICE '  - Type: TABLE (not VIEW - can accept INSERTs)';
    RAISE NOTICE '  - Constraint: One summary per user per day';
    RAISE NOTICE '  - Indexes: user_date, goal_achieved';
    RAISE NOTICE '  - RLS: Enabled with proper policies';
    RAISE NOTICE '';
    RAISE NOTICE 'This fixes the bug: "cannot insert into view daily_nutrition_summary"';
    RAISE NOTICE '';
END $$;
