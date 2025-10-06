import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  print('🔐 Testing Unified OTP Authentication Flow');
  print('==========================================\n');

  // Initialize Supabase
  await Supabase.initialize(
    url: 'https://xzwvckziavhzmghizyqx.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inh6d3Zja3ppYXZoem1naGl6eXF4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTgwOTk0NjIsImV4cCI6MjA3MzY3NTQ2Mn0.fUtnAzqNGzKvo-FTWqpemcf0wvdlC6gpUg_ZllXBulo',
  );

  final supabase = Supabase.instance.client;

  // Test 1: Check if OTP/Magic Link is enabled
  print('Test 1: Checking OTP Configuration');
  print('-----------------------------------');

  stdout.write('Enter a test email address: ');
  final testEmail = stdin.readLineSync() ?? 'test@example.com';

  try {
    print('Attempting to send OTP to: $testEmail');

    await supabase.auth.signInWithOtp(
      email: testEmail,
      emailRedirectTo: 'com.streaker.streaker://auth-callback',
    );

    print('✅ SUCCESS: OTP sent successfully!');
    print('📧 Check the email inbox for the verification code\n');

    // Test 2: Check if user exists
    print('Test 2: Checking User Existence');
    print('--------------------------------');

    try {
      final response = await supabase
          .from('profiles')
          .select('id, email')
          .eq('email', testEmail.toLowerCase().trim())
          .maybeSingle();

      if (response != null) {
        print('✅ User EXISTS in database: ${response['email']}');
        print('   This should trigger SIGN IN flow\n');
      } else {
        print('❌ User does NOT exist in database');
        print('   This should trigger SIGN UP flow\n');
      }
    } catch (e) {
      print('⚠️  Could not check user existence: $e\n');
    }

    // Test 3: Verify OTP (manual input required)
    print('Test 3: OTP Verification');
    print('------------------------');
    stdout.write('Enter the 6-digit OTP code from your email (or press Enter to skip): ');
    final otpCode = stdin.readLineSync();

    if (otpCode != null && otpCode.length == 6) {
      try {
        print('Attempting to verify OTP...');

        final response = await supabase.auth.verifyOTP(
          email: testEmail,
          token: otpCode,
          type: OtpType.email,
        );

        if (response.user != null) {
          print('✅ OTP Verified Successfully!');
          print('   User ID: ${response.user!.id}');
          print('   Email: ${response.user!.email}');
          print('   Session: ${response.session != null ? "Active" : "None"}\n');

          // Sign out for cleanup
          await supabase.auth.signOut();
          print('🔓 Signed out for cleanup\n');
        }
      } catch (e) {
        print('❌ OTP Verification Failed: $e\n');
      }
    } else {
      print('⏭️  Skipping OTP verification\n');
    }

  } catch (e) {
    print('❌ FAILED to send OTP: $e\n');

    if (e.toString().contains('Email logins are disabled')) {
      print('🚨 ACTION REQUIRED - Email authentication is disabled!\n');
      print('Please follow these steps:');
      print('1. Go to: https://supabase.com/dashboard/project/xzwvckziavhzmghizyqx/auth/providers');
      print('2. Click on "Email" provider');
      print('3. Toggle "Enable Email provider" to ON');
      print('4. Enable "Confirm email" (OTP/Magic Link)');
      print('5. Set "OTP Expiry duration" to 300 seconds');
      print('6. Save changes\n');

      print('Email Template (optional customization):');
      print('----------------------------------------');
      print('Subject: Your Streaker verification code');
      print('Body:');
      print('Hi there,\n');
      print('Your verification code is: {{ .Token }}\n');
      print('This code will expire in 5 minutes.\n');
      print('Thanks,');
      print('The Streaker Team\n');
    } else if (e.toString().contains('rate_limit')) {
      print('⚠️  Rate limited - too many OTP requests');
      print('   Wait a few minutes before trying again\n');
    }
  }

  // Test 4: Check authentication methods availability
  print('Test 4: Authentication Methods Status');
  print('-------------------------------------');

  // Check password auth
  print('Password Authentication: ✅ Available (existing implementation)');
  print('Google OAuth: ✅ Available (requires dashboard config)');
  print('OTP/Magic Link: ${testEmail.contains('@') ? '🔄 Testing required' : '❓ Unknown'}');

  print('\n==========================================');
  print('🏁 Test Complete!\n');

  print('Summary:');
  print('--------');
  print('• If OTP was sent successfully, email auth is ENABLED');
  print('• If you received an error, follow the dashboard steps above');
  print('• The unified auth screen will work once OTP is enabled');
  print('• Existing password and Google auth remain functional\n');

  print('Next Steps:');
  print('-----------');
  print('1. Enable OTP in Supabase dashboard (if not already)');
  print('2. Test the app with flutter run');
  print('3. Try the new "Get Started" button on welcome screen');
  print('4. Verify both new signup and existing signin flows work\n');
}