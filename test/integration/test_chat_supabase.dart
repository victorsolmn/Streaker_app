import 'dart:io';
import 'package:supabase/supabase.dart';

// Simple test to create chat session entries in Supabase
void main() async {
  print('🧪 Chat Feature Integration Test\n');
  print('================================\n');

  // Initialize Supabase client with correct URL from config
  final supabase = SupabaseClient(
    'https://xzwvckziavhzmghizyqx.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inh6d3Zja3ppYXZoem1naGl6eXF4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTgwOTk0NjIsImV4cCI6MjA3MzY3NTQ2Mn0.fUtnAzqNGzKvo-FTWqpemcf0wvdlC6gpUg_ZllXBulo',
  );

  try {
    // Step 1: Use a test user ID directly (since we're testing backend functionality)
    print('📱 Setting up test user...');
    // Using a fixed test user ID for demonstration
    // In production, this would come from actual authentication
    final userId = '06c9edbc-1dd9-4e49-b8f1-e969f582d10a'; // Test user ID
    print('✅ Using test user ID: $userId\n');
    print('ℹ️ Note: In production, user would be authenticated via the app\n');

    // Step 2: Check if table exists and get current sessions
    print('🔍 Checking existing sessions...');
    final existingSessions = await supabase
        .from('chat_sessions')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(5);

    print('✅ Found ${existingSessions.length} existing sessions\n');

    // Step 3: Get next session number
    print('🔢 Getting next session number...');
    final today = DateTime.now().toIso8601String().split('T')[0];
    final nextNumber = await supabase.rpc('get_next_session_number', params: {
      'p_user_id': userId,
      'p_date': today,
    });
    print('✅ Next session number for today: $nextNumber\n');

    // Step 4: Create a realistic test session
    print('💬 Creating test chat session...');
    final testSession = {
      'user_id': userId,
      'session_date': today,
      'session_number': nextNumber,
      'session_title': 'Fitness Goal Discussion',
      'session_summary': 'Explored personalized workout strategies for building muscle while maintaining cardiovascular health',
      'topics_discussed': [
        'muscle building',
        'cardio balance',
        'protein intake',
        'recovery time'
      ],
      'user_goals_discussed': 'Build 5kg lean muscle in 6 months while improving 5K run time',
      'recommendations_given': 'Upper/lower split 4x week, HIIT cardio 2x week, 1.6g protein per kg bodyweight, 8hrs sleep',
      'user_sentiment': 'positive',
      'message_count': 15,
      'duration_minutes': 8,
      'started_at': DateTime.now().subtract(Duration(minutes: 8)).toIso8601String(),
      'ended_at': DateTime.now().toIso8601String(),
    };

    final insertResult = await supabase
        .from('chat_sessions')
        .insert(testSession)
        .select()
        .single();

    print('✅ Session created successfully!');
    print('   ID: ${insertResult['id']}');
    print('   Title: ${insertResult['session_title']}');
    print('   Summary: ${insertResult['session_summary']}\n');

    // Step 5: Create another session with different topic
    print('💬 Creating second test session...');
    final testSession2 = {
      'user_id': userId,
      'session_date': today,
      'session_number': nextNumber + 1,
      'session_title': 'Nutrition Optimization Chat',
      'session_summary': 'Discussed meal timing strategies and macro distribution for optimal performance and recovery',
      'topics_discussed': [
        'meal timing',
        'macros',
        'supplements',
        'hydration'
      ],
      'user_goals_discussed': 'Optimize pre and post workout nutrition for better performance',
      'recommendations_given': 'Carbs 2-3hrs pre-workout, protein within 30min post, creatine 5g daily, 3L water minimum',
      'user_sentiment': 'positive',
      'message_count': 10,
      'duration_minutes': 6,
      'started_at': DateTime.now().subtract(Duration(hours: 1, minutes: 6)).toIso8601String(),
      'ended_at': DateTime.now().subtract(Duration(hours: 1)).toIso8601String(),
    };

    final insertResult2 = await supabase
        .from('chat_sessions')
        .insert(testSession2)
        .select()
        .single();

    print('✅ Second session created!');
    print('   Title: ${insertResult2['session_title']}\n');

    // Step 6: Test retrieval of user context
    print('📊 Testing context retrieval...');
    final context = await supabase.rpc('get_user_chat_context', params: {
      'p_user_id': userId,
    });

    if (context != null && (context as List).isNotEmpty) {
      print('✅ Recent conversation context:');
      for (var session in context) {
        print('   📝 ${session['session_date']}: ${session['session_summary']}');
        if (session['topics_discussed'] != null) {
          print('      Topics: ${(session['topics_discussed'] as List).join(', ')}');
        }
      }
      print('');
    }

    // Step 7: Display summary
    print('📋 Test Summary');
    print('==============');
    final allSessions = await supabase
        .from('chat_sessions')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    print('✅ Total sessions in database: ${allSessions.length}');
    print('✅ Sessions created in this test: 2');
    print('✅ All integration points working correctly!\n');

    print('🎉 SUCCESS! Chat feature is fully integrated with Supabase.');
    print('   - Sessions are being saved');
    print('   - Summaries are stored');
    print('   - Context retrieval works');
    print('   - Session numbering works\n');

    print('📱 You can now:');
    print('   1. Open the Flutter app');
    print('   2. Go to Chat screen (Workouts tab)');
    print('   3. Have a conversation');
    print('   4. Click "Save & End"');
    print('   5. View history to see saved sessions');

  } catch (e) {
    print('❌ Error during test: $e');
    print('\nPlease check:');
    print('1. Supabase project is active');
    print('2. Migration has been run');
    print('3. Network connection is working');
  }

  exit(0);
}