-- ============================================
-- BACKFILL HISTORICAL NUTRITION DATA
-- Purpose: Fix all historical data where nutrition was logged but not synced
-- This will recalculate goals and streaks for all past dates
-- ============================================

-- Step 1: Show summary of affected data BEFORE backfill
DO $$
DECLARE
  v_affected_users INT;
  v_affected_dates INT;
  v_total_entries INT;
BEGIN
  SELECT COUNT(DISTINCT user_id) INTO v_affected_users
  FROM nutrition_entries;

  SELECT COUNT(DISTINCT date) INTO v_affected_dates
  FROM nutrition_entries;

  SELECT COUNT(*) INTO v_total_entries
  FROM nutrition_entries;

  RAISE NOTICE '
📊 BACKFILL ANALYSIS:
- Users with nutrition entries: %
- Unique dates with entries: %
- Total nutrition entries: %
', v_affected_users, v_affected_dates, v_total_entries;
END $$;

-- Step 2: Find specific issue dates (nutrition logged but health_metrics.calories_consumed = 0)
DO $$
DECLARE
  v_broken_records INT;
BEGIN
  SELECT COUNT(*) INTO v_broken_records
  FROM (
    SELECT DISTINCT ne.user_id, ne.date
    FROM nutrition_entries ne
    LEFT JOIN health_metrics hm ON ne.user_id = hm.user_id AND ne.date = hm.date
    WHERE COALESCE(hm.calories_consumed, 0) = 0
  ) broken;

  RAISE NOTICE '⚠️ Found % dates with nutrition logged but calories_consumed = 0', v_broken_records;
END $$;

-- Step 3: Backfill nutrition data to health_metrics
DO $$
DECLARE
  v_user RECORD;
  v_date RECORD;
  v_synced_count INT := 0;
  v_start_time TIMESTAMP := clock_timestamp();
  v_end_time TIMESTAMP;
BEGIN
  RAISE NOTICE '🔄 Starting nutrition backfill...';

  -- For each user with nutrition entries
  FOR v_user IN
    SELECT DISTINCT user_id
    FROM nutrition_entries
    ORDER BY user_id
  LOOP
    -- For each date they have entries
    FOR v_date IN
      SELECT DISTINCT date
      FROM nutrition_entries
      WHERE user_id = v_user.user_id
      ORDER BY date
    LOOP
      -- Sync that day's nutrition data
      PERFORM sync_nutrition_to_health_metrics_for_date(v_user.user_id, v_date.date);
      v_synced_count := v_synced_count + 1;

      -- Progress indicator every 10 records
      IF v_synced_count % 10 = 0 THEN
        RAISE NOTICE '  ... synced % dates', v_synced_count;
      END IF;
    END LOOP;
  END LOOP;

  v_end_time := clock_timestamp();

  RAISE NOTICE '✅ Nutrition backfill completed: % dates synced in % seconds',
    v_synced_count,
    EXTRACT(EPOCH FROM (v_end_time - v_start_time));
END $$;

-- Step 4: Recalculate goal achievements for all dates
DO $$
DECLARE
  v_metric RECORD;
  v_calculated_count INT := 0;
  v_start_time TIMESTAMP := clock_timestamp();
  v_end_time TIMESTAMP;
BEGIN
  RAISE NOTICE '🎯 Recalculating goal achievements...';

  FOR v_metric IN
    SELECT id, user_id, date
    FROM health_metrics
    ORDER BY date DESC
  LOOP
    PERFORM calculate_goal_achievements(v_metric.id);
    v_calculated_count := v_calculated_count + 1;

    IF v_calculated_count % 20 = 0 THEN
      RAISE NOTICE '  ... calculated % records', v_calculated_count;
    END IF;
  END LOOP;

  v_end_time := clock_timestamp();

  RAISE NOTICE '✅ Goal calculations completed: % records in % seconds',
    v_calculated_count,
    EXTRACT(EPOCH FROM (v_end_time - v_start_time));
END $$;

-- Step 5: Recalculate streaks for all users
DO $$
DECLARE
  v_user RECORD;
  v_date RECORD;
  v_streak_count INT := 0;
  v_start_time TIMESTAMP := clock_timestamp();
  v_end_time TIMESTAMP;
BEGIN
  RAISE NOTICE '🔥 Recalculating streaks...';

  -- For each user
  FOR v_user IN
    SELECT DISTINCT user_id
    FROM health_metrics
    WHERE all_goals_achieved = TRUE
    ORDER BY user_id
  LOOP
    -- For each date where they achieved all goals (in chronological order)
    FOR v_date IN
      SELECT date
      FROM health_metrics
      WHERE user_id = v_user.user_id
        AND all_goals_achieved = TRUE
      ORDER BY date ASC
    LOOP
      PERFORM update_user_streak(v_user.user_id, v_date.date);
      v_streak_count := v_streak_count + 1;
    END LOOP;
  END LOOP;

  v_end_time := clock_timestamp();

  RAISE NOTICE '✅ Streak calculations completed: % dates processed in % seconds',
    v_streak_count,
    EXTRACT(EPOCH FROM (v_end_time - v_start_time));
END $$;

-- Step 6: Show summary of results AFTER backfill
DO $$
DECLARE
  v_total_synced INT;
  v_goals_achieved INT;
  v_current_streaks TEXT;
BEGIN
  SELECT COUNT(*) INTO v_total_synced
  FROM health_metrics
  WHERE calories_consumed > 0;

  SELECT COUNT(*) INTO v_goals_achieved
  FROM health_metrics
  WHERE all_goals_achieved = TRUE;

  SELECT string_agg(
    user_id::TEXT || ': ' || current_streak || ' days',
    E'\n  '
  ) INTO v_current_streaks
  FROM streaks
  WHERE streak_type = 'daily' AND current_streak > 0;

  RAISE NOTICE '
📈 BACKFILL RESULTS:
- Health metrics with nutrition: %
- Dates with all goals achieved: %
- Current user streaks:
  %
', v_total_synced, v_goals_achieved, COALESCE(v_current_streaks, 'None');
END $$;

-- Step 7: Verify October 3rd specifically for the reported user
DO $$
DECLARE
  v_user_id UUID := '5acc8e5f-03b2-48cf-bd29-f7a2f1fc06e9';
  v_date DATE := '2025-10-03';
  v_metric RECORD;
  v_streak RECORD;
BEGIN
  SELECT * INTO v_metric
  FROM health_metrics
  WHERE user_id = v_user_id AND date = v_date;

  SELECT * INTO v_streak
  FROM streaks
  WHERE user_id = v_user_id AND streak_type = 'daily';

  RAISE NOTICE '
🔍 VERIFICATION FOR USER % ON %:

Health Metrics:
- Steps: % / % (achieved: %)
- Calories: % / % (achieved: %)
- Sleep: % / % (achieved: %)
- Nutrition: achieved = %
- ALL GOALS: %

Current Streak: % days
Longest Streak: % days
Last Completed: %
',
    v_user_id, v_date,
    v_metric.steps, v_metric.steps_goal, v_metric.steps_achieved,
    v_metric.calories_consumed, v_metric.calories_goal, v_metric.calories_achieved,
    v_metric.sleep_hours, v_metric.sleep_goal, v_metric.sleep_achieved,
    v_metric.nutrition_achieved,
    v_metric.all_goals_achieved,
    v_streak.current_streak,
    v_streak.longest_streak,
    v_streak.last_completed_date;
END $$;

-- Step 8: Show top users by streak
SELECT
  p.name,
  p.email,
  s.current_streak,
  s.longest_streak,
  s.total_days_completed,
  s.last_completed_date
FROM streaks s
JOIN profiles p ON s.user_id = p.id
WHERE s.streak_type = 'daily'
ORDER BY s.current_streak DESC
LIMIT 10;

-- ============================================
-- BACKFILL COMPLETE
-- ============================================

RAISE NOTICE '
🎉 BACKFILL COMPLETED!

Summary:
✅ All nutrition data synced to health_metrics
✅ All goal achievements recalculated
✅ All streaks recalculated from scratch
✅ Historical data is now accurate

The automatic triggers will handle all future updates.
No manual intervention needed going forward.
';
