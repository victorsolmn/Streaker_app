import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  // Initialize Supabase
  await Supabase.initialize(
    url: 'https://xzwvckziavhzmghizyqx.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inh6d3Zja3ppYXZoem1naGl6eXF4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzcxMDQ0MTEsImV4cCI6MjA1MjY4MDQxMX0.DdKlXVAPhN6I5xL0jw9TWJEp2dPPHSqG0VXEfAEU0xI',
  );

  final supabase = Supabase.instance.client;

  // Test account details
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final email = 'test_$timestamp@example.com';
  final password = 'Test123456!';
  final name = 'Test User $timestamp';

  try {
    print('\n' + '=' * 60);
    print('🚀 TESTING ONBOARDING INTEGRATION');
    print('=' * 60);

    // Step 1: Sign up
    print('\n📝 STEP 1: Creating account...');
    print('Email: $email');
    print('Password: $password');
    print('Name: $name');

    final signupResponse = await supabase.auth.signUp(
      email: email,
      password: password,
      data: {'name': name},
    );

    if (signupResponse.user != null) {
      print('✅ Account created successfully!');
      print('User ID: ${signupResponse.user!.id}');

      // Wait a moment for trigger to create profile
      await Future.delayed(Duration(seconds: 2));

      // Step 2: Update profile with onboarding data
      print('\n📝 STEP 2: Updating profile with onboarding data...');

      final profileData = {
        'name': name,
        'email': email,
        'age': 28,
        'height': 175,
        'weight': 75,
        'activity_level': 'Moderately Active',
        'fitness_goal': 'Maintain Weight',
        'has_completed_onboarding': true,
        'updated_at': DateTime.now().toIso8601String(),
      };

      print('\n📤 REQUEST DATA:');
      profileData.forEach((key, value) {
        print('  $key: $value');
      });

      try {
        final updateResponse = await supabase
            .from('profiles')
            .update(profileData)
            .eq('id', signupResponse.user!.id)
            .select();

        print('\n✅ Profile updated successfully!');
        print('\n📥 RESPONSE DATA:');
        if (updateResponse is List && updateResponse.isNotEmpty) {
          updateResponse[0].forEach((key, value) {
            print('  $key: $value');
          });
        }
      } catch (updateError) {
        print('\n❌ UPDATE ERROR: $updateError');
        if (updateError.toString().contains('42501')) {
          print('\n⚠️ RLS POLICY ISSUE DETECTED!');
          print('The Row Level Security policy is blocking the update.');
          print('Please run fix_rls_final_solution.sql in Supabase SQL editor.');
        }
      }

      // Step 3: Verify the data
      print('\n📝 STEP 3: Verifying data in database...');

      try {
        final profile = await supabase
            .from('profiles')
            .select()
            .eq('id', signupResponse.user!.id)
            .single();

        print('\n✅ Data retrieved from database:');
        profile.forEach((key, value) {
          print('  $key: $value');
        });

        // Check specific fields
        print('\n🔍 FIELD VERIFICATION:');
        print('  has_completed_onboarding: ${profile['has_completed_onboarding']} (${profile['has_completed_onboarding'] == true ? "✅ CORRECT" : "❌ STILL FALSE"})');
        print('  age: ${profile['age']} (${profile['age'] != null ? "✅" : "❌ NULL"})');
        print('  height: ${profile['height']} (${profile['height'] != null ? "✅" : "❌ NULL"})');
        print('  weight: ${profile['weight']} (${profile['weight'] != null ? "✅" : "❌ NULL"})');
        print('  activity_level: ${profile['activity_level']} (${profile['activity_level'] != null ? "✅" : "❌ NULL"})');
        print('  fitness_goal: ${profile['fitness_goal']} (${profile['fitness_goal'] != null ? "✅" : "❌ NULL"})');

        if (profile['has_completed_onboarding'] == true &&
            profile['age'] != null &&
            profile['height'] != null &&
            profile['weight'] != null) {
          print('\n🎉 SUCCESS: All onboarding data persisted correctly!');
        } else {
          print('\n⚠️ ISSUE: Some fields are not persisting correctly');
        }

      } catch (fetchError) {
        print('\n❌ FETCH ERROR: $fetchError');
      }

    } else {
      print('❌ Failed to create account');
    }

  } catch (e) {
    print('\n❌ ERROR: $e');
  }

  print('\n' + '=' * 60);
  print('TEST COMPLETE');
  print('=' * 60);
}