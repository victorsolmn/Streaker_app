-- Achievement Notification Triggers
-- These triggers automatically send push notifications when users hit milestones

-- Enable the http extension for making HTTP requests from triggers
CREATE EXTENSION IF NOT EXISTS http;

-- Function to send achievement notification via Edge Function
CREATE OR REPLACE FUNCTION notify_streak_achievement()
RETURNS TRIGGER AS $$
DECLARE
  milestone_streaks INTEGER[] := ARRAY[3, 7, 14, 21, 30, 60, 90, 100, 180, 365];
  response http_response;
BEGIN
  -- Check if new streak count is a milestone
  IF NEW.current_streak = ANY(milestone_streaks) THEN
    -- Only notify if streak increased (not decreased or reset)
    IF OLD.current_streak IS NULL OR NEW.current_streak > OLD.current_streak THEN
      BEGIN
        SELECT * INTO response FROM http_post(
          'https://xzwvckziavhzmghizyqx.supabase.co/functions/v1/achievement-notification',
          json_build_object(
            'user_id', NEW.user_id,
            'streak_count', NEW.current_streak,
            'achievement_type', 'streak'
          )::text,
          'application/json'
        );
        RAISE NOTICE 'Achievement notification sent for user % at streak %', NEW.user_id, NEW.current_streak;
      EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Failed to send achievement notification: %', SQLERRM;
      END;
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to notify on first meal log
CREATE OR REPLACE FUNCTION notify_first_meal_log()
RETURNS TRIGGER AS $$
DECLARE
  meal_count INTEGER;
  response http_response;
BEGIN
  -- Count existing meals for this user
  SELECT COUNT(*) INTO meal_count
  FROM meals
  WHERE user_id = NEW.user_id AND id != NEW.id;

  -- If this is the first meal, send notification
  IF meal_count = 0 THEN
    BEGIN
      SELECT * INTO response FROM http_post(
        'https://xzwvckziavhzmghizyqx.supabase.co/functions/v1/achievement-notification',
        json_build_object(
          'user_id', NEW.user_id,
          'streak_count', 0,
          'achievement_type', 'first_log'
        )::text,
        'application/json'
      );
      RAISE NOTICE 'First meal notification sent for user %', NEW.user_id;
    EXCEPTION WHEN OTHERS THEN
      RAISE NOTICE 'Failed to send first meal notification: %', SQLERRM;
    END;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to notify when daily goal is achieved
CREATE OR REPLACE FUNCTION notify_goal_achieved()
RETURNS TRIGGER AS $$
DECLARE
  response http_response;
BEGIN
  -- Check if goal was just achieved (changed from false to true)
  IF NEW.all_goals_achieved = true AND (OLD.all_goals_achieved IS NULL OR OLD.all_goals_achieved = false) THEN
    BEGIN
      SELECT * INTO response FROM http_post(
        'https://xzwvckziavhzmghizyqx.supabase.co/functions/v1/achievement-notification',
        json_build_object(
          'user_id', NEW.user_id,
          'streak_count', 0,
          'achievement_type', 'goal'
        )::text,
        'application/json'
      );
      RAISE NOTICE 'Goal achieved notification sent for user %', NEW.user_id;
    EXCEPTION WHEN OTHERS THEN
      RAISE NOTICE 'Failed to send goal notification: %', SQLERRM;
    END;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for streak milestones
-- First, drop if exists to allow re-running
DROP TRIGGER IF EXISTS trigger_streak_achievement ON streaks;
CREATE TRIGGER trigger_streak_achievement
  AFTER INSERT OR UPDATE OF current_streak ON streaks
  FOR EACH ROW
  EXECUTE FUNCTION notify_streak_achievement();

-- Create trigger for first meal log
DROP TRIGGER IF EXISTS trigger_first_meal ON meals;
CREATE TRIGGER trigger_first_meal
  AFTER INSERT ON meals
  FOR EACH ROW
  EXECUTE FUNCTION notify_first_meal_log();

-- Create trigger for daily goal achievement
DROP TRIGGER IF EXISTS trigger_goal_achieved ON daily_metrics;
CREATE TRIGGER trigger_goal_achieved
  AFTER INSERT OR UPDATE OF all_goals_achieved ON daily_metrics
  FOR EACH ROW
  EXECUTE FUNCTION notify_goal_achieved();

-- Comments for documentation
COMMENT ON FUNCTION notify_streak_achievement() IS 'Sends push notification when user hits a streak milestone (3, 7, 14, 21, 30, 60, 90, 100, 180, 365 days)';
COMMENT ON FUNCTION notify_first_meal_log() IS 'Sends welcome push notification when user logs their first meal';
COMMENT ON FUNCTION notify_goal_achieved() IS 'Sends congratulations push notification when user achieves all daily goals';

-- View to check triggers
-- SELECT * FROM information_schema.triggers WHERE trigger_schema = 'public';
