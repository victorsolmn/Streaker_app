import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/weight_model.dart';
import 'package:intl/intl.dart';

class WeightProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  WeightProgress? _weightProgress;
  bool _isLoading = false;
  String? _error;
  List<WeightEntry> _entries = [];

  // Cache management
  DateTime? _lastFetchTime;
  static const Duration _cacheValidity = Duration(minutes: 5);

  // Getters
  WeightProgress? get weightProgress => _weightProgress;
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<WeightEntry> get entries => _entries;

  bool get hasData => _weightProgress != null;

  // Calculate trend (weight change per week)
  double? get weeklyTrend {
    if (_entries.length < 2) return null;

    final sortedEntries = List<WeightEntry>.from(_entries)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    // Get entries from last 30 days for trend calculation
    final thirtyDaysAgo = DateTime.now().subtract(Duration(days: 30));
    final recentEntries = sortedEntries.where((e) => e.timestamp.isAfter(thirtyDaysAgo)).toList();

    if (recentEntries.length < 2) return null;

    final firstEntry = recentEntries.first;
    final lastEntry = recentEntries.last;
    final daysDiff = lastEntry.timestamp.difference(firstEntry.timestamp).inDays;

    if (daysDiff == 0) return null;

    final weightChange = lastEntry.weight - firstEntry.weight;
    final weeklyChange = (weightChange / daysDiff) * 7;

    return weeklyChange;
  }

  // Check if cache is still valid
  bool get _isCacheValid {
    if (_lastFetchTime == null) return false;
    return DateTime.now().difference(_lastFetchTime!) < _cacheValidity;
  }

  /// Load weight data from Supabase
  Future<void> loadWeightData({bool forceRefresh = false}) async {
    // Use cache if valid and not forcing refresh
    if (!forceRefresh && _isCacheValid && _weightProgress != null) {
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not logged in');
      }

      // Load weight entries (handle table not existing)
      List<dynamic> entriesResponse = [];
      try {
        entriesResponse = await _supabase
            .from('weight_entries')
            .select()
            .eq('user_id', userId)
            .order('timestamp', ascending: false);
      } catch (e) {
        // Table might not exist yet, continue with empty entries
        debugPrint('weight_entries table not found or error: $e');
        entriesResponse = [];
      }

      if (entriesResponse is List) {
        _entries = entriesResponse
            .map((e) => WeightEntry.fromJson(e))
            .toList();
      }

      // Load user profile for current weight and targets
      // Only select columns that exist in the database
      final profileResponse = await _supabase
          .from('profiles')
          .select('weight, target_weight')
          .eq('id', userId)  // Changed from 'user_id' to 'id' to match your table structure
          .single();

      if (profileResponse != null) {
        // Handle weight conversion - it might be string or number
        double currentWeight = 0.0;
        if (profileResponse['weight'] != null) {
          if (profileResponse['weight'] is String) {
            currentWeight = double.tryParse(profileResponse['weight']) ?? 0.0;
          } else {
            currentWeight = profileResponse['weight'].toDouble();
          }
        }

        double targetWeight = 0.0;
        if (profileResponse['target_weight'] != null) {
          if (profileResponse['target_weight'] is String) {
            targetWeight = double.tryParse(profileResponse['target_weight']) ?? 0.0;
          } else {
            targetWeight = profileResponse['target_weight'].toDouble();
          }
        }
        // Default to kg since weight_unit column doesn't exist yet
        final unit = 'kg';

        // If no entries but we have current weight, create a synthetic entry for display
        if (_entries.isEmpty && currentWeight > 0) {
          _entries = [
            WeightEntry(
              id: 'profile-weight',
              userId: userId,
              weight: currentWeight,
              timestamp: DateTime.now(),
              note: 'Current weight from profile',
            ),
          ];
        }

        // Get start weight (first entry or current weight)
        final startWeight = _entries.isNotEmpty
            ? _entries.last.weight
            : currentWeight;

        _weightProgress = WeightProgress(
          startWeight: startWeight,
          currentWeight: currentWeight,
          targetWeight: targetWeight,
          entries: _entries,
          unit: unit,
        );

        _lastFetchTime = DateTime.now();
        _error = null; // Clear any previous error since we have data
      }

    } catch (e) {
      // Only set error if we don't have any weight progress data
      if (_weightProgress == null) {
        _error = 'Failed to load weight data: ${e.toString()}';
      }
      debugPrint('Error loading weight data: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Add a new weight entry
  Future<bool> addWeightEntry(double weight, {String? note}) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        _error = 'User not logged in';
        notifyListeners();
        return false;
      }

      // Check if weight is valid
      if (weight <= 0 || weight > 500) {
        _error = 'Please enter a valid weight between 1 and 500';
        notifyListeners();
        return false;
      }

      // Create new entry
      final timestamp = DateTime.now();

      // Insert into Supabase
      final response = await _supabase
          .from('weight_entries')
          .insert({
            'user_id': userId,
            'weight': weight,
            'timestamp': timestamp.toIso8601String(),
            'note': note,
          })
          .select()
          .single();

      if (response != null) {
        // Add to local list
        final newEntry = WeightEntry.fromJson(response);
        _entries.insert(0, newEntry);

        // Update weight progress
        if (_weightProgress != null) {
          _weightProgress = _weightProgress!.copyWith(
            currentWeight: weight,
            entries: _entries,
          );
        }

        // Update profile weight (the trigger should handle this, but we do it for immediate UI update)
        await _supabase
            .from('profiles')
            .update({
              'weight': weight,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', userId);

        notifyListeners();
        return true;
      }

      return false;
    } catch (e) {
      _error = 'Failed to add weight entry: ${e.toString()}';
      debugPrint('Error adding weight entry: $e');
      notifyListeners();
      return false;
    }
  }

  /// Delete a weight entry
  Future<bool> deleteWeightEntry(String entryId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        _error = 'User not logged in';
        notifyListeners();
        return false;
      }

      // Delete from Supabase
      await _supabase
          .from('weight_entries')
          .delete()
          .eq('id', entryId)
          .eq('user_id', userId);

      // Remove from local list
      _entries.removeWhere((e) => e.id == entryId);

      // Update weight progress
      if (_weightProgress != null) {
        // If we deleted the latest entry, update current weight to the next latest
        if (_entries.isNotEmpty) {
          final sortedEntries = List<WeightEntry>.from(_entries)
            ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

          final latestWeight = sortedEntries.first.weight;

          _weightProgress = _weightProgress!.copyWith(
            currentWeight: latestWeight,
            entries: _entries,
          );

          // Update profile weight
          await _supabase
              .from('profiles')
              .update({
                'weight': latestWeight,
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('id', userId);
        }
      }

      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to delete weight entry: ${e.toString()}';
      debugPrint('Error deleting weight entry: $e');
      notifyListeners();
      return false;
    }
  }

  /// Update weight unit preference
  Future<bool> updateWeightUnit(String unit) async {
    if (unit != 'kg' && unit != 'lbs') {
      _error = 'Invalid weight unit';
      notifyListeners();
      return false;
    }

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        _error = 'User not logged in';
        notifyListeners();
        return false;
      }

      // Skip updating weight_unit since column doesn't exist
      // Just update locally
      // await _supabase
      //     .from('profiles')
      //     .update({
      //       'weight_unit': unit,
      //       'updated_at': DateTime.now().toIso8601String(),
      //     })
      //     .eq('user_id', userId);

      if (_weightProgress != null) {
        _weightProgress = _weightProgress!.copyWith(unit: unit);
      }

      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to update weight unit: ${e.toString()}';
      debugPrint('Error updating weight unit: $e');
      notifyListeners();
      return false;
    }
  }

  /// Update target weight
  Future<bool> updateTargetWeight(double targetWeight) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        _error = 'User not logged in';
        notifyListeners();
        return false;
      }

      if (targetWeight <= 0 || targetWeight > 500) {
        _error = 'Please enter a valid target weight between 1 and 500';
        notifyListeners();
        return false;
      }

      await _supabase
          .from('profiles')
          .update({
            'target_weight': targetWeight,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', userId);

      if (_weightProgress != null) {
        _weightProgress = _weightProgress!.copyWith(targetWeight: targetWeight);
      }

      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to update target weight: ${e.toString()}';
      debugPrint('Error updating target weight: $e');
      notifyListeners();
      return false;
    }
  }

  /// Get weight entries for a specific date range
  List<WeightEntry> getEntriesForDateRange(DateTime start, DateTime end) {
    return _entries.where((entry) {
      return entry.timestamp.isAfter(start) && entry.timestamp.isBefore(end);
    }).toList();
  }

  /// Calculate average weight for a given period
  double? getAverageWeight({int days = 7}) {
    final startDate = DateTime.now().subtract(Duration(days: days));
    final recentEntries = getEntriesForDateRange(startDate, DateTime.now());

    if (recentEntries.isEmpty) return null;

    final sum = recentEntries.fold<double>(0, (sum, entry) => sum + entry.weight);
    return sum / recentEntries.length;
  }

  /// Project goal achievement date based on current trend
  DateTime? getProjectedGoalDate() {
    if (_weightProgress == null || weeklyTrend == null) return null;

    final currentWeight = _weightProgress!.currentWeight;
    final targetWeight = _weightProgress!.targetWeight;
    final trend = weeklyTrend!;

    // Can't project if trend is going wrong direction
    if (currentWeight > targetWeight && trend >= 0) return null;
    if (currentWeight < targetWeight && trend <= 0) return null;

    final weightToChange = (targetWeight - currentWeight).abs();
    final weeklyChangeAbs = trend.abs();

    if (weeklyChangeAbs == 0) return null;

    final weeksNeeded = weightToChange / weeklyChangeAbs;
    return DateTime.now().add(Duration(days: (weeksNeeded * 7).round()));
  }

  /// Clear all data
  void clear() {
    _weightProgress = null;
    _entries.clear();
    _error = null;
    _lastFetchTime = null;
    notifyListeners();
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}