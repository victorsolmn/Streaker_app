-- Create user_devices table for storing FCM tokens
CREATE TABLE IF NOT EXISTS public.user_devices (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  fcm_token TEXT NOT NULL,
  platform TEXT NOT NULL CHECK (platform IN ('ios', 'android')),
  device_name TEXT,
  device_model TEXT,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),

  -- Ensure unique combination of user and FCM token
  UNIQUE(user_id, fcm_token)
);

-- Create index for faster queries
CREATE INDEX IF NOT EXISTS idx_user_devices_user_id ON public.user_devices(user_id);
CREATE INDEX IF NOT EXISTS idx_user_devices_fcm_token ON public.user_devices(fcm_token);
CREATE INDEX IF NOT EXISTS idx_user_devices_active ON public.user_devices(is_active) WHERE is_active = true;

-- Enable Row Level Security (RLS)
ALTER TABLE public.user_devices ENABLE ROW LEVEL SECURITY;

-- RLS Policy: Users can only view their own devices
CREATE POLICY "Users can view own devices"
  ON public.user_devices
  FOR SELECT
  USING (auth.uid() = user_id);

-- RLS Policy: Users can insert their own devices
CREATE POLICY "Users can insert own devices"
  ON public.user_devices
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- RLS Policy: Users can update their own devices
CREATE POLICY "Users can update own devices"
  ON public.user_devices
  FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- RLS Policy: Users can delete their own devices
CREATE POLICY "Users can delete own devices"
  ON public.user_devices
  FOR DELETE
  USING (auth.uid() = user_id);

-- Function to automatically update updated_at timestamp
CREATE OR REPLACE FUNCTION update_user_devices_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to call the function before update
CREATE TRIGGER trigger_update_user_devices_updated_at
  BEFORE UPDATE ON public.user_devices
  FOR EACH ROW
  EXECUTE FUNCTION update_user_devices_updated_at();

-- Grant necessary permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON public.user_devices TO authenticated;
GRANT USAGE ON SEQUENCE user_devices_id_seq TO authenticated;

-- Comments for documentation
COMMENT ON TABLE public.user_devices IS 'Stores FCM tokens for push notifications';
COMMENT ON COLUMN public.user_devices.user_id IS 'Reference to the user who owns this device';
COMMENT ON COLUMN public.user_devices.fcm_token IS 'Firebase Cloud Messaging token for push notifications';
COMMENT ON COLUMN public.user_devices.platform IS 'Device platform: ios or android';
COMMENT ON COLUMN public.user_devices.is_active IS 'Whether this device should receive notifications';
