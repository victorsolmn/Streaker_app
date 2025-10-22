-- ============================================
-- Migration 006: Fix Nutrition Entry Save Issue
-- Date: October 22, 2025
-- Issue: Nutrition entries were not saving to database due to
--        sync_nutrition_to_health_metrics function trying to insert
--        into health_metrics table with columns that don't exist
-- ============================================

-- STEP 1: Drop the problematic function that syncs nutrition to health_metrics
-- This function was trying to insert nutrition data (protein, carbs, fat, fiber)
-- into health_metrics table which doesn't have those columns
DROP FUNCTION IF EXISTS sync_nutrition_to_health_metrics() CASCADE;
DROP FUNCTION IF EXISTS public.sync_nutrition_to_health_metrics() CASCADE;

-- STEP 2: Drop any triggers that were calling this function
DROP TRIGGER IF EXISTS sync_nutrition_to_health_metrics_trigger ON nutrition_entries;
DROP TRIGGER IF EXISTS trigger_sync_nutrition_to_health_metrics ON nutrition_entries;
DROP TRIGGER IF EXISTS nutrition_entry_sync ON nutrition_entries;

-- STEP 3: Drop the aggregate function if it exists
DROP FUNCTION IF EXISTS aggregate_daily_nutrition(UUID, DATE) CASCADE;
DROP FUNCTION IF EXISTS public.aggregate_daily_nutrition(UUID, DATE) CASCADE;

-- STEP 4: Ensure sync_user_daily_data is updated to not sync to health_metrics
CREATE OR REPLACE FUNCTION sync_user_daily_data(
  p_user_id UUID,
  p_date DATE DEFAULT CURRENT_DATE
)
RETURNS JSON AS $$
BEGIN
  -- Nutrition entries now save directly to nutrition_entries table
  -- No sync to health_metrics needed (table was removed in migration 004)
  RETURN json_build_object(
    'success', true,
    'message', 'Nutrition entries save directly - no sync needed',
    'synced_at', NOW()
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- STEP 5: Verify cleanup
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_proc
    WHERE proname = 'sync_nutrition_to_health_metrics'
  ) THEN
    RAISE NOTICE '✅ sync_nutrition_to_health_metrics function removed successfully';
  ELSE
    RAISE EXCEPTION '❌ Function still exists!';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.triggers
    WHERE trigger_name LIKE '%sync_nutrition%'
    AND event_object_table = 'nutrition_entries'
  ) THEN
    RAISE NOTICE '✅ All nutrition sync triggers removed';
  ELSE
    RAISE EXCEPTION '❌ Triggers still exist!';
  END IF;

  RAISE NOTICE '✅ Migration 006 complete - Nutrition entries now save directly to nutrition_entries table';
END $$;

-- ============================================
-- EXPLANATION:
-- ============================================
-- Prior to this migration, when a nutrition entry was inserted into the
-- nutrition_entries table, a trigger would fire the sync_nutrition_to_health_metrics
-- function which attempted to aggregate and insert nutrition data into health_metrics.
--
-- However, health_metrics table is designed for health tracking data (steps, sleep,
-- heart rate, etc.) and does not have nutrition columns (protein, carbs, fat, fiber).
--
-- This caused PostgreSQL error 42703: "column protein of relation health_metrics does not exist"
--
-- The fix: Remove the sync mechanism entirely. Nutrition data stays in nutrition_entries
-- table where it belongs, and health data stays in health_metrics table.
-- ============================================
