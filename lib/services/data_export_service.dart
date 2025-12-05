import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'supabase_service.dart';

/// Service for exporting user data (GDPR compliance)
/// Allows users to download all their data in JSON format
class DataExportService {
  final SupabaseService _supabase = SupabaseService();

  /// Export all user data to JSON file and share it
  Future<void> exportUserData(BuildContext context) async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => WillPopScope(
          onWillPop: () async => false,
          child: AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Exporting your data...'),
                SizedBox(height: 8),
                Text(
                  'This may take a moment',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      );

      final user = _supabase.currentUser;
      if (user == null) {
        throw Exception('No user logged in');
      }

      final userId = user.id;
      debugPrint('📦 Starting data export for user: $userId');

      // Fetch all user data
      final profile = await _fetchProfile(userId);
      final nutritionEntries = await _fetchNutritionEntries(userId);
      final weightEntries = await _fetchWeightEntries(userId);
      final workoutSessions = await _fetchWorkoutSessions(userId);
      final workoutTemplates = await _fetchWorkoutTemplates(userId);
      final achievements = await _fetchAchievements(userId);
      final streakData = await _fetchStreakData(userId);
      final dailySummaries = await _fetchDailySummaries(userId);

      // Calculate statistics
      final stats = _calculateStatistics(
        nutritionEntries: nutritionEntries,
        workoutSessions: workoutSessions,
        weightEntries: weightEntries,
      );

      // Create comprehensive export data
      final exportData = {
        'export_info': {
          'export_date': DateTime.now().toIso8601String(),
          'export_version': '1.0',
          'app_version': '1.0.21',
          'user_id': userId,
          'email': user.email,
        },
        'profile': profile,
        'statistics': stats,
        'nutrition': {
          'total_entries': nutritionEntries.length,
          'entries': nutritionEntries,
        },
        'weight': {
          'total_entries': weightEntries.length,
          'entries': weightEntries,
        },
        'workouts': {
          'total_sessions': workoutSessions.length,
          'total_templates': workoutTemplates.length,
          'sessions': workoutSessions,
          'templates': workoutTemplates,
        },
        'achievements': {
          'total_unlocked': achievements.length,
          'progress': achievements,
        },
        'streaks': streakData,
        'daily_summaries': {
          'total_days': dailySummaries.length,
          'summaries': dailySummaries,
        },
      };

      // Convert to pretty JSON
      final jsonString = JsonEncoder.withIndent('  ').convert(exportData);

      // Save to file
      final directory = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'streaker_data_export_$timestamp.json';
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(jsonString);

      debugPrint('✅ Data export created: ${file.path}');
      
      // Calculate file size before showing dialog
      final fileSize = await file.length();
      final fileSizeKB = (fileSize / 1024).toStringAsFixed(2);
      debugPrint('📊 Export size: $fileSizeKB KB');

      // Close loading dialog
      Navigator.pop(context);

      // Show success dialog with options
      final shouldShare = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 8),
              Text('Export Complete'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Your data has been exported successfully!'),
              SizedBox(height: 16),
              Text(
                'Export Details:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              _buildExportStat('Total Records', stats['total_records'].toString()),
              _buildExportStat('Nutrition Entries', nutritionEntries.length.toString()),
              _buildExportStat('Workout Sessions', workoutSessions.length.toString()),
              _buildExportStat('Weight Entries', weightEntries.length.toString()),
              _buildExportStat('Achievements', achievements.length.toString()),
              SizedBox(height: 8),
              Text(
                'File size: $fileSizeKB KB',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Close'),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context, true),
              icon: Icon(Icons.share),
              label: Text('Share File'),
            ),
          ],
        ),
      );

      // Share file if user wants to
      if (shouldShare == true) {
        await Share.shareXFiles(
          [XFile(file.path)],
          subject: 'Streaker Data Export',
          text: 'Your complete Streaker app data export from ${DateTime.now().toString().substring(0, 10)}',
        );
      }

      debugPrint('✅ Data export completed successfully');
    } catch (e) {
      debugPrint('❌ Data export failed: $e');
      
      // Close loading dialog if open
      Navigator.pop(context);

      // Show error dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.error, color: Colors.red),
              SizedBox(width: 8),
              Text('Export Failed'),
            ],
          ),
          content: Text('Failed to export data: ${e.toString()}'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildExportStat(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('• $label:', style: TextStyle(fontSize: 13)),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  /// Fetch user profile
  Future<Map<String, dynamic>?> _fetchProfile(String userId) async {
    try {
      final profile = await _supabase.getUserProfile(userId);
      return profile;
    } catch (e) {
      debugPrint('⚠️ Error fetching profile: $e');
      return null;
    }
  }

  /// Fetch nutrition entries
  Future<List<Map<String, dynamic>>> _fetchNutritionEntries(String userId) async {
    try {
      return await _supabase.getNutritionHistory(userId: userId, days: 365);
    } catch (e) {
      debugPrint('⚠️ Error fetching nutrition entries: $e');
      return [];
    }
  }

  /// Fetch weight entries
  Future<List<Map<String, dynamic>>> _fetchWeightEntries(String userId) async {
    try {
      final response = await _supabase.client
          .from('weight_entries')
          .select()
          .eq('user_id', userId)
          .order('date', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('⚠️ Error fetching weight entries: $e');
      return [];
    }
  }

  /// Fetch workout sessions
  Future<List<Map<String, dynamic>>> _fetchWorkoutSessions(String userId) async {
    try {
      final response = await _supabase.client
          .from('workout_sessions')
          .select()
          .eq('user_id', userId)
          .order('date', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('⚠️ Error fetching workout sessions: $e');
      return [];
    }
  }

  /// Fetch workout templates
  Future<List<Map<String, dynamic>>> _fetchWorkoutTemplates(String userId) async {
    try {
      final response = await _supabase.client
          .from('workout_templates')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('⚠️ Error fetching workout templates: $e');
      return [];
    }
  }

  /// Fetch achievements progress
  Future<List<Map<String, dynamic>>> _fetchAchievements(String userId) async {
    try {
      final response = await _supabase.client
          .from('achievements_progress')
          .select()
          .eq('user_id', userId);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('⚠️ Error fetching achievements: $e');
      return [];
    }
  }

  /// Fetch streak data
  Future<Map<String, dynamic>?> _fetchStreakData(String userId) async {
    try {
      return await _supabase.getStreak(userId);
    } catch (e) {
      debugPrint('⚠️ Error fetching streak data: $e');
      return null;
    }
  }

  /// Fetch daily nutrition summaries
  Future<List<Map<String, dynamic>>> _fetchDailySummaries(String userId) async {
    try {
      final response = await _supabase.client
          .from('daily_nutrition_summary')
          .select()
          .eq('user_id', userId)
          .order('date', ascending: false)
          .limit(90); // Last 90 days
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('⚠️ Error fetching daily summaries: $e');
      return [];
    }
  }

  /// Calculate statistics from data
  Map<String, dynamic> _calculateStatistics({
    required List<Map<String, dynamic>> nutritionEntries,
    required List<Map<String, dynamic>> workoutSessions,
    required List<Map<String, dynamic>> weightEntries,
  }) {
    // Total records
    final totalRecords = nutritionEntries.length + 
                         workoutSessions.length + 
                         weightEntries.length;

    // Date range
    DateTime? firstEntry;
    DateTime? lastEntry;

    if (nutritionEntries.isNotEmpty) {
      final dates = nutritionEntries
          .map((e) => DateTime.parse(e['created_at']))
          .toList()..sort();
      firstEntry = dates.first;
      lastEntry = dates.last;
    }

    // Total calories tracked
    final totalCalories = nutritionEntries.fold<int>(
      0,
      (sum, entry) => sum + (entry['calories'] as int? ?? 0),
    );

    // Total workouts
    final totalWorkouts = workoutSessions.length;

    // Weight change
    double? weightChange;
    if (weightEntries.length >= 2) {
      final sortedWeights = weightEntries.toList()
        ..sort((a, b) => DateTime.parse(a['date'])
            .compareTo(DateTime.parse(b['date'])));
      final firstWeight = sortedWeights.first['weight'] as num?;
      final lastWeight = sortedWeights.last['weight'] as num?;
      if (firstWeight != null && lastWeight != null) {
        weightChange = lastWeight.toDouble() - firstWeight.toDouble();
      }
    }

    return {
      'total_records': totalRecords,
      'first_entry_date': firstEntry?.toIso8601String(),
      'last_entry_date': lastEntry?.toIso8601String(),
      'days_of_data': firstEntry != null && lastEntry != null
          ? lastEntry.difference(firstEntry).inDays
          : 0,
      'total_calories_tracked': totalCalories,
      'total_workouts': totalWorkouts,
      'weight_change_kg': weightChange?.toStringAsFixed(2),
      'nutrition_entries_count': nutritionEntries.length,
      'workout_sessions_count': workoutSessions.length,
      'weight_entries_count': weightEntries.length,
    };
  }
}
