-- Achievement Notification Triggers (Corrected Version)
-- These triggers automatically send push notifications when users hit milestones
--
-- Tables used in app:
-- - streaks: current_streak, longest_streak, user_id
-- - nutrition_entries: meals logged
-- - profiles: user profile data
-- - daily_nutrition_summary: daily totals with all_goals_achieved

-- Enable the http extension for making HTTP requests from triggers
CREATE EXTENSION IF NOT EXISTS http WITH SCHEMA extensions;

-- ============================================
-- 1. STREAK MILESTONE TRIGGER
-- ============================================
-- Sends notification when user hits 3, 7, 14, 21, 30, 60, 90, 100, 180, 365 day streaks

CREATE OR REPLACE FUNCTION notify_streak_achievement()
RETURNS TRIGGER AS $$
DECLARE
  milestone_streaks INTEGER[] := ARRAY[3, 7, 14, 21, 30, 60, 90, 100, 180, 365];
BEGIN
  -- Check if new streak count is a milestone
  IF NEW.current_streak = ANY(milestone_streaks) THEN
    -- Only notify if streak increased (not decreased or unchanged)
    IF OLD.current_streak IS NULL OR NEW.current_streak > OLD.current_streak THEN
      BEGIN
        PERFORM extensions.http_post(
          url := 'https://xzwvckziavhzmghizyqx.supabase.co/functions/v1/achievement-notification',
          body := json_build_object(
            'user_id', NEW.user_id,
            'streak_count', NEW.current_streak,
            'achievement_type', 'streak'
          )::text,
          content_type := 'application/json'
        );
        RAISE LOG 'Achievement notification sent for user % at streak %', NEW.user_id, NEW.current_streak;
      EXCEPTION WHEN OTHERS THEN
        RAISE LOG 'Failed to send achievement notification: %', SQLERRM;
      END;
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create the trigger on streaks table
DROP TRIGGER IF EXISTS trigger_streak_achievement ON streaks;
CREATE TRIGGER trigger_streak_achievement
  AFTER INSERT OR UPDATE OF current_streak ON streaks
  FOR EACH ROW
  EXECUTE FUNCTION notify_streak_achievement();

-- ============================================
-- 2. FIRST MEAL LOG TRIGGER
-- ============================================
-- Sends welcome notification when user logs their very first meal

CREATE OR REPLACE FUNCTION notify_first_meal_log()
RETURNS TRIGGER AS $$
DECLARE
  meal_count INTEGER;
BEGIN
  -- Count existing meals for this user (excluding the one just inserted)
  SELECT COUNT(*) INTO meal_count
  FROM nutrition_entries
  WHERE user_id = NEW.user_id AND id != NEW.id;

  -- If this is the first meal, send notification
  IF meal_count = 0 THEN
    BEGIN
      PERFORM extensions.http_post(
        url := 'https://xzwvckziavhzmghizyqx.supabase.co/functions/v1/achievement-notification',
        body := json_build_object(
          'user_id', NEW.user_id,
          'streak_count', 0,
          'achievement_type', 'first_log'
        )::text,
        content_type := 'application/json'
      );
      RAISE LOG 'First meal notification sent for user %', NEW.user_id;
    EXCEPTION WHEN OTHERS THEN
      RAISE LOG 'Failed to send first meal notification: %', SQLERRM;
    END;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create the trigger on nutrition_entries table
DROP TRIGGER IF EXISTS trigger_first_meal ON nutrition_entries;
CREATE TRIGGER trigger_first_meal
  AFTER INSERT ON nutrition_entries
  FOR EACH ROW
  EXECUTE FUNCTION notify_first_meal_log();

-- ============================================
-- 3. DAILY GOAL ACHIEVED TRIGGER
-- ============================================
-- Sends notification when user achieves all daily nutrition goals

CREATE OR REPLACE FUNCTION notify_goal_achieved()
RETURNS TRIGGER AS $$
BEGIN
  -- Check if goal was just achieved (changed from false/null to true)
  IF NEW.all_goals_achieved = true AND (OLD.all_goals_achieved IS NULL OR OLD.all_goals_achieved = false) THEN
    BEGIN
      PERFORM extensions.http_post(
        url := 'https://xzwvckziavhzmghizyqx.supabase.co/functions/v1/achievement-notification',
        body := json_build_object(
          'user_id', NEW.user_id,
          'streak_count', 0,
          'achievement_type', 'goal'
        )::text,
        content_type := 'application/json'
      );
      RAISE LOG 'Goal achieved notification sent for user %', NEW.user_id;
    EXCEPTION WHEN OTHERS THEN
      RAISE LOG 'Failed to send goal notification: %', SQLERRM;
    END;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create the trigger on daily_nutrition_summary table
DROP TRIGGER IF EXISTS trigger_goal_achieved ON daily_nutrition_summary;
CREATE TRIGGER trigger_goal_achieved
  AFTER INSERT OR UPDATE OF all_goals_achieved ON daily_nutrition_summary
  FOR EACH ROW
  EXECUTE FUNCTION notify_goal_achieved();

-- ============================================
-- DOCUMENTATION
-- ============================================
COMMENT ON FUNCTION notify_streak_achievement() IS 'Sends push notification when user hits a streak milestone (3, 7, 14, 21, 30, 60, 90, 100, 180, 365 days)';
COMMENT ON FUNCTION notify_first_meal_log() IS 'Sends welcome push notification when user logs their first meal ever';
COMMENT ON FUNCTION notify_goal_achieved() IS 'Sends congratulations push notification when user achieves all daily nutrition goals';

-- ============================================
-- VERIFICATION QUERIES
-- ============================================
-- Run these to verify triggers are set up correctly:

-- List all triggers:
-- SELECT trigger_name, event_manipulation, event_object_table, action_statement
-- FROM information_schema.triggers
-- WHERE trigger_schema = 'public';

-- Check trigger functions:
-- SELECT proname, prosrc FROM pg_proc WHERE proname LIKE 'notify_%';
