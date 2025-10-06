-- ============================================
-- TEST SCRIPT: Verify October 3rd Fix
-- Purpose: Validate that the streak system fix worked for the reported issue
-- User: 5acc8e5f-03b2-48cf-bd29-f7a2f1fc06e9 (Vic)
-- Date: 2025-10-03
-- ============================================

\echo '🔍 Testing October 3rd Streak Fix...'
\echo ''

-- Step 1: Check nutrition entries for Oct 3
\echo '📊 Step 1: Nutrition entries for 2025-10-03'
SELECT
  food_name,
  calories,
  protein,
  created_at AT TIME ZONE 'UTC' as created_at_utc
FROM nutrition_entries
WHERE user_id = '5acc8e5f-03b2-48cf-bd29-f7a2f1fc06e9'
  AND date = '2025-10-03'
ORDER BY created_at;

\echo ''
\echo '📊 Total nutrition for Oct 3:'
SELECT
  SUM(calories) as total_calories,
  SUM(protein) as total_protein,
  SUM(carbs) as total_carbs,
  SUM(fat) as total_fat
FROM nutrition_entries
WHERE user_id = '5acc8e5f-03b2-48cf-bd29-f7a2f1fc06e9'
  AND date = '2025-10-03';

\echo ''
\echo '============================================'

-- Step 2: Check health_metrics for Oct 3
\echo '🏃 Step 2: Health metrics for 2025-10-03'
SELECT
  date,
  steps,
  steps_goal,
  steps_achieved,
  calories_consumed,
  calories_goal,
  calories_achieved,
  sleep_hours,
  sleep_goal,
  sleep_achieved,
  nutrition_achieved,
  all_goals_achieved,
  updated_at AT TIME ZONE 'UTC' as updated_at_utc
FROM health_metrics
WHERE user_id = '5acc8e5f-03b2-48cf-bd29-f7a2f1fc06e9'
  AND date = '2025-10-03';

\echo ''
\echo '============================================'

-- Step 3: Check streak status
\echo '🔥 Step 3: Current streak status'
SELECT
  current_streak,
  longest_streak,
  total_days_completed,
  last_completed_date,
  last_activity_date,
  updated_at AT TIME ZONE 'UTC' as updated_at_utc
FROM streaks
WHERE user_id = '5acc8e5f-03b2-48cf-bd29-f7a2f1fc06e9'
  AND streak_type = 'daily';

\echo ''
\echo '============================================'

-- Step 4: Verify the fix
\echo '✅ Step 4: Verification Summary'

DO $$
DECLARE
  v_nutrition_total INT;
  v_health_calories INT;
  v_all_goals BOOLEAN;
  v_current_streak INT;
  v_status TEXT;
BEGIN
  -- Get nutrition total
  SELECT COALESCE(SUM(calories), 0)::INT INTO v_nutrition_total
  FROM nutrition_entries
  WHERE user_id = '5acc8e5f-03b2-48cf-bd29-f7a2f1fc06e9'
    AND date = '2025-10-03';

  -- Get health_metrics calories
  SELECT COALESCE(calories_consumed, 0)::INT INTO v_health_calories
  FROM health_metrics
  WHERE user_id = '5acc8e5f-03b2-48cf-bd29-f7a2f1fc06e9'
    AND date = '2025-10-03';

  -- Get goal achievement status
  SELECT COALESCE(all_goals_achieved, FALSE) INTO v_all_goals
  FROM health_metrics
  WHERE user_id = '5acc8e5f-03b2-48cf-bd29-f7a2f1fc06e9'
    AND date = '2025-10-03';

  -- Get current streak
  SELECT COALESCE(current_streak, 0) INTO v_current_streak
  FROM streaks
  WHERE user_id = '5acc8e5f-03b2-48cf-bd29-f7a2f1fc06e9'
    AND streak_type = 'daily';

  -- Determine status
  IF v_nutrition_total = v_health_calories AND v_health_calories > 0 THEN
    v_status := '✅ PASS: Nutrition synced correctly';
  ELSE
    v_status := '❌ FAIL: Nutrition not synced (nutrition=' || v_nutrition_total || ', health=' || v_health_calories || ')';
  END IF;

  -- Print results
  RAISE NOTICE '
╔════════════════════════════════════════════════════╗
║          OCTOBER 3RD FIX VERIFICATION              ║
╠════════════════════════════════════════════════════╣
║ Nutrition Logged:    % calories                 ║
║ Health Metrics:      % calories                 ║
║ Sync Status:         %                            ║
║                                                    ║
║ All Goals Achieved:  %                            ║
║ Current Streak:      % days                      ║
║                                                    ║
║ %                                                  ║
╚════════════════════════════════════════════════════╝
',
    LPAD(v_nutrition_total::TEXT, 4),
    LPAD(v_health_calories::TEXT, 4),
    CASE WHEN v_nutrition_total = v_health_calories THEN '✅ SYNCED' ELSE '❌ NOT SYNCED' END,
    CASE WHEN v_all_goals THEN '✅ YES' ELSE '❌ NO' END,
    LPAD(v_current_streak::TEXT, 2),
    v_status;

  -- Additional checks
  IF v_all_goals AND v_current_streak = 0 THEN
    RAISE WARNING 'Goals achieved but streak is 0 - may need manual update_user_streak() call';
  END IF;

END $$;

\echo ''
\echo '============================================'

-- Step 5: Check recent days for pattern
\echo '📅 Step 5: Recent days summary (last 7 days)'
SELECT
  h.date,
  h.steps,
  h.calories_consumed,
  h.sleep_hours,
  h.all_goals_achieved,
  CASE
    WHEN h.all_goals_achieved THEN '🔥'
    ELSE '❌'
  END as streak_icon
FROM health_metrics h
WHERE h.user_id = '5acc8e5f-03b2-48cf-bd29-f7a2f1fc06e9'
  AND h.date >= CURRENT_DATE - INTERVAL '7 days'
ORDER BY h.date DESC;

\echo ''
\echo '🎉 Test complete! Review results above.'
\echo ''
