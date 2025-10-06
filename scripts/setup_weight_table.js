const { createClient } = require('@supabase/supabase-js');

const SUPABASE_URL = 'https://xzwvckziavhzmghizyqx.supabase.co';
const SERVICE_ROLE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inh6d3Zja3ppYXZoem1naGl6eXF4Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1ODA5OTQ2MiwiZXhwIjoyMDczNjc1NDYyfQ.jXjRDeSc1e3RLQVIxZwNRgYwF-nXmHf4icvnjllW-ao';

const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

async function setupWeightTable() {
  try {
    // First check if table exists
    const { data: tables, error: checkError } = await supabase
      .from('weight_entries')
      .select('id')
      .limit(1);

    if (!checkError) {
      console.log('✅ weight_entries table already exists');
      return;
    }

    console.log('Table does not exist. Please run the following SQL in your Supabase SQL Editor:');
    console.log('\n=== INSTRUCTIONS ===\n');
    console.log('1. Go to: https://xzwvckziavhzmghizyqx.supabase.co');
    console.log('2. Navigate to SQL Editor (in the left sidebar)');
    console.log('3. Create a new query');
    console.log('4. Copy and paste the SQL from: /Users/Vicky/Streaker_app/supabase/migrations/create_weight_entries.sql');
    console.log('5. Click "Run" to execute the SQL');
    console.log('\n===================\n');

  } catch (error) {
    console.error('Error:', error);
  }
}

setupWeightTable();