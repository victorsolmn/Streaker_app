# How to Create the app_config Table

## Issue
The app is showing this error:
```
❌ Error fetching app config: PostgrestException(message: Could not find the table 'public.app_config' in the schema cache, code: PGRST205, details: Not Found, hint: null)
```

## Solution

The migration file already exists at `/supabase/migrations/20250925_app_config_table.sql`

### Option 1: Using Supabase Dashboard (Recommended)

1. Go to your Supabase Dashboard: https://supabase.com/dashboard
2. Select your project: **xzwvckziavhzmghizyqx**
3. Navigate to **SQL Editor** in the left sidebar
4. Click **New Query**
5. Copy the entire contents from `/supabase/migrations/20250925_app_config_table.sql`
6. Paste into the SQL editor
7. Click **Run** to execute the migration

### Option 2: Using Supabase CLI

```bash
cd /Users/Vicky/streaker_app
supabase db push
```

### Option 3: Manual SQL Execution

If you have the Supabase connection details, run:

```bash
psql -h [your-db-host] -U postgres.[project-ref] -d postgres -f supabase/migrations/20250925_app_config_table.sql
```

## What This Migration Does

1. **Creates `app_config` table** with fields for:
   - Version management (min_version, min_build_number, recommended_version)
   - Force update configuration
   - Maintenance mode support
   - Platform-specific configs (iOS/Android/All)
   - Update severity levels (critical/required/recommended/optional)

2. **Sets up Row Level Security (RLS)** policies:
   - Public read access for all users
   - Only service_role can modify

3. **Inserts initial data** for both iOS and Android platforms

4. **Creates useful triggers and views** for easier querying

## After Running the Migration

The app will no longer show the warning message and the force update system will work properly.

## Alternative: Make the Feature Optional

If you don't want to use the force update feature, you can modify the version manager service to gracefully handle the missing table (which it already does - the app continues to work despite the missing table).
