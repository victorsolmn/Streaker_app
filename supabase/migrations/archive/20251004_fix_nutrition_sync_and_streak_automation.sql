-- ============================================
-- STREAK SYSTEM FIX - AUTOMATIC NUTRITION SYNC & STREAK CALCULATION
-- Migration: 20251004_fix_nutrition_sync_and_streak_automation.sql
-- Purpose: Fix broken nutrition sync and automate streak calculations
-- Date: October 4, 2025
-- ============================================

-- ============================================
-- STEP 1: CREATE NUTRITION AGGREGATION FUNCTION
-- ============================================

CREATE OR REPLACE FUNCTION aggregate_daily_nutrition(p_user_id UUID, p_date DATE)
RETURNS TABLE(
  total_calories DECIMAL,
  total_protein DECIMAL,
  total_carbs DECIMAL,
  total_fat DECIMAL,
  total_fiber DECIMAL
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    COALESCE(SUM(calories), 0) AS total_calories,
    COALESCE(SUM(protein), 0) AS total_protein,
    COALESCE(SUM(carbs), 0) AS total_carbs,
    COALESCE(SUM(fat), 0) AS total_fat,
    COALESCE(SUM(fiber), 0) AS total_fiber
  FROM nutrition_entries
  WHERE user_id = p_user_id
    AND date = p_date;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- STEP 2: CREATE AUTO-SYNC TRIGGER FUNCTION
-- ============================================

CREATE OR REPLACE FUNCTION sync_nutrition_to_health_metrics()
RETURNS TRIGGER AS $$
DECLARE
  v_nutrition RECORD;
  v_date DATE;
  v_user_id UUID;
BEGIN
  -- Determine the affected date and user
  IF TG_OP = 'DELETE' THEN
    v_date := OLD.date;
    v_user_id := OLD.user_id;
  ELSE
    v_date := NEW.date;
    v_user_id := NEW.user_id;
  END IF;

  -- Aggregate nutrition data for this user/date
  SELECT * INTO v_nutrition
  FROM aggregate_daily_nutrition(v_user_id, v_date);

  -- Update or create health_metrics entry
  INSERT INTO health_metrics (
    user_id, date,
    calories_consumed, protein, carbs, fat, fiber,
    updated_at
  ) VALUES (
    v_user_id, v_date,
    v_nutrition.total_calories,
    v_nutrition.total_protein,
    v_nutrition.total_carbs,
    v_nutrition.total_fat,
    v_nutrition.total_fiber,
    NOW()
  )
  ON CONFLICT (user_id, date)
  DO UPDATE SET
    calories_consumed = EXCLUDED.calories_consumed,
    protein = EXCLUDED.protein,
    carbs = EXCLUDED.carbs,
    fat = EXCLUDED.fat,
    fiber = EXCLUDED.fiber,
    updated_at = NOW();

  -- Log success (if audit table exists)
  BEGIN
    INSERT INTO sync_audit_log (user_id, sync_type, date_synced, success)
    VALUES (v_user_id, 'nutrition_sync', v_date, TRUE);
  EXCEPTION WHEN undefined_table THEN
    -- Ignore if audit table doesn't exist
    NULL;
  END;

  RETURN NEW;

EXCEPTION WHEN OTHERS THEN
  -- Log error (if audit table exists)
  BEGIN
    INSERT INTO sync_audit_log (user_id, sync_type, date_synced, success, error_message)
    VALUES (v_user_id, 'nutrition_sync', v_date, FALSE, SQLERRM);
  EXCEPTION WHEN undefined_table THEN
    NULL;
  END;

  RAISE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- STEP 3: ATTACH TRIGGER TO nutrition_entries
-- ============================================

-- Drop existing trigger if exists
DROP TRIGGER IF EXISTS trigger_sync_nutrition_to_health_metrics ON nutrition_entries;

-- Create trigger for INSERT, UPDATE, DELETE
CREATE TRIGGER trigger_sync_nutrition_to_health_metrics
  AFTER INSERT OR UPDATE OR DELETE ON nutrition_entries
  FOR EACH ROW
  EXECUTE FUNCTION sync_nutrition_to_health_metrics();

COMMENT ON TRIGGER trigger_sync_nutrition_to_health_metrics ON nutrition_entries IS
'Automatically syncs nutrition totals to health_metrics whenever nutrition entries change';

-- ============================================
-- STEP 4: CREATE GOAL ACHIEVEMENT CALCULATION FUNCTION
-- ============================================

CREATE OR REPLACE FUNCTION calculate_goal_achievements(p_metric_id UUID)
RETURNS void AS $$
DECLARE
  v_metric RECORD;
  v_steps_achieved BOOLEAN;
  v_calories_achieved BOOLEAN;
  v_sleep_achieved BOOLEAN;
  v_water_achieved BOOLEAN;
  v_nutrition_achieved BOOLEAN;
  v_all_goals_achieved BOOLEAN;
BEGIN
  -- Get the health metric
  SELECT * INTO v_metric
  FROM health_metrics
  WHERE id = p_metric_id;

  IF NOT FOUND THEN
    RETURN;
  END IF;

  -- Calculate achievements (80% threshold for flexibility, matching Flutter logic)
  v_steps_achieved := COALESCE(v_metric.steps, 0) >= (COALESCE(v_metric.steps_goal, 10000) * 0.8);

  v_calories_achieved := (COALESCE(v_metric.calories_consumed, 0) <= (COALESCE(v_metric.calories_goal, 2000) * 1.2))
                         AND (COALESCE(v_metric.calories_consumed, 0) > 0);

  v_sleep_achieved := COALESCE(v_metric.sleep_hours, 0) >= (COALESCE(v_metric.sleep_goal, 8.0) * 0.8);

  v_water_achieved := COALESCE(v_metric.water_glasses, 0) >= COALESCE(v_metric.water_goal, 8);

  v_nutrition_achieved := COALESCE(v_metric.calories_consumed, 0) > 0;

  -- Water is optional - only 4 goals required for streak (matching Flutter logic)
  v_all_goals_achieved := v_steps_achieved
                          AND v_calories_achieved
                          AND v_sleep_achieved
                          AND v_nutrition_achieved;

  -- Update the record with calculated achievements
  UPDATE health_metrics SET
    steps_achieved = v_steps_achieved,
    calories_achieved = v_calories_achieved,
    sleep_achieved = v_sleep_achieved,
    water_achieved = v_water_achieved,
    nutrition_achieved = v_nutrition_achieved,
    all_goals_achieved = v_all_goals_achieved,
    updated_at = NOW()
  WHERE id = p_metric_id;

  -- Log calculation
  RAISE DEBUG 'Goals calculated for metric %: steps=%, calories=%, sleep=%, nutrition=%, all=%',
    p_metric_id, v_steps_achieved, v_calories_achieved, v_sleep_achieved, v_nutrition_achieved, v_all_goals_achieved;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- STEP 5: CREATE AUTO-CALCULATE GOALS TRIGGER
-- ============================================

CREATE OR REPLACE FUNCTION trigger_calculate_goal_achievements()
RETURNS TRIGGER AS $$
BEGIN
  -- Recalculate achievements whenever health_metrics changes
  PERFORM calculate_goal_achievements(NEW.id);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop existing trigger if exists
DROP TRIGGER IF EXISTS trigger_auto_calculate_goals ON health_metrics;

-- Create trigger
CREATE TRIGGER trigger_auto_calculate_goals
  AFTER INSERT OR UPDATE ON health_metrics
  FOR EACH ROW
  EXECUTE FUNCTION trigger_calculate_goal_achievements();

COMMENT ON TRIGGER trigger_auto_calculate_goals ON health_metrics IS
'Automatically recalculates goal achievements whenever health metrics are updated';

-- ============================================
-- STEP 6: CREATE STREAK UPDATE FUNCTION
-- ============================================

CREATE OR REPLACE FUNCTION update_user_streak(p_user_id UUID, p_date DATE)
RETURNS void AS $$
DECLARE
  v_metric RECORD;
  v_streak RECORD;
  v_yesterday DATE;
  v_new_streak INT;
  v_new_longest INT;
  v_increment_total BOOLEAN;
BEGIN
  -- Get today's metrics
  SELECT * INTO v_metric
  FROM health_metrics
  WHERE user_id = p_user_id AND date = p_date;

  -- Only proceed if all goals achieved
  IF NOT COALESCE(v_metric.all_goals_achieved, FALSE) THEN
    RAISE DEBUG 'Streak not updated: goals not achieved for user % on %', p_user_id, p_date;
    RETURN;
  END IF;

  -- Get current streak data
  SELECT * INTO v_streak
  FROM streaks
  WHERE user_id = p_user_id AND streak_type = 'daily';

  -- If no streak record exists, create one
  IF NOT FOUND THEN
    INSERT INTO streaks (
      user_id, streak_type, current_streak, longest_streak,
      last_completed_date, last_activity_date, last_checked_date,
      total_days_completed
    ) VALUES (
      p_user_id, 'daily', 1, 1,
      p_date, p_date, p_date, 1
    );
    RAISE NOTICE 'Created new streak for user %: 1 day', p_user_id;
    RETURN;
  END IF;

  -- Calculate yesterday's date
  v_yesterday := p_date - INTERVAL '1 day';

  -- Determine new streak value
  IF v_streak.last_completed_date = v_yesterday THEN
    -- Consecutive day - increment streak
    v_new_streak := v_streak.current_streak + 1;
    v_increment_total := TRUE;
    RAISE DEBUG 'Consecutive day detected: % -> %', v_streak.current_streak, v_new_streak;
  ELSIF v_streak.last_completed_date = p_date THEN
    -- Same day update - keep current streak (prevent double counting)
    v_new_streak := v_streak.current_streak;
    v_increment_total := FALSE;
    RAISE DEBUG 'Same day update: keeping streak at %', v_new_streak;
  ELSE
    -- Gap in days - reset to 1
    v_new_streak := 1;
    v_increment_total := TRUE;
    RAISE NOTICE 'Streak broken for user %: reset to 1 (was %)', p_user_id, v_streak.current_streak;
  END IF;

  -- Update longest streak if needed
  v_new_longest := GREATEST(COALESCE(v_streak.longest_streak, 0), v_new_streak);

  -- Update streak record
  UPDATE streaks SET
    current_streak = v_new_streak,
    longest_streak = v_new_longest,
    last_completed_date = p_date,
    last_activity_date = p_date,
    last_checked_date = p_date,
    last_attempted_date = p_date,
    total_days_completed = CASE
      WHEN v_increment_total THEN COALESCE(total_days_completed, 0) + 1
      ELSE COALESCE(total_days_completed, 0)
    END,
    consecutive_missed_days = 0,
    updated_at = NOW()
  WHERE user_id = p_user_id AND streak_type = 'daily';

  RAISE NOTICE 'Streak updated for user %: % days (longest: %)', p_user_id, v_new_streak, v_new_longest;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- STEP 7: CREATE AUTO-UPDATE STREAK TRIGGER
-- ============================================

CREATE OR REPLACE FUNCTION trigger_update_streak_on_goals_achieved()
RETURNS TRIGGER AS $$
BEGIN
  -- Only trigger if all_goals_achieved changed to TRUE
  IF NEW.all_goals_achieved = TRUE AND
     (OLD.all_goals_achieved IS NULL OR OLD.all_goals_achieved = FALSE) THEN
    PERFORM update_user_streak(NEW.user_id, NEW.date);
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop existing trigger if exists
DROP TRIGGER IF EXISTS trigger_auto_update_streak ON health_metrics;

-- Create trigger
CREATE TRIGGER trigger_auto_update_streak
  AFTER UPDATE ON health_metrics
  FOR EACH ROW
  EXECUTE FUNCTION trigger_update_streak_on_goals_achieved();

COMMENT ON TRIGGER trigger_auto_update_streak ON health_metrics IS
'Automatically updates user streak when all goals are achieved';

-- ============================================
-- STEP 8: CREATE MANUAL SYNC HELPER FUNCTIONS
-- ============================================

-- Helper: Sync nutrition for specific date
CREATE OR REPLACE FUNCTION sync_nutrition_to_health_metrics_for_date(p_user_id UUID, p_date DATE)
RETURNS void AS $$
DECLARE
  v_nutrition RECORD;
BEGIN
  SELECT * INTO v_nutrition FROM aggregate_daily_nutrition(p_user_id, p_date);

  INSERT INTO health_metrics (
    user_id, date,
    calories_consumed, protein, carbs, fat, fiber,
    updated_at
  )
  VALUES (
    p_user_id, p_date,
    v_nutrition.total_calories, v_nutrition.total_protein,
    v_nutrition.total_carbs, v_nutrition.total_fat, v_nutrition.total_fiber,
    NOW()
  )
  ON CONFLICT (user_id, date) DO UPDATE SET
    calories_consumed = EXCLUDED.calories_consumed,
    protein = EXCLUDED.protein,
    carbs = EXCLUDED.carbs,
    fat = EXCLUDED.fat,
    fiber = EXCLUDED.fiber,
    updated_at = NOW();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Helper: Calculate goals for specific date
CREATE OR REPLACE FUNCTION calculate_goal_achievements_for_date(p_user_id UUID, p_date DATE)
RETURNS void AS $$
DECLARE
  v_metric_id UUID;
BEGIN
  SELECT id INTO v_metric_id FROM health_metrics WHERE user_id = p_user_id AND date = p_date;
  IF v_metric_id IS NOT NULL THEN
    PERFORM calculate_goal_achievements(v_metric_id);
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- STEP 9: CREATE COMPREHENSIVE SYNC FUNCTION (FOR APP TO CALL)
-- ============================================

CREATE OR REPLACE FUNCTION sync_user_daily_data(
  p_user_id UUID,
  p_date DATE DEFAULT CURRENT_DATE
)
RETURNS JSON AS $$
DECLARE
  v_result JSON;
BEGIN
  -- Step 1: Force recalculate nutrition
  PERFORM sync_nutrition_to_health_metrics_for_date(p_user_id, p_date);

  -- Step 2: Force recalculate goals
  PERFORM calculate_goal_achievements_for_date(p_user_id, p_date);

  -- Step 3: Force update streak
  PERFORM update_user_streak(p_user_id, p_date);

  -- Step 4: Return updated data
  SELECT json_build_object(
    'health_metrics', (
      SELECT row_to_json(h.*)
      FROM health_metrics h
      WHERE h.user_id = p_user_id AND h.date = p_date
    ),
    'streak', (
      SELECT row_to_json(s.*)
      FROM streaks s
      WHERE s.user_id = p_user_id AND s.streak_type = 'daily'
    ),
    'synced_at', NOW()
  ) INTO v_result;

  RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION sync_user_daily_data(UUID, DATE) TO authenticated;
GRANT EXECUTE ON FUNCTION aggregate_daily_nutrition(UUID, DATE) TO authenticated;

-- ============================================
-- STEP 10: CREATE AUDIT LOG TABLE (OPTIONAL)
-- ============================================

CREATE TABLE IF NOT EXISTS sync_audit_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  sync_type TEXT NOT NULL,
  date_synced DATE NOT NULL,
  success BOOLEAN DEFAULT TRUE,
  error_message TEXT,
  execution_time_ms INTEGER,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_sync_audit_log_user_date ON sync_audit_log(user_id, date_synced DESC);
CREATE INDEX IF NOT EXISTS idx_sync_audit_log_created_at ON sync_audit_log(created_at DESC);

-- Enable RLS
ALTER TABLE sync_audit_log ENABLE ROW LEVEL SECURITY;

-- RLS Policy
CREATE POLICY "Users can view own sync logs"
  ON sync_audit_log FOR SELECT
  USING (auth.uid() = user_id);

-- ============================================
-- STEP 11: CREATE STREAK DASHBOARD VIEW
-- ============================================

CREATE OR REPLACE VIEW user_streak_dashboard AS
SELECT
  s.user_id,
  s.current_streak,
  s.longest_streak,
  s.total_days_completed,
  s.last_completed_date,
  s.last_activity_date,
  s.consecutive_missed_days,
  s.grace_days_used,
  s.grace_days_available,
  (s.grace_days_available - s.grace_days_used) AS remaining_grace_days,
  h.all_goals_achieved AS today_goals_achieved,
  h.steps_achieved,
  h.calories_achieved,
  h.sleep_achieved,
  h.nutrition_achieved,
  h.water_achieved,
  h.steps,
  h.steps_goal,
  h.calories_consumed,
  h.calories_goal,
  h.sleep_hours,
  h.sleep_goal
FROM streaks s
LEFT JOIN health_metrics h ON s.user_id = h.user_id
  AND h.date = CURRENT_DATE
WHERE s.streak_type = 'daily';

GRANT SELECT ON user_streak_dashboard TO authenticated;

-- ============================================
-- VERIFICATION & TESTING
-- ============================================

-- Verify all functions exist
DO $$
DECLARE
  func_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO func_count
  FROM pg_proc
  WHERE proname IN (
    'aggregate_daily_nutrition',
    'sync_nutrition_to_health_metrics',
    'calculate_goal_achievements',
    'update_user_streak',
    'sync_user_daily_data'
  );

  IF func_count = 5 THEN
    RAISE NOTICE '✅ All 5 core functions created successfully';
  ELSE
    RAISE WARNING '⚠️ Only % out of 5 functions created', func_count;
  END IF;
END $$;

-- Verify all triggers exist
DO $$
DECLARE
  trigger_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO trigger_count
  FROM pg_trigger
  WHERE tgname IN (
    'trigger_sync_nutrition_to_health_metrics',
    'trigger_auto_calculate_goals',
    'trigger_auto_update_streak'
  );

  IF trigger_count = 3 THEN
    RAISE NOTICE '✅ All 3 triggers created successfully';
  ELSE
    RAISE WARNING '⚠️ Only % out of 3 triggers created', trigger_count;
  END IF;
END $$;

-- ============================================
-- MIGRATION COMPLETE
-- ============================================

RAISE NOTICE '
🎉 MIGRATION COMPLETED SUCCESSFULLY!

Created:
- 5 Core Functions (aggregation, sync, calculation, streak update)
- 3 Automatic Triggers (nutrition sync, goal calc, streak update)
- 1 Manual Sync RPC (sync_user_daily_data)
- 1 Audit Log Table (optional monitoring)
- 1 Dashboard View (user_streak_dashboard)

Next Steps:
1. Run backfill script to fix historical data
2. Update Flutter app to use new sync functions
3. Test with sample data
4. Monitor sync_audit_log for issues

The system will now automatically:
✅ Sync nutrition to health_metrics on every food entry
✅ Recalculate goals whenever health data changes
✅ Update streaks when all goals are achieved
';
