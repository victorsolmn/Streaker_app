-- ============================================
-- Migration 005: Remove Calorie Tracking System
-- Purpose: Drop smartwatch calorie tracking infrastructure
-- Created: October 16, 2025
-- ============================================

-- STEP 1: Drop triggers first (to prevent cascading issues)
-- ============================================
DROP TRIGGER IF EXISTS auto_calculate_daily_totals ON public.calorie_sessions;

-- STEP 2: Drop functions
-- ============================================
DROP FUNCTION IF EXISTS public.trigger_calculate_daily_totals();
DROP FUNCTION IF EXISTS public.get_last_calorie_sync(UUID);
DROP FUNCTION IF EXISTS public.check_daily_data_completeness(UUID, DATE);

-- Note: calculate_daily_calorie_totals() already updated by migration 004
-- to not reference health_metrics

-- STEP 3: Drop views that reference these tables
-- ============================================
DROP VIEW IF EXISTS public.user_calorie_dashboard;

-- STEP 4: Drop the calorie tracking tables
-- ============================================
DROP TABLE IF EXISTS public.calorie_sessions CASCADE;
DROP TABLE IF EXISTS public.daily_calorie_totals CASCADE;

-- STEP 5: Drop user_goals table if not used by app
-- ============================================
-- Uncomment if you've verified user_goals is not used:
-- DROP TABLE IF EXISTS public.user_goals CASCADE;

-- STEP 6: Verification
-- ============================================
DO $$
BEGIN
  RAISE NOTICE '✅ Calorie tracking system removed!';
  RAISE NOTICE '   - calorie_sessions table dropped';
  RAISE NOTICE '   - daily_calorie_totals table dropped';
  RAISE NOTICE '   - Related functions and triggers dropped';
  RAISE NOTICE '   - Database optimized for nutrition-only tracking';
END $$;
