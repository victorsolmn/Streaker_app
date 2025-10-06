-- ============================================
-- COMPREHENSIVE STREAK SYSTEM FIX
-- Date: October 5, 2025
-- Purpose: Fix all streak reset issues and implement proper automation
-- ============================================

-- PART 1: Create streak history table for debugging
-- ============================================
CREATE TABLE IF NOT EXISTS streak_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  date DATE NOT NULL,
  previous_streak INT,
  new_streak INT,
  action TEXT, -- 'increment', 'reset', 'grace_period', 'maintain'
  reason TEXT,
  all_goals_achieved BOOLEAN,
  grace_days_used INT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_streak_history_user_date ON streak_history(user_id, date DESC);

-- PART 2: Fix calorie threshold (120% -> 150%)
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
  SELECT * INTO v_metric FROM health_metrics WHERE id = p_metric_id;
  IF NOT FOUND THEN RETURN; END IF;

  -- Steps: 80% of goal is acceptable
  v_steps_achieved := COALESCE(v_metric.steps, 0) >= (COALESCE(v_metric.steps_goal, 10000) * 0.8);

  -- Calories: Between 80% and 150% of goal (was 120%, now more flexible)
  v_calories_achieved := (COALESCE(v_metric.calories_consumed, 0) BETWEEN
                          (COALESCE(v_metric.calories_goal, 2000) * 0.8) AND
                          (COALESCE(v_metric.calories_goal, 2000) * 1.5))
                         AND (COALESCE(v_metric.calories_consumed, 0) > 0);

  -- Sleep: 80% of goal is acceptable
  v_sleep_achieved := COALESCE(v_metric.sleep_hours, 0) >= (COALESCE(v_metric.sleep_goal, 8.0) * 0.8);

  -- Water: 100% of goal (can be flexible if needed)
  v_water_achieved := COALESCE(v_metric.water_glasses, 0) >= COALESCE(v_metric.water_goal, 8);

  -- Nutrition: Any logged food counts
  v_nutrition_achieved := COALESCE(v_metric.calories_consumed, 0) > 0;

  -- All goals: Require 4 out of 5 goals (more forgiving)
  v_all_goals_achieved := (
    (v_steps_achieved::int + v_calories_achieved::int + v_sleep_achieved::int +
     v_water_achieved::int + v_nutrition_achieved::int) >= 4
  );

  UPDATE health_metrics SET
    steps_achieved = v_steps_achieved,
    calories_achieved = v_calories_achieved,
    sleep_achieved = v_sleep_achieved,
    water_achieved = v_water_achieved,
    nutrition_achieved = v_nutrition_achieved,
    all_goals_achieved = v_all_goals_achieved,
    updated_at = NOW()
  WHERE id = p_metric_id;

  RAISE NOTICE 'Goals calculated for metric %: steps=%, cal=%, sleep=%, water=%, nutr=%, all=%',
    p_metric_id, v_steps_achieved, v_calories_achieved, v_sleep_achieved,
    v_water_achieved, v_nutrition_achieved, v_all_goals_achieved;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- PART 3: Enhanced streak update with grace period
-- ============================================
CREATE OR REPLACE FUNCTION update_user_streak(p_user_id UUID, p_date DATE)
RETURNS void AS $$
DECLARE
  v_metric RECORD;
  v_streak RECORD;
  v_yesterday DATE;
  v_new_streak INT;
  v_new_longest INT;
  v_grace_days_to_use INT;
  v_action TEXT;
  v_reason TEXT;
BEGIN
  -- Get today's metrics
  SELECT * INTO v_metric FROM health_metrics
  WHERE user_id = p_user_id AND date = p_date;

  -- Get current streak
  SELECT * INTO v_streak FROM streaks
  WHERE user_id = p_user_id AND streak_type = 'daily';

  -- If no streak exists, create it
  IF NOT FOUND THEN
    INSERT INTO streaks (
      user_id, streak_type, current_streak, longest_streak,
      last_completed_date, last_activity_date, last_checked_date,
      total_days_completed, grace_days_available, grace_days_used,
      consecutive_missed_days
    ) VALUES (
      p_user_id, 'daily', 1, 1, p_date, p_date, p_date, 1, 2, 0, 0
    );

    -- Log to history
    INSERT INTO streak_history (user_id, date, previous_streak, new_streak, action, reason, all_goals_achieved)
    VALUES (p_user_id, p_date, 0, 1, 'increment', 'Initial streak creation', v_metric.all_goals_achieved);

    RETURN;
  END IF;

  v_yesterday := p_date - INTERVAL '1 day';

  -- Determine action based on goal achievement and date continuity
  IF COALESCE(v_metric.all_goals_achieved, FALSE) THEN
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
      -- Gap exists, check if grace period can bridge it
      v_grace_days_to_use := (p_date - v_streak.last_completed_date - 1)::INT;

      IF v_grace_days_to_use <= (v_streak.grace_days_available - v_streak.grace_days_used) THEN
        -- Use grace days to maintain streak
        v_new_streak := v_streak.current_streak + 1;
        v_action := 'increment';
        v_reason := format('Used %s grace days to bridge gap', v_grace_days_to_use);
      ELSE
        -- Gap too large, reset streak
        v_new_streak := 1;
        v_action := 'reset';
        v_reason := format('Gap of %s days exceeds available grace days', v_grace_days_to_use);
        v_grace_days_to_use := 0;
      END IF;
    ELSE
      -- Future date or other edge case
      v_new_streak := v_streak.current_streak;
      v_action := 'maintain';
      v_reason := 'Edge case - maintaining current streak';
      v_grace_days_to_use := 0;
    END IF;
  ELSE
    -- Goals not achieved today
    IF v_streak.last_completed_date = p_date - INTERVAL '1 day' THEN
      -- First miss after streak
      IF v_streak.grace_days_used < v_streak.grace_days_available THEN
        -- Use grace day
        v_new_streak := v_streak.current_streak;
        v_action := 'grace_period';
        v_reason := 'Using grace day for missed goals';
        v_grace_days_to_use := 1;
      ELSE
        -- No grace days left, reset
        v_new_streak := 0;
        v_action := 'reset';
        v_reason := 'Goals not achieved, no grace days remaining';
        v_grace_days_to_use := 0;
      END IF;
    ELSIF v_streak.last_checked_date < p_date - INTERVAL '1 day' THEN
      -- Multiple days missed
      v_new_streak := 0;
      v_action := 'reset';
      v_reason := 'Multiple days missed';
      v_grace_days_to_use := 0;
    ELSE
      -- Maintain current state
      v_new_streak := v_streak.current_streak;
      v_action := 'maintain';
      v_reason := 'Maintaining current state';
      v_grace_days_to_use := 0;
    END IF;
  END IF;

  v_new_longest := GREATEST(COALESCE(v_streak.longest_streak, 0), v_new_streak);

  -- Update streak record
  UPDATE streaks SET
    current_streak = v_new_streak,
    longest_streak = v_new_longest,
    last_completed_date = CASE
      WHEN COALESCE(v_metric.all_goals_achieved, FALSE) THEN p_date
      ELSE last_completed_date
    END,
    last_activity_date = p_date,
    last_checked_date = p_date,
    total_days_completed = CASE
      WHEN COALESCE(v_metric.all_goals_achieved, FALSE) AND v_streak.last_completed_date != p_date
      THEN total_days_completed + 1
      ELSE total_days_completed
    END,
    consecutive_missed_days = CASE
      WHEN COALESCE(v_metric.all_goals_achieved, FALSE) THEN 0
      WHEN v_action = 'grace_period' THEN consecutive_missed_days
      ELSE consecutive_missed_days + 1
    END,
    grace_days_used = CASE
      WHEN v_action = 'reset' AND v_new_streak = 0 THEN 0  -- Reset grace days on streak break
      ELSE COALESCE(grace_days_used, 0) + v_grace_days_to_use
    END,
    updated_at = NOW()
  WHERE user_id = p_user_id AND streak_type = 'daily';

  -- Log to history
  INSERT INTO streak_history (
    user_id, date, previous_streak, new_streak, action, reason,
    all_goals_achieved, grace_days_used
  ) VALUES (
    p_user_id, p_date, v_streak.current_streak, v_new_streak, v_action,
    v_reason, COALESCE(v_metric.all_goals_achieved, FALSE), v_grace_days_to_use
  );

  RAISE NOTICE 'Streak updated for user %: % -> % (%s)',
    p_user_id, v_streak.current_streak, v_new_streak, v_reason;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- PART 4: Fix trigger to fire on ALL updates
-- ============================================
DROP TRIGGER IF EXISTS trigger_auto_update_streak ON health_metrics;

CREATE OR REPLACE FUNCTION trigger_update_streak_always()
RETURNS TRIGGER AS $$
BEGIN
  -- Always update streak when health metrics change
  -- This ensures grace periods are properly applied
  PERFORM update_user_streak(NEW.user_id, NEW.date);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_auto_update_streak
  AFTER INSERT OR UPDATE ON health_metrics
  FOR EACH ROW
  EXECUTE FUNCTION trigger_update_streak_always();

-- PART 5: Daily check function for all users
-- ============================================
CREATE OR REPLACE FUNCTION check_all_user_streaks()
RETURNS void AS $$
DECLARE
  v_user RECORD;
  v_today DATE;
  v_count INT := 0;
BEGIN
  v_today := CURRENT_DATE;

  RAISE NOTICE 'Starting daily streak check for %', v_today;

  -- Process all active users
  FOR v_user IN
    SELECT DISTINCT u.id
    FROM auth.users u
    INNER JOIN streaks s ON s.user_id = u.id
    WHERE s.streak_type = 'daily'
    AND s.last_checked_date < v_today  -- Only process if not already checked today
  LOOP
    -- Ensure health_metrics exists for today
    INSERT INTO health_metrics (user_id, date, created_at, updated_at)
    VALUES (v_user.id, v_today, NOW(), NOW())
    ON CONFLICT (user_id, date) DO NOTHING;

    -- Update streak (will use grace period if needed)
    PERFORM update_user_streak(v_user.id, v_today);

    v_count := v_count + 1;
  END LOOP;

  RAISE NOTICE 'Daily streak check completed. Processed % users', v_count;

  -- Log to audit
  INSERT INTO sync_audit_log (user_id, sync_type, date_synced, success)
  VALUES (NULL, 'daily_streak_check', v_today, TRUE);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- PART 6: Enable pg_cron extension (if not already enabled)
-- ============================================
-- Note: pg_cron must be enabled by Supabase dashboard first
-- Go to: Database -> Extensions -> Enable pg_cron

-- PART 7: Create a function to be called by Supabase Edge Function
-- ============================================
CREATE OR REPLACE FUNCTION public.daily_streak_check_endpoint()
RETURNS json AS $$
DECLARE
  v_result json;
BEGIN
  -- Run the daily check
  PERFORM check_all_user_streaks();

  -- Return success status
  v_result := json_build_object(
    'success', true,
    'timestamp', NOW(),
    'message', 'Daily streak check completed'
  );

  RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission for service role
GRANT EXECUTE ON FUNCTION public.daily_streak_check_endpoint() TO service_role;

-- PART 8: Fix existing bad data
-- ============================================
DO $$
DECLARE
  v_user_id UUID := '5acc8e5f-03b2-48cf-bd29-f7a2f1fc06e9';
BEGIN
  -- Recalculate all recent metrics with new thresholds
  UPDATE health_metrics
  SET updated_at = NOW()
  WHERE user_id = v_user_id
  AND date >= '2025-10-03'::date;

  -- This will trigger recalculation of goals and streak
  RAISE NOTICE 'Fixed existing data for user %', v_user_id;
END $$;

-- PART 9: Add RLS policies for streak_history
-- ============================================
ALTER TABLE streak_history ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own streak history"
  ON streak_history FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Service role can manage all streak history"
  ON streak_history FOR ALL
  USING (auth.jwt() ->> 'role' = 'service_role');

-- PART 10: Create view for easy streak monitoring
-- ============================================
CREATE OR REPLACE VIEW streak_status AS
SELECT
  s.user_id,
  s.current_streak,
  s.longest_streak,
  s.last_completed_date,
  s.grace_days_used,
  s.grace_days_available,
  s.consecutive_missed_days,
  h.all_goals_achieved as today_achieved,
  h.steps_achieved,
  h.calories_achieved,
  h.sleep_achieved,
  h.water_achieved,
  h.nutrition_achieved
FROM streaks s
LEFT JOIN health_metrics h ON h.user_id = s.user_id AND h.date = CURRENT_DATE
WHERE s.streak_type = 'daily';

-- Grant select on view
GRANT SELECT ON streak_status TO authenticated;

-- Success message
DO $$
BEGIN
  RAISE NOTICE '✅ COMPREHENSIVE STREAK FIX DEPLOYED SUCCESSFULLY!';
  RAISE NOTICE 'Features added:';
  RAISE NOTICE '  - Calorie threshold increased to 150%';
  RAISE NOTICE '  - Grace period logic implemented';
  RAISE NOTICE '  - Daily streak check function created';
  RAISE NOTICE '  - Streak history tracking enabled';
  RAISE NOTICE '  - Trigger fixed to fire on all updates';
  RAISE NOTICE '  - 4/5 goals sufficient for achievement';
END $$;