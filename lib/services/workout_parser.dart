import 'dart:convert';
import '../models/workout_template.dart';

class WorkoutParser {
  static final WorkoutParser _instance = WorkoutParser._internal();
  factory WorkoutParser() => _instance;
  WorkoutParser._internal();

  /// Parse AI response and return WorkoutTemplate if valid JSON workout
  /// Returns null if response is not a workout JSON
  WorkoutTemplate? parseWorkoutResponse(String response, String userId) {
    try {
      // Try to parse as JSON
      final jsonData = jsonDecode(response.trim());

      // Validate required fields
      if (!_isValidWorkoutJson(jsonData)) {
        print('❌ Invalid workout JSON structure');
        return null;
      }

      // Parse exercises
      final exercisesList = <TemplateExercise>[];
      final exercises = jsonData['exercises'] as List;

      for (final exerciseJson in exercises) {
        try {
          exercisesList.add(TemplateExercise.fromJson(exerciseJson as Map<String, dynamic>));
        } catch (e) {
          print('⚠️ Skipping invalid exercise: $e');
          continue;
        }
      }

      if (exercisesList.isEmpty) {
        print('❌ No valid exercises found in workout');
        return null;
      }

      // Create WorkoutTemplate from parsed data
      final template = WorkoutTemplate(
        id: '', // Will be assigned by database
        userId: userId,
        name: _generateWorkoutName(jsonData),
        description: _generateWorkoutDescription(jsonData),
        workoutType: jsonData['workout_type'] as String?,
        estimatedDurationMinutes: jsonData['estimated_duration_minutes'] as int?,
        equipmentNeeded: _parseEquipmentNeeded(jsonData),
        difficultyLevel: jsonData['difficulty_level'] as String?,
        exercises: exercisesList,
        source: 'ai',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      print('✅ Successfully parsed workout: ${template.name} with ${template.exercises.length} exercises');
      return template;

    } on FormatException catch (e) {
      // Not JSON - this is fine, it's a regular chat response
      print('ℹ️ Response is not JSON (regular chat): $e');
      return null;
    } catch (e) {
      // Error parsing workout
      print('❌ Error parsing workout: $e');
      return null;
    }
  }

  /// Validate if JSON has required workout fields
  bool _isValidWorkoutJson(dynamic json) {
    if (json is! Map<String, dynamic>) return false;

    // Check required fields
    if (!json.containsKey('exercises')) return false;
    if (json['exercises'] is! List) return false;
    if ((json['exercises'] as List).isEmpty) return false;

    // Validate first exercise has required fields
    final firstExercise = json['exercises'][0];
    if (firstExercise is! Map<String, dynamic>) return false;

    final requiredExerciseFields = ['name', 'sets', 'reps'];
    for (final field in requiredExerciseFields) {
      if (!firstExercise.containsKey(field)) return false;
    }

    return true;
  }

  /// Generate workout name from JSON data
  String _generateWorkoutName(Map<String, dynamic> json) {
    final workoutType = json['workout_type'] as String?;
    final duration = json['estimated_duration_minutes'] as int?;

    if (workoutType != null && duration != null) {
      return '$workoutType Workout ($duration min)';
    } else if (workoutType != null) {
      return '$workoutType Workout';
    } else if (duration != null) {
      return '$duration Minute Workout';
    } else {
      return 'AI Generated Workout';
    }
  }

  /// Generate workout description from JSON data
  String _generateWorkoutDescription(Map<String, dynamic> json) {
    final exercises = json['exercises'] as List;
    final exerciseCount = exercises.length;
    final difficulty = json['difficulty_level'] as String?;
    final equipment = _parseEquipmentNeeded(json);

    final parts = <String>[];

    if (difficulty != null) {
      parts.add(difficulty);
    }

    parts.add('$exerciseCount exercises');

    if (equipment.isNotEmpty) {
      if (equipment.length == 1 && equipment.first.toLowerCase() == 'bodyweight') {
        parts.add('no equipment needed');
      } else {
        parts.add('${equipment.join(", ")} required');
      }
    }

    return parts.join(' • ');
  }

  /// Parse equipment needed list
  List<String> _parseEquipmentNeeded(Map<String, dynamic> json) {
    if (!json.containsKey('equipment_needed')) return ['Bodyweight'];

    final equipment = json['equipment_needed'];
    if (equipment is List) {
      return equipment.map((e) => e.toString()).toList();
    } else if (equipment is String) {
      return [equipment];
    }

    return ['Bodyweight'];
  }

  /// Try to clean and parse malformed JSON
  /// Sometimes AI adds extra text before/after JSON
  WorkoutTemplate? parseWithCleaning(String response, String userId) {
    try {
      // Try direct parse first
      final direct = parseWorkoutResponse(response, userId);
      if (direct != null) return direct;

      // Try to extract JSON from markdown code blocks
      final codeBlockPattern = RegExp(r'```(?:json)?\s*(\{[\s\S]*?\})\s*```');
      final match = codeBlockPattern.firstMatch(response);
      if (match != null) {
        final jsonStr = match.group(1)!;
        return parseWorkoutResponse(jsonStr, userId);
      }

      // Try to find JSON object in text
      final jsonPattern = RegExp(r'\{[\s\S]*"exercises"[\s\S]*\}');
      final jsonMatch = jsonPattern.firstMatch(response);
      if (jsonMatch != null) {
        final jsonStr = jsonMatch.group(0)!;
        return parseWorkoutResponse(jsonStr, userId);
      }

      print('⚠️ Could not extract valid JSON from response');
      return null;

    } catch (e) {
      print('❌ Error in parseWithCleaning: $e');
      return null;
    }
  }

  /// Quick check if response looks like a workout JSON
  bool looksLikeWorkoutJson(String response) {
    final trimmed = response.trim();
    // Check if starts with { and contains "exercises"
    return (trimmed.startsWith('{') || trimmed.startsWith('```')) &&
           trimmed.contains('"exercises"');
  }
}
