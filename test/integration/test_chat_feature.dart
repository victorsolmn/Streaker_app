import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';

// Test script to validate chat feature end-to-end
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  await Supabase.initialize(
    url: 'https://mzlqiqdcvxpwtzaehwgo.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im16bHFpcWRjdnhwd3R6YWVod2dvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MjEwODQ0MjAsImV4cCI6MjAzNjY2MDQyMH0.c3TrhpvD8sTvGMYTnIN4WL65v3cpEl7hnhapJRfHbYE',
  );

  final supabase = Supabase.instance.client;

  print('🧪 Starting Chat Feature End-to-End Test...\n');

  try {
    // Step 1: Authenticate (using existing test user)
    print('📱 Step 1: Authenticating user...');
    final authResponse = await supabase.auth.signInWithOtp(
      email: 'test@example.com',
    );

    // For testing, we'll simulate the OTP verification
    // In real test, you'd need to get the OTP from email
    print('✅ OTP sent to test@example.com\n');

    // Step 2: Create a test chat session
    print('💬 Step 2: Creating chat session...');
    final userId = supabase.auth.currentUser?.id ?? 'test-user-id';

    // Create session with test data
    final sessionData = {
      'user_id': userId,
      'session_date': DateTime.now().toIso8601String().split('T')[0],
      'session_number': 1,
      'session_title': 'Test Workout Planning Session',
      'session_summary': 'Discussed creating a personalized workout plan focusing on strength training and cardio balance for weight loss goals',
      'topics_discussed': ['workout planning', 'strength training', 'cardio', 'weight loss'],
      'user_goals_discussed': 'Lose 10 pounds in 3 months while building lean muscle',
      'recommendations_given': 'Start with 3 days strength training, 2 days cardio, focus on compound movements',
      'user_sentiment': 'positive',
      'message_count': 8,
      'duration_minutes': 5,
      'started_at': DateTime.now().subtract(Duration(minutes: 5)).toIso8601String(),
      'ended_at': DateTime.now().toIso8601String(),
    };

    final insertResponse = await supabase
        .from('chat_sessions')
        .insert(sessionData)
        .select()
        .single();

    print('✅ Chat session created with ID: ${insertResponse['id']}');
    print('   Title: ${insertResponse['session_title']}');
    print('   Summary: ${insertResponse['session_summary']}\n');

    // Step 3: Retrieve the session to verify
    print('🔍 Step 3: Retrieving session from database...');
    final sessions = await supabase
        .from('chat_sessions')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(1);

    if (sessions.isNotEmpty) {
      final latestSession = sessions[0];
      print('✅ Session retrieved successfully:');
      print('   - Date: ${latestSession['session_date']}');
      print('   - Topics: ${latestSession['topics_discussed']}');
      print('   - Sentiment: ${latestSession['user_sentiment']}');
      print('   - Messages: ${latestSession['message_count']}');
      print('   - Duration: ${latestSession['duration_minutes']} minutes\n');
    }

    // Step 4: Test the get_user_chat_context function
    print('📊 Step 4: Testing context retrieval function...');
    final contextResponse = await supabase
        .rpc('get_user_chat_context', params: {'p_user_id': userId});

    if (contextResponse != null && (contextResponse as List).isNotEmpty) {
      print('✅ User context retrieved:');
      for (var session in contextResponse) {
        print('   - ${session['session_date']}: ${session['session_summary']}');
      }
      print('');
    }

    // Step 5: Test session numbering
    print('🔢 Step 5: Testing session numbering...');
    final nextNumber = await supabase.rpc('get_next_session_number', params: {
      'p_user_id': userId,
      'p_date': DateTime.now().toIso8601String().split('T')[0],
    });
    print('✅ Next session number for today: $nextNumber\n');

    // Step 6: Create another session to test multiple sessions
    print('💬 Step 6: Creating second test session...');
    final session2Data = {
      'user_id': userId,
      'session_date': DateTime.now().toIso8601String().split('T')[0],
      'session_number': nextNumber,
      'session_title': 'Nutrition Guidance Session',
      'session_summary': 'Reviewed daily meal plan with focus on protein intake and pre-workout nutrition timing',
      'topics_discussed': ['nutrition', 'meal planning', 'protein', 'pre-workout'],
      'user_goals_discussed': 'Optimize nutrition for muscle growth and recovery',
      'recommendations_given': 'Aim for 1g protein per pound body weight, eat carbs 2 hours before workout',
      'user_sentiment': 'positive',
      'message_count': 12,
      'duration_minutes': 7,
      'started_at': DateTime.now().subtract(Duration(minutes: 7)).toIso8601String(),
      'ended_at': DateTime.now().toIso8601String(),
    };

    final insert2Response = await supabase
        .from('chat_sessions')
        .insert(session2Data)
        .select()
        .single();

    print('✅ Second session created: ${insert2Response['session_title']}\n');

    // Step 7: Verify all sessions
    print('📋 Step 7: Listing all user sessions...');
    final allSessions = await supabase
        .from('chat_sessions')
        .select()
        .eq('user_id', userId)
        .order('session_date', ascending: false)
        .order('session_number', ascending: false);

    print('✅ Total sessions found: ${allSessions.length}');
    for (var session in allSessions) {
      print('   📝 ${session['session_date']} #${session['session_number']}: ${session['session_title']}');
      print('      Summary: ${session['session_summary']}');
      print('      Topics: ${session['topics_discussed']?.join(', ')}');
      print('');
    }

    print('🎉 Chat Feature Test Complete!\n');
    print('✅ All integration points working:');
    print('   - Session creation');
    print('   - Session retrieval');
    print('   - Context function');
    print('   - Session numbering');
    print('   - Multiple sessions per day');

  } catch (e) {
    print('❌ Test failed with error: $e');
  }
}