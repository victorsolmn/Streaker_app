-- Migration: Remove health_metrics table and related database objects
-- This migration removes all health/smartwatch tracking database structures
-- while preserving nutrition tracking functionality

-- STEP 1: Drop views that depend on health_metrics
-- ============================================
DROP VIEW IF EXISTS public.user_dashboard;
DROP VIEW IF EXISTS public.user_calorie_dashboard;

-- STEP 2: Drop functions that reference health_metrics
-- ============================================

-- Update calculate_daily_calorie_totals to remove health_metrics references
CREATE OR REPLACE FUNCTION calculate_daily_calorie_totals(
  p_user_id UUID,
  p_date DATE
) RETURNS VOID AS $$
DECLARE
  v_total_calories DECIMAL(10,2);
  v_session_count INTEGER;
  v_data_completeness DECIMAL(3,2);
  v_has_full_day BOOLEAN;
BEGIN
  -- Calculate aggregates from calorie_sessions
  WITH daily_stats AS (
    SELECT
      COALESCE(SUM(bmr_calories), 0) as total_bmr,
      COALESCE(SUM(active_calories), 0) as total_active,
      COALESCE(SUM(exercise_calories), 0) as total_exercise,
      COALESCE(SUM(total_calories), 0) as total_cal,
      COALESCE(SUM(steps), 0) as total_steps,
      COALESCE(SUM(distance_meters), 0) as total_distance,
      COALESCE(SUM(floors_climbed), 0) as total_floors,
      COALESCE(AVG(avg_heart_rate)::INTEGER, 0) as avg_hr,
      COALESCE(MAX(max_heart_rate), 0) as max_hr,
      COALESCE(MIN(NULLIF(min_heart_rate, 0)), 0) as min_hr,
      COUNT(*) as session_count,
      COUNT(CASE WHEN exercise_type IS NOT NULL THEN 1 END) as exercise_count,
      MIN(session_start::TIME) as first_activity,
      MAX(session_end::TIME) as last_activity,
      COALESCE(SUM(CASE WHEN exercise_type IS NOT NULL THEN duration_minutes END), 0) as exercise_mins
    FROM calorie_sessions
    WHERE user_id = p_user_id AND session_date = p_date
  ),
  coverage_stats AS (
    SELECT
      COUNT(DISTINCT EXTRACT(HOUR FROM session_start)) as hours_covered
    FROM calorie_sessions
    WHERE user_id = p_user_id AND session_date = p_date
  )
  INSERT INTO daily_calorie_totals (
    user_id, date,
    total_bmr_calories, total_active_calories, total_exercise_calories, total_calories,
    total_steps, total_distance_meters, total_floors,
    avg_heart_rate, max_heart_rate, min_heart_rate,
    session_count, exercise_session_count,
    first_activity_time, last_activity_time,
    exercise_minutes,
    data_completeness, has_full_day_data,
    updated_at
  )
  SELECT
    p_user_id, p_date,
    ds.total_bmr, ds.total_active, ds.total_exercise, ds.total_cal,
    ds.total_steps, ds.total_distance, ds.total_floors,
    ds.avg_hr, ds.max_hr, ds.min_hr,
    ds.session_count, ds.exercise_count,
    ds.first_activity, ds.last_activity,
    ds.exercise_mins,
    LEAST(cs.hours_covered::DECIMAL / 24, 1.0),
    CASE
      WHEN cs.hours_covered >= 20
       AND ds.first_activity <= '02:00:00'::TIME
       AND ds.last_activity >= '22:00:00'::TIME
      THEN TRUE
      ELSE FALSE
    END,
    NOW()
  FROM daily_stats ds, coverage_stats cs
  ON CONFLICT (user_id, date) DO UPDATE SET
    total_bmr_calories = EXCLUDED.total_bmr_calories,
    total_active_calories = EXCLUDED.total_active_calories,
    total_exercise_calories = EXCLUDED.total_exercise_calories,
    total_calories = EXCLUDED.total_calories,
    total_steps = EXCLUDED.total_steps,
    total_distance_meters = EXCLUDED.total_distance_meters,
    total_floors = EXCLUDED.total_floors,
    avg_heart_rate = EXCLUDED.avg_heart_rate,
    max_heart_rate = EXCLUDED.max_heart_rate,
    min_heart_rate = EXCLUDED.min_heart_rate,
    session_count = EXCLUDED.session_count,
    exercise_session_count = EXCLUDED.exercise_session_count,
    first_activity_time = EXCLUDED.first_activity_time,
    last_activity_time = EXCLUDED.last_activity_time,
    exercise_minutes = EXCLUDED.exercise_minutes,
    data_completeness = EXCLUDED.data_completeness,
    has_full_day_data = EXCLUDED.has_full_day_data,
    updated_at = NOW();

  -- Note: Removed health_metrics table update code
END;
$$ LANGUAGE plpgsql;

-- STEP 3: Drop triggers related to health_metrics
-- ============================================
DROP TRIGGER IF EXISTS handle_health_metrics_updated_at ON public.health_metrics;

-- STEP 4: Drop RLS policies on health_metrics
-- ============================================
DROP POLICY IF EXISTS "Users can view own health metrics" ON public.health_metrics;
DROP POLICY IF EXISTS "Users can insert own health metrics" ON public.health_metrics;
DROP POLICY IF EXISTS "Users can update own health metrics" ON public.health_metrics;
DROP POLICY IF EXISTS "Users can delete own health metrics" ON public.health_metrics;

-- STEP 5: Drop indexes on health_metrics
-- ============================================
DROP INDEX IF EXISTS idx_health_metrics_user_id;
DROP INDEX IF EXISTS idx_health_metrics_date;
DROP INDEX IF EXISTS idx_health_metrics_user_date;

-- STEP 6: Drop the health_metrics table
-- ============================================
DROP TABLE IF EXISTS public.health_metrics CASCADE;

-- STEP 7: Remove health-related columns from profiles table
-- ============================================
ALTER TABLE public.profiles
DROP COLUMN IF EXISTS daily_steps_target,
DROP COLUMN IF EXISTS daily_sleep_target,
DROP COLUMN IF EXISTS daily_water_target,
DROP COLUMN IF EXISTS daily_active_calories_target;

-- STEP 8: Recreate nutrition-focused user_dashboard view
-- ============================================
CREATE OR REPLACE VIEW public.user_dashboard AS
SELECT
  p.id as user_id,
  p.name,
  p.email,
  p.daily_calories_target,
  COALESCE(s.current_streak, 0) as current_streak,
  COALESCE(s.longest_streak, 0) as longest_streak,
  COALESCE(ne.today_calories, 0) as today_calories
FROM public.profiles p
LEFT JOIN public.streaks s ON p.id = s.user_id AND s.streak_type = 'daily'
LEFT JOIN (
  SELECT user_id, SUM(calories) as today_calories
  FROM public.nutrition_entries
  WHERE date = CURRENT_DATE
  GROUP BY user_id
) ne ON p.id = ne.user_id;

-- STEP 9: Grant permissions
-- ============================================
GRANT SELECT ON public.user_dashboard TO authenticated;

-- STEP 10: Verification and success message
-- ============================================
DO $$
BEGIN
  RAISE NOTICE '✅ Health metrics removal complete!';
  RAISE NOTICE '   - health_metrics table dropped';
  RAISE NOTICE '   - Health-related columns removed from profiles';
  RAISE NOTICE '   - Views updated for nutrition-only tracking';
  RAISE NOTICE '   - Database now focused on nutrition tracking only';
END $$;
