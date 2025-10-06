import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streaker_flutter/services/supabase_service.dart';
import 'package:streaker_flutter/services/firebase_analytics_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  print('🔍 Starting Integration Tests...\n');
  
  // Test Results Storage
  Map<String, dynamic> testResults = {
    'firebase': {},
    'supabase': {},
    'localStorage': {},
    'dataFlow': {},
  };

  // 1. Test Firebase Initialization
  print('1️⃣ Testing Firebase Integration...');
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
    testResults['firebase']['initialization'] = '✅ Success';
    print('   ✅ Firebase initialized successfully');
    
    // Test Firebase Analytics
    try {
      FirebaseAnalyticsService().logEvent('test_event', {'test': 'value'});
      testResults['firebase']['analytics'] = '✅ Working';
      print('   ✅ Firebase Analytics is working');
    } catch (e) {
      testResults['firebase']['analytics'] = '❌ Error: $e';
      print('   ❌ Firebase Analytics error: $e');
    }
  } catch (e) {
    testResults['firebase']['initialization'] = '❌ Failed: $e';
    print('   ❌ Firebase initialization failed: $e');
  }

  // 2. Test Supabase Integration
  print('\n2️⃣ Testing Supabase Integration...');
  try {
    final supabase = Supabase.instance.client;
    testResults['supabase']['initialization'] = '✅ Success';
    print('   ✅ Supabase client initialized');
    
    // Check connection
    final response = await supabase.from('profiles').select().limit(1);
    testResults['supabase']['connection'] = '✅ Connected';
    print('   ✅ Supabase connection established');
  } catch (e) {
    if (e.toString().contains('PGRST205')) {
      testResults['supabase']['initialization'] = '✅ Success';
      testResults['supabase']['connection'] = '⚠️ No tables configured';
      print('   ⚠️ Supabase connected but no tables configured');
    } else {
      testResults['supabase']['initialization'] = '❌ Failed: $e';
      print('   ❌ Supabase error: $e');
    }
  }

  // 3. Test Local Storage
  print('\n3️⃣ Testing Local Storage...');
  try {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    
    // Test write
    await prefs.setString('test_key', 'test_value');
    testResults['localStorage']['write'] = '✅ Success';
    print('   ✅ Local storage write successful');
    
    // Test read
    final value = prefs.getString('test_key');
    if (value == 'test_value') {
      testResults['localStorage']['read'] = '✅ Success';
      print('   ✅ Local storage read successful');
    } else {
      testResults['localStorage']['read'] = '❌ Failed';
      print('   ❌ Local storage read failed');
    }
  } catch (e) {
    testResults['localStorage']['error'] = '❌ Failed: $e';
    print('   ❌ Local storage error: $e');
  }

  // 4. Test Authentication Flow
  print('\n4️⃣ Testing Authentication Flow...');
  try {
    final supabase = Supabase.instance.client;
    
    // Check current session
    final session = supabase.auth.currentSession;
    if (session != null) {
      testResults['supabase']['auth'] = '✅ User logged in';
      print('   ✅ User is authenticated');
      print('   📧 Email: ${session.user.email}');
    } else {
      testResults['supabase']['auth'] = '⚠️ No active session';
      print('   ⚠️ No active user session');
    }
  } catch (e) {
    testResults['supabase']['auth'] = '❌ Error: $e';
    print('   ❌ Authentication check error: $e');
  }

  // 5. Generate Report
  print('\n' + '=' * 50);
  print('📊 INTEGRATION TEST REPORT');
  print('=' * 50);
  
  print('\n🔥 FIREBASE STATUS:');
  testResults['firebase'].forEach((key, value) {
    print('   ${key.toUpperCase()}: $value');
  });
  
  print('\n⚡ SUPABASE STATUS:');
  testResults['supabase'].forEach((key, value) {
    print('   ${key.toUpperCase()}: $value');
  });
  
  print('\n💾 LOCAL STORAGE STATUS:');
  testResults['localStorage'].forEach((key, value) {
    print('   ${key.toUpperCase()}: $value');
  });
  
  // Overall Assessment
  print('\n' + '=' * 50);
  print('🎯 OVERALL ASSESSMENT:');
  
  bool firebaseOk = testResults['firebase']['initialization']?.contains('✅') ?? false;
  bool supabaseOk = testResults['supabase']['initialization']?.contains('✅') ?? false;
  bool localStorageOk = testResults['localStorage']['write']?.contains('✅') ?? false;
  
  if (firebaseOk && supabaseOk && localStorageOk) {
    print('   ✅ All core integrations are working!');
  } else {
    print('   ⚠️ Some integrations need attention:');
    if (!firebaseOk) print('      - Firebase needs configuration');
    if (!supabaseOk) print('      - Supabase needs configuration');
    if (!localStorageOk) print('      - Local storage has issues');
  }
  
  print('=' * 50);
}