const https = require('https');

const SUPABASE_URL = 'xzwvckziavhzmghizyqx.supabase.co';
const SERVICE_ROLE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inh6d3Zja3ppYXZoem1naGl6eXF4Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1ODA5OTQ2MiwiZXhwIjoyMDczNjc1NDYyfQ.jXjRDeSc1e3RLQVIxZwNRgYwF-nXmHf4icvnjllW-ao';

// Try to insert a test record to force table creation if using auto-migrations
async function tryCreateTable() {
  const testData = {
    weight: 70.5,
    note: 'Initial test entry',
    timestamp: new Date().toISOString()
  };

  const data = JSON.stringify(testData);

  const options = {
    hostname: SUPABASE_URL,
    path: '/rest/v1/weight_entries',
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Content-Length': data.length,
      'apikey': SERVICE_ROLE_KEY,
      'Authorization': `Bearer ${SERVICE_ROLE_KEY}`,
      'Prefer': 'return=representation'
    }
  };

  return new Promise((resolve, reject) => {
    const req = https.request(options, (res) => {
      let responseData = '';

      res.on('data', (chunk) => {
        responseData += chunk;
      });

      res.on('end', () => {
        console.log('Status:', res.statusCode);
        console.log('Response:', responseData);

        if (res.statusCode === 404) {
          console.log('\n❌ Table does not exist.');
          console.log('\n📋 MANUAL STEPS REQUIRED:\n');
          console.log('Since the Supabase REST API cannot directly create tables,');
          console.log('you need to manually run the SQL in the Supabase Dashboard:\n');
          console.log('1. Open your browser and go to:');
          console.log('   https://supabase.com/dashboard/project/xzwvckziavhzmghizyqx/sql/new');
          console.log('\n2. Copy the entire SQL from this file:');
          console.log('   /Users/Vicky/Streaker_app/supabase/migrations/create_weight_entries.sql');
          console.log('\n3. Paste it into the SQL editor and click "Run"\n');
          console.log('4. The table will be created with all necessary columns, indexes, and RLS policies.');
          console.log('\n✨ After running the SQL, your weight tracking feature will be fully functional!');
        } else if (res.statusCode >= 200 && res.statusCode < 300) {
          console.log('✅ Table appears to exist or was created successfully');
        } else {
          console.log('⚠️  Unexpected response. Please check Supabase dashboard.');
        }

        resolve(responseData);
      });
    });

    req.on('error', (error) => {
      console.error('Error:', error);
      reject(error);
    });

    req.write(data);
    req.end();
  });
}

// Run the check
console.log('🔍 Checking if weight_entries table exists in Supabase...\n');
tryCreateTable().catch(console.error);