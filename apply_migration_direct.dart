import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  print('🚀 Applying Migration 008: Fix Missing Tables/Columns');
  print('=' * 60);

  // Initialize Supabase
  await Supabase.initialize(
    url: 'https://xzwvckziavhzmghizyqx.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inh6d3Zja3ppYXZoem1naGl6eXF4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTgwOTk0NjIsImV4cCI6MjA3MzY3NTQ2Mn0.fUtnAzqNGzKvo-FTWqpemcf0wvdlC6gpUg_ZllXBulo',
  );

  final supabase = Supabase.instance.client;

  try {
    // Read the migration SQL file
    final sqlFile = File('supabase/migrations/008_fix_missing_tables_columns.sql');
    final sqlContent = await sqlFile.readAsString();

    print('\n📄 Migration file loaded: ${sqlContent.length} characters');
    print('\n🔧 Executing migration via RPC...\n');

    // Execute the SQL using Supabase's RPC
    // Note: This requires a custom RPC function in Supabase or we need to use the REST API directly

    // For now, let's break down into individual operations:

    // 1. Check if app_config table exists
    print('1️⃣ Checking app_config table...');
    try {
      final result = await supabase
          .from('app_config')
          .select('id')
          .limit(1);
      print('   ✅ app_config table exists');
    } catch (e) {
      print('   ⚠️  app_config table missing: $e');
      print('   📋 Please create it manually via Supabase SQL Editor');
    }

    // 2. Check if daily_nutrition_summary table and calorie_target column exist
    print('\n2️⃣ Checking daily_nutrition_summary table...');
    try {
      final result = await supabase
          .from('daily_nutrition_summary')
          .select('date, total_calories, calorie_target, goal_achieved')
          .limit(1);
      print('   ✅ daily_nutrition_summary table exists with all required columns');
    } catch (e) {
      print('   ⚠️  Issue with daily_nutrition_summary: $e');
      print('   📋 Columns might be missing');
    }

    print('\n' + '=' * 60);
    print('✅ Migration check completed');
    print('\n📝 MANUAL STEPS REQUIRED:');
    print('   1. Go to: https://supabase.com/dashboard/project/xzwvckziavhzmghizyqx/sql/new');
    print('   2. Copy contents from: supabase/migrations/008_fix_missing_tables_columns.sql');
    print('   3. Paste and execute in SQL Editor');
    print('=' * 60);

  } catch (e) {
    print('❌ Error: $e');
    exit(1);
  }

  exit(0);
}
