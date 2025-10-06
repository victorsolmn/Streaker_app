import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:convert';
import 'lib/services/health_log_capture_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  print('\n🚀 Starting Health Data Log Capture...\n');

  try {
    // Capture and save the health logs
    final result = await HealthLogCaptureService.captureAndSaveHealthLogs();

    // Print the analysis summary
    await HealthLogCaptureService.printLogSummary(result);

    if (result['success']) {
      print('\n✅ SUCCESS! Health data logs have been captured.');
      print('\n📌 Next Steps:');
      print('1. Open the log file: ${result['filePath']}');
      print('2. Look for "calorieData" section');
      print('3. Check "activeCaloriesRecords" vs "totalCaloriesRecords"');
      print('4. Identify which data Samsung Health is providing');
      print('5. Review the "dataOrigin" field to confirm source');

      // Also save to desktop if we're on a desktop platform
      if (Platform.isMacOS || Platform.isLinux || Platform.isWindows) {
        final desktopPath = '${Platform.environment['HOME']}/Desktop';
        final fileName = 'health_data_logs.json';
        final desktopFile = File('$desktopPath/$fileName');

        // Read the original file
        final originalFile = File(result['filePath']);
        if (await originalFile.exists()) {
          final content = await originalFile.readAsString();
          await desktopFile.writeAsString(content);
          print('\n📁 Also saved to Desktop: $desktopPath/$fileName');
        }
      }
    } else {
      print('\n❌ Failed to capture logs: ${result['error']}');
      print('\nTroubleshooting:');
      print('1. Make sure the app is running on an Android device');
      print('2. Ensure Health Connect permissions are granted');
      print('3. Check that Samsung Health has data for today');
    }
  } catch (e) {
    print('\n❌ Error: $e');
    print('\nThis script needs to be run as part of the Flutter app.');
    print('To capture logs:');
    print('1. Add a button in your app that calls HealthLogCaptureService.captureAndSaveHealthLogs()');
    print('2. Run the app on your Android device');
    print('3. Tap the button to capture logs');
  }

  exit(0);
}