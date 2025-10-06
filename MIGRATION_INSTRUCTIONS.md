# 🚀 MIGRATION DEPLOYMENT INSTRUCTIONS

## Quick Deploy (Copy & Paste)

1. **Open Supabase SQL Editor:**
   - Go to: https://supabase.com/dashboard/project/xzwvckziavhzmghizyqx/sql/new
   - Or navigate: Dashboard → SQL Editor → New Query

2. **Copy the entire migration:**
   - File location: `/Users/Vicky/Streaker_app/supabase/migrations/20251005_comprehensive_streak_fix.sql`

3. **Paste and Run:**
   - Paste the SQL into the editor
   - Click "Run" or press Cmd+Enter

## What This Migration Does:

✅ **Immediate Fixes:**
- Increases calorie threshold from 120% to 150%
- Changes "all goals" requirement from 5/5 to 4/5
- Fixes trigger to fire on ALL updates (not just successes)

✅ **Grace Period Implementation:**
- Properly tracks and uses grace days (2 days allowance)
- Maintains streak during grace period
- Resets grace days when streak breaks

✅ **Tracking & Debugging:**
- Creates `streak_history` table to track all changes
- Logs every streak update with reason
- Helps debug future issues

✅ **Daily Automation:**
- Creates `check_all_user_streaks()` function
- Can be called manually or via cron job
- Processes all users at midnight

✅ **Data Fix:**
- Recalculates your recent metrics (Oct 3-5)
- Applies new thresholds retroactively
- Should restore proper streak value

## Next Steps After Migration:

1. **Enable pg_cron Extension:**
   - Go to: Database → Extensions
   - Find "pg_cron" and enable it
   - This allows scheduled jobs

2. **Create Edge Function for Daily Check:**
   - We'll create this next to run at midnight daily

3. **Test the System:**
   - We'll run comprehensive tests to verify everything works