import 'package:supabase/supabase.dart';

void main() async {
  final supabase = SupabaseClient(
    'https://xzwvckziavhzmghizyqx.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inh6d3Zja3ppYXZoem1naGl6eXF4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTgwOTk0NjIsImV4cCI6MjA3MzY3NTQ2Mn0.fUtnAzqNGzKvo-FTWqpemcf0wvdlC6gpUg_ZllXBulo',
  );

  print('Testing Supabase configuration...\n');

  // Test with a new user
  final testEmail = 'test${DateTime.now().millisecondsSinceEpoch}@example.com';
  final testPassword = 'TestPassword123!';

  try {
    // 1. Sign up
    print('1. Testing signup with email: $testEmail');
    final signUpResponse = await supabase.auth.signUp(
      email: testEmail,
      password: testPassword,
    );

    if (signUpResponse.user != null) {
      print('   ✅ User created: ${signUpResponse.user!.id}');
      print('   Email confirmed required: ${signUpResponse.user!.emailConfirmedAt == null}');
    }

    // 2. Try to sign in immediately
    print('\n2. Testing immediate sign in...');
    try {
      final signInResponse = await supabase.auth.signInWithPassword(
        email: testEmail,
        password: testPassword,
      );

      if (signInResponse.session != null) {
        print('   ✅ Session created successfully!');
        print('   Session token: ${signInResponse.session!.accessToken.substring(0, 20)}...');
        print('   User ID: ${signInResponse.user!.id}');
        print('   \n🎉 EMAIL CONFIRMATION IS DISABLED!');
      }
    } catch (e) {
      if (e.toString().contains('Email not confirmed')) {
        print('   ❌ Email confirmation still required');
        print('   ⚠️ EMAIL CONFIRMATION IS STILL ENABLED IN SUPABASE');
      } else {
        print('   ❌ Sign in error: $e');
      }
    }

    // 3. Check if profile was created
    print('\n3. Checking if profile exists...');
    final profile = await supabase
        .from('profiles')
        .select()
        .eq('id', signUpResponse.user!.id)
        .maybeSingle();

    if (profile != null) {
      print('   ✅ Profile created by trigger');
      print('   Profile data: $profile');
    } else {
      print('   ⚠️ No profile found (trigger may have failed)');
    }

    // 4. Test updating profile with nullable fields
    print('\n4. Testing profile update with user data...');
    try {
      await supabase.from('profiles').upsert({
        'id': signUpResponse.user!.id,
        'email': testEmail,
        'name': 'Test User',
        'age': 25,
        'height': 175.5,
        'weight': 70.0,
        'activity_level': 'Moderately Active',
        'fitness_goal': 'Lose Weight',
      });
      print('   ✅ Profile updated successfully with user data!');
    } catch (e) {
      print('   ❌ Profile update failed: $e');
    }

    // Clean up - delete test user
    if (signUpResponse.session != null) {
      await supabase.auth.admin.deleteUser(signUpResponse.user!.id);
      print('\n5. Test user cleaned up');
    }

  } catch (e) {
    print('Error: $e');
  }

  await supabase.dispose();
}