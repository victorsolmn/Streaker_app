-- Migration: Remove workout-based achievements and related triggers
-- This migration removes all workout/health tracking achievements and keeps only nutrition streak-based achievements

-- Drop the workout achievement trigger and function
DROP TRIGGER IF EXISTS trigger_check_workout_achievements ON health_metrics;
DROP FUNCTION IF EXISTS check_workout_achievements();

-- Delete workout-based achievements from user_achievements first (foreign key constraint)
DELETE FROM user_achievements
WHERE achievement_id IN ('warm_up', 'sweatflix', 'gym_goblin', 'no_days_off');

-- Delete workout-based achievement progress
DELETE FROM achievement_progress
WHERE achievement_id IN ('warm_up', 'sweatflix', 'gym_goblin', 'no_days_off');

-- Delete workout-based achievements from the achievements table
DELETE FROM achievements
WHERE id IN ('warm_up', 'sweatflix', 'gym_goblin', 'no_days_off');

-- Update remaining special achievements to reflect nutrition-only focus
-- (comeback_kid is kept as it applies to nutrition streak recovery)

-- Re-order remaining achievements for better display
UPDATE achievements SET sort_order = 1 WHERE id = 'no_excuses';
UPDATE achievements SET sort_order = 2 WHERE id = 'sweat_starter';
UPDATE achievements SET sort_order = 3 WHERE id = 'grind_machine';
UPDATE achievements SET sort_order = 4 WHERE id = 'beast_mode';
UPDATE achievements SET sort_order = 5 WHERE id = 'iron_month';
UPDATE achievements SET sort_order = 6 WHERE id = 'quarter_crusher';
UPDATE achievements SET sort_order = 7 WHERE id = 'half_year';
UPDATE achievements SET sort_order = 8 WHERE id = 'comeback_kid';
UPDATE achievements SET sort_order = 9 WHERE id = 'year_one';
UPDATE achievements SET sort_order = 10 WHERE id = 'streak_titan';
UPDATE achievements SET sort_order = 11 WHERE id = 'immortal';

-- Update achievement descriptions to reflect nutrition focus
UPDATE achievements SET
  description = 'Your first 3-day nutrition streak!'
WHERE id = 'no_excuses';

UPDATE achievements SET
  description = 'First 7-day nutrition streak, habit unlocked'
WHERE id = 'sweat_starter';

UPDATE achievements SET
  description = '14 days of nutrition tracking'
WHERE id = 'grind_machine';

UPDATE achievements SET
  description = '21 days of nutrition tracking, habit locked!'
WHERE id = 'beast_mode';

UPDATE achievements SET
  description = '30 days nutrition streak, strong foundation'
WHERE id = 'iron_month';

UPDATE achievements SET
  description = '90 days nutrition streak, domination'
WHERE id = 'quarter_crusher';

UPDATE achievements SET
  description = '180 days nutrition streak, crowned king 👑'
WHERE id = 'half_year';

UPDATE achievements SET
  description = 'Lost nutrition streak, but bounced back fast'
WHERE id = 'comeback_kid';

UPDATE achievements SET
  description = '365 days nutrition streak, respect earned 🔥'
WHERE id = 'year_one';

UPDATE achievements SET
  description = '500 days nutrition tracking, godlike consistency'
WHERE id = 'streak_titan';

UPDATE achievements SET
  description = '1000 days nutrition tracking, immortality achieved'
WHERE id = 'immortal';

-- Note: The check_streak_achievements() function and trigger remain active
-- as they still handle nutrition-based streak achievements
