-- ============================================
-- FIX: Update sync_user_daily_data function
-- Date: October 5, 2025
-- Issue: Function was calling calculate_goal_achievements_for_date()
--        which was deleted in 20251005_comprehensive_streak_fix.sql
-- Solution: Remove that call since BEFORE triggers handle goal calculations automatically
-- ============================================

CREATE OR REPLACE FUNCTION sync_user_daily_data(
  p_user_id UUID,
  p_date DATE DEFAULT CURRENT_DATE
)
RETURNS JSON AS $$
DECLARE
  v_result JSON;
BEGIN
  -- Step 1: Sync nutrition to health_metrics
  -- The BEFORE trigger (trigger_before_calculate_achievements) will automatically
  -- calculate goal achievements when data is inserted/updated
  PERFORM sync_nutrition_to_health_metrics_for_date(p_user_id, p_date);

  -- Step 2: REMOVED - No longer needed due to BEFORE trigger system:
  -- PERFORM calculate_goal_achievements_for_date(p_user_id, p_date);
  -- The before_calculate_goal_achievements() function handles this automatically

  -- Step 3: Update streak based on the trigger-calculated achievements
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

-- Verify the function was updated successfully
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'public' AND p.proname = 'sync_user_daily_data'
  ) THEN
    RAISE NOTICE '✅ sync_user_daily_data function updated successfully';
    RAISE NOTICE '   Now compatible with BEFORE trigger system';
    RAISE NOTICE '   No longer calls deleted calculate_goal_achievements_for_date function';
  ELSE
    RAISE EXCEPTION '❌ Failed to update sync_user_daily_data function';
  END IF;
END $$;
