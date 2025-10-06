import 'package:supabase/supabase.dart';
import 'dart:math';

void main() async {
  print('🧪 Testing Calorie Tracking System...\n');

  final supabase = SupabaseClient(
    'https://xzwvckziavhzmghizyqx.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inh6d3Zja3ppYXZoem1naGl6eXF4Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1ODA5OTQ2MiwiZXhwIjoyMDczNjc1NDYyfQ.jXjRDeSc1e3RLQVIxZwNRgYwF-nXmHf4icvnjllW-ao',
  );

  try {
    // Get user ID for victorsolmn@gmail.com
    final userResponse = await supabase
        .from('profiles')
        .select('id, weight, height, age')
        .eq('email', 'victorsolmn@gmail.com')
        .single();

    final userId = userResponse['id'];
    final weight = userResponse['weight'] ?? 70.0;
    final height = userResponse['height'] ?? 170.0;
    final age = userResponse['age'] ?? 30;

    print('User: victorsolmn@gmail.com');
    print('Profile: Age=$age, Weight=${weight}kg, Height=${height}cm\n');

    // Create test data for today
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final random = Random();

    print('📝 Creating test calorie sessions for today...\n');

    // Session 1: Early morning (12 AM - 6 AM) - Sleep
    await _createSession(supabase, userId, today, 0, 6, 'sleep',
      bmr: (weight * 0.9 * 6 / 24), // Lower BMR during sleep
      active: 0,
      exercise: 0,
      steps: 0,
    );

    // Session 2: Morning (6 AM - 7 AM) - Wake up routine
    await _createSession(supabase, userId, today, 6, 7, 'rest',
      bmr: weight * 1 / 24,
      active: 10,
      exercise: 0,
      steps: 500,
    );

    // Session 3: Morning workout (7 AM - 9 AM) - Gym
    await _createSession(supabase, userId, today, 7, 9, 'exercise',
      bmr: weight * 2 / 24,
      active: 200,
      exercise: 360, // High burn during workout
      steps: 1000,
      exerciseType: 'WEIGHT_TRAINING',
      heartRate: 145,
    );

    // Session 4: Work hours (9 AM - 12 PM)
    await _createSession(supabase, userId, today, 9, 12, 'rest',
      bmr: weight * 3 / 24,
      active: 50,
      exercise: 0,
      steps: 2000,
    );

    // Session 5: Lunch walk (12 PM - 1 PM)
    await _createSession(supabase, userId, today, 12, 13, 'rest',
      bmr: weight * 1 / 24,
      active: 80,
      exercise: 0,
      steps: 2500,
    );

    // Session 6: Afternoon work (1 PM - 5 PM)
    await _createSession(supabase, userId, today, 13, 17, 'rest',
      bmr: weight * 4 / 24,
      active: 60,
      exercise: 0,
      steps: 1500,
    );

    // Session 7: Evening (5 PM - current time)
    final currentHour = now.hour;
    if (currentHour >= 17) {
      await _createSession(supabase, userId, today, 17, currentHour, 'rest',
        bmr: weight * (currentHour - 17) / 24,
        active: 40 * (currentHour - 17).toDouble(),
        exercise: 0,
        steps: 1000 * (currentHour - 17),
      );
    }

    print('✅ Test sessions created!\n');

    // Check the daily total
    print('📊 Checking daily totals...\n');

    final dailyTotal = await supabase
        .from('daily_calorie_totals')
        .select()
        .eq('user_id', userId)
        .eq('date', today.toIso8601String().split('T')[0])
        .maybeSingle();

    if (dailyTotal != null) {
      print('Today\'s Calorie Breakdown:');
      print('================================');
      print('BMR Calories: ${dailyTotal['total_bmr_calories']?.toStringAsFixed(1)} kcal');
      print('Active Calories: ${dailyTotal['total_active_calories']?.toStringAsFixed(1)} kcal');
      print('Exercise Calories: ${dailyTotal['total_exercise_calories']?.toStringAsFixed(1)} kcal');
      print('--------------------------------');
      print('TOTAL CALORIES: ${dailyTotal['total_calories']?.toStringAsFixed(1)} kcal');
      print('================================');
      print('');
      print('Activity Summary:');
      print('Steps: ${dailyTotal['total_steps']}');
      print('Exercise Minutes: ${dailyTotal['exercise_minutes']}');
      print('Sessions: ${dailyTotal['session_count']}');
      print('Data Completeness: ${(dailyTotal['data_completeness'] * 100).toStringAsFixed(0)}%');
      print('Has Full Day: ${dailyTotal['has_full_day_data']}');
    } else {
      print('No daily total found - trigger may be pending');
    }

    // Check health_metrics compatibility
    print('\n🔄 Checking backward compatibility...\n');

    final healthMetrics = await supabase
        .from('health_metrics')
        .select('calories_burned')
        .eq('user_id', userId)
        .eq('date', today.toIso8601String().split('T')[0])
        .maybeSingle();

    if (healthMetrics != null) {
      print('health_metrics.calories_burned: ${healthMetrics['calories_burned']?.toStringAsFixed(1)} kcal');
      print('✅ Backward compatibility maintained!');
    } else {
      print('⚠️  No health_metrics entry yet');
    }

    print('\n🎉 Calorie tracking system test complete!');

  } catch (e) {
    print('❌ Error: $e');
  }
}

Future<void> _createSession(
  SupabaseClient supabase,
  String userId,
  DateTime date,
  int startHour,
  int endHour,
  String segmentType, {
  required double bmr,
  required double active,
  required double exercise,
  required int steps,
  String? exerciseType,
  int? heartRate,
}) async {
  final start = DateTime(date.year, date.month, date.day, startHour);
  final end = DateTime(date.year, date.month, date.day, endHour);

  final session = {
    'user_id': userId,
    'session_date': date.toIso8601String().split('T')[0],
    'session_start': start.toIso8601String(),
    'session_end': end.toIso8601String(),
    'bmr_calories': bmr,
    'active_calories': active,
    'exercise_calories': exercise,
    'steps': steps,
    'segment_type': segmentType,
    'data_source': 'manual',
    'platform': 'android',
    'sync_status': 'synced',
  };

  if (exerciseType != null) {
    session['exercise_type'] = exerciseType;
    session['exercise_intensity'] = 'moderate';
  }

  if (heartRate != null) {
    session['avg_heart_rate'] = heartRate;
    session['max_heart_rate'] = heartRate + 20;
  }

  await supabase.from('calorie_sessions').upsert(
    session,
    onConflict: 'user_id,session_start,session_end',
  );

  final total = bmr + active + exercise;
  print('  ${startHour.toString().padLeft(2, '0')}:00-${endHour.toString().padLeft(2, '0')}:00: '
      '${total.toStringAsFixed(0)} cal '
      '($segmentType${exerciseType != null ? ' - $exerciseType' : ''})');
}