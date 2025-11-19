# Migration 008: Fix Missing Tables and Columns

## Quick Fix Instructions

### Option 1: Supabase SQL Editor (RECOMMENDED - 2 minutes)

1. **Open Supabase SQL Editor:**
   - Go to: https://supabase.com/dashboard/project/xzwvckziavhzmghizyqx/sql/new

2. **Copy the entire SQL migration:**
   - Open file: `/Users/Vicky/Streaker_app/supabase/migrations/008_fix_missing_tables_columns.sql`
   - Copy ALL contents (Cmd+A, Cmd+C)

3. **Execute in SQL Editor:**
   - Paste into the SQL Editor
   - Click "Run" button
   - You should see success messages with ✅ checkmarks

4. **Verify:**
   - Scroll down to see verification results
   - Look for: "✅ app_config table exists" and "✅ calorie_target column exists"

---

### Option 2: Command Line with Supabase CLI

```bash
# Install Supabase CLI if not already installed
brew install supabase/tap/supabase

# Login to Supabase
supabase login

# Link your project
supabase link --project-ref xzwvckziavhzmghizyqx

# Apply the migration
supabase db push
```

---

### Option 3: Manual Step-by-Step (if SQL Editor doesn't work)

#### Step 1: Create app_config table

```sql
CREATE TABLE IF NOT EXISTS public.app_config (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  platform TEXT NOT NULL CHECK (platform IN ('ios', 'android', 'all')),
  min_version TEXT NOT NULL,
  min_build_number INTEGER NOT NULL,
  force_update BOOLEAN DEFAULT true,
  update_message TEXT,
  update_url TEXT,
  maintenance_mode BOOLEAN DEFAULT false,
  maintenance_message TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
  active BOOLEAN DEFAULT true,
  recommended_version TEXT,
  features_list TEXT[],
  update_severity TEXT CHECK (update_severity IN ('critical', 'required', 'recommended', 'optional')) DEFAULT 'required'
);

-- Enable RLS
ALTER TABLE public.app_config ENABLE ROW LEVEL SECURITY;

-- Allow public read
CREATE POLICY "Allow public read access to app_config"
ON public.app_config FOR SELECT
USING (true);

-- Insert initial data
INSERT INTO public.app_config (platform, min_version, min_build_number, recommended_version, force_update, update_message, update_url, update_severity, features_list)
VALUES
('ios', '1.0.13', 16, '1.0.13', false, 'A new version of Streaker is available!', 'https://apps.apple.com/app/streaker/id6737292817', 'optional', ARRAY['🚀 Improved performance', '🐛 Bug fixes']),
('android', '1.0.13', 16, '1.0.13', false, 'A new version of Streaker is available!', 'https://play.google.com/store/apps/details?id=com.streaker.streaker', 'optional', ARRAY['🚀 Improved performance', '🐛 Bug fixes']);
```

#### Step 2: Add calorie_target column to daily_nutrition_summary

```sql
-- Add calorie_target column if missing
ALTER TABLE public.daily_nutrition_summary
ADD COLUMN IF NOT EXISTS calorie_target INTEGER DEFAULT 2000;

-- Add goal_achieved column if missing
ALTER TABLE public.daily_nutrition_summary
ADD COLUMN IF NOT EXISTS goal_achieved BOOLEAN DEFAULT FALSE;

-- Add updated_at column if missing
ALTER TABLE public.daily_nutrition_summary
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_daily_nutrition_summary_user_date
ON public.daily_nutrition_summary(user_id, date DESC);

CREATE INDEX IF NOT EXISTS idx_daily_nutrition_summary_goal_achieved
ON public.daily_nutrition_summary(user_id, goal_achieved, date DESC);
```

---

## Verification

After running the migration, verify with these queries:

```sql
-- Check app_config table exists
SELECT table_name FROM information_schema.tables
WHERE table_name = 'app_config';

-- Check calorie_target column exists
SELECT column_name FROM information_schema.columns
WHERE table_name = 'daily_nutrition_summary'
AND column_name = 'calorie_target';

-- View app_config data
SELECT * FROM app_config;
```

Expected results:
- ✅ app_config table should exist
- ✅ calorie_target column should exist in daily_nutrition_summary
- ✅ 2 rows in app_config (ios and android configurations)

---

## What This Fixes

### Issue #1: Missing app_config table
**Impact:** Force update system disabled
**After Fix:** ✅ Can remotely control app updates and maintenance mode

### Issue #2: Missing calorie_target column
**Impact:** Streak history and progress charts not loading
**After Fix:** ✅ Historical nutrition data and trends work properly

---

## Need Help?

If you encounter any errors:
1. Check the error message in the SQL Editor
2. Make sure you're logged into the correct Supabase project
3. Verify you have sufficient permissions (owner/admin)

Contact: The migration file is at `/Users/Vicky/Streaker_app/supabase/migrations/008_fix_missing_tables_columns.sql`
