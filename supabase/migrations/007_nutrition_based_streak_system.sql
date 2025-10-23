-- ============================================================================
-- MIGRATION 007: NUTRITION-BASED STREAK SYSTEM
-- Date: October 23, 2025
-- Purpose: Complete rewrite of streak system to use nutrition_entries
--          instead of deleted health_metrics table
-- ============================================================================

-- PART 1: Extend daily_nutrition_summary table
-- ============================================================================
DO $$
BEGIN
    -- Add goal_achieved column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'daily_nutrition_summary'
        AND column_name = 'goal_achieved'
    ) THEN
        ALTER TABLE daily_nutrition_summary
        ADD COLUMN goal_achieved BOOLEAN DEFAULT FALSE;
    END IF;

    -- Add calorie_target column to store user's target at that time
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'daily_nutrition_summary'
        AND column_name = 'calorie_target'
    ) THEN
        ALTER TABLE daily_nutrition_summary
        ADD COLUMN calorie_target INTEGER DEFAULT 2000;
    END IF;

    -- Add updated_at timestamp
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'daily_nutrition_summary'
        AND column_name = 'updated_at'
    ) THEN
        ALTER TABLE daily_nutrition_summary
        ADD COLUMN updated_at TIMESTAMPTZ DEFAULT NOW();
    END IF;
END $$;

-- Create index for faster queries
CREATE INDEX IF NOT EXISTS idx_daily_nutrition_summary_user_date
ON daily_nutrition_summary(user_id, date DESC);

CREATE INDEX IF NOT EXISTS idx_daily_nutrition_summary_goal_achieved
ON daily_nutrition_summary(user_id, goal_achieved, date DESC);

-- ============================================================================
-- PART 2: Function to update daily_nutrition_summary
-- ============================================================================
CREATE OR REPLACE FUNCTION update_daily_nutrition_summary()
RETURNS TRIGGER AS $$
DECLARE
    v_user_id UUID;
    v_date DATE;
    v_total_calories INTEGER;
    v_total_protein DECIMAL(10,2);
    v_total_carbs DECIMAL(10,2);
    v_total_fat DECIMAL(10,2);
    v_calorie_target INTEGER;
    v_goal_achieved BOOLEAN;
    v_min_calories INTEGER;
    v_max_calories INTEGER;
BEGIN
    -- Get user_id and date from the trigger
    v_user_id := COALESCE(NEW.user_id, OLD.user_id);
    v_date := COALESCE(NEW.date::DATE, OLD.date::DATE);

    -- Get user's calorie target from profile
    SELECT COALESCE(daily_calories_target, 2000)
    INTO v_calorie_target
    FROM profiles
    WHERE id = v_user_id;

    -- If no target found, use default
    v_calorie_target := COALESCE(v_calorie_target, 2000);

    -- Calculate daily totals from nutrition_entries
    SELECT
        COALESCE(SUM(calories), 0)::INTEGER,
        COALESCE(SUM(protein), 0)::DECIMAL(10,2),
        COALESCE(SUM(carbs), 0)::DECIMAL(10,2),
        COALESCE(SUM(fat), 0)::DECIMAL(10,2)
    INTO
        v_total_calories,
        v_total_protein,
        v_total_carbs,
        v_total_fat
    FROM nutrition_entries
    WHERE user_id = v_user_id
    AND date = v_date;

    -- Calculate if goal is achieved (80% - 110% of target)
    v_min_calories := (v_calorie_target * 0.8)::INTEGER;
    v_max_calories := (v_calorie_target * 1.1)::INTEGER;
    v_goal_achieved := (v_total_calories >= v_min_calories
                       AND v_total_calories <= v_max_calories
                       AND v_total_calories > 0);

    -- Upsert into daily_nutrition_summary
    INSERT INTO daily_nutrition_summary (
        user_id,
        date,
        total_calories,
        total_protein,
        total_carbs,
        total_fat,
        calorie_target,
        goal_achieved,
        updated_at
    ) VALUES (
        v_user_id,
        v_date,
        v_total_calories,
        v_total_protein,
        v_total_carbs,
        v_total_fat,
        v_calorie_target,
        v_goal_achieved,
        NOW()
    )
    ON CONFLICT (user_id, date)
    DO UPDATE SET
        total_calories = EXCLUDED.total_calories,
        total_protein = EXCLUDED.total_protein,
        total_carbs = EXCLUDED.total_carbs,
        total_fat = EXCLUDED.total_fat,
        calorie_target = EXCLUDED.calorie_target,
        goal_achieved = EXCLUDED.goal_achieved,
        updated_at = NOW();

    RAISE NOTICE 'Updated daily_nutrition_summary for user % on %: % kcal (goal: % kcal, achieved: %)',
        v_user_id, v_date, v_total_calories, v_calorie_target, v_goal_achieved;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- PART 3: Create trigger on nutrition_entries
-- ============================================================================
DROP TRIGGER IF EXISTS trigger_update_daily_nutrition_summary ON nutrition_entries;

CREATE TRIGGER trigger_update_daily_nutrition_summary
    AFTER INSERT OR UPDATE OR DELETE ON nutrition_entries
    FOR EACH ROW
    EXECUTE FUNCTION update_daily_nutrition_summary();

-- ============================================================================
-- PART 4: Enhanced streak update function (nutrition-based)
-- ============================================================================
CREATE OR REPLACE FUNCTION update_nutrition_streak(p_user_id UUID, p_date DATE)
RETURNS void AS $$
DECLARE
    v_summary RECORD;
    v_streak RECORD;
    v_yesterday DATE;
    v_new_streak INT;
    v_new_longest INT;
    v_grace_days_to_use INT;
    v_action TEXT;
    v_reason TEXT;
BEGIN
    -- Get today's nutrition summary
    SELECT * INTO v_summary
    FROM daily_nutrition_summary
    WHERE user_id = p_user_id AND date = p_date;

    -- If no summary exists yet, exit early
    IF NOT FOUND THEN
        RAISE NOTICE 'No nutrition summary found for user % on %', p_user_id, p_date;
        RETURN;
    END IF;

    -- Get current streak
    SELECT * INTO v_streak
    FROM streaks
    WHERE user_id = p_user_id;

    -- If no streak exists, create it
    IF NOT FOUND THEN
        INSERT INTO streaks (
            user_id,
            current_streak,
            longest_streak,
            last_completed_date,
            last_activity_date,
            last_checked_date,
            grace_days_available,
            grace_days_used,
            consecutive_missed_days,
            created_at,
            updated_at
        ) VALUES (
            p_user_id,
            CASE WHEN v_summary.goal_achieved THEN 1 ELSE 0 END,
            CASE WHEN v_summary.goal_achieved THEN 1 ELSE 0 END,
            CASE WHEN v_summary.goal_achieved THEN p_date ELSE NULL END,
            p_date,
            p_date,
            2,
            0,
            0,
            NOW(),
            NOW()
        );

        -- Log to history
        INSERT INTO streak_history (
            user_id, date, previous_streak, new_streak, action, reason, all_goals_achieved
        ) VALUES (
            p_user_id, p_date, 0,
            CASE WHEN v_summary.goal_achieved THEN 1 ELSE 0 END,
            'increment', 'Initial streak creation', v_summary.goal_achieved
        );

        RAISE NOTICE 'Created initial streak for user %: achieved=%', p_user_id, v_summary.goal_achieved;
        RETURN;
    END IF;

    v_yesterday := p_date - INTERVAL '1 day';

    -- Determine action based on goal achievement and date continuity
    IF v_summary.goal_achieved THEN
        -- Goals achieved today
        IF v_streak.last_completed_date = v_yesterday THEN
            -- Continuing streak
            v_new_streak := v_streak.current_streak + 1;
            v_action := 'increment';
            v_reason := 'Goals achieved, continuing from yesterday';
            v_grace_days_to_use := 0;
        ELSIF v_streak.last_completed_date = p_date THEN
            -- Already processed today
            v_new_streak := v_streak.current_streak;
            v_action := 'maintain';
            v_reason := 'Already processed today';
            v_grace_days_to_use := 0;
        ELSIF v_streak.last_completed_date < v_yesterday THEN
            -- Gap exists, start new streak
            v_new_streak := 1;
            v_action := 'reset';
            v_reason := format('Gap detected, starting new streak (last: %s, current: %s)',
                             v_streak.last_completed_date, p_date);
            v_grace_days_to_use := 0;
        ELSE
            -- Edge case
            v_new_streak := v_streak.current_streak;
            v_action := 'maintain';
            v_reason := 'Edge case - maintaining current streak';
            v_grace_days_to_use := 0;
        END IF;
    ELSE
        -- Goals not achieved today - don't modify streak yet
        v_new_streak := v_streak.current_streak;
        v_action := 'maintain';
        v_reason := 'Goals not achieved yet';
        v_grace_days_to_use := 0;
    END IF;

    v_new_longest := GREATEST(COALESCE(v_streak.longest_streak, 0), v_new_streak);

    -- Update streak record
    UPDATE streaks SET
        current_streak = v_new_streak,
        longest_streak = v_new_longest,
        last_completed_date = CASE
            WHEN v_summary.goal_achieved THEN p_date
            ELSE last_completed_date
        END,
        last_activity_date = p_date,
        last_checked_date = p_date,
        consecutive_missed_days = CASE
            WHEN v_summary.goal_achieved THEN 0
            ELSE consecutive_missed_days
        END,
        grace_days_used = CASE
            WHEN v_action = 'reset' AND v_new_streak = 0 THEN 0
            ELSE COALESCE(grace_days_used, 0) + v_grace_days_to_use
        END,
        updated_at = NOW()
    WHERE user_id = p_user_id;

    -- Log to history only if there's a change
    IF v_action != 'maintain' OR v_streak.current_streak != v_new_streak THEN
        INSERT INTO streak_history (
            user_id, date, previous_streak, new_streak, action, reason,
            all_goals_achieved, grace_days_used
        ) VALUES (
            p_user_id, p_date, v_streak.current_streak, v_new_streak, v_action,
            v_reason, v_summary.goal_achieved, v_grace_days_to_use
        );
    END IF;

    RAISE NOTICE 'Streak updated for user %: % -> % (%)',
        p_user_id, v_streak.current_streak, v_new_streak, v_action;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- PART 5: Trigger to auto-update streaks when daily_nutrition_summary changes
-- ============================================================================
DROP TRIGGER IF EXISTS trigger_update_streak_from_nutrition ON daily_nutrition_summary;

CREATE OR REPLACE FUNCTION trigger_update_streak_from_nutrition()
RETURNS TRIGGER AS $$
BEGIN
    -- Only update streak if goal_achieved changed or new record
    IF TG_OP = 'INSERT' OR (TG_OP = 'UPDATE' AND NEW.goal_achieved != OLD.goal_achieved) THEN
        PERFORM update_nutrition_streak(NEW.user_id, NEW.date);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_streak_from_nutrition
    AFTER INSERT OR UPDATE ON daily_nutrition_summary
    FOR EACH ROW
    EXECUTE FUNCTION trigger_update_streak_from_nutrition();

-- ============================================================================
-- PART 6: Backfill existing data
-- ============================================================================
DO $$
DECLARE
    v_user_id UUID := '5acc8e5f-03b2-48cf-bd29-f7a2f1fc06e9';
    v_date DATE;
BEGIN
    RAISE NOTICE '=== BACKFILLING DATA FOR USER % ===', v_user_id;

    -- Process all existing nutrition entries to update daily_nutrition_summary
    FOR v_date IN
        SELECT DISTINCT date::DATE
        FROM nutrition_entries
        WHERE user_id = v_user_id
        ORDER BY date
    LOOP
        -- Manually trigger the update function for each date
        PERFORM update_daily_nutrition_summary()
        FROM nutrition_entries
        WHERE user_id = v_user_id AND date = v_date
        LIMIT 1;

        RAISE NOTICE 'Processed date: %', v_date;
    END LOOP;

    -- Now update streaks based on the daily summaries
    FOR v_date IN
        SELECT DISTINCT date
        FROM daily_nutrition_summary
        WHERE user_id = v_user_id
        AND goal_achieved = TRUE
        ORDER BY date
    LOOP
        PERFORM update_nutrition_streak(v_user_id, v_date);
        RAISE NOTICE 'Updated streak for date: %', v_date;
    END LOOP;

    RAISE NOTICE '=== BACKFILL COMPLETE ===';
END $$;

-- ============================================================================
-- PART 7: Create helper function for manual sync (called from app)
-- ============================================================================
CREATE OR REPLACE FUNCTION sync_nutrition_and_streaks(p_user_id UUID, p_date DATE DEFAULT CURRENT_DATE)
RETURNS JSON AS $$
DECLARE
    v_result JSON;
    v_summary RECORD;
    v_streak RECORD;
BEGIN
    -- First, ensure daily_nutrition_summary is up to date
    PERFORM update_daily_nutrition_summary()
    FROM nutrition_entries
    WHERE user_id = p_user_id AND date = p_date
    LIMIT 1;

    -- Then update streak
    PERFORM update_nutrition_streak(p_user_id, p_date);

    -- Get updated summary
    SELECT * INTO v_summary
    FROM daily_nutrition_summary
    WHERE user_id = p_user_id AND date = p_date;

    -- Get updated streak
    SELECT * INTO v_streak
    FROM streaks
    WHERE user_id = p_user_id;

    -- Return result as JSON
    v_result := json_build_object(
        'success', true,
        'date', p_date,
        'summary', json_build_object(
            'total_calories', v_summary.total_calories,
            'calorie_target', v_summary.calorie_target,
            'goal_achieved', v_summary.goal_achieved
        ),
        'streak', json_build_object(
            'current_streak', v_streak.current_streak,
            'longest_streak', v_streak.longest_streak,
            'last_completed_date', v_streak.last_completed_date
        )
    );

    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION sync_nutrition_and_streaks(UUID, DATE) TO authenticated;
GRANT EXECUTE ON FUNCTION sync_nutrition_and_streaks(UUID, DATE) TO service_role;

-- ============================================================================
-- PART 8: Clean up old health_metrics-based functions
-- ============================================================================
DROP FUNCTION IF EXISTS calculate_goal_achievements(UUID);
DROP FUNCTION IF EXISTS update_user_streak(UUID, DATE);
DROP FUNCTION IF EXISTS trigger_update_streak_always();
DROP TRIGGER IF EXISTS trigger_auto_update_streak ON health_metrics;

-- ============================================================================
-- PART 9: Add RLS policies for daily_nutrition_summary
-- ============================================================================
ALTER TABLE daily_nutrition_summary ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own nutrition summary" ON daily_nutrition_summary;
DROP POLICY IF EXISTS "Users can insert own nutrition summary" ON daily_nutrition_summary;
DROP POLICY IF EXISTS "Users can update own nutrition summary" ON daily_nutrition_summary;

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

-- ============================================================================
-- PART 10: Verification and success message
-- ============================================================================
DO $$
DECLARE
    v_user_id UUID := '5acc8e5f-03b2-48cf-bd29-f7a2f1fc06e9';
    v_streak RECORD;
    v_summary_count INT;
BEGIN
    -- Get streak data
    SELECT * INTO v_streak FROM streaks WHERE user_id = v_user_id;

    -- Count daily summaries
    SELECT COUNT(*) INTO v_summary_count
    FROM daily_nutrition_summary
    WHERE user_id = v_user_id;

    RAISE NOTICE '';
    RAISE NOTICE '✅ ============================================';
    RAISE NOTICE '✅ NUTRITION-BASED STREAK SYSTEM DEPLOYED!';
    RAISE NOTICE '✅ ============================================';
    RAISE NOTICE '';
    RAISE NOTICE 'Current Status for User %:', v_user_id;
    RAISE NOTICE '  - Current Streak: %', v_streak.current_streak;
    RAISE NOTICE '  - Longest Streak: %', v_streak.longest_streak;
    RAISE NOTICE '  - Last Completed: %', v_streak.last_completed_date;
    RAISE NOTICE '  - Daily Summaries: % days', v_summary_count;
    RAISE NOTICE '';
    RAISE NOTICE 'Features Enabled:';
    RAISE NOTICE '  ✓ Auto-update daily_nutrition_summary on nutrition_entries change';
    RAISE NOTICE '  ✓ Auto-update streaks when goals achieved';
    RAISE NOTICE '  ✓ 80-110%% calorie range for goal achievement';
    RAISE NOTICE '  ✓ Historical data backfilled';
    RAISE NOTICE '  ✓ Manual sync function available';
    RAISE NOTICE '  ✓ Streak history logging enabled';
    RAISE NOTICE '';
END $$;
