#!/bin/bash

echo "🚀 Deploying Daily Streak Check Edge Function"
echo "============================================"

# Install Supabase CLI if not installed
if ! command -v supabase &> /dev/null; then
    echo "Installing Supabase CLI..."
    brew install supabase/tap/supabase
fi

# Login to Supabase (you may need to do this manually)
echo "Logging into Supabase..."
echo "If prompted, enter your access token from: https://app.supabase.com/account/tokens"

# Deploy the function
echo "Deploying edge function..."
supabase functions deploy daily-streak-check \
  --project-ref xzwvckziavhzmghizyqx \
  --no-verify-jwt

echo "✅ Edge function deployed!"
echo ""
echo "To schedule this function to run daily at midnight:"
echo "1. Go to: https://app.supabase.com/project/xzwvckziavhzmghizyqx/functions"
echo "2. Find 'daily-streak-check' function"
echo "3. Click on 'Schedule'"
echo "4. Set cron expression: 0 0 * * * (runs at midnight UTC)"
echo ""
echo "To test manually, run:"
echo "curl -X POST https://xzwvckziavhzmghizyqx.functions.supabase.co/daily-streak-check \\"
echo "  -H 'Authorization: Bearer YOUR_ANON_KEY' \\"
echo "  -H 'Content-Type: application/json' \\"
echo "  -d '{}'"