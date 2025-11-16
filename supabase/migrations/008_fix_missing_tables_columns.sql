-- ============================================================================
-- MIGRATION 008: FIX MISSING TABLES AND COLUMNS
-- Date: November 14, 2025
-- Purpose: Fix missing app_config table and calorie_target column issues
-- ============================================================================

-- PART 1: Create app_config table (if not exists)
-- ============================================================================
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

  -- Additional fields for enhanced features
  recommended_version TEXT,
  features_list TEXT[], -- Array of new features
  update_severity TEXT CHECK (update_severity IN ('critical', 'required', 'recommended', 'optional')) DEFAULT 'required'
);

-- Create index for faster queries (if not exists)
CREATE INDEX IF NOT EXISTS idx_app_config_platform_active
ON public.app_config(platform, active);

-- Create updated_at trigger function (if not exists)
CREATE OR REPLACE FUNCTION update_modified_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = timezone('utc'::text, now());
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create trigger (drop if exists, then create)
DROP TRIGGER IF EXISTS update_app_config_modtime ON public.app_config;
CREATE TRIGGER update_app_config_modtime
BEFORE UPDATE ON public.app_config
FOR EACH ROW EXECUTE FUNCTION update_modified_column();

-- Insert initial configuration for both platforms (only if table is empty)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.app_config LIMIT 1) THEN
    INSERT INTO public.app_config (
      platform,
      min_version,
      min_build_number,
      recommended_version,
      force_update,
      update_message,
      update_url,
      update_severity,
      features_list
    ) VALUES
    (
      'ios',
      '1.0.13',
      16,
      '1.0.13',
      false, -- Start with false, can be enabled when needed
      'A new version of Streaker is available with exciting features and improvements!',
      'https://apps.apple.com/app/streaker/id6737292817',
      'optional',
      ARRAY['🚀 Improved performance', '🐛 Bug fixes', '✨ Enhanced UI']
    ),
    (
      'android',
      '1.0.13',
      16,
      '1.0.13',
      false, -- Start with false, can be enabled when needed
      'A new version of Streaker is available with exciting features and improvements!',
      'https://play.google.com/store/apps/details?id=com.streaker.streaker',
      'optional',
      ARRAY['🚀 Improved performance', '🐛 Bug fixes', '✨ Enhanced UI']
    );
  END IF;
END $$;

-- Create RLS policies
ALTER TABLE public.app_config ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Allow public read access to app_config" ON public.app_config;
DROP POLICY IF EXISTS "Only service role can modify app_config" ON public.app_config;

-- Allow public read access to app config
CREATE POLICY "Allow public read access to app_config"
ON public.app_config FOR SELECT
USING (true);

-- Only service role can modify
CREATE POLICY "Only service role can modify app_config"
ON public.app_config FOR ALL
USING (auth.role() = 'service_role')
WITH CHECK (auth.role() = 'service_role');

-- Create a view for easier querying
CREATE OR REPLACE VIEW public.current_app_config AS
SELECT * FROM public.app_config
WHERE active = true
ORDER BY created_at DESC;

-- ============================================================================
-- PART 2: Ensure calorie_target column exists in daily_nutrition_summary
-- ============================================================================
DO $$
BEGIN
    -- Check if daily_nutrition_summary table exists first
    IF EXISTS (
        SELECT 1 FROM information_schema.tables
        WHERE table_schema = 'public'
        AND table_name = 'daily_nutrition_summary'
    ) THEN
        -- Add calorie_target column if it doesn't exist
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_schema = 'public'
            AND table_name = 'daily_nutrition_summary'
            AND column_name = 'calorie_target'
        ) THEN
            ALTER TABLE public.daily_nutrition_summary
            ADD COLUMN calorie_target INTEGER DEFAULT 2000;

            RAISE NOTICE 'Added calorie_target column to daily_nutrition_summary';
        ELSE
            RAISE NOTICE 'calorie_target column already exists in daily_nutrition_summary';
        END IF;

        -- Add goal_achieved column if it doesn't exist (for completeness)
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_schema = 'public'
            AND table_name = 'daily_nutrition_summary'
            AND column_name = 'goal_achieved'
        ) THEN
            ALTER TABLE public.daily_nutrition_summary
            ADD COLUMN goal_achieved BOOLEAN DEFAULT FALSE;

            RAISE NOTICE 'Added goal_achieved column to daily_nutrition_summary';
        ELSE
            RAISE NOTICE 'goal_achieved column already exists in daily_nutrition_summary';
        END IF;

        -- Add updated_at timestamp if it doesn't exist
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_schema = 'public'
            AND table_name = 'daily_nutrition_summary'
            AND column_name = 'updated_at'
        ) THEN
            ALTER TABLE public.daily_nutrition_summary
            ADD COLUMN updated_at TIMESTAMPTZ DEFAULT NOW();

            RAISE NOTICE 'Added updated_at column to daily_nutrition_summary';
        ELSE
            RAISE NOTICE 'updated_at column already exists in daily_nutrition_summary';
        END IF;

        -- Create indexes for faster queries (if not exist)
        CREATE INDEX IF NOT EXISTS idx_daily_nutrition_summary_user_date
        ON public.daily_nutrition_summary(user_id, date DESC);

        CREATE INDEX IF NOT EXISTS idx_daily_nutrition_summary_goal_achieved
        ON public.daily_nutrition_summary(user_id, goal_achieved, date DESC);

        RAISE NOTICE 'Migration 008 completed successfully for daily_nutrition_summary';
    ELSE
        RAISE NOTICE 'daily_nutrition_summary table does not exist - skipping column additions';
    END IF;
END $$;

-- ============================================================================
-- VERIFICATION
-- ============================================================================
DO $$
BEGIN
    RAISE NOTICE '=== MIGRATION 008 VERIFICATION ===';

    -- Verify app_config table
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'app_config') THEN
        RAISE NOTICE '✅ app_config table exists';
    ELSE
        RAISE NOTICE '❌ app_config table NOT found';
    END IF;

    -- Verify calorie_target column
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'daily_nutrition_summary'
        AND column_name = 'calorie_target'
    ) THEN
        RAISE NOTICE '✅ calorie_target column exists in daily_nutrition_summary';
    ELSE
        RAISE NOTICE '⚠️  calorie_target column NOT found (table may not exist)';
    END IF;

    RAISE NOTICE '=== END VERIFICATION ===';
END $$;
