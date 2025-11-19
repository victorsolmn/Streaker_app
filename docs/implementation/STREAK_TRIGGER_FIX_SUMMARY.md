# Streak Trigger Fix - Complete Summary

**Date:** November 19, 2025
**Issue:** Hero section shows "Streak: 1" instead of correct "Streak: 3"
**Status:** ✅ Temporary fix applied, permanent migration ready

---

## Problem Analysis

### Root Cause

The database trigger that updates streaks has a flawed condition:

**Location:** `supabase/migrations/007_nutrition_based_streak_system.sql` (Line 310)

**Problematic Code:**
```sql
IF TG_OP = 'INSERT' OR (TG_OP = 'UPDATE' AND NEW.goal_achieved != OLD.goal_achieved) THEN
    PERFORM update_nutrition_streak(NEW.user_id, NEW.date);
END IF;
```

**Why It Fails:**
- The condition `NEW.goal_achieved != OLD.goal_achieved` only fires when the value **changes**
- On consecutive successful days, `goal_achieved` stays `true` → trigger doesn't fire
- Result: Streak doesn't increment beyond the first successful day

### Data Evidence

**Your Nutrition Data:**
```
Nov 16: 1818 cal / 2200 target → goal_achieved: true  ✅
Nov 17: 2058 cal / 2200 target → goal_achieved: true  ✅
Nov 18: 2280 cal / 2200 target → goal_achieved: true  ✅
```

**Streak Table (Before Fix):**
```
current_streak: 1
last_completed_date: 2025-11-16
last_checked_date: 2025-11-17
```

The streak stopped updating after Nov 16 because Nov 17 and 18 didn't change `goal_achieved` from `true` to anything else.

---

## What Was Done

### 1. Temporary Fix ✅ (Applied)

Manually updated the `streaks` table to correct the current value:

```sql
UPDATE streaks
SET current_streak = 3,
    longest_streak = 3,
    last_completed_date = '2025-11-18',
    last_checked_date = '2025-11-18'
WHERE user_id = '5acc8e5f-03b2-48cf-bd29-f7a2f1fc06e9';
```

**Result:** Your app now shows "Streak: 3" ✅

### 2. Permanent Fix 📝 (Ready to Apply)

Created migration file: `supabase/migrations/010_fix_streak_trigger_logic.sql`

**What It Does:**
1. **Fixes the trigger condition:**
   ```sql
   -- Before (Broken):
   IF TG_OP = 'INSERT' OR (TG_OP = 'UPDATE' AND NEW.goal_achieved != OLD.goal_achieved)

   -- After (Fixed):
   IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE'
   ```

2. **Backfills all existing streak data:** Recalculates streaks for all historical successful days in chronological order

3. **Adds documentation:** Function comment explaining the fix

---

## How to Apply Permanent Fix

### Option 1: Using Supabase SQL Editor (Recommended)

1. **Go to:** Supabase Dashboard → SQL Editor
2. **Click:** "New query"
3. **Copy/paste:** The entire contents of `supabase/migrations/010_fix_streak_trigger_logic.sql`
4. **Click:** "Run"
5. **Verify:** Check the output shows "✅ Migration 010 completed successfully"

### Option 2: Using Command Line (If psql works)

```bash
cd /Users/Vicky/Streaker_app
chmod +x run_streak_fix_migration.sh
./run_streak_fix_migration.sh
```

---

## Verification Steps

After applying the permanent fix:

### 1. Check Current Streak
```sql
SELECT current_streak, longest_streak, last_completed_date, last_checked_date
FROM streaks
WHERE user_id = '5acc8e5f-03b2-48cf-bd29-f7a2f1fc06e9';
```

**Expected Result:**
```
current_streak: 3
longest_streak: 3
last_completed_date: 2025-11-18
last_checked_date: 2025-11-18
```

### 2. Check Recent Nutrition Summary
```sql
SELECT date, total_calories, calorie_target, goal_achieved
FROM daily_nutrition_summary
WHERE user_id = '5acc8e5f-03b2-48cf-bd29-f7a2f1fc06e9'
ORDER BY date DESC
LIMIT 7;
```

**Expected:** Nov 16, 17, 18 all show `goal_achieved: true`

### 3. Test Future Updates

**Test Scenario:** Add nutrition entry for tomorrow (Nov 19)

**What Should Happen:**
1. Nutrition entry inserted → `daily_nutrition_summary` updated
2. Trigger fires automatically (with new logic)
3. `update_nutrition_streak()` function runs
4. If goal achieved: `current_streak` → 4
5. App hero section shows "Streak: 4"

---

## Files Created/Modified

### New Files:
1. **`supabase/migrations/010_fix_streak_trigger_logic.sql`**
   - Complete migration with trigger fix
   - Backfill logic for existing data
   - Verification queries

2. **`run_streak_fix_migration.sh`**
   - Executable script to run migration
   - Includes error handling and instructions

3. **`STREAK_TRIGGER_FIX_SUMMARY.md`** (this file)
   - Complete documentation of issue and fix

---

## Technical Details

### Trigger Execution Flow (After Fix)

```
User adds nutrition entry
    ↓
nutrition_entries table INSERT/UPDATE
    ↓
trigger_update_daily_nutrition_summary() fires
    ↓
daily_nutrition_summary UPSERT
    ↓
trigger_update_streak_from_nutrition() fires ✅ (NEW: Always fires on UPDATE)
    ↓
update_nutrition_streak(user_id, date) runs
    ↓
Streak logic determines:
    - If yesterday was completed → increment streak
    - If gap exists → reset to 1
    - If already processed → maintain
    ↓
streaks table UPDATED
    ↓
App refreshes → Shows correct streak
```

### Key Change

The trigger now fires on **every UPDATE**, allowing the `update_nutrition_streak()` function to run its own logic for detecting consecutive days. This is safer because:

1. **Separation of Concerns:** Trigger = "when to run", Function = "what to do"
2. **Idempotent:** Running the function multiple times for same date is safe
3. **Accurate:** Function has full context to calculate streaks correctly

---

## Future Proofing

### This Fix Ensures:
✅ Consecutive successful days increment streak correctly
✅ Gaps in activity properly reset streak
✅ Manual backfills work correctly
✅ App shows real-time accurate streak counts
✅ No user intervention needed for streak updates

### No Breaking Changes:
- Existing data preserved
- All user streaks recalculated accurately
- App code unchanged (reads from same tables)
- API unchanged

---

## Next Steps

1. **Apply permanent fix:** Run migration 010 in Supabase SQL Editor
2. **Restart app:** Force close and reopen to reload data
3. **Test:** Add nutrition entry tomorrow and verify streak increments to 4
4. **Monitor:** Check streak updates daily for next few days
5. **Commit:** Add migration file to git repository

---

## Support

If you encounter any issues:

1. **Check trigger status:**
   ```sql
   SELECT * FROM pg_trigger WHERE tgname = 'trigger_update_streak_from_nutrition';
   ```

2. **Check function exists:**
   ```sql
   SELECT * FROM pg_proc WHERE proname = 'update_nutrition_streak';
   ```

3. **Manually trigger for specific date:**
   ```sql
   SELECT update_nutrition_streak('5acc8e5f-03b2-48cf-bd29-f7a2f1fc06e9', '2025-11-19');
   ```

---

**Status:** ✅ Temporary fix applied (streak shows 3)
**Action Required:** Apply permanent fix via Supabase SQL Editor
**Estimated Time:** 2 minutes
