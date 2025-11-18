-- Check yesterday's nutrition data
SELECT 
    'Yesterday Nutrition Entries' as check_type,
    date,
    COUNT(*) as entry_count,
    SUM(calories) as total_calories
FROM nutrition_entries
WHERE user_id = '5acc8e5f-03b2-48cf-bd29-f7a2f1fc06e9'
AND date = CURRENT_DATE - INTERVAL '1 day'
GROUP BY date;

-- Check yesterday's daily nutrition summary
SELECT
    'Yesterday Daily Summary' as check_type,
    date,
    total_calories,
    calorie_target,
    goal_achieved,
    updated_at
FROM daily_nutrition_summary
WHERE user_id = '5acc8e5f-03b2-48cf-bd29-f7a2f1fc06e9'
AND date = CURRENT_DATE - INTERVAL '1 day';

-- Check current streak
SELECT
    'Current Streak' as check_type,
    current_streak,
    longest_streak,
    last_completed_date,
    last_activity_date,
    grace_days_used,
    consecutive_missed_days
FROM streaks
WHERE user_id = '5acc8e5f-03b2-48cf-bd29-f7a2f1fc06e9';

-- Check user's calorie target
SELECT
    'User Profile' as check_type,
    daily_calories_target
FROM profiles
WHERE id = '5acc8e5f-03b2-48cf-bd29-f7a2f1fc06e9';

-- Check recent streak history
SELECT
    'Recent Streak History' as check_type,
    date,
    previous_streak,
    new_streak,
    action,
    reason,
    all_goals_achieved
FROM streak_history
WHERE user_id = '5acc8e5f-03b2-48cf-bd29-f7a2f1fc06e9'
ORDER BY created_at DESC
LIMIT 5;
