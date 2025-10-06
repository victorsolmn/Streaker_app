const https = require('https');

// Supabase configuration
const SUPABASE_URL = 'https://xzwvckziavhzmghizyqx.supabase.co';
const SERVICE_ROLE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inh6d3Zja3ppYXZoem1naGl6eXF4Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1ODA5OTQ2MiwiZXhwIjoyMDczNjc1NDYyfQ.jXjRDeSc1e3RLQVIxZwNRgYwF-nXmHf4icvnjllW-ao';

// SQL to create weight_entries table
const sql = `
-- Create weight_entries table if it doesn't exist
CREATE TABLE IF NOT EXISTS public.weight_entries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    weight DECIMAL(5,2) NOT NULL,
    note TEXT,
    timestamp TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_weight_entries_user_timestamp
ON public.weight_entries(user_id, timestamp DESC);

-- Enable Row Level Security
ALTER TABLE public.weight_entries ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Users can view own weight entries" ON public.weight_entries;
DROP POLICY IF EXISTS "Users can insert own weight entries" ON public.weight_entries;
DROP POLICY IF EXISTS "Users can update own weight entries" ON public.weight_entries;
DROP POLICY IF EXISTS "Users can delete own weight entries" ON public.weight_entries;

-- Create RLS policies
CREATE POLICY "Users can view own weight entries" ON public.weight_entries
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own weight entries" ON public.weight_entries
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own weight entries" ON public.weight_entries
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own weight entries" ON public.weight_entries
    FOR DELETE USING (auth.uid() = user_id);

-- Create function to update profile weight when new entry is added
CREATE OR REPLACE FUNCTION update_profile_weight()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE public.profiles
        SET weight = NEW.weight::text,
            updated_at = NOW()
        WHERE id = NEW.user_id;
    ELSIF TG_OP = 'DELETE' THEN
        -- Update to previous weight if exists
        UPDATE public.profiles
        SET weight = (
            SELECT weight::text FROM public.weight_entries
            WHERE user_id = OLD.user_id
            ORDER BY timestamp DESC
            LIMIT 1
        ),
        updated_at = NOW()
        WHERE id = OLD.user_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop existing trigger if it exists
DROP TRIGGER IF EXISTS update_profile_weight_trigger ON public.weight_entries;

-- Create trigger for auto-updating profile weight
CREATE TRIGGER update_profile_weight_trigger
AFTER INSERT OR DELETE ON public.weight_entries
FOR EACH ROW
EXECUTE FUNCTION update_profile_weight();

-- Add weight_unit column to profiles if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_name = 'profiles'
                   AND column_name = 'weight_unit')
    THEN
        ALTER TABLE public.profiles ADD COLUMN weight_unit VARCHAR(10) DEFAULT 'kg';
    END IF;
END $$;
`;

// Make the API request
const data = JSON.stringify({ query: sql });

const options = {
  hostname: 'xzwvckziavhzmghizyqx.supabase.co',
  path: '/rest/v1/rpc/exec_sql',
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Content-Length': data.length,
    'apikey': SERVICE_ROLE_KEY,
    'Authorization': `Bearer ${SERVICE_ROLE_KEY}`,
    'Prefer': 'return=minimal'
  }
};

// First, let's try a different approach using the query endpoint
const options2 = {
  hostname: 'xzwvckziavhzmghizyqx.supabase.co',
  path: '/rest/v1/rpc',
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'apikey': SERVICE_ROLE_KEY,
    'Authorization': `Bearer ${SERVICE_ROLE_KEY}`
  }
};

// Let's use curl instead for better control
const { exec } = require('child_process');

const curlCommand = `curl -X POST '${SUPABASE_URL}/rest/v1/rpc' \\
  -H "apikey: ${SERVICE_ROLE_KEY}" \\
  -H "Authorization: Bearer ${SERVICE_ROLE_KEY}" \\
  -H "Content-Type: application/json" \\
  -H "Prefer: return=representation" \\
  -d '{"query": ${JSON.stringify(sql)}}'`;

console.log('Creating weight_entries table in Supabase...');

// Since we can't directly execute SQL via REST API, let's create a Node.js script that uses Supabase client
console.log(`
To create the weight_entries table, please:

1. Go to your Supabase Dashboard
2. Navigate to SQL Editor
3. Run the following SQL:

${sql}

Or use the Supabase client in your app to run migrations.
`);