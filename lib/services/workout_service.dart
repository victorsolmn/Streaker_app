import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/workout_session.dart';
import '../models/workout_set.dart';
import '../models/workout_template.dart';

class WorkoutService {
  static final WorkoutService _instance = WorkoutService._internal();
  factory WorkoutService() => _instance;
  WorkoutService._internal();

  final _supabase = Supabase.instance.client;

  // ============================================================================
  // WORKOUT TEMPLATES
  // ============================================================================

  /// Save a workout template
  Future<WorkoutTemplate> saveTemplate(WorkoutTemplate template) async {
    try {
      print('💾 Saving workout template: ${template.name}');

      final response = await _supabase
          .from('workout_templates')
          .insert(template.toInsertJson())
          .select()
          .single();

      final savedTemplate = WorkoutTemplate.fromJson(response);
      print('✅ Template saved successfully: ${savedTemplate.id}');
      return savedTemplate;
    } catch (e) {
      print('❌ Error saving template: $e');
      throw Exception('Failed to save workout template: $e');
    }
  }

  /// Get all templates for a user
  Future<List<WorkoutTemplate>> getUserTemplates(String userId) async {
    try {
      print('📥 Fetching templates for user: $userId');

      final response = await _supabase
          .from('workout_templates')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final templates = (response as List)
          .map((json) => WorkoutTemplate.fromJson(json))
          .toList();

      print('✅ Fetched ${templates.length} templates');
      return templates;
    } catch (e) {
      print('❌ Error fetching templates: $e');
      return [];
    }
  }

  /// Get favorite templates
  Future<List<WorkoutTemplate>> getFavoriteTemplates(String userId) async {
    try {
      final response = await _supabase
          .from('workout_templates')
          .select()
          .eq('user_id', userId)
          .eq('is_favorite', true)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => WorkoutTemplate.fromJson(json))
          .toList();
    } catch (e) {
      print('❌ Error fetching favorite templates: $e');
      return [];
    }
  }

  /// Update template (toggle favorite, edit name, etc.)
  Future<void> updateTemplate(String templateId, Map<String, dynamic> updates) async {
    try {
      await _supabase
          .from('workout_templates')
          .update(updates)
          .eq('id', templateId);

      print('✅ Template updated: $templateId');
    } catch (e) {
      print('❌ Error updating template: $e');
      throw Exception('Failed to update template: $e');
    }
  }

  /// Delete template
  Future<void> deleteTemplate(String templateId) async {
    try {
      await _supabase
          .from('workout_templates')
          .delete()
          .eq('id', templateId);

      print('✅ Template deleted: $templateId');
    } catch (e) {
      print('❌ Error deleting template: $e');
      throw Exception('Failed to delete template: $e');
    }
  }

  /// Toggle favorite status
  Future<void> toggleFavorite(String templateId, bool isFavorite) async {
    await updateTemplate(templateId, {'is_favorite': !isFavorite});
  }

  // ============================================================================
  // WORKOUT SESSIONS
  // ============================================================================

  /// Create a new workout session
  Future<WorkoutSession> createSession(WorkoutSession session) async {
    try {
      print('💾 Creating workout session: ${session.workoutName}');

      final response = await _supabase
          .from('workout_sessions')
          .insert(session.toInsertJson())
          .select()
          .single();

      final savedSession = WorkoutSession.fromJson(response);
      print('✅ Session created: ${savedSession.id}');
      return savedSession;
    } catch (e) {
      print('❌ Error creating session: $e');
      throw Exception('Failed to create workout session: $e');
    }
  }

  /// Get workout sessions for a user
  Future<List<WorkoutSession>> getUserSessions(String userId, {int limit = 20}) async {
    try {
      print('📥 Fetching sessions for user: $userId');

      final response = await _supabase
          .from('workout_sessions')
          .select()
          .eq('user_id', userId)
          .order('completed_at', ascending: false)
          .limit(limit);

      final sessions = (response as List)
          .map((json) => WorkoutSession.fromJson(json))
          .toList();

      print('✅ Fetched ${sessions.length} sessions');
      return sessions;
    } catch (e) {
      print('❌ Error fetching sessions: $e');
      return [];
    }
  }

  /// Get sessions for a specific date range
  Future<List<WorkoutSession>> getSessionsByDateRange(
    String userId,
    DateTime start,
    DateTime end,
  ) async {
    try {
      final response = await _supabase
          .from('workout_sessions')
          .select()
          .eq('user_id', userId)
          .gte('completed_at', start.toIso8601String())
          .lte('completed_at', end.toIso8601String())
          .order('completed_at', ascending: false);

      return (response as List)
          .map((json) => WorkoutSession.fromJson(json))
          .toList();
    } catch (e) {
      print('❌ Error fetching sessions by date: $e');
      return [];
    }
  }

  /// Get a single session with its sets
  Future<WorkoutSession?> getSessionWithSets(String sessionId) async {
    try {
      // Get session
      final sessionResponse = await _supabase
          .from('workout_sessions')
          .select()
          .eq('id', sessionId)
          .single();

      final session = WorkoutSession.fromJson(sessionResponse);

      // Get sets for this session
      final sets = await getSessionSets(sessionId);

      // Return session with sets
      return session.copyWith(sets: sets);
    } catch (e) {
      print('❌ Error fetching session with sets: $e');
      return null;
    }
  }

  /// Delete a workout session (and all its sets - cascade delete)
  Future<void> deleteSession(String sessionId) async {
    try {
      await _supabase
          .from('workout_sessions')
          .delete()
          .eq('id', sessionId);

      print('✅ Session deleted: $sessionId');
    } catch (e) {
      print('❌ Error deleting session: $e');
      throw Exception('Failed to delete session: $e');
    }
  }

  // ============================================================================
  // WORKOUT SETS
  // ============================================================================

  /// Save workout sets (batch insert)
  Future<List<WorkoutSet>> saveSets(List<WorkoutSet> sets) async {
    try {
      print('💾 Saving ${sets.length} workout sets');

      final inserts = sets.map((set) => set.toInsertJson()).toList();

      final response = await _supabase
          .from('workout_sets')
          .insert(inserts)
          .select();

      final savedSets = (response as List)
          .map((json) => WorkoutSet.fromJson(json))
          .toList();

      print('✅ Saved ${savedSets.length} sets');
      return savedSets;
    } catch (e) {
      print('❌ Error saving sets: $e');
      throw Exception('Failed to save workout sets: $e');
    }
  }

  /// Save a single set
  Future<WorkoutSet> saveSet(WorkoutSet set) async {
    try {
      final response = await _supabase
          .from('workout_sets')
          .insert(set.toInsertJson())
          .select()
          .single();

      return WorkoutSet.fromJson(response);
    } catch (e) {
      print('❌ Error saving set: $e');
      throw Exception('Failed to save set: $e');
    }
  }

  /// Get all sets for a session
  Future<List<WorkoutSet>> getSessionSets(String sessionId) async {
    try {
      final response = await _supabase
          .from('workout_sets')
          .select()
          .eq('session_id', sessionId)
          .order('exercise_order')
          .order('set_number');

      return (response as List)
          .map((json) => WorkoutSet.fromJson(json))
          .toList();
    } catch (e) {
      print('❌ Error fetching sets: $e');
      return [];
    }
  }

  /// Update a set (e.g., modify reps or weight)
  Future<void> updateSet(String setId, Map<String, dynamic> updates) async {
    try {
      await _supabase
          .from('workout_sets')
          .update(updates)
          .eq('id', setId);

      print('✅ Set updated: $setId');
    } catch (e) {
      print('❌ Error updating set: $e');
      throw Exception('Failed to update set: $e');
    }
  }

  /// Delete a set
  Future<void> deleteSet(String setId) async {
    try {
      await _supabase
          .from('workout_sets')
          .delete()
          .eq('id', setId);

      print('✅ Set deleted: $setId');
    } catch (e) {
      print('❌ Error deleting set: $e');
      throw Exception('Failed to delete set: $e');
    }
  }

  // ============================================================================
  // ANALYTICS & STATS
  // ============================================================================

  /// Get total workouts count for a user
  Future<int> getTotalWorkoutsCount(String userId) async {
    try {
      final response = await _supabase
          .from('workout_sessions')
          .select('id')
          .eq('user_id', userId) as List;

      return response.length;
    } catch (e) {
      print('❌ Error getting workouts count: $e');
      return 0;
    }
  }

  /// Get total volume lifted (all time)
  Future<double> getTotalVolume(String userId) async {
    try {
      final response = await _supabase
          .from('workout_sessions')
          .select('total_volume_kg')
          .eq('user_id', userId);

      double total = 0;
      for (final row in response) {
        total += (row['total_volume_kg'] ?? 0.0) as double;
      }

      return total;
    } catch (e) {
      print('❌ Error calculating total volume: $e');
      return 0;
    }
  }

  /// Get workout streak (consecutive days)
  Future<int> getWorkoutStreak(String userId) async {
    try {
      final sessions = await _supabase
          .from('workout_sessions')
          .select('completed_at')
          .eq('user_id', userId)
          .order('completed_at', ascending: false)
          .limit(365); // Check last year

      if (sessions.isEmpty) return 0;

      // Get unique dates
      final dates = <DateTime>{};
      for (final session in sessions) {
        final date = DateTime.parse(session['completed_at']);
        dates.add(DateTime(date.year, date.month, date.day));
      }

      final sortedDates = dates.toList()..sort((a, b) => b.compareTo(a));

      // Calculate streak
      int streak = 0;
      DateTime expectedDate = DateTime.now();
      expectedDate = DateTime(expectedDate.year, expectedDate.month, expectedDate.day);

      for (final date in sortedDates) {
        if (date.isAtSameMomentAs(expectedDate) ||
            date.isAtSameMomentAs(expectedDate.subtract(const Duration(days: 1)))) {
          streak++;
          expectedDate = date.subtract(const Duration(days: 1));
        } else {
          break;
        }
      }

      return streak;
    } catch (e) {
      print('❌ Error calculating workout streak: $e');
      return 0;
    }
  }

  /// Get most used exercises
  Future<Map<String, int>> getMostUsedExercises(String userId, {int limit = 10}) async {
    try {
      // Get all sessions for user
      final sessions = await getUserSessions(userId, limit: 100);
      final sessionIds = sessions.map((s) => s.id).toList();

      if (sessionIds.isEmpty) return {};

      // Get all sets for these sessions
      final response = await _supabase
          .from('workout_sets')
          .select('exercise_name')
          .inFilter('session_id', sessionIds);

      // Count exercise occurrences
      final exerciseCounts = <String, int>{};
      for (final row in response) {
        final name = row['exercise_name'] as String;
        exerciseCounts[name] = (exerciseCounts[name] ?? 0) + 1;
      }

      // Sort and limit
      final sorted = exerciseCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      return Map.fromEntries(sorted.take(limit));
    } catch (e) {
      print('❌ Error getting most used exercises: $e');
      return {};
    }
  }
}
