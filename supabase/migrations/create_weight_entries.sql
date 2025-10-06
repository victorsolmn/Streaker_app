-- Create weight_entries table if it doesn't exist
CREATE TABLE IF NOT EXISTS public.weight_entries (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
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
        SET weight = NEW.weight,
            updated_at = NOW()
        WHERE id = NEW.user_id;
    ELSIF TG_OP = 'DELETE' THEN
        -- Update to previous weight if exists
        UPDATE public.profiles
        SET weight = (
            SELECT weight FROM public.weight_entries
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

-- Create trigger for auto-updating profile weight
DROP TRIGGER IF EXISTS update_profile_weight_trigger ON public.weight_entries;
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