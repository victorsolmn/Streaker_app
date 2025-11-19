# 🎯 Database Migration Execution Guide

## ✅ Progress So Far

- **✅ MIGRATION 003 COMPLETE** - Workout achievements removed successfully
- **❌ CODE FIXES:** 100% Complete - All app code ready
- **❌ MIGRATION 004:** Pending - Drop health_metrics table
- **❌ MIGRATION 005:** Pending - Drop calorie tracking tables

---

## 🔧 How to Execute Remaining Migrations

### Option 1: Supabase SQL Editor (Recommended)

1. **Open Supabase SQL Editor:**
   - Go to: https://supabase.com/dashboard/project/xzwvckziavhzmghizyqx/sql
   - Click "New query"

2. **Copy & Paste Migration 004:**
   ```sql
   -- ============================================
   -- MIGRATION 004: Remove Health Metrics Table
   -- ============================================

   -- Step 1: Drop triggers
   DROP TRIGGER IF EXISTS update_health_metrics_updated_at ON public.health_metrics;

   -- Step 2: Drop functions
   DROP FUNCTION IF EXISTS public.calculate_daily_calorie_totals(UUID, DATE) CASCADE;
   DROP FUNCTION IF EXISTS public.check_workout_achievements() CASCADE;

   -- Step 3: Drop views
   DROP VIEW IF EXISTS public.user_dashboard CASCADE;

   -- Step 4: Drop the health_metrics table
   DROP TABLE IF EXISTS public.health_metrics CASCADE;

   -- Step 5: Remove health columns from profiles
   ALTER TABLE public.profiles
   DROP COLUMN IF EXISTS daily_steps_target,
   DROP COLUMN IF EXISTS daily_sleep_target,
   DROP COLUMN IF EXISTS daily_water_target,
   DROP COLUMN IF EXISTS daily_active_calories_target,
   DROP COLUMN IF EXISTS device_name,
   DROP COLUMN IF EXISTS device_connected;

   -- Step 6: Recreate user_dashboard view
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

   SELECT '✅ Migration 004 completed - health_metrics removed' AS result;
   ```

3. **Click "RUN"** - Wait for success message

4. **Copy & Paste Migration 005:**
   ```sql
   -- ============================================
   -- MIGRATION 005: Remove Calorie Tracking System
   -- ============================================

   -- Step 1: Drop triggers
   DROP TRIGGER IF EXISTS auto_calculate_daily_totals ON public.calorie_sessions;

   -- Step 2: Drop functions
   DROP FUNCTION IF EXISTS public.trigger_calculate_daily_totals();
   DROP FUNCTION IF EXISTS public.get_last_calorie_sync(UUID);
   DROP FUNCTION IF EXISTS public.check_daily_data_completeness(UUID, DATE);

   -- Step 3: Drop views
   DROP VIEW IF EXISTS public.user_calorie_dashboard;

   -- Step 4: Drop tables
   DROP TABLE IF EXISTS public.calorie_sessions CASCADE;
   DROP TABLE IF EXISTS public.daily_calorie_totals CASCADE;

   SELECT '✅ Migration 005 completed - calorie tracking removed' AS result;
   ```

5. **Click "RUN"** - Wait for success message

---

### Option 2: Troubleshoot Supabase SQL Editor Connection

If you see "Connection string is missing" error:

1. **Refresh the Supabase dashboard** - Hard refresh (Cmd+Shift+R or Ctrl+Shift+R)
2. **Check project status** - Make sure project is not paused
3. **Try different browser** - Chrome/Firefox may behave differently
4. **Re-login to Supabase** - Logout and login again
5. **Check connection settings** - Ensure you're connected to the correct project

---

### Option 3: Use Supabase CLI (Alternative)

If SQL Editor fails, install and use Supabase CLI:

```bash
# Install Supabase CLI (if not installed)
brew install supabase/tap/supabase

# Login to Supabase
supabase login

# Link your project
supabase link --project-ref xzwvckziavhzmghizyqx

# Run migrations
supabase db push
```

---

## 📊 Verification After Migrations

After executing both migrations, verify success:

```sql
-- Check remaining tables
SELECT tablename
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY tablename;

-- You should see ONLY these tables:
-- ✅ achievements
-- ✅ achievement_progress
-- ✅ chat_sessions
-- ✅ nutrition_entries
-- ✅ profiles
-- ✅ streaks
-- ✅ user_achievements
-- ✅ weight_entries
```

---

## 🎉 After Migrations Complete

1. **Restart your Flutter app** on iOS simulator
2. **Test key features:**
   - ✅ User login
   - ✅ Nutrition entry creation
   - ✅ Streak tracking
   - ✅ Achievement unlocking
3. **Check logs** for any database errors

---

## ⚠️ Important Notes

- **Do NOT run migrations on production until tested**
- **Backup your database before running** (if this is production data)
- **Migrations are IRREVERSIBLE** - they will delete data
- **App code is already updated** - migrations just cleanup the database

---

## 🆘 Need Help?

If you encounter issues:
1. Check Supabase project status
2. Verify you have correct permissions (service_role)
3. Check error messages carefully
4. Contact Supabase support if connection issues persist
