#!/bin/bash

# Apply Migration 008 to Supabase Database
# This script runs the SQL migration to fix missing tables and columns

SUPABASE_URL="https://xzwvckziavhzmghizyqx.supabase.co"
SERVICE_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inh6d3Zja3ppYXZoem1naGl6eXF4Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1ODA5OTQ2MiwiZXhwIjoyMDczNjc1NDYyfQ.jXjRDeSc1e3RLQVIxZwNRgYwF-nXmHf4icvnjllW-ao"

echo "=================================================="
echo "APPLYING MIGRATION 008: Fix Missing Tables/Columns"
echo "=================================================="
echo ""

# Read the migration file
MIGRATION_SQL=$(cat supabase/migrations/008_fix_missing_tables_columns.sql)

# Execute via Supabase SQL API
echo "Executing SQL migration..."
echo ""

# Use psql to connect and execute (requires password)
# Alternatively use Supabase Studio's SQL Editor

# For now, let's output the SQL for manual execution
echo "Please execute the following SQL in your Supabase SQL Editor:"
echo "https://supabase.com/dashboard/project/xzwvckziavhzmghizyqx/sql/new"
echo ""
echo "Or run this command:"
echo ""
echo "cat supabase/migrations/008_fix_missing_tables_columns.sql | PGPASSWORD='YOUR_DB_PASSWORD' psql -h db.xzwvckziavhzmghizyqx.supabase.co -U postgres -d postgres"
echo ""
echo "Migration file ready at: supabase/migrations/008_fix_missing_tables_columns.sql"
echo ""
echo "=================================================="
