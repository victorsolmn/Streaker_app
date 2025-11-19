#!/bin/bash

# Streak Trigger Fix Migration Script
# This script applies the permanent fix for the streak trigger issue

echo "=========================================="
echo "STREAK TRIGGER FIX - Migration 010"
echo "=========================================="
echo ""

# Database connection details
DB_HOST="db.xzwvckziavhzmghizyqx.supabase.co"
DB_USER="postgres"
DB_NAME="postgres"
DB_PASSWORD="8uFx3FRs-p_r7nu"

# Check if psql is available
if ! command -v psql &> /dev/null; then
    echo "❌ psql is not installed or not in PATH"
    echo ""
    echo "ALTERNATIVE: Run this SQL manually in Supabase SQL Editor:"
    echo "File: supabase/migrations/010_fix_streak_trigger_logic.sql"
    exit 1
fi

echo "📁 Running migration file..."
echo ""

# Run the migration
PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" \
    -f supabase/migrations/010_fix_streak_trigger_logic.sql

if [ $? -eq 0 ]; then
    echo ""
    echo "=========================================="
    echo "✅ Migration completed successfully!"
    echo "=========================================="
    echo ""
    echo "Next steps:"
    echo "1. Restart your app to reload the streak data"
    echo "2. Check that the hero section shows 'Streak: 3'"
    echo "3. Future nutrition entries will automatically update streaks"
else
    echo ""
    echo "=========================================="
    echo "❌ Migration failed"
    echo "=========================================="
    echo ""
    echo "Please run the SQL manually in Supabase SQL Editor:"
    echo "File: supabase/migrations/010_fix_streak_trigger_logic.sql"
    exit 1
fi
