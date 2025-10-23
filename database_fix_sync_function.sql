-- ========================================
-- SUPABASE DATABASE FIX: sync_user_daily_data Function
-- ========================================
-- This function aggregates nutrition data and updates health metrics & streaks
-- Run this in your Supabase SQL Editor

-- Drop existing function if it exists
DROP FUNCTION IF EXISTS public.sync_user_daily_data(UUID, DATE);
DROP FUNCTION IF EXISTS public.sync_user_daily_data(DATE, UUID);

-- Create the sync function with correct parameter order
CREATE OR REPLACE FUNCTION public.sync_user_daily_data(
  p_user_id UUID,
  p_date DATE
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_calories_consumed INT := 0;
  v_protein_consumed DECIMAL := 0;
  v_carbs_consumed DECIMAL := 0;
  v_fat_consumed DECIMAL := 0;
  v_all_goals_achieved BOOLEAN := FALSE;
  v_current_streak INT := 0;
  v_longest_streak INT := 0;
  v_result JSON;
BEGIN
  -- ==========================================
  -- STEP 1: Aggregate nutrition data for the day
  -- ==========================================
  SELECT
    COALESCE(SUM(calories), 0),
    COALESCE(SUM(protein), 0),
    COALESCE(SUM(carbs), 0),
    COALESCE(SUM(fat), 0)
  INTO
    v_calories_consumed,
    v_protein_consumed,
    v_carbs_consumed,
    v_fat_consumed
  FROM nutrition_entries
  WHERE user_id = p_user_id
    AND DATE(created_at) = p_date;

  -- ==========================================
  -- STEP 2: Get user's goals from profiles
  -- ==========================================
  -- Check if all goals are achieved (using default values if not set)
  v_all_goals_achieved := (
    v_calories_consumed >= COALESCE((SELECT calorie_goal FROM profiles WHERE id = p_user_id), 2000) AND
    v_protein_consumed >= COALESCE((SELECT protein_goal FROM profiles WHERE id = p_user_id), 150) AND
    v_carbs_consumed >= COALESCE((SELECT carb_goal FROM profiles WHERE id = p_user_id), 250) AND
    v_fat_consumed >= COALESCE((SELECT fat_goal FROM profiles WHERE id = p_user_id), 67)
  );

  -- ==========================================
  -- STEP 3: Upsert health_metrics
  -- ==========================================
  INSERT INTO health_metrics (
    user_id,
    date,
    calories_consumed,
    protein_consumed,
    carbs_consumed,
    fat_consumed,
    all_goals_achieved,
    updated_at
  )
  VALUES (
    p_user_id,
    p_date,
    v_calories_consumed,
    v_protein_consumed,
    v_carbs_consumed,
    v_fat_consumed,
    v_all_goals_achieved,
    NOW()
  )
  ON CONFLICT (user_id, date)
  DO UPDATE SET
    calories_consumed = EXCLUDED.calories_consumed,
    protein_consumed = EXCLUDED.protein_consumed,
    carbs_consumed = EXCLUDED.carbs_consumed,
    fat_consumed = EXCLUDED.fat_consumed,
    all_goals_achieved = EXCLUDED.all_goals_achieved,
    updated_at = NOW();

  -- ==========================================
  -- STEP 4: Calculate and update streaks
  -- ==========================================
  -- Calculate current streak
  WITH streak_calc AS (
    SELECT
      COUNT(*) as streak_count
    FROM (
      SELECT date
      FROM health_metrics
      WHERE user_id = p_user_id
        AND all_goals_achieved = TRUE
        AND date <= p_date
      ORDER BY date DESC
    ) consecutive_days
    WHERE date >= p_date - (ROW_NUMBER() OVER (ORDER BY date DESC) - 1) * INTERVAL '1 day'
  )
  SELECT COALESCE(MAX(streak_count), 0)
  INTO v_current_streak
  FROM streak_calc;

  -- Calculate longest streak
  SELECT COALESCE(MAX(current_streak), 0)
  INTO v_longest_streak
  FROM streaks
  WHERE user_id = p_user_id;

  -- Update longest streak if current is higher
  IF v_current_streak > v_longest_streak THEN
    v_longest_streak := v_current_streak;
  END IF;

  -- Upsert streaks table
  INSERT INTO streaks (
    user_id,
    current_streak,
    longest_streak,
    last_updated
  )
  VALUES (
    p_user_id,
    v_current_streak,
    v_longest_streak,
    NOW()
  )
  ON CONFLICT (user_id)
  DO UPDATE SET
    current_streak = EXCLUDED.current_streak,
    longest_streak = GREATEST(streaks.longest_streak, EXCLUDED.longest_streak),
    last_updated = NOW();

  -- ==========================================
  -- STEP 5: Return result as JSON
  -- ==========================================
  SELECT json_build_object(
    'success', TRUE,
    'date', p_date,
    'health_metrics', json_build_object(
      'calories_consumed', v_calories_consumed,
      'protein_consumed', v_protein_consumed,
      'carbs_consumed', v_carbs_consumed,
      'fat_consumed', v_fat_consumed,
      'all_goals_achieved', v_all_goals_achieved
    ),
    'streak', json_build_object(
      'current_streak', v_current_streak,
      'longest_streak', v_longest_streak
    )
  ) INTO v_result;

  RETURN v_result;

EXCEPTION
  WHEN OTHERS THEN
    -- Return error details
    RETURN json_build_object(
      'success', FALSE,
      'error', SQLERRM,
      'detail', SQLSTATE
    );
END;
$$;

-- ==========================================
-- Grant execute permissions
-- ==========================================
GRANT EXECUTE ON FUNCTION public.sync_user_daily_data(UUID, DATE) TO authenticated;
GRANT EXECUTE ON FUNCTION public.sync_user_daily_data(UUID, DATE) TO service_role;

-- ==========================================
-- OPTIONAL: Create triggers for automatic sync
-- ==========================================
-- This will auto-sync whenever nutrition entries are modified

CREATE OR REPLACE FUNCTION public.trigger_sync_on_nutrition_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Sync the affected date
  PERFORM sync_user_daily_data(
    COALESCE(NEW.user_id, OLD.user_id),
    COALESCE(DATE(NEW.created_at), DATE(OLD.created_at))
  );

  RETURN COALESCE(NEW, OLD);
END;
$$;

-- Drop existing trigger if exists
DROP TRIGGER IF EXISTS nutrition_entry_sync ON nutrition_entries;

-- Create trigger
CREATE TRIGGER nutrition_entry_sync
AFTER INSERT OR UPDATE OR DELETE ON nutrition_entries
FOR EACH ROW
EXECUTE FUNCTION trigger_sync_on_nutrition_change();

-- ==========================================
-- Test the function (OPTIONAL - uncomment to test)
-- ==========================================
/*
SELECT sync_user_daily_data(
  '5acc8e5f-03b2-48cf-bd29-f7a2f1fc06e9'::UUID,  -- Replace with your user ID
  CURRENT_DATE
);
*/

-- ==========================================
-- VERIFICATION QUERIES
-- ==========================================
-- Run these to verify the function works:

/*
-- 1. Check if function exists
SELECT proname, proargnames
FROM pg_proc
WHERE proname = 'sync_user_daily_data';

-- 2. Check health_metrics after sync
SELECT * FROM health_metrics
WHERE user_id = '5acc8e5f-03b2-48cf-bd29-f7a2f1fc06e9'::UUID
ORDER BY date DESC
LIMIT 5;

-- 3. Check streaks after sync
SELECT * FROM streaks
WHERE user_id = '5acc8e5f-03b2-48cf-bd29-f7a2f1fc06e9'::UUID;

-- 4. Check nutrition entries
SELECT
  DATE(created_at) as date,
  COUNT(*) as entry_count,
  SUM(calories) as total_calories,
  SUM(protein) as total_protein
FROM nutrition_entries
WHERE user_id = '5acc8e5f-03b2-48cf-bd29-f7a2f1fc06e9'::UUID
GROUP BY DATE(created_at)
ORDER BY date DESC
LIMIT 7;
*/
