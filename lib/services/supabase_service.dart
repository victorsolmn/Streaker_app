import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/user_model.dart';
import '../models/nutrition_model.dart';
import 'dart:convert';
import 'dart:io';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  late final SupabaseClient _supabase;
  bool _isInitialized = false;

  SupabaseClient get client => _supabase;
  User? get currentUser => _supabase.auth.currentUser;
  bool get isAuthenticated => currentUser != null;

  Future<void> initialize() async {
    if (_isInitialized) return;

    await Supabase.initialize(
      url: SupabaseConfig.supabaseUrl,
      anonKey: SupabaseConfig.supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
        autoRefreshToken: true,
      ),
    );

    _supabase = Supabase.instance.client;
    _isInitialized = true;
  }

  // Authentication Methods
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {'name': name},
        emailRedirectTo: null, // Disable email confirmation redirect
      );

      if (response.user != null) {
        // Create initial profile
        await createUserProfile(
          userId: response.user!.id,
          email: email,
          name: name,
        );
      }

      return response;
    } catch (e) {
      throw Exception('Sign up failed: $e');
    }
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return response;
    } catch (e) {
      throw Exception('Sign in failed: $e');
    }
  }

  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
    } catch (e) {
      throw Exception('Sign out failed: $e');
    }
  }

  /// Delete user account and all associated data permanently
  Future<void> deleteUserAccount() async {
    try {
      final user = currentUser;
      if (user == null) {
        throw Exception('No user logged in');
      }

      final userId = user.id;
      debugPrint('🗑️ Starting account deletion for user: $userId');

      // Delete all user data from tables (in order to avoid foreign key issues)
      await Future.wait([
        // Delete nutrition entries
        _supabase.from('nutrition_entries').delete().eq('user_id', userId),
        
        // Delete weight entries
        _supabase.from('weight_entries').delete().eq('user_id', userId),
        
        // Delete workout sessions
        _supabase.from('workout_sessions').delete().eq('user_id', userId),
        
        // Delete workout templates
        _supabase.from('workout_templates').delete().eq('user_id', userId),
        
        // Delete achievements progress
        _supabase.from('achievements_progress').delete().eq('user_id', userId),
        
        // Delete daily nutrition summary
        _supabase.from('daily_nutrition_summary').delete().eq('user_id', userId),
        
        // Delete streaks
        _supabase.from('streaks').delete().eq('user_id', userId),
        
        // Delete user devices (for push notifications)
        _supabase.from('user_devices').delete().eq('user_id', userId),
      ]);

      debugPrint('✅ All user data deleted from tables');

      // Delete profile photo from storage if exists
      try {
        final profile = await getUserProfile(userId);
        final photoUrl = profile?['photo_url'] as String?;
        if (photoUrl != null && photoUrl.isNotEmpty) {
          await deleteProfilePhoto(photoUrl);
          debugPrint('✅ Profile photo deleted from storage');
        }
      } catch (e) {
        debugPrint('⚠️ Failed to delete profile photo: $e');
        // Continue with account deletion even if photo deletion fails
      }

      // Delete profile (should be last due to foreign keys)
      await _supabase.from('profiles').delete().eq('id', userId);
      debugPrint('✅ Profile deleted');

      // Sign out the user (this effectively ends the session)
      await signOut();
      debugPrint('✅ User signed out');

      // Note: We cannot delete the user from auth.users table directly from client
      // This requires admin privileges. Options:
      // 1. Use a Supabase Edge Function with service role key
      // 2. Let the user data remain in auth.users (empty profile)
      // 3. Admin manually deletes from dashboard
      
      debugPrint('✅ Account deletion complete');
    } catch (e) {
      debugPrint('❌ Account deletion failed: $e');
      throw Exception('Failed to delete account: $e');
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(email);
    } catch (e) {
      throw Exception('Password reset failed: $e');
    }
  }

  /// Check if email already exists in Supabase auth
  /// Returns true if email exists, false if it doesn't
  Future<bool> checkEmailExists(String email) async {
    try {
      final cleanEmail = email.toLowerCase().trim();
      
      // Method 1: Check profiles table first (faster)
      final profileResponse = await _supabase
          .from('profiles')
          .select('email')
          .eq('email', cleanEmail)
          .maybeSingle();
      
      if (profileResponse != null) {
        print('Email exists in profiles: $cleanEmail');
        return true;
      }
      
      // Method 2: Try sign-in with dummy password to check auth.users table
      try {
        await _supabase.auth.signInWithPassword(
          email: cleanEmail,
          password: 'invalid_dummy_password_check_12345',
        );
        // If successful (shouldn't happen), sign out and return true
        await _supabase.auth.signOut();
        return true;
      } on AuthException catch (authError) {
        final errorMessage = authError.message.toLowerCase();
        
        // Email exists if we get invalid login credentials
        if (errorMessage.contains('invalid login credentials') ||
            errorMessage.contains('invalid password') ||
            errorMessage.contains('wrong password') ||
            errorMessage.contains('incorrect password')) {
          print('Email exists in auth.users: $cleanEmail');
          return true;
        }
        
        // Email doesn't exist if we get user not found errors
        if (errorMessage.contains('user not found') ||
            errorMessage.contains('no user found') ||
            errorMessage.contains('email not found') ||
            errorMessage.contains('user does not exist')) {
          print('Email not found: $cleanEmail');
          return false;
        }
        
        // For any other auth error, assume email doesn't exist
        print('Auth check inconclusive for $cleanEmail: ${authError.message}');
        return false;
      }
      
      // Fallback: Check in profiles table
      try {
        final profileResponse = await _supabase
            .from('profiles')
            .select('id, email')
            .eq('email', email.toLowerCase())
            .maybeSingle();
        
        if (profileResponse != null) {
          print('Email found in profiles table: $email');
          return true;
        }
      } catch (profileError) {
        print('Profile check error: $profileError');
      }
      
      // Try RPC function if available
      try {
        final response = await _supabase.rpc('check_email_exists', params: {
          'email_input': email.toLowerCase(),
        });
        if (response != null) {
          print('Email check via RPC: $response for $email');
          return response as bool;
        }
      } catch (rpcError) {
        print('RPC function not available: $rpcError');
      }
      
      print('Email not found, can proceed with signup: $email');
      return false;
    } catch (e) {
      print('Error checking email existence: $e');
      // On error, return false to allow signup to proceed
      // Supabase will handle duplicate email validation
      return false;
    }
  }

  // Nutrition Entry Methods
  Future<void> saveNutritionEntry({
    required String userId,
    required String foodName,
    required int calories,
    required double protein,
    required double carbs,
    required double fat,
    // Note: fiber and foodSource parameters REMOVED - fields don't exist in database after cleanup
    int quantityGrams = 100,
    String mealType = 'snack',
    DateTime? timestamp,
  }) async {
    try {
      final entryTimestamp = timestamp ?? DateTime.now();

      // First check if entry already exists
      final existingEntry = await _supabase
          .from('nutrition_entries')
          .select()
          .eq('user_id', userId)
          .eq('food_name', foodName)
          .gte('created_at', entryTimestamp.subtract(Duration(seconds: 5)).toIso8601String())
          .lte('created_at', entryTimestamp.add(Duration(seconds: 5)).toIso8601String())
          .maybeSingle();

      if (existingEntry != null) {
        debugPrint('Nutrition entry already exists, skipping: $foodName');
        return;
      }

      // Extract date from timestamp for the date column
      final dateStr = '${entryTimestamp.year}-${entryTimestamp.month.toString().padLeft(2, '0')}-${entryTimestamp.day.toString().padLeft(2, '0')}';

      await _supabase.from('nutrition_entries').insert({
        'user_id': userId,
        'food_name': foodName,
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
        // Note: fiber and food_source fields removed during database cleanup
        'quantity_grams': quantityGrams,
        'meal_type': mealType,
        'date': dateStr, // Required field for nutrition_entries
        'created_at': entryTimestamp.toIso8601String(),
        'updated_at': entryTimestamp.toIso8601String(),
      });
      debugPrint('✅ Nutrition entry saved to database: $foodName ($quantityGrams grams) on $dateStr');
    } catch (e) {
      debugPrint('Error saving nutrition entry: $e');
      throw e;
    }
  }

  Future<List<Map<String, dynamic>>> getNutritionHistory({
    required String userId,
    int days = 30,
  }) async {
    try {
      final startDate = DateTime.now().subtract(Duration(days: days));
      
      final response = await _supabase
          .from('nutrition_entries')
          .select()
          .eq('user_id', userId)
          .gte('created_at', startDate.toIso8601String())
          .order('created_at', ascending: false);
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error loading nutrition history: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getTodayNutritionEntries({
    required String userId,
  }) async {
    try {
      final today = DateTime.now();
      final dateStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      debugPrint('📅 Fetching nutrition entries for today: $dateStr');

      final response = await _supabase
          .from('nutrition_entries')
          .select()
          .eq('user_id', userId)
          .eq('date', dateStr)
          .order('created_at', ascending: false);

      debugPrint('✅ Found ${(response as List).length} entries for today');

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('❌ Error loading today\'s nutrition: $e');
      return [];
    }
  }

  // Get nutrition entries for a specific date (for date navigation feature)
  Future<List<Map<String, dynamic>>> getNutritionEntriesForDate({
    required String userId,
    required DateTime date,
  }) async {
    try {
      final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

      debugPrint('📅 Fetching nutrition entries for date: $dateStr');

      final response = await _supabase
          .from('nutrition_entries')
          .select()
          .eq('user_id', userId)
          .eq('date', dateStr)
          .order('created_at', ascending: false);

      debugPrint('✅ Found ${(response as List).length} entries for $dateStr');

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('❌ Error loading nutrition for date: $e');
      return [];
    }
  }

  Future<void> deleteNutritionEntry(String entryId) async {
    try {
      await _supabase.from('nutrition_entries').delete().eq('id', entryId);
      debugPrint('Nutrition entry deleted: $entryId');
    } catch (e) {
      debugPrint('Error deleting nutrition entry: $e');
      throw e;
    }
  }

  // Clear duplicate nutrition entries for a specific date
  Future<void> clearDuplicateNutritionEntries(String userId, DateTime date) async {
    try {
      final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

      // Get all entries for the date
      final response = await _supabase
          .from('nutrition_entries')
          .select()
          .eq('user_id', userId)
          .eq('date', dateStr)
          .order('created_at', ascending: false);

      final entries = response as List<dynamic>;

      if (entries.isEmpty) {
        debugPrint('No nutrition entries found for $dateStr');
        return;
      }

      // Group entries by food_name and timestamp
      final uniqueEntries = <String, dynamic>{};
      final duplicateIds = <String>[];

      for (final entry in entries) {
        final key = '${entry['food_name']}_${entry['calories']}_${entry['protein']}_${entry['carbs']}';

        if (uniqueEntries.containsKey(key)) {
          // This is a duplicate, mark for deletion
          duplicateIds.add(entry['id']);
        } else {
          // Keep the first occurrence
          uniqueEntries[key] = entry;
        }
      }

      // Delete duplicates
      if (duplicateIds.isNotEmpty) {
        for (final id in duplicateIds) {
          await _supabase.from('nutrition_entries').delete().eq('id', id);
        }
        debugPrint('Deleted ${duplicateIds.length} duplicate nutrition entries for $dateStr');
      } else {
        debugPrint('No duplicate nutrition entries found for $dateStr');
      }
    } catch (e) {
      debugPrint('Error clearing duplicate nutrition entries: $e');
      throw e;
    }
  }

  // Clear all nutrition entries for a user
  Future<void> clearAllNutritionEntries(String userId) async {
    try {
      debugPrint('Clearing all nutrition entries for user: $userId');

      // Delete all nutrition entries for the user
      final response = await _supabase
          .from('nutrition_entries')
          .delete()
          .eq('user_id', userId);

      debugPrint('✅ Successfully cleared all nutrition entries for user: $userId');
    } catch (e) {
      debugPrint('Error clearing all nutrition entries: $e');
      throw e;
    }
  }

  // User Profile Methods
  Future<void> createUserProfile({
    required String userId,
    required String email,
    required String name,
  }) async {
    try {
      // Use upsert instead of insert since the trigger already creates a basic profile
      // This will update the existing profile with the name
      await _supabase.from('profiles').upsert({
        'id': userId,
        'email': email,
        'name': name,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'id');
      print('✅ Profile upserted successfully for user: $userId');
    } catch (e) {
      print('Error upserting profile: $e');
    }
  }

  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();
      
      return response;
    } catch (e) {
      print('Error fetching profile: $e');
      return null;
    }
  }

  Future<void> updateUserProfile({
    required String userId,
    required Map<String, dynamic> updates,
  }) async {
    try {
      updates['updated_at'] = DateTime.now().toIso8601String();

      print('\n' + '=' * 60);
      print('📝 SUPABASE UPDATE REQUEST');
      print('=' * 60);
      print('🔑 User ID: $userId');
      print('📊 REQUEST DATA BEING SENT:');
      updates.forEach((key, value) {
        print('  - $key: $value (${value.runtimeType})');
      });
      print('=' * 60);

      // Attempt the update
      final response = await _supabase
          .from('profiles')
          .update(updates)
          .eq('id', userId)
          .select();

      print('\n' + '=' * 60);
      print('✅ SUPABASE RESPONSE SUCCESS');
      print('=' * 60);
      print('📊 RESPONSE DATA RECEIVED:');
      if (response != null && response is List && response.isNotEmpty) {
        final profileData = response[0];
        profileData.forEach((key, value) {
          print('  - $key: $value');
        });
      } else {
        print('  ⚠️ No response data returned');
      }
      print('=' * 60 + '\n');
    } catch (e) {
      print('\n' + '=' * 60);
      print('❌ SUPABASE UPDATE ERROR');
      print('=' * 60);
      print('🔑 User ID: $userId');
      print('📊 DATA ATTEMPTED TO SEND:');
      updates.forEach((key, value) {
        print('  - $key: $value');
      });
      print('\n🚨 ERROR DETAILS:');
      print('  Error Type: ${e.runtimeType}');
      print('  Error Message: $e');

      if (e.toString().contains('42501')) {
        print('\n⚠️ RLS POLICY VIOLATION DETECTED!');
        print('  The Row Level Security policy is blocking this update.');
        print('  This means the user does not have permission to update their profile.');
      }
      print('=' * 60 + '\n');
      throw Exception('Failed to update profile: $e');
    }
  }

  // Storage Methods for Profile Photos
  Future<String?> uploadProfilePhoto({
    required String userId,
    required String filePath,
  }) async {
    try {
      final file = File(filePath);
      final fileExtension = filePath.split('.').last;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExtension';
      final storagePath = '$userId/$fileName';

      // Upload file to Supabase storage
      // Try to upload, if file exists it will throw error so we use upsert
      await _supabase.storage
          .from('profile-photos')
          .uploadBinary(
            storagePath,
            await file.readAsBytes(),
            fileOptions: FileOptions(
              upsert: true,
              contentType: 'image/${fileExtension}',
            ),
          );

      // Get the public URL for the uploaded file
      final publicUrl = _supabase.storage
          .from('profile-photos')
          .getPublicUrl(storagePath);

      return publicUrl;
    } catch (e) {
      print('Error uploading profile photo: $e');
      throw Exception('Failed to upload profile photo: $e');
    }
  }

  Future<void> deleteProfilePhoto(String? photoUrl) async {
    if (photoUrl == null || photoUrl.isEmpty) return;

    try {
      // Extract the storage path from the URL
      final uri = Uri.parse(photoUrl);
      final pathSegments = uri.pathSegments;

      // Find the index of 'profile-photos' in the path
      final bucketIndex = pathSegments.indexOf('profile-photos');
      if (bucketIndex == -1 || bucketIndex >= pathSegments.length - 1) {
        print('Invalid photo URL format');
        return;
      }

      // Get the path after 'profile-photos'
      final storagePath = pathSegments.sublist(bucketIndex + 1).join('/');

      // Delete the file from storage
      await _supabase.storage
          .from('profile-photos')
          .remove([storagePath]);
    } catch (e) {
      // Don't throw error for deletion failures, just log it
      print('Failed to delete old profile photo: $e');
    }
  }

  Future<void> updateProfilePhoto({
    required String userId,
    required String filePath,
  }) async {
    try {
      // Get current profile to find old photo URL
      final currentProfile = await getUserProfile(userId);
      final oldPhotoUrl = currentProfile?['photo_url'] as String?;

      // Upload new photo
      final newPhotoUrl = await uploadProfilePhoto(
        userId: userId,
        filePath: filePath,
      );

      if (newPhotoUrl == null) {
        throw Exception('Failed to get photo URL after upload');
      }

      // Update profile with new photo URL
      await updateUserProfile(
        userId: userId,
        updates: {
          'photo_url': newPhotoUrl,
        },
      );

      // Delete old photo after successful update
      if (oldPhotoUrl != null && oldPhotoUrl != newPhotoUrl) {
        await deleteProfilePhoto(oldPhotoUrl);
      }
    } catch (e) {
      throw Exception('Failed to update profile photo: $e');
    }
  }


  // Note: Health metrics methods removed - app now focuses on nutrition tracking only

  // Streak Methods
  Future<void> updateStreak({
    required String userId,
    required int currentStreak,
    int? longestStreak,
  }) async {
    try {
      final updates = {
        'current_streak': currentStreak,
        'last_activity_date': DateTime.now().toIso8601String().split('T')[0],
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (longestStreak != null) {
        updates['longest_streak'] = longestStreak;
      }

      await _supabase
          .from('streaks')
          .upsert({
            'user_id': userId,
            ...updates,
          }, onConflict: 'user_id');
    } catch (e) {
      throw Exception('Failed to update streak: $e');
    }
  }

  Future<Map<String, dynamic>?> getStreak(String userId) async {
    try {
      final response = await _supabase
          .from('streaks')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      
      return response;
    } catch (e) {
      print('Error fetching streak: $e');
      return null;
    }
  }

  // Real-time subscriptions
  Stream<List<Map<String, dynamic>>> subscribeToNutrition(String userId) {
    return _supabase
        .from('nutrition_entries')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('date', ascending: false);
  }

  // Note: subscribeToHealthMetrics removed - health tracking removed from app

  // Batch operations
  Future<void> syncOfflineData({
    required String userId,
    required List<Map<String, dynamic>> nutritionEntries,
  }) async {
    try {
      // Batch insert nutrition entries
      if (nutritionEntries.isNotEmpty) {
        await _supabase.from('nutrition_entries').upsert(
          nutritionEntries.map((entry) => {
            'user_id': userId,
            ...entry,
          }).toList(),
          onConflict: 'user_id,date',
        );
      }
      // Note: Health metrics batch sync removed - app now focuses on nutrition tracking only
    } catch (e) {
      throw Exception('Failed to sync offline data: $e');
    }
  }

  // Helper method to check connection
  Future<bool> isConnected() async {
    try {
      await _supabase.from('profiles').select().limit(1);
      return true;
    } catch (e) {
      return false;
    }
  }
}