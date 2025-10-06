import 'package:flutter/material.dart';
import 'package:health/health.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  print('🔍 ===== HEALTH SYNC TEST STARTED =====');
  print('📅 Testing date: ${DateTime.now()}');

  final health = Health();

  // Define types to fetch
  final types = [
    HealthDataType.STEPS,
    HealthDataType.HEART_RATE,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.DISTANCE_WALKING_RUNNING,
    HealthDataType.SLEEP_IN_BED,
    HealthDataType.WATER,
  ];

  // Request permissions
  print('\n📱 REQUESTING PERMISSIONS...');
  bool hasPermissions = await health.hasPermissions(types) ?? false;
  print('Has permissions: $hasPermissions');

  if (!hasPermissions) {
    bool requested = await health.requestAuthorization(types);
    print('Authorization result: $requested');
  }

  // Define time range
  final now = DateTime.now();
  final midnight = DateTime(now.year, now.month, now.day);
  final yesterday = midnight.subtract(Duration(days: 1));

  print('\n⏰ TIME RANGE:');
  print('Start: $yesterday');
  print('End: $now');

  // Fetch each metric individually
  print('\n📊 ===== FETCHING HEALTH DATA =====\n');

  // STEPS
  try {
    print('👟 STEPS DATA:');
    print('Request: getHealthDataFromTypes(STEPS, $midnight - $now)');
    List<HealthDataPoint> stepsData = await health.getHealthDataFromTypes(
      types: [HealthDataType.STEPS],
      startTime: midnight,
      endTime: now,
    );

    print('Response: ${stepsData.length} data points');
    int totalSteps = 0;
    for (var point in stepsData) {
      if (point.value is NumericHealthValue) {
        int value = (point.value as NumericHealthValue).numericValue.toInt();
        totalSteps += value;
        print('  - ${point.dateFrom}: $value steps (source: ${point.sourceName})');
      }
    }
    print('TOTAL STEPS TODAY: $totalSteps\n');
  } catch (e) {
    print('ERROR fetching steps: $e\n');
  }

  // HEART RATE
  try {
    print('❤️ HEART RATE DATA:');
    print('Request: getHealthDataFromTypes(HEART_RATE, last 24 hours)');
    List<HealthDataPoint> heartData = await health.getHealthDataFromTypes(
      types: [HealthDataType.HEART_RATE],
      startTime: yesterday,
      endTime: now,
    );

    print('Response: ${heartData.length} data points');
    if (heartData.isNotEmpty) {
      heartData.sort((a, b) => b.dateFrom.compareTo(a.dateFrom));
      for (int i = 0; i < (heartData.length < 5 ? heartData.length : 5); i++) {
        var point = heartData[i];
        if (point.value is NumericHealthValue) {
          int value = (point.value as NumericHealthValue).numericValue.toInt();
          print('  - ${point.dateFrom}: $value bpm (source: ${point.sourceName})');
        }
      }

      // Calculate resting heart rate (lowest 10% of readings)
      List<int> allRates = [];
      for (var point in heartData) {
        if (point.value is NumericHealthValue) {
          allRates.add((point.value as NumericHealthValue).numericValue.toInt());
        }
      }
      if (allRates.isNotEmpty) {
        allRates.sort();
        int tenPercent = (allRates.length * 0.1).ceil();
        double restingSum = 0;
        for (int i = 0; i < tenPercent; i++) {
          restingSum += allRates[i];
        }
        int restingHR = (restingSum / tenPercent).round();
        print('RESTING HEART RATE (lowest 10%): $restingHR bpm');
      }
    } else {
      print('No heart rate data found');
    }
    print('');
  } catch (e) {
    print('ERROR fetching heart rate: $e\n');
  }

  // CALORIES
  try {
    print('🔥 CALORIES DATA:');
    print('Request: getHealthDataFromTypes(ACTIVE_ENERGY_BURNED, $midnight - $now)');
    List<HealthDataPoint> caloriesData = await health.getHealthDataFromTypes(
      types: [HealthDataType.ACTIVE_ENERGY_BURNED],
      startTime: midnight,
      endTime: now,
    );

    print('Response: ${caloriesData.length} data points');
    double totalCalories = 0;
    for (var point in caloriesData) {
      if (point.value is NumericHealthValue) {
        double value = (point.value as NumericHealthValue).numericValue.toDouble();
        totalCalories += value;
        print('  - ${point.dateFrom}: ${value.toStringAsFixed(1)} kcal (source: ${point.sourceName})');
        if (caloriesData.length > 10 && caloriesData.indexOf(point) > 5) {
          print('  ... (${caloriesData.length - 6} more entries)');
          break;
        }
      }
    }
    print('TOTAL CALORIES BURNED TODAY: ${totalCalories.toStringAsFixed(0)} kcal\n');
  } catch (e) {
    print('ERROR fetching calories: $e\n');
  }

  // SLEEP
  try {
    print('😴 SLEEP DATA:');
    print('Request: getHealthDataFromTypes(SLEEP_IN_BED, last 24 hours)');
    List<HealthDataPoint> sleepData = await health.getHealthDataFromTypes(
      types: [HealthDataType.SLEEP_IN_BED],
      startTime: yesterday,
      endTime: now,
    );

    print('Response: ${sleepData.length} data points');
    double totalSleep = 0;
    for (var point in sleepData) {
      if (point.value is NumericHealthValue) {
        double value = (point.value as NumericHealthValue).numericValue.toDouble();
        Duration sleepDuration = point.dateTo.difference(point.dateFrom);
        double hours = sleepDuration.inMinutes / 60.0;
        print('  - ${point.dateFrom} to ${point.dateTo}: ${hours.toStringAsFixed(1)} hours (source: ${point.sourceName})');
        totalSleep += hours;
      }
    }
    print('TOTAL SLEEP: ${totalSleep.toStringAsFixed(1)} hours\n');
  } catch (e) {
    print('ERROR fetching sleep: $e\n');
  }

  // WATER
  try {
    print('💧 WATER DATA:');
    print('Request: getHealthDataFromTypes(WATER, $midnight - $now)');
    List<HealthDataPoint> waterData = await health.getHealthDataFromTypes(
      types: [HealthDataType.WATER],
      startTime: midnight,
      endTime: now,
    );

    print('Response: ${waterData.length} data points');
    double totalWater = 0;
    for (var point in waterData) {
      if (point.value is NumericHealthValue) {
        double value = (point.value as NumericHealthValue).numericValue.toDouble();
        totalWater += value;
        print('  - ${point.dateFrom}: ${value.toStringAsFixed(0)} ml (source: ${point.sourceName})');
      }
    }
    print('TOTAL WATER TODAY: ${totalWater.toStringAsFixed(0)} ml\n');
  } catch (e) {
    print('ERROR fetching water: $e\n');
  }

  // DISTANCE
  try {
    print('📏 DISTANCE DATA:');
    print('Request: getHealthDataFromTypes(DISTANCE_WALKING_RUNNING, $midnight - $now)');
    List<HealthDataPoint> distanceData = await health.getHealthDataFromTypes(
      types: [HealthDataType.DISTANCE_WALKING_RUNNING],
      startTime: midnight,
      endTime: now,
    );

    print('Response: ${distanceData.length} data points');
    double totalDistance = 0;
    for (var point in distanceData) {
      if (point.value is NumericHealthValue) {
        double value = (point.value as NumericHealthValue).numericValue.toDouble();
        totalDistance += value;
        print('  - ${point.dateFrom}: ${value.toStringAsFixed(0)} meters (source: ${point.sourceName})');
        if (distanceData.length > 10 && distanceData.indexOf(point) > 5) {
          print('  ... (${distanceData.length - 6} more entries)');
          break;
        }
      }
    }
    print('TOTAL DISTANCE TODAY: ${(totalDistance/1000).toStringAsFixed(2)} km\n');
  } catch (e) {
    print('ERROR fetching distance: $e\n');
  }

  print('===== TEST COMPLETED =====');
}