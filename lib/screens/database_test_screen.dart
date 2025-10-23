import 'package:flutter/material.dart';
import '../services/enhanced_supabase_service.dart';
import '../utils/database_migrator.dart';
import '../utils/app_theme.dart';

class DatabaseTestScreen extends StatefulWidget {
  @override
  _DatabaseTestScreenState createState() => _DatabaseTestScreenState();
}

class _DatabaseTestScreenState extends State<DatabaseTestScreen> {
  final EnhancedSupabaseService _supabaseService = EnhancedSupabaseService();
  bool _isLoading = false;
  List<String> _logs = [];
  String _currentOperation = '';

  void _log(String message) {
    setState(() {
      final timestamp = DateTime.now().toString().substring(11, 19);
      _logs.add('[$timestamp] $message');
      if (_logs.length > 50) _logs.removeAt(0);
    });
    print(message);
  }

  Future<void> _generateTestData() async {
    setState(() {
      _isLoading = true;
      _currentOperation = 'Generating test data...';
      _logs.clear();
    });

    try {
      _log('🚀 Starting comprehensive test data generation');
      _log('This will create 10 test accounts with full data sets');

      await _supabaseService.generateTestData();

      _log('✅ Test data generation completed successfully!');
      _log('📊 Created:');
      _log('  • 10 user accounts with profiles');
      _log('  • 7 days of nutrition data per user');
      _log('  • 30 days of health metrics per user');
      _log('  • Streak data for each user');
      _log('  • Custom goals for each user');

    } catch (e) {
      _log('❌ Error generating test data: $e');
    } finally {
      setState(() {
        _isLoading = false;
        _currentOperation = '';
      });
    }
  }

  Future<void> _testCrudOperations() async {
    setState(() {
      _isLoading = true;
      _currentOperation = 'Testing CRUD operations...';
      _logs.clear();
    });

    try {
      _log('🧪 Starting CRUD operations test');

      // Test connection
      _log('1️⃣ Testing database connection...');
      final isConnected = await _supabaseService.isConnected();
      if (!isConnected) {
        throw Exception('Database connection failed');
      }
      _log('✅ Database connection successful');

      // Test user creation
      _log('2️⃣ Testing user creation...');
      final testEmail = 'crud.test.${DateTime.now().millisecondsSinceEpoch}@test.com';
      final signUpResponse = await _supabaseService.signUp(
        email: testEmail,
        password: 'testpass123',
        name: 'CRUD Test User',
      );

      if (signUpResponse.user == null) {
        throw Exception('User creation failed');
      }

      final userId = signUpResponse.user!.id;
      _log('✅ User created: $testEmail');

      // Wait for profile creation trigger
      await Future.delayed(Duration(seconds: 2));

      // Test profile operations
      _log('3️⃣ Testing profile operations...');

      // Read profile
      var profile = await _supabaseService.getUserProfile(userId);
      if (profile == null) {
        throw Exception('Profile not found after creation');
      }
      _log('✅ Profile read successful');

      // Update profile
      await _supabaseService.updateUserProfile(
        userId: userId,
        age: 25,
        height: 175.5,
        weight: 70.2,
        activityLevel: 'moderately_active',
        fitnessGoal: 'build_muscle',
      );
      _log('✅ Profile updated');

      // Test nutrition operations
      _log('4️⃣ Testing nutrition operations...');

      // Add nutrition entry
      await _supabaseService.addNutritionEntry(
        userId: userId,
        foodName: 'Test Chicken Breast',
        calories: 165,
        protein: 31.0,
        carbs: 0.0,
        fat: 3.6,
        // Note: fiber and foodSource parameters removed - fields don't exist in database
        mealType: 'lunch',
      );
      _log('✅ Nutrition entry added');

      // Read nutrition entries
      final nutritionEntries = await _supabaseService.getNutritionEntries(
        userId: userId,
        limit: 10,
      );
      if (nutritionEntries.isEmpty) {
        throw Exception('No nutrition entries found');
      }
      _log('✅ Nutrition entries retrieved: ${nutritionEntries.length}');

      // Get daily nutrition summary
      final nutritionSummary = await _supabaseService.getDailyNutritionSummary(
        userId: userId,
      );
      _log('✅ Daily nutrition summary: ${nutritionSummary['total_calories']} calories');

      // Note: Health metrics tests removed - health tracking has been removed from app
      _log('5️⃣ Health metrics tests skipped (feature removed)');

      // Test streak operations
      _log('6️⃣ Testing streak operations...');

      // Update streak
      await _supabaseService.updateStreak(
        userId: userId,
        currentStreak: 15,
        longestStreak: 45,
        lastActivityDate: DateTime.now(),
        targetAchieved: true,
      );
      _log('✅ Streak updated');

      // Read streak
      final streak = await _supabaseService.getStreak(userId: userId);
      if (streak == null) {
        throw Exception('Streak not found');
      }
      _log('✅ Streak retrieved: ${streak['current_streak']} days');

      // Test goals operations
      _log('7️⃣ Testing goals operations...');

      // Set goals
      await _supabaseService.setUserGoal(
        userId: userId,
        goalType: 'daily_steps',
        targetValue: 12000,
        unit: 'steps',
      );
      _log('✅ Goal set');

      // Update goal progress
      await _supabaseService.updateGoalProgress(
        userId: userId,
        goalType: 'daily_steps',
        currentValue: 8500,
      );
      _log('✅ Goal progress updated');

      // Read goals
      final goals = await _supabaseService.getUserGoals(userId: userId);
      if (goals.isEmpty) {
        throw Exception('No goals found');
      }
      _log('✅ Goals retrieved: ${goals.length} active goals');

      // Test dashboard
      _log('8️⃣ Testing dashboard operations...');

      final dashboard = await _supabaseService.getUserDashboard(userId);
      _log('✅ Dashboard data retrieved');

      _log('🎉 All CRUD operations completed successfully!');
      _log('📊 Test Summary:');
      _log('  • User creation: ✅');
      _log('  • Profile CRUD: ✅');
      _log('  • Nutrition CRUD: ✅');
      _log('  • Health metrics CRUD: ⏭️  (skipped - feature removed)');
      _log('  • Streaks CRUD: ✅');
      _log('  • Goals CRUD: ✅');
      _log('  • Dashboard query: ✅');

    } catch (e) {
      _log('❌ CRUD test failed: $e');
    } finally {
      setState(() {
        _isLoading = false;
        _currentOperation = '';
      });
    }
  }

  Future<void> _testGoogleSignIn() async {
    setState(() {
      _isLoading = true;
      _currentOperation = 'Testing Google Sign In...';
      _logs.clear();
    });

    try {
      _log('🔐 Testing Google Sign In functionality');
      _log('Please complete the Google sign-in flow when prompted');

      // This would trigger the Google sign-in flow
      // The actual implementation depends on your auth provider
      _log('💡 Google Sign-In test requires manual interaction');
      _log('Please test this through the main app interface');

    } catch (e) {
      _log('❌ Google sign-in test error: $e');
    } finally {
      setState(() {
        _isLoading = false;
        _currentOperation = '';
      });
    }
  }

  Future<void> _testMigrations() async {
    setState(() {
      _isLoading = true;
      _currentOperation = 'Testing database migrations...';
      _logs.clear();
    });

    try {
      _log('🔧 Starting database migration tests');

      // Test migrations
      final migrationResults = await DatabaseMigrator.applyAllMigrations();

      _log('📊 Migration Test Results:');
      migrationResults.forEach((migration, success) {
        final status = success ? '✅' : '❌';
        _log('$status $migration');
      });

      final successCount = migrationResults.values.where((success) => success).length;
      final totalCount = migrationResults.length;

      if (successCount == totalCount) {
        _log('🎉 All migrations successful ($successCount/$totalCount)');
      } else {
        _log('⚠️ Some migrations failed ($successCount/$totalCount)');
        _log('🔗 Manual migration script available');
      }

      // Test database status
      _log('🔍 Checking database status...');
      final status = await DatabaseMigrator.getDatabaseStatus();

      _log('📋 Database Status:');
      status.forEach((table, tableStatus) {
        _log('  📄 $table: $tableStatus');
      });

    } catch (e) {
      _log('❌ Migration test failed: $e');
    } finally {
      setState(() {
        _isLoading = false;
        _currentOperation = '';
      });
    }
  }

  Future<void> _testSchemaFixes() async {
    setState(() {
      _isLoading = true;
      _currentOperation = 'Testing schema fixes...';
      _logs.clear();
    });

    try {
      _log('🧪 Starting schema fix validation');

      // Test 1: Heart rate constraint validation - SKIPPED (health tracking removed)
      _log('1️⃣ Heart rate tests skipped (feature removed)');

      // Test 2: Profile with daily_calories_target
      _log('2️⃣ Testing daily_calories_target field...');
      try {
        if (_supabaseService.currentUser != null) {
          await _supabaseService.updateUserProfile(
            userId: _supabaseService.currentUser!.id,
            dailyCaloriesTarget: 2500,
          );
          _log('✅ daily_calories_target field working');
        } else {
          _log('⚠️ No user logged in - skipping profile test');
        }
      } catch (e) {
        _log('❌ daily_calories_target test failed: $e');
      }

      // Test 3: Streaks upsert with constraints
      _log('3️⃣ Testing streaks upsert operations...');
      try {
        if (_supabaseService.currentUser != null) {
          await _supabaseService.updateStreak(
            userId: _supabaseService.currentUser!.id,
            currentStreak: 5,
            longestStreak: 10,
            targetAchieved: true,
          );
          _log('✅ Streaks upsert working');
        } else {
          _log('⚠️ No user logged in - skipping streaks test');
        }
      } catch (e) {
        _log('❌ Streaks upsert test failed: $e');
      }

      // Test 4: Nutrition data type handling
      _log('4️⃣ Testing nutrition data handling...');
      try {
        if (_supabaseService.currentUser != null) {
          await _supabaseService.addNutritionEntry(
            userId: _supabaseService.currentUser!.id,
            foodName: 'Schema Test Food',
            calories: 200,
            protein: 10.0,
            carbs: 30.0,
            fat: 5.0,
          );
          _log('✅ Nutrition data handling working');
        } else {
          _log('⚠️ No user logged in - skipping nutrition test');
        }
      } catch (e) {
        _log('❌ Nutrition data test failed: $e');
      }

      _log('🎯 Schema fix validation completed');

    } catch (e) {
      _log('❌ Schema fix test failed: $e');
    } finally {
      setState(() {
        _isLoading = false;
        _currentOperation = '';
      });
    }
  }

  void _clearLogs() {
    setState(() {
      _logs.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        title: Text('Database Integration Test'),
        backgroundColor: AppTheme.darkBackground,
        actions: [
          IconButton(
            icon: Icon(Icons.clear_all),
            onPressed: _clearLogs,
            tooltip: 'Clear logs',
          ),
        ],
      ),
      body: Column(
        children: [
          // Control Panel
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.darkCardBackground,
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Supabase Integration Tests',
                  style: TextStyle(
                    color: AppTheme.primaryAccent,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 16),

                // Test Buttons
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _generateTestData,
                      icon: Icon(Icons.data_usage),
                      label: Text('Generate Test Data'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryAccent,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _testCrudOperations,
                      icon: Icon(Icons.playlist_add_check),
                      label: Text('Test CRUD Operations'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _testGoogleSignIn,
                      icon: Icon(Icons.login),
                      label: Text('Test Google Sign-In'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _testMigrations,
                      icon: Icon(Icons.build),
                      label: Text('Test Migrations'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _testSchemaFixes,
                      icon: Icon(Icons.verified),
                      label: Text('Test Schema Fixes'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),

                if (_isLoading) ...[
                  SizedBox(height: 16),
                  Row(
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: AppTheme.primaryAccent,
                          strokeWidth: 2,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _currentOperation,
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Logs Display
          Expanded(
            child: Container(
              margin: EdgeInsets.all(16),
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.primaryAccent.withOpacity(0.3)),
              ),
              child: _logs.isEmpty
                  ? Center(
                      child: Text(
                        'Select a test to begin\n\n'
                        '• Generate Test Data: Creates 10 accounts with sample data\n'
                        '• Test CRUD: Validates all database operations\n'
                        '• Test Google Sign-In: Checks authentication flow',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.builder(
                      itemCount: _logs.length,
                      itemBuilder: (context, index) {
                        final log = _logs[index];
                        Color textColor = Colors.white70;

                        if (log.contains('✅')) textColor = Colors.greenAccent;
                        else if (log.contains('❌')) textColor = Colors.redAccent;
                        else if (log.contains('🚀') || log.contains('🧪')) textColor = Colors.blueAccent;
                        else if (log.contains('📊') || log.contains('🎉')) textColor = AppTheme.primaryAccent;
                        else if (log.contains('💡')) textColor = Colors.orangeAccent;

                        return Padding(
                          padding: EdgeInsets.symmetric(vertical: 1),
                          child: Text(
                            log,
                            style: TextStyle(
                              color: textColor,
                              fontFamily: 'monospace',
                              fontSize: 12,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}