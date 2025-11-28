-- Enable the pg_cron extension (if not already enabled)
-- This needs to be run by a superuser or through Supabase Dashboard
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Grant usage to postgres user
GRANT USAGE ON SCHEMA cron TO postgres;

-- Schedule daily streak reminder at 9:00 AM UTC (adjust timezone as needed)
-- This will send reminders to users who haven't logged their meals yet
SELECT cron.schedule(
  'daily-streak-reminder-morning',  -- job name
  '0 9 * * *',                       -- cron expression: 9:00 AM UTC daily
  $$
  SELECT net.http_post(
    url := 'https://xzwvckziavhzmghizyqx.supabase.co/functions/v1/daily-streak-reminder',
    headers := '{"Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inh6d3Zja3ppYXZoem1naGl6eXF4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTgwOTk0NjIsImV4cCI6MjA3MzY3NTQ2Mn0.fUtnAzqNGzKvo-FTWqpemcf0wvdlC6gpUg_ZllXBulo", "Content-Type": "application/json"}'::jsonb,
    body := '{}'::jsonb
  ) AS request_id;
  $$
);

-- Schedule evening reminder at 7:00 PM UTC for users who still haven't logged
SELECT cron.schedule(
  'daily-streak-reminder-evening',  -- job name
  '0 19 * * *',                      -- cron expression: 7:00 PM UTC daily
  $$
  SELECT net.http_post(
    url := 'https://xzwvckziavhzmghizyqx.supabase.co/functions/v1/daily-streak-reminder',
    headers := '{"Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inh6d3Zja3ppYXZoem1naGl6eXF4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTgwOTk0NjIsImV4cCI6MjA3MzY3NTQ2Mn0.fUtnAzqNGzKvo-FTWqpemcf0wvdlC6gpUg_ZllXBulo", "Content-Type": "application/json"}'::jsonb,
    body := '{}'::jsonb
  ) AS request_id;
  $$
);

-- View scheduled jobs
-- SELECT * FROM cron.job;

-- To unschedule a job:
-- SELECT cron.unschedule('daily-streak-reminder-morning');
-- SELECT cron.unschedule('daily-streak-reminder-evening');

-- Comments for documentation
COMMENT ON EXTENSION pg_cron IS 'Job scheduler for PostgreSQL - used for automated daily streak reminders';
