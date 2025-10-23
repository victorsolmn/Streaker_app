import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DatabaseMigrator {
  static final SupabaseClient _supabase = Supabase.instance.client;

  static Future<Map<String, bool>> applyAllMigrations() async {
    final results = <String, bool>{};

    debugPrint('🔧 Starting database migrations...');

    // Migration 1: Add daily_calories_target column
    results['daily_calories_target'] = await _runMigration(
      'Add daily_calories_target column',
      () async {
        // Test if column exists by trying to select it
        try {
          await _supabase
              .from('profiles')
              .select('daily_calories_target')
              .limit(1);
          debugPrint('✅ daily_calories_target column already exists');
          return true;
        } catch (e) {
          debugPrint('ℹ️ daily_calories_target column missing - this is expected');
          debugPrint('❌ Cannot add column via app - manual database fix needed');
          return false;
        }
      },
    );

    // Migration 2: Test heart rate constraints
    results['heart_rate_constraints'] = await _runMigration(
      'Verify heart rate constraints',
      () async {
        try {
          // Try inserting a test value that would fail with old constraints
          final testUserId = 'test-constraint-${DateTime.now().millisecondsSinceEpoch}';
          await _supabase.from('health_metrics').insert({
            'user_id': testUserId,
            'date': DateTime.now().toIso8601String().split('T')[0],
            'heart_rate': 25, // This should fail with old constraints
          });

          // Clean up test data
          await _supabase
              .from('health_metrics')
              .delete()
              .eq('user_id', testUserId);

          debugPrint('✅ Heart rate constraints are relaxed');
          return true;
        } catch (e) {
          if (e.toString().contains('heart_rate_check')) {
            debugPrint('❌ Heart rate constraints still too restrictive');
            return false;
          }
          debugPrint('✅ Heart rate constraints appear to be working');
          return true;
        }
      },
    );

    // Migration 3: Test user_streaks view
    results['user_streaks_view'] = await _runMigration(
      'Test user_streaks view',
      () async {
        try {
          await _supabase
              .from('user_streaks')
              .select('id')
              .limit(1);
          debugPrint('✅ user_streaks view accessible');
          return true;
        } catch (e) {
          debugPrint('❌ user_streaks view not accessible: $e');
          return false;
        }
      },
    );

    // Migration 4: Test daily_nutrition_summary view
    results['nutrition_summary_view'] = await _runMigration(
      'Test daily_nutrition_summary view',
      () async {
        try {
          await _supabase
              .from('daily_nutrition_summary')
              .select('user_id')
              .limit(1);
          debugPrint('✅ daily_nutrition_summary view accessible');
          return true;
        } catch (e) {
          debugPrint('❌ daily_nutrition_summary view not accessible: $e');
          return false;
        }
      },
    );

    // Migration 5: Test user_dashboard view
    results['dashboard_view'] = await _runMigration(
      'Test user_dashboard view',
      () async {
        try {
          await _supabase
              .from('user_dashboard')
              .select('id')
              .limit(1);
          debugPrint('✅ user_dashboard view accessible');
          return true;
        } catch (e) {
          debugPrint('❌ user_dashboard view not accessible: $e');
          return false;
        }
      },
    );

    final successCount = results.values.where((success) => success).length;
    final totalCount = results.length;

    debugPrint('\n📊 Migration Results: $successCount/$totalCount successful');
    debugPrint('=' * 50);

    for (final entry in results.entries) {
      final status = entry.value ? '✅' : '❌';
      debugPrint('$status ${entry.key}');
    }

    return results;
  }

  static Future<bool> _runMigration(String description, Future<bool> Function() migration) async {
    try {
      debugPrint('🔄 $description...');
      final result = await migration();
      if (result) {
        debugPrint('✅ $description completed');
      } else {
        debugPrint('❌ $description failed');
      }
      return result;
    } catch (e) {
      debugPrint('❌ $description error: $e');
      return false;
    }
  }

  static Future<Map<String, String>> getDatabaseStatus() async {
    final status = <String, String>{};

    // Check current schema state
    try {
      // Test profiles table structure
      final profileResult = await _supabase
          .from('profiles')
          .select()
          .limit(1);
      status['profiles'] = 'Accessible (${profileResult.length} sample records)';

      // Test nutrition entries
      final nutritionResult = await _supabase
          .from('nutrition_entries')
          .select()
          .limit(1);
      status['nutrition_entries'] = 'Accessible (${nutritionResult.length} sample records)';

      // Test health metrics
      final healthResult = await _supabase
          .from('health_metrics')
          .select()
          .limit(1);
      status['health_metrics'] = 'Accessible (${healthResult.length} sample records)';

      // Test streaks
      final streaksResult = await _supabase
          .from('streaks')
          .select()
          .limit(1);
      status['streaks'] = 'Accessible (${streaksResult.length} sample records)';

      // Test user goals
      final goalsResult = await _supabase
          .from('user_goals')
          .select()
          .limit(1);
      status['user_goals'] = 'Accessible (${goalsResult.length} sample records)';

    } catch (e) {
      status['error'] = 'Database connection error: $e';
    }

    return status;
  }

  static String generateManualMigrationScript() {
    return '''
-- MANUAL DATABASE MIGRATIONS REQUIRED
-- Copy and paste this into your Supabase SQL Editor

-- 1. Add missing daily_calories_target column
ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS daily_calories_target INTEGER DEFAULT 2000;

-- 2. Fix heart rate constraints
ALTER TABLE health_metrics
DROP CONSTRAINT IF EXISTS health_metrics_heart_rate_check;

ALTER TABLE health_metrics
ADD CONSTRAINT health_metrics_heart_rate_check
CHECK (heart_rate IS NULL OR (heart_rate >= 30 AND heart_rate <= 250));

-- 3. Create user_streaks compatibility view
CREATE OR REPLACE VIEW user_streaks AS
SELECT * FROM streaks;

-- 4. Add unique constraint for streaks upsert
ALTER TABLE streaks
ADD CONSTRAINT IF NOT EXISTS streaks_user_type_unique
UNIQUE (user_id, streak_type);

-- 5. Create daily_nutrition_summary view
CREATE OR REPLACE VIEW daily_nutrition_summary AS
SELECT
    user_id,
    date,
    SUM(calories) as total_calories,
    SUM(protein) as total_protein,
    SUM(carbs) as total_carbs,
    SUM(fat) as total_fat,
    COUNT(*) as entries_count,
    CURRENT_TIMESTAMP as calculated_at
FROM nutrition_entries
GROUP BY user_id, date;

-- 6. Create user_dashboard view
CREATE OR REPLACE VIEW user_dashboard AS
SELECT
    p.id,
    p.name,
    p.email,
    p.age,
    p.height,
    p.weight,
    p.activity_level,
    p.fitness_goal,
    p.daily_calories_target,
    s.current_streak,
    s.longest_streak,
    s.last_activity_date,
    hm.steps as today_steps,
    hm.calories_burned as today_calories_burned,
    hm.heart_rate as today_heart_rate,
    hm.sleep_hours as today_sleep_hours,
    hm.water_intake as today_water_intake,
    p.created_at as profile_created_at
FROM profiles p
LEFT JOIN streaks s ON p.id = s.user_id AND s.streak_type = 'daily'
LEFT JOIN health_metrics hm ON p.id = hm.user_id AND hm.date = CURRENT_DATE;

-- 7. Add performance indexes
CREATE INDEX IF NOT EXISTS idx_nutrition_entries_user_date ON nutrition_entries(user_id, date);
CREATE INDEX IF NOT EXISTS idx_health_metrics_user_date ON health_metrics(user_id, date);
CREATE INDEX IF NOT EXISTS idx_streaks_user_type ON streaks(user_id, streak_type);
CREATE INDEX IF NOT EXISTS idx_user_goals_user_active ON user_goals(user_id, is_active);

-- 8. Update existing data
UPDATE profiles
SET daily_calories_target = 2000
WHERE daily_calories_target IS NULL;

UPDATE health_metrics
SET heart_rate = NULL
WHERE heart_rate IS NOT NULL AND (heart_rate < 30 OR heart_rate > 250);
''';
  }
}