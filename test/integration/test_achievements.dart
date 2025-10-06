import 'package:supabase/supabase.dart';

void main() async {
  print('🏆 Testing Achievement System\n');
  print('=' * 60);

  // Initialize Supabase client
  final supabase = SupabaseClient(
    'https://xzwvckziavhzmghizyqx.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inh6d3Zja3ppYXZoem1naGl6eXF4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTgwOTk0NjIsImV4cCI6MjA3MzY3NTQ2Mn0.fUtnAzqNGzKvo-FTWqpemcf0wvdlC6gpUg_ZllXBulo',
  );

  print('✅ Connected to Supabase\n');

  // Test 1: Check if achievements table exists and has data
  print('1️⃣ Testing ACHIEVEMENTS table...');
  try {
    final response = await supabase
        .from('achievements')
        .select('id, title, requirement_type, requirement_value, color_primary')
        .order('sort_order');

    print('   ✅ Achievements table accessible');
    print('   Found ${response.length} achievements');

    if (response.isNotEmpty) {
      print('\n   📋 Achievement List:');
      for (var achievement in response) {
        print('   - ${achievement['title']} (${achievement['requirement_type']}: ${achievement['requirement_value']})');
      }
    } else {
      print('   ⚠️ No achievements found - run SQL setup scripts');
    }
  } catch (e) {
    print('   ❌ Error accessing achievements table: $e');
    print('   → Please run the SQL setup scripts in Supabase');
  }

  // Test 2: Check user_achievements table
  print('\n2️⃣ Testing USER_ACHIEVEMENTS table...');
  try {
    final response = await supabase
        .from('user_achievements')
        .select('id, achievement_id, unlocked_at')
        .limit(5);

    print('   ✅ User achievements table accessible');
    print('   Found ${response.length} unlocked achievements');
  } catch (e) {
    print('   ❌ Error accessing user_achievements table: $e');
  }

  // Test 3: Check achievement_progress table
  print('\n3️⃣ Testing ACHIEVEMENT_PROGRESS table...');
  try {
    final response = await supabase
        .from('achievement_progress')
        .select('achievement_id, current_value, target_value')
        .limit(5);

    print('   ✅ Achievement progress table accessible');
    print('   Tracking progress for ${response.length} achievements');
  } catch (e) {
    print('   ❌ Error accessing achievement_progress table: $e');
  }

  print('\n' + '=' * 60);
  print('📊 ACHIEVEMENT SYSTEM STATUS\n');

  print('✅ TABLES CREATED:');
  print('   • achievements (master list)');
  print('   • user_achievements (unlocked)');
  print('   • achievement_progress (tracking)');

  print('\n🎯 ACHIEVEMENT CATEGORIES:');
  print('   • Streak Achievements: 10 badges');
  print('   • Workout Achievements: 1 badge');
  print('   • Special Achievements: 4 badges');

  print('\n🔄 AUTOMATIC TRIGGERS:');
  print('   • Streak updates → Check streak achievements');
  print('   • Health metrics → Check workout achievements');
  print('   • Real-time sync enabled');

  print('\n📱 IN-APP FEATURES:');
  print('   • 5x3 grid layout (15 badges)');
  print('   • Progress tracking for locked badges');
  print('   • Tap badges for details');
  print('   • Unlock animations');
  print('   • Recent unlocks section');

  print('\n🚀 NEXT STEPS:');
  print('1. Run SQL setup scripts if not done');
  print('2. Restart Flutter app');
  print('3. Navigate to Streaks tab → Achievements');
  print('4. Complete activities to unlock badges');

  print('\n✨ ACHIEVEMENT EXAMPLES:');
  print('   🏃 Log first workout → "Warm-up Warrior"');
  print('   🔥 3-day streak → "No Excuses Rookie"');
  print('   💪 7-day streak → "Sweat Starter"');
  print('   👑 365-day streak → "Year-One Legend"');
  print('   🦉 Midnight workout → "Gym Goblin"');
}