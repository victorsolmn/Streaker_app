-- ============================================
-- CONSOLIDATED CLEANUP MIGRATION
-- Execute all 3 migrations in correct order
-- Purpose: Remove ALL smartwatch/health tracking infrastructure
-- Created: October 16, 2025
-- ============================================

\echo '🚀 Starting consolidated cleanup migration...'
\echo ''

-- ============================================
-- MIGRATION 003: Remove Workout Achievements
-- ============================================

\echo '📝 STEP 1: Removing workout achievements...'

-- Remove user progress for workout achievements
DELETE FROM public.user_achievements
WHERE achievement_id IN ('warm_up', 'sweatflix', 'gym_goblin', 'no_days_off');

-- Remove achievement progress for workout achievements
DELETE FROM public.achievement_progress
WHERE achievement_id IN ('warm_up', 'sweatflix', 'gym_goblin', 'no_days_off');

-- Remove the workout achievements themselves
DELETE FROM public.achievements
WHERE id IN ('warm_up', 'sweatflix', 'gym_goblin', 'no_days_off');

\echo '✅ Workout achievements removed'
\echo ''

-- ============================================
-- MIGRATION 004: Remove Health Metrics Table
-- ============================================

\echo '📝 STEP 2: Removing health_metrics table and related infrastructure...'

-- Step 1: Drop triggers first
DROP TRIGGER IF EXISTS update_health_metrics_updated_at ON public.health_metrics;

-- Step 2: Drop functions that depend on health_metrics
DROP FUNCTION IF EXISTS public.calculate_daily_calorie_totals(UUID, DATE) CASCADE;
DROP FUNCTION IF EXISTS public.check_workout_achievements() CASCADE;

-- Step 3: Drop views that reference health_metrics
DROP VIEW IF EXISTS public.user_dashboard CASCADE;

-- Step 4: Drop the health_metrics table
DROP TABLE IF EXISTS public.health_metrics CASCADE;

-- Step 5: Remove health-related columns from profiles
ALTER TABLE public.profiles
DROP COLUMN IF EXISTS daily_steps_target,
DROP COLUMN IF EXISTS daily_sleep_target,
DROP COLUMN IF EXISTS daily_water_target,
DROP COLUMN IF EXISTS daily_active_calories_target,
DROP COLUMN IF EXISTS device_name,
DROP COLUMN IF EXISTS device_connected;

\echo '✅ health_metrics table and columns removed'
\echo ''

-- Step 6: Recreate user_dashboard view WITHOUT health_metrics
CREATE OR REPLACE VIEW public.user_dashboard AS
SELECT
    p.id,
    p.name,
    p.email,
    p.age,
    p.height,
    p.weight,
    p.target_weight,
    p.fitness_goal,
    p.activity_level,
    p.bmi_value,
    p.daily_calories_target,
    s.current_streak,
    s.longest_streak,
    s.last_activity_date,
    s.target_achieved,
    (
        SELECT COUNT(*)
        FROM nutrition_entries ne
        WHERE ne.user_id = p.id
          AND ne.date = CURRENT_DATE
    ) AS today_nutrition_entries,
    (
        SELECT COALESCE(SUM(ne.calories), 0)
        FROM nutrition_entries ne
        WHERE ne.user_id = p.id
          AND ne.date = CURRENT_DATE
    ) AS today_calories_consumed
FROM profiles p
LEFT JOIN streaks s ON p.id = s.user_id AND s.streak_type = 'daily';

\echo '✅ user_dashboard view recreated without health_metrics'
\echo ''

-- ============================================
-- MIGRATION 005: Remove Calorie Tracking System
-- ============================================

\echo '📝 STEP 3: Removing smartwatch calorie tracking tables...'

-- Step 1: Drop triggers
DROP TRIGGER IF EXISTS auto_calculate_daily_totals ON public.calorie_sessions;

-- Step 2: Drop functions
DROP FUNCTION IF EXISTS public.trigger_calculate_daily_totals();
DROP FUNCTION IF EXISTS public.get_last_calorie_sync(UUID);
DROP FUNCTION IF EXISTS public.check_daily_data_completeness(UUID, DATE);

-- Step 3: Drop views
DROP VIEW IF EXISTS public.user_calorie_dashboard;

-- Step 4: Drop the calorie tracking tables
DROP TABLE IF EXISTS public.calorie_sessions CASCADE;
DROP TABLE IF EXISTS public.daily_calorie_totals CASCADE;

-- Step 5: Optionally drop user_goals table if not used
-- Uncomment if you've verified user_goals is not used:
-- DROP TABLE IF EXISTS public.user_goals CASCADE;

\echo '✅ Calorie tracking system removed'
\echo ''

-- ============================================
-- VERIFICATION
-- ============================================

\echo '🔍 Verifying cleanup...'
\echo ''

-- List remaining tables
\echo 'Remaining tables:'
SELECT schemaname, tablename
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY tablename;

\echo ''
\echo '✅ ALL CLEANUP MIGRATIONS COMPLETED SUCCESSFULLY!'
\echo ''
\echo '📊 Summary:'
\echo '  - Removed 4 workout achievements'
\echo '  - Dropped health_metrics table'
\echo '  - Removed 6 health columns from profiles'
\echo '  - Recreated user_dashboard view'
\echo '  - Dropped calorie_sessions table'
\echo '  - Dropped daily_calorie_totals table'
\echo '  - Removed related functions and triggers'
\echo ''
\echo '🎯 Database is now optimized for nutrition-only tracking!'
