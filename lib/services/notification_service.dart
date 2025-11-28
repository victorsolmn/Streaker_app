import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:io' show Platform;
import 'supabase_service.dart';

/// Top-level function to handle background messages
/// Must be a top-level function or static method
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('📬 Background message received: ${message.messageId}');
  debugPrint('Title: ${message.notification?.title}');
  debugPrint('Body: ${message.notification?.body}');

  // Handle the notification data
  if (message.data.isNotEmpty) {
    debugPrint('Data: ${message.data}');
  }
}

/// Notification Service for Firebase Cloud Messaging integration
/// Handles push notifications, local notifications, and FCM token management
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  String? _fcmToken;
  bool _isInitialized = false;

  /// Get the current FCM token
  String? get fcmToken => _fcmToken;

  /// Check if the service is initialized
  bool get isInitialized => _isInitialized;

  /// Initialize the notification service
  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('⚠️ NotificationService already initialized');
      return;
    }

    try {
      // Request notification permissions (iOS)
      await _requestPermissions();

      // Initialize local notifications
      await _initializeLocalNotifications();

      // Set up background message handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Get and store FCM token
      await _getFCMToken();

      // Listen to token refresh
      _firebaseMessaging.onTokenRefresh.listen((newToken) {
        debugPrint('🔄 FCM token refreshed: $newToken');
        _fcmToken = newToken;
        _saveFCMTokenToSupabase(newToken);
      });

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Handle notification taps (app opened from notification)
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      // Check if app was opened from a terminated state via notification
      RemoteMessage? initialMessage = await _firebaseMessaging.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationTap(initialMessage);
      }

      _isInitialized = true;
      debugPrint('✅ NotificationService initialized successfully');
    } catch (e) {
      debugPrint('❌ NotificationService initialization error: $e');
      rethrow;
    }
  }

  /// Request notification permissions (primarily for iOS)
  Future<void> _requestPermissions() async {
    if (Platform.isIOS) {
      NotificationSettings settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
        announcement: false,
        carPlay: false,
        criticalAlert: false,
      );

      debugPrint('📱 iOS notification permission: ${settings.authorizationStatus}');
    } else if (Platform.isAndroid) {
      // Android 13+ requires runtime permission
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }
  }

  /// Initialize local notifications for foreground handling
  Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create Android notification channels
    if (Platform.isAndroid) {
      await _createAndroidNotificationChannels();
    }
  }

  /// Create Android notification channels
  Future<void> _createAndroidNotificationChannels() async {
    final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
        _localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin == null) return;

    // Streaks & Reminders channel (High priority)
    const AndroidNotificationChannel streaksChannel = AndroidNotificationChannel(
      'streaks_channel',
      'Streaks & Reminders',
      description: 'Notifications for daily streaks and goal reminders',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    // Achievements channel (Max priority)
    const AndroidNotificationChannel achievementsChannel = AndroidNotificationChannel(
      'achievements_channel',
      'Achievements',
      description: 'Notifications for unlocked achievements and milestones',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      enableLights: true,
    );

    // Goals channel (High priority)
    const AndroidNotificationChannel goalsChannel = AndroidNotificationChannel(
      'goals_channel',
      'Goals & Progress',
      description: 'Notifications for goal completion and progress updates',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    // General channel (Default priority)
    const AndroidNotificationChannel generalChannel = AndroidNotificationChannel(
      'general_channel',
      'General Updates',
      description: 'General app notifications and updates',
      importance: Importance.defaultImportance,
      playSound: true,
    );

    await androidPlugin.createNotificationChannel(streaksChannel);
    await androidPlugin.createNotificationChannel(achievementsChannel);
    await androidPlugin.createNotificationChannel(goalsChannel);
    await androidPlugin.createNotificationChannel(generalChannel);

    debugPrint('✅ Android notification channels created');
  }

  /// Get and save FCM token
  Future<void> _getFCMToken() async {
    try {
      _fcmToken = await _firebaseMessaging.getToken();

      if (_fcmToken != null) {
        debugPrint('📱 FCM Token: $_fcmToken');
        await _saveFCMTokenToSupabase(_fcmToken!);
      } else {
        debugPrint('⚠️ Failed to get FCM token');
      }
    } catch (e) {
      debugPrint('❌ Error getting FCM token: $e');
    }
  }

  /// Save FCM token to Supabase
  Future<void> _saveFCMTokenToSupabase(String token) async {
    try {
      final supabase = SupabaseService().client;
      final userId = supabase.auth.currentUser?.id;

      if (userId == null) {
        debugPrint('⚠️ Cannot save FCM token: User not authenticated');
        return;
      }

      // Upsert FCM token to user_devices table
      await supabase.from('user_devices').upsert({
        'user_id': userId,
        'fcm_token': token,
        'platform': Platform.isIOS ? 'ios' : 'android',
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id,fcm_token');

      debugPrint('✅ FCM token saved to Supabase');
    } catch (e) {
      debugPrint('❌ Error saving FCM token to Supabase: $e');
    }
  }

  /// Handle foreground messages (app is open)
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('📬 Foreground message received: ${message.messageId}');
    debugPrint('Title: ${message.notification?.title}');
    debugPrint('Body: ${message.notification?.body}');

    // Show local notification when app is in foreground
    if (message.notification != null) {
      await _showLocalNotification(message);
    }
  }

  /// Show local notification
  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    final data = message.data;

    if (notification == null) return;

    // Determine the channel based on notification type
    String channelId = 'general_channel';
    if (data['type'] == 'streak') {
      channelId = 'streaks_channel';
    } else if (data['type'] == 'achievement') {
      channelId = 'achievements_channel';
    } else if (data['type'] == 'goal') {
      channelId = 'goals_channel';
    }

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      channelId,
      _getChannelName(channelId),
      channelDescription: _getChannelDescription(channelId),
      importance: channelId == 'achievements_channel'
          ? Importance.max
          : Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      message.hashCode,
      notification.title,
      notification.body,
      platformDetails,
      payload: data['screen'] ?? 'home',
    );
  }

  /// Get channel name by ID
  String _getChannelName(String channelId) {
    switch (channelId) {
      case 'streaks_channel':
        return 'Streaks & Reminders';
      case 'achievements_channel':
        return 'Achievements';
      case 'goals_channel':
        return 'Goals & Progress';
      default:
        return 'General Updates';
    }
  }

  /// Get channel description by ID
  String _getChannelDescription(String channelId) {
    switch (channelId) {
      case 'streaks_channel':
        return 'Notifications for daily streaks and goal reminders';
      case 'achievements_channel':
        return 'Notifications for unlocked achievements and milestones';
      case 'goals_channel':
        return 'Notifications for goal completion and progress updates';
      default:
        return 'General app notifications and updates';
    }
  }

  /// Handle notification tap
  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('👆 Notification tapped: ${message.messageId}');
    debugPrint('Data: ${message.data}');

    // Navigate to specific screen based on data
    final screen = message.data['screen'];
    if (screen != null) {
      _navigateToScreen(screen);
    }
  }

  /// Handle local notification tap
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('👆 Local notification tapped: ${response.payload}');

    if (response.payload != null) {
      _navigateToScreen(response.payload!);
    }
  }

  /// Navigate to screen based on payload
  void _navigateToScreen(String screen) {
    // This will be implemented with your navigation logic
    // For now, just log the intended navigation
    debugPrint('🧭 Navigate to screen: $screen');

    // You can use a navigation key or implement deep linking here
    // Example screens: 'home', 'nutrition', 'streaks', 'achievements', 'profile'
  }

  /// Subscribe to topic (for broadcast notifications)
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _firebaseMessaging.subscribeToTopic(topic);
      debugPrint('✅ Subscribed to topic: $topic');
    } catch (e) {
      debugPrint('❌ Error subscribing to topic $topic: $e');
    }
  }

  /// Unsubscribe from topic
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _firebaseMessaging.unsubscribeFromTopic(topic);
      debugPrint('✅ Unsubscribed from topic: $topic');
    } catch (e) {
      debugPrint('❌ Error unsubscribing from topic $topic: $e');
    }
  }

  /// Delete FCM token (for logout)
  Future<void> deleteFCMToken() async {
    try {
      await _firebaseMessaging.deleteToken();
      _fcmToken = null;
      debugPrint('✅ FCM token deleted');
    } catch (e) {
      debugPrint('❌ Error deleting FCM token: $e');
    }
  }

  /// Register FCM token after user login
  /// Call this method after successful authentication
  Future<void> registerTokenAfterLogin() async {
    if (_fcmToken != null) {
      await _saveFCMTokenToSupabase(_fcmToken!);
    } else {
      // Try to get token again
      await _getFCMToken();
    }
  }

  /// Schedule a local notification (for testing or offline reminders)
  Future<void> scheduleLocalNotification({
    required String title,
    required String body,
    required DateTime scheduledTime,
    String? payload,
  }) async {
    // Note: This requires timezone package and additional setup
    // For now, this is a placeholder for future implementation
    debugPrint('📅 Schedule notification: $title at $scheduledTime');
  }
}
