import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:convert';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const platform = MethodChannel('com.streaker/health_connect');

  print('\n🚀 Directly capturing Health Connect data...\n');

  try {
    // Call the native Android method to capture detailed health data logs
    final result = await platform.invokeMethod('captureHealthDataLogs');

    if (result != null && result['logData'] != null) {
      final String logData = result['logData'];
      final String summary = result['summary'] ?? 'No summary available';

      print('✅ Log capture successful!');
      print('📊 $summary\n');

      // Save to desktop
      final String desktopPath = '${Platform.environment['HOME']}/Desktop';
      final String timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0];
      final String fileName = 'health_data_logs_$timestamp.json';
      final File logFile = File('$desktopPath/$fileName');

      // Write the JSON data to file
      await logFile.writeAsString(logData);

      print('📁 Logs saved to: $desktopPath/$fileName\n');

      // Parse and display analysis
      final Map<String, dynamic> jsonData = json.decode(logData);
      final calorieData = jsonData['calorieData'];

      print('📊 CAPTURED DATA SUMMARY:');
      print('=' * 50);

      // Active Calories
      if (calorieData['activeCaloriesCount'] != null) {
        print('\n🔥 Active Calories:');
        print('   Records: ${calorieData['activeCaloriesCount']}');
        if (calorieData['activeCaloriesBySource'] != null) {
          final sources = calorieData['activeCaloriesBySource'] as Map;
          sources.forEach((source, calories) {
            final isSamsung = source.contains('shealth') || source.contains('com.sec.android');
            print('   ${isSamsung ? "⭐" : "•"} $source: ${calories.toStringAsFixed(2)} kcal');
          });
        }
      }

      // Total Calories
      if (calorieData['totalCaloriesCount'] != null) {
        print('\n💪 Total Calories:');
        print('   Records: ${calorieData['totalCaloriesCount']}');
        if (calorieData['totalCaloriesBySource'] != null) {
          final sources = calorieData['totalCaloriesBySource'] as Map;
          sources.forEach((source, calories) {
            final isSamsung = source.contains('shealth') || source.contains('com.sec.android');
            print('   ${isSamsung ? "⭐" : "•"} $source: ${calories.toStringAsFixed(2)} kcal');
          });
        }
      }

      // BMR
      if (calorieData['basalMetabolicRateCount'] != null && calorieData['basalMetabolicRateCount'] > 0) {
        print('\n🏃 BMR Records: ${calorieData['basalMetabolicRateCount']}');
      }

      // Analysis
      final analysis = jsonData['analysis'];
      if (analysis != null) {
        print('\n💡 RECOMMENDATIONS:');
        print('=' * 50);
        for (int i = 1; i <= 4; i++) {
          final rec = analysis['recommendation$i'];
          if (rec != null) {
            print('$i. $rec');
          }
        }
      }

      print('\n✅ SUCCESS! Check the log file for complete details.');

    } else {
      print('❌ Failed to capture health data logs');
      print('   No data returned from native method');
    }
  } on PlatformException catch (e) {
    print('❌ Platform error: ${e.message}');
    print('   Code: ${e.code}');
    print('   Details: ${e.details}');
  } catch (e) {
    print('❌ Error: $e');
  }

  exit(0);
}