#!/bin/bash

# Apply Migration 008 directly via SQL query
SERVICE_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inh6d3Zja3ppYXZoem1naGl6eXF4Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1ODA5OTQ2MiwiZXhwIjoyMDczNjc1NDYyfQ.jXjRDeSc1e3RLQVIxZwNRgYwF-nXmHf4icvnjllW-ao"

echo "🚀 Applying Migration 008: Fix Missing Tables/Columns"
echo "======================================================"

# Read SQL file
SQL_CONTENT=$(cat supabase/migrations/008_fix_missing_tables_columns.sql)

# Execute via Supabase RPC (using a custom function)
# Since Supabase doesn't have direct SQL execution API, we'll use PostgreSQL connection

echo ""
echo "Migration SQL ready. Attempting to apply..."
echo ""

# Try to execute using psql if available
if command -v psql &> /dev/null; then
    echo "📡 Connecting to Supabase PostgreSQL..."
    echo ""
    echo "⚠️  You'll need the database password from: https://supabase.com/dashboard/project/xzwvckziavhzmghizyqx/settings/database"
    echo ""

    psql "postgresql://postgres:[YOUR-PASSWORD]@db.xzwvckziavhzmghizyqx.supabase.co:5432/postgres" \
        -f supabase/migrations/008_fix_missing_tables_columns.sql
else
    echo "❌ psql not found. Please install PostgreSQL client or use Supabase Studio."
    echo ""
    echo "📋 Manual steps:"
    echo "1. Go to: https://supabase.com/dashboard/project/xzwvckziavhzmghizyqx/sql/new"
    echo "2. Copy the contents of: supabase/migrations/008_fix_missing_tables_columns.sql"
    echo "3. Paste and run in the SQL Editor"
    echo ""
fi

echo ""
echo "======================================================"
