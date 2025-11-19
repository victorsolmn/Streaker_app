-- ============================================================================
-- MIGRATION 010: FIX STREAK TRIGGER LOGIC
-- Date: November 19, 2025
-- Purpose: Fix the trigger condition that prevents streak updates on consecutive
--          successful days
-- ============================================================================

-- Problem: The original trigger only fired when goal_achieved CHANGED value
-- This meant consecutive days of achievement didn't update the streak
--
-- Before: IF TG_OP = 'INSERT' OR (TG_OP = 'UPDATE' AND NEW.goal_achieved != OLD.goal_achieved)
-- After:  IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE'
--
-- This ensures streak is recalculated every time daily_nutrition_summary changes

-- ============================================================================
-- PART 1: Drop and recreate the trigger function with correct logic
-- ============================================================================

DROP TRIGGER IF EXISTS trigger_update_streak_from_nutrition ON daily_nutrition_summary;

CREATE OR REPLACE FUNCTION trigger_update_streak_from_nutrition()
RETURNS TRIGGER AS $$
BEGIN
    -- Update streak on every INSERT or UPDATE
    -- The update_nutrition_streak function itself handles all the logic
    -- for determining if the streak should increment, reset, etc.
    IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN
        PERFORM update_nutrition_streak(NEW.user_id, NEW.date);
        RAISE NOTICE 'Triggered streak update for user % on % (operation: %)',
                     NEW.user_id, NEW.date, TG_OP;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Recreate the trigger
CREATE TRIGGER trigger_update_streak_from_nutrition
    AFTER INSERT OR UPDATE ON daily_nutrition_summary
    FOR EACH ROW
    EXECUTE FUNCTION trigger_update_streak_from_nutrition();

RAISE NOTICE '✅ Streak trigger logic has been fixed';

-- ============================================================================
-- PART 2: Backfill any missing streak updates for existing data
-- ============================================================================

DO $$
DECLARE
    v_user_id UUID := '5acc8e5f-03b2-48cf-bd29-f7a2f1fc06e9';
    v_date DATE;
    v_count INTEGER := 0;
BEGIN
    RAISE NOTICE '=== BACKFILLING STREAK UPDATES ===';

    -- Process all days with achieved goals in chronological order
    FOR v_date IN
        SELECT DISTINCT date
        FROM daily_nutrition_summary
        WHERE user_id = v_user_id
        AND goal_achieved = TRUE
        ORDER BY date ASC
    LOOP
        -- Recalculate streak for each successful day
        PERFORM update_nutrition_streak(v_user_id, v_date);
        v_count := v_count + 1;
        RAISE NOTICE 'Recalculated streak for %', v_date;
    END LOOP;

    RAISE NOTICE '=== BACKFILL COMPLETE: Processed % days ===', v_count;

    -- Show final streak status
    DECLARE
        v_current_streak INTEGER;
        v_longest_streak INTEGER;
    BEGIN
        SELECT current_streak, longest_streak
        INTO v_current_streak, v_longest_streak
        FROM streaks
        WHERE user_id = v_user_id;

        RAISE NOTICE '📊 Final Streak Status:';
        RAISE NOTICE '   Current Streak: % days', v_current_streak;
        RAISE NOTICE '   Longest Streak: % days', v_longest_streak;
    END;
END $$;

-- ============================================================================
-- PART 3: Add explanatory comment
-- ============================================================================

COMMENT ON FUNCTION trigger_update_streak_from_nutrition() IS
'Triggers streak recalculation whenever daily_nutrition_summary is updated.
Changed from conditional (goal_achieved changed) to always trigger on UPDATE
to ensure consecutive successful days properly increment the streak.';

-- ============================================================================
-- VERIFICATION QUERIES (Run these to verify the fix)
-- ============================================================================

-- Check recent streak updates
-- SELECT date, total_calories, calorie_target, goal_achieved
-- FROM daily_nutrition_summary
-- WHERE user_id = '5acc8e5f-03b2-48cf-bd29-f7a2f1fc06e9'
-- ORDER BY date DESC
-- LIMIT 7;

-- Check current streak status
-- SELECT current_streak, longest_streak, last_completed_date, last_checked_date
-- FROM streaks
-- WHERE user_id = '5acc8e5f-03b2-48cf-bd29-f7a2f1fc06e9';

-- Check streak history
-- SELECT date, previous_streak, new_streak, action, reason
-- FROM streak_history
-- WHERE user_id = '5acc8e5f-03b2-48cf-bd29-f7a2f1fc06e9'
-- ORDER BY date DESC
-- LIMIT 10;

RAISE NOTICE '✅ Migration 010 completed successfully';
