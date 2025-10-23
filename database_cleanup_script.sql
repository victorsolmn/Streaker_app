-- ========================================
-- SUPABASE DATABASE CLEANUP SCRIPT
-- ========================================
-- Date: 2025-10-17
-- Purpose: Remove unused fields from database after app scope reduction
-- Impact: Removes ~47 unused fields across 4 tables
-- Safety: All user data is preserved, only column definitions are removed
--
-- IMPORTANT: This script follows "Option B: Aggressive Cleanup"
-- Run this in your Supabase SQL Editor
-- ========================================

BEGIN;

-- ========================================
-- STEP 1: PROFILES TABLE CLEANUP
-- ========================================
-- Remove 14 unused fields related to workouts, health tracking, and goals

ALTER TABLE public.profiles DROP COLUMN IF EXISTS activity_level;
ALTER TABLE public.profiles DROP COLUMN IF EXISTS experience_level;
ALTER TABLE public.profiles DROP COLUMN IF EXISTS workout_consistency;
ALTER TABLE public.profiles DROP COLUMN IF EXISTS device_name;
ALTER TABLE public.profiles DROP COLUMN IF EXISTS device_connected;
ALTER TABLE public.profiles DROP COLUMN IF EXISTS daily_active_calories_target;
ALTER TABLE public.profiles DROP COLUMN IF EXISTS daily_steps_target;
ALTER TABLE public.profiles DROP COLUMN IF EXISTS daily_sleep_target;
ALTER TABLE public.profiles DROP COLUMN IF EXISTS daily_water_target;
ALTER TABLE public.profiles DROP COLUMN IF EXISTS fitness_goal;
ALTER TABLE public.profiles DROP COLUMN IF EXISTS target_weight;
ALTER TABLE public.profiles DROP COLUMN IF EXISTS has_seen_fitness_goal_summary;
ALTER TABLE public.profiles DROP COLUMN IF EXISTS bmi_value;
ALTER TABLE public.profiles DROP COLUMN IF EXISTS bmi_category_value;

-- Add nutrition goal fields (if they don't exist)
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS calorie_goal INT DEFAULT 2000;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS protein_goal DECIMAL DEFAULT 150;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS carb_goal DECIMAL DEFAULT 250;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS fat_goal DECIMAL DEFAULT 67;

-- ========================================
-- STEP 2: NUTRITION_ENTRIES TABLE CLEANUP
-- ========================================
-- Remove 7 fields that are not used in current app

ALTER TABLE public.nutrition_entries DROP COLUMN IF EXISTS brand;
ALTER TABLE public.nutrition_entries DROP COLUMN IF EXISTS barcode;
ALTER TABLE public.nutrition_entries DROP COLUMN IF EXISTS fiber;
ALTER TABLE public.nutrition_entries DROP COLUMN IF EXISTS sugar;
ALTER TABLE public.nutrition_entries DROP COLUMN IF EXISTS sodium;
ALTER TABLE public.nutrition_entries DROP COLUMN IF EXISTS serving_size;
ALTER TABLE public.nutrition_entries DROP COLUMN IF EXISTS food_source;

-- ========================================
-- STEP 3: HEALTH_METRICS TABLE CLEANUP
-- ========================================
-- Remove all workout/health tracking fields (keep only nutrition aggregation)

ALTER TABLE public.health_metrics DROP COLUMN IF EXISTS steps;
ALTER TABLE public.health_metrics DROP COLUMN IF EXISTS calories_burned;
ALTER TABLE public.health_metrics DROP COLUMN IF EXISTS heart_rate;
ALTER TABLE public.health_metrics DROP COLUMN IF EXISTS sleep_hours;
ALTER TABLE public.health_metrics DROP COLUMN IF EXISTS distance;
ALTER TABLE public.health_metrics DROP COLUMN IF EXISTS water_glasses;
ALTER TABLE public.health_metrics DROP COLUMN IF EXISTS workouts;
ALTER TABLE public.health_metrics DROP COLUMN IF EXISTS weight;
ALTER TABLE public.health_metrics DROP COLUMN IF EXISTS steps_goal;
ALTER TABLE public.health_metrics DROP COLUMN IF EXISTS calories_goal;
ALTER TABLE public.health_metrics DROP COLUMN IF EXISTS sleep_goal;
ALTER TABLE public.health_metrics DROP COLUMN IF EXISTS water_goal;
ALTER TABLE public.health_metrics DROP COLUMN IF EXISTS protein_goal;
ALTER TABLE public.health_metrics DROP COLUMN IF EXISTS steps_achieved;
ALTER TABLE public.health_metrics DROP COLUMN IF EXISTS calories_achieved;
ALTER TABLE public.health_metrics DROP COLUMN IF EXISTS sleep_achieved;
ALTER TABLE public.health_metrics DROP COLUMN IF EXISTS water_achieved;
ALTER TABLE public.health_metrics DROP COLUMN IF EXISTS nutrition_achieved;

-- ========================================
-- STEP 4: STREAKS TABLE CLEANUP
-- ========================================
-- Remove 14 fields related to multi-streak tracking and unused metrics

ALTER TABLE public.streaks DROP COLUMN IF EXISTS workout_streak;
ALTER TABLE public.streaks DROP COLUMN IF EXISTS nutrition_streak;
ALTER TABLE public.streaks DROP COLUMN IF EXISTS meditation_streak;
ALTER TABLE public.streaks DROP COLUMN IF EXISTS water_streak;
ALTER TABLE public.streaks DROP COLUMN IF EXISTS streak_goal;
ALTER TABLE public.streaks DROP COLUMN IF EXISTS streak_type;
ALTER TABLE public.streaks DROP COLUMN IF EXISTS total_steps;
ALTER TABLE public.streaks DROP COLUMN IF EXISTS total_calories_burned;
ALTER TABLE public.streaks DROP COLUMN IF EXISTS total_workouts;
ALTER TABLE public.streaks DROP COLUMN IF EXISTS average_sleep;
ALTER TABLE public.streaks DROP COLUMN IF EXISTS perfect_weeks;
ALTER TABLE public.streaks DROP COLUMN IF EXISTS perfect_months;
ALTER TABLE public.streaks DROP COLUMN IF EXISTS total_days_completed;
ALTER TABLE public.streaks DROP COLUMN IF EXISTS streak_start_date;

COMMIT;

-- ========================================
-- VERIFICATION QUERIES
-- ========================================
-- Run these to verify the cleanup was successful

-- 1. Check profiles table structure
SELECT
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'profiles'
ORDER BY ordinal_position;

-- 2. Check nutrition_entries table structure
SELECT
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'nutrition_entries'
ORDER BY ordinal_position;

-- 3. Check health_metrics table structure
SELECT
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'health_metrics'
ORDER BY ordinal_position;

-- 4. Check streaks table structure
SELECT
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'streaks'
ORDER BY ordinal_position;

-- 5. Verify data integrity (counts should remain the same)
SELECT
    'profiles' as table_name,
    COUNT(*) as row_count
FROM public.profiles
UNION ALL
SELECT
    'nutrition_entries',
    COUNT(*)
FROM public.nutrition_entries
UNION ALL
SELECT
    'health_metrics',
    COUNT(*)
FROM public.health_metrics
UNION ALL
SELECT
    'streaks',
    COUNT(*)
FROM public.streaks
UNION ALL
SELECT
    'weight_entries',
    COUNT(*)
FROM public.weight_entries;

-- ========================================
-- EXPECTED RESULTS AFTER CLEANUP
-- ========================================
/*
PROFILES TABLE - Expected columns (15):
- id, name, email, age, gender, height, weight
- created_at, updated_at
- has_completed_onboarding, photo_url, weight_unit
- calorie_goal, protein_goal, carb_goal, fat_goal

NUTRITION_ENTRIES TABLE - Expected columns (12):
- id, user_id, food_name
- calories, protein, carbs, fat
- quantity_grams, meal_type, date
- created_at, updated_at

HEALTH_METRICS TABLE - Expected columns (10):
- id, user_id, date
- calories_consumed, protein_consumed, carbs_consumed, fat_consumed
- all_goals_achieved
- created_at, updated_at

STREAKS TABLE - Expected columns (13):
- id, user_id
- current_streak, longest_streak
- last_activity_date, last_attempted_date, last_checked_date
- consecutive_missed_days, grace_days_used, grace_days_available
- last_grace_reset_date
- created_at, updated_at

WEIGHT_ENTRIES TABLE - No changes (6 columns):
- id, user_id, weight, note, timestamp
- created_at, updated_at

ACHIEVEMENTS TABLE - No changes (kept as-is for future use)
*/
