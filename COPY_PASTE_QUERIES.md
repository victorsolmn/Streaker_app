# 📋 Copy-Paste SQL Queries for Supabase

Run these queries in order in your **Supabase Dashboard → SQL Editor**

---

## ✅ STEP 1: Main Migration (Required)

**Copy and paste this entire block into Supabase SQL Editor:**

```sql
-- ============================================
-- STREAK SYSTEM FIX - MAIN MIGRATION
-- ============================================

-- 1. Nutrition aggregation function
CREATE OR REPLACE FUNCTION aggregate_daily_nutrition(p_user_id UUID, p_date DATE)
RETURNS TABLE(
  total_calories DECIMAL,
  total_protein DECIMAL,
  total_carbs DECIMAL,
  total_fat DECIMAL,
  total_fiber DECIMAL
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    COALESCE(SUM(calories), 0) AS total_calories,
    COALESCE(SUM(protein), 0) AS total_protein,
    COALESCE(SUM(carbs), 0) AS total_carbs,
    COALESCE(SUM(fat), 0) AS total_fat,
    COALESCE(SUM(fiber), 0) AS total_fiber
  FROM nutrition_entries
  WHERE user_id = p_user_id AND date = p_date;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Auto-sync trigger function
CREATE OR REPLACE FUNCTION sync_nutrition_to_health_metrics()
RETURNS TRIGGER AS $$
DECLARE
  v_nutrition RECORD;
  v_date DATE;
  v_user_id UUID;
BEGIN
  IF TG_OP = 'DELETE' THEN
    v_date := OLD.date;
    v_user_id := OLD.user_id;
  ELSE
    v_date := NEW.date;
    v_user_id := NEW.user_id;
  END IF;

  SELECT * INTO v_nutrition FROM aggregate_daily_nutrition(v_user_id, v_date);

  INSERT INTO health_metrics (
    user_id, date, calories_consumed, protein, carbs, fat, fiber, updated_at
  ) VALUES (
    v_user_id, v_date,
    v_nutrition.total_calories, v_nutrition.total_protein,
    v_nutrition.total_carbs, v_nutrition.total_fat, v_nutrition.total_fiber,
    NOW()
  )
  ON CONFLICT (user_id, date) DO UPDATE SET
    calories_consumed = EXCLUDED.calories_consumed,
    protein = EXCLUDED.protein,
    carbs = EXCLUDED.carbs,
    fat = EXCLUDED.fat,
    fiber = EXCLUDED.fiber,
    updated_at = NOW();

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Attach trigger to nutrition_entries
DROP TRIGGER IF EXISTS trigger_sync_nutrition_to_health_metrics ON nutrition_entries;
CREATE TRIGGER trigger_sync_nutrition_to_health_metrics
  AFTER INSERT OR UPDATE OR DELETE ON nutrition_entries
  FOR EACH ROW EXECUTE FUNCTION sync_nutrition_to_health_metrics();

-- 4. Goal achievement calculation function
CREATE OR REPLACE FUNCTION calculate_goal_achievements(p_metric_id UUID)
RETURNS void AS $$
DECLARE
  v_metric RECORD;
  v_steps_achieved BOOLEAN;
  v_calories_achieved BOOLEAN;
  v_sleep_achieved BOOLEAN;
  v_water_achieved BOOLEAN;
  v_nutrition_achieved BOOLEAN;
  v_all_goals_achieved BOOLEAN;
BEGIN
  SELECT * INTO v_metric FROM health_metrics WHERE id = p_metric_id;
  IF NOT FOUND THEN RETURN; END IF;

  v_steps_achieved := COALESCE(v_metric.steps, 0) >= (COALESCE(v_metric.steps_goal, 10000) * 0.8);
  v_calories_achieved := (COALESCE(v_metric.calories_consumed, 0) <= (COALESCE(v_metric.calories_goal, 2000) * 1.2))
                         AND (COALESCE(v_metric.calories_consumed, 0) > 0);
  v_sleep_achieved := COALESCE(v_metric.sleep_hours, 0) >= (COALESCE(v_metric.sleep_goal, 8.0) * 0.8);
  v_water_achieved := COALESCE(v_metric.water_glasses, 0) >= COALESCE(v_metric.water_goal, 8);
  v_nutrition_achieved := COALESCE(v_metric.calories_consumed, 0) > 0;
  v_all_goals_achieved := v_steps_achieved AND v_calories_achieved AND v_sleep_achieved AND v_nutrition_achieved;

  UPDATE health_metrics SET
    steps_achieved = v_steps_achieved,
    calories_achieved = v_calories_achieved,
    sleep_achieved = v_sleep_achieved,
    water_achieved = v_water_achieved,
    nutrition_achieved = v_nutrition_achieved,
    all_goals_achieved = v_all_goals_achieved,
    updated_at = NOW()
  WHERE id = p_metric_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. Auto-calculate goals trigger
CREATE OR REPLACE FUNCTION trigger_calculate_goal_achievements()
RETURNS TRIGGER AS $$
BEGIN
  PERFORM calculate_goal_achievements(NEW.id);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_auto_calculate_goals ON health_metrics;
CREATE TRIGGER trigger_auto_calculate_goals
  AFTER INSERT OR UPDATE ON health_metrics
  FOR EACH ROW EXECUTE FUNCTION trigger_calculate_goal_achievements();

-- 6. Streak update function
CREATE OR REPLACE FUNCTION update_user_streak(p_user_id UUID, p_date DATE)
RETURNS void AS $$
DECLARE
  v_metric RECORD;
  v_streak RECORD;
  v_yesterday DATE;
  v_new_streak INT;
  v_new_longest INT;
BEGIN
  SELECT * INTO v_metric FROM health_metrics WHERE user_id = p_user_id AND date = p_date;
  IF NOT COALESCE(v_metric.all_goals_achieved, FALSE) THEN RETURN; END IF;

  SELECT * INTO v_streak FROM streaks WHERE user_id = p_user_id AND streak_type = 'daily';

  IF NOT FOUND THEN
    INSERT INTO streaks (user_id, streak_type, current_streak, longest_streak, last_completed_date, last_activity_date, last_checked_date, total_days_completed)
    VALUES (p_user_id, 'daily', 1, 1, p_date, p_date, p_date, 1);
    RETURN;
  END IF;

  v_yesterday := p_date - INTERVAL '1 day';

  IF v_streak.last_completed_date = v_yesterday THEN
    v_new_streak := v_streak.current_streak + 1;
  ELSIF v_streak.last_completed_date = p_date THEN
    v_new_streak := v_streak.current_streak;
  ELSE
    v_new_streak := 1;
  END IF;

  v_new_longest := GREATEST(COALESCE(v_streak.longest_streak, 0), v_new_streak);

  UPDATE streaks SET
    current_streak = v_new_streak,
    longest_streak = v_new_longest,
    last_completed_date = p_date,
    last_activity_date = p_date,
    last_checked_date = p_date,
    total_days_completed = CASE WHEN v_streak.last_completed_date = p_date THEN total_days_completed ELSE total_days_completed + 1 END,
    consecutive_missed_days = 0,
    updated_at = NOW()
  WHERE user_id = p_user_id AND streak_type = 'daily';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 7. Auto-update streak trigger
CREATE OR REPLACE FUNCTION trigger_update_streak_on_goals_achieved()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.all_goals_achieved = TRUE AND (OLD.all_goals_achieved IS NULL OR OLD.all_goals_achieved = FALSE) THEN
    PERFORM update_user_streak(NEW.user_id, NEW.date);
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_auto_update_streak ON health_metrics;
CREATE TRIGGER trigger_auto_update_streak
  AFTER UPDATE ON health_metrics
  FOR EACH ROW EXECUTE FUNCTION trigger_update_streak_on_goals_achieved();

-- 8. Manual sync RPC function
CREATE OR REPLACE FUNCTION sync_user_daily_data(p_user_id UUID, p_date DATE DEFAULT CURRENT_DATE)
RETURNS JSON AS $$
DECLARE
  v_nutrition RECORD;
  v_metric_id UUID;
  v_result JSON;
BEGIN
  -- Sync nutrition
  SELECT * INTO v_nutrition FROM aggregate_daily_nutrition(p_user_id, p_date);
  INSERT INTO health_metrics (user_id, date, calories_consumed, protein, carbs, fat, fiber, updated_at)
  VALUES (p_user_id, p_date, v_nutrition.total_calories, v_nutrition.total_protein, v_nutrition.total_carbs, v_nutrition.total_fat, v_nutrition.total_fiber, NOW())
  ON CONFLICT (user_id, date) DO UPDATE SET
    calories_consumed = EXCLUDED.calories_consumed,
    protein = EXCLUDED.protein,
    carbs = EXCLUDED.carbs,
    fat = EXCLUDED.fat,
    fiber = EXCLUDED.fiber,
    updated_at = NOW();

  -- Recalculate goals
  SELECT id INTO v_metric_id FROM health_metrics WHERE user_id = p_user_id AND date = p_date;
  IF v_metric_id IS NOT NULL THEN
    PERFORM calculate_goal_achievements(v_metric_id);
  END IF;

  -- Update streak
  PERFORM update_user_streak(p_user_id, p_date);

  -- Return result
  SELECT json_build_object(
    'health_metrics', (SELECT row_to_json(h.*) FROM health_metrics h WHERE h.user_id = p_user_id AND h.date = p_date),
    'streak', (SELECT row_to_json(s.*) FROM streaks s WHERE s.user_id = p_user_id AND s.streak_type = 'daily'),
    'synced_at', NOW()
  ) INTO v_result;

  RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION sync_user_daily_data(UUID, DATE) TO authenticated;

-- 9. Create audit log table
CREATE TABLE IF NOT EXISTS sync_audit_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  sync_type TEXT NOT NULL,
  date_synced DATE NOT NULL,
  success BOOLEAN DEFAULT TRUE,
  error_message TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_sync_audit_log_user_date ON sync_audit_log(user_id, date_synced DESC);
ALTER TABLE sync_audit_log ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view own sync logs" ON sync_audit_log FOR SELECT USING (auth.uid() = user_id);

-- Success message
DO $$
BEGIN
  RAISE NOTICE '🎉 MIGRATION COMPLETED! All functions and triggers created successfully.';
END $$;
```

**Expected Output:** `🎉 MIGRATION COMPLETED!`

---

## ✅ STEP 2: Backfill Historical Data (Required)

**Copy and paste this entire block:**

```sql
-- ============================================
-- BACKFILL HISTORICAL DATA
-- ============================================

-- Sync all nutrition to health_metrics
DO $$
DECLARE
  v_user RECORD;
  v_date RECORD;
  v_count INT := 0;
BEGIN
  FOR v_user IN SELECT DISTINCT user_id FROM nutrition_entries LOOP
    FOR v_date IN SELECT DISTINCT date FROM nutrition_entries WHERE user_id = v_user.user_id LOOP
      PERFORM sync_user_daily_data(v_user.user_id, v_date.date);
      v_count := v_count + 1;
    END LOOP;
  END LOOP;
  RAISE NOTICE '✅ Backfilled % dates', v_count;
END $$;

-- Success message
DO $$
BEGIN
  RAISE NOTICE '🎉 BACKFILL COMPLETED! Historical data has been fixed.';
END $$;
```

**Expected Output:** `✅ Backfilled X dates` and `🎉 BACKFILL COMPLETED!`

---

## ✅ STEP 3: Verify October 3rd Fix (Verification)

**Copy and paste this to verify it worked:**

```sql
-- Check October 3rd data
SELECT
  '📊 Nutrition Entries' as section,
  COUNT(*) as count,
  SUM(calories) as total_calories
FROM nutrition_entries
WHERE user_id = '5acc8e5f-03b2-48cf-bd29-f7a2f1fc06e9' AND date = '2025-10-03'

UNION ALL

SELECT
  '🏃 Health Metrics' as section,
  1 as count,
  calories_consumed as total_calories
FROM health_metrics
WHERE user_id = '5acc8e5f-03b2-48cf-bd29-f7a2f1fc06e9' AND date = '2025-10-03'

UNION ALL

SELECT
  '🔥 Current Streak' as section,
  current_streak as count,
  longest_streak as total_calories
FROM streaks
WHERE user_id = '5acc8e5f-03b2-48cf-bd29-f7a2f1fc06e9' AND streak_type = 'daily';
```

**Expected Result:**
- Nutrition: 3 entries, 2,885 calories
- Health Metrics: 2,885 calories (not 0!)
- Streak: Updated value

---

## ✅ STEP 4: Test Real-Time Sync (Optional Test)

**Insert a test entry to verify triggers work:**

```sql
-- Insert test nutrition entry
INSERT INTO nutrition_entries (user_id, food_name, calories, protein, carbs, fat, fiber, date)
VALUES (
  '5acc8e5f-03b2-48cf-bd29-f7a2f1fc06e9',
  'Test Food - Delete Me',
  100,
  10,
  15,
  5,
  2,
  CURRENT_DATE
);

-- Check if it auto-synced (should happen immediately)
SELECT calories_consumed FROM health_metrics
WHERE user_id = '5acc8e5f-03b2-48cf-bd29-f7a2f1fc06e9' AND date = CURRENT_DATE;

-- Delete test entry
DELETE FROM nutrition_entries
WHERE user_id = '5acc8e5f-03b2-48cf-bd29-f7a2f1fc06e9'
  AND food_name = 'Test Food - Delete Me';

-- Verify it auto-updated
SELECT calories_consumed FROM health_metrics
WHERE user_id = '5acc8e5f-03b2-48cf-bd29-f7a2f1fc06e9' AND date = CURRENT_DATE;
```

---

## 🎯 That's It!

After running these 3 SQL blocks:
1. ✅ All functions and triggers will be active
2. ✅ Historical data (including Oct 3rd) will be fixed
3. ✅ Future syncs will happen automatically

**No manual intervention needed going forward!** 🔥

---

## 📱 Next: Deploy App

After database is updated, run:
```bash
cd /Users/Vicky/Streaker_app
flutter pub get
flutter build apk --release
```

---

## 🆘 Troubleshooting

If you get errors, check:
1. Make sure you're in **SQL Editor** (not REST API)
2. Run each block separately if needed
3. Check for typos in copy-paste
4. Verify user ID: `5acc8e5f-03b2-48cf-bd29-f7a2f1fc06e9`

**Need help?** Check the full deployment guide at `/DEPLOYMENT_GUIDE.md`
