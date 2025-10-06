import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  // Initialize Supabase with provided credentials
  await Supabase.initialize(
    url: 'https://xzwvckziavhzmghizyqx.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inh6d3Zja3ppYXZoem1naGl6eXF4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTgwOTk0NjIsImV4cCI6MjA3MzY3NTQ2Mn0.fUtnAzqNGzKvo-FTWqpemcf0wvdlC6gpUg_ZllXBulo',
  );

  final supabase = Supabase.instance.client;

  print('Testing Supabase OTP Configuration...');
  print('=====================================');

  try {
    // Test OTP sending (this will actually send an OTP to test email)
    final testEmail = 'test@example.com';

    print('Attempting to send OTP to: $testEmail');

    await supabase.auth.signInWithOtp(
      email: testEmail,
      emailRedirectTo: 'com.streaker.streaker://auth-callback',
    );

    print('✅ OTP sent successfully!');
    print('OTP/Magic Link is ENABLED in your Supabase project');

  } catch (e) {
    print('❌ Failed to send OTP: $e');

    if (e.toString().contains('Email logins are disabled')) {
      print('\n⚠️ ACTION REQUIRED FROM YOUR SIDE:');
      print('1. Go to https://supabase.com/dashboard/project/xzwvckziavhzmghizyqx/auth/providers');
      print('2. Click on "Email" provider');
      print('3. Toggle "Enable Email provider" to ON');
      print('4. Under "Email Auth", enable "Magic Link" or "OTP"');
      print('5. Set OTP expiry to 300 seconds (5 minutes)');
      print('6. Save changes');
    } else if (e.toString().contains('rate limit')) {
      print('Rate limited - OTP might be working but hitting limits');
    } else {
      print('Unknown error - check Supabase dashboard settings');
    }
  }

  print('\n=====================================');
  print('Test complete!');
}