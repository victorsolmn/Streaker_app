import 'package:flutter/foundation.dart';

/// Notification service — stubbed while firebase_messaging /
/// flutter_local_notifications packages are disabled in pubspec.yaml.
/// Re-enable packages and restore full implementation when ready.
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;
    debugPrint('NotificationService: running in stub mode (packages disabled)');
  }

  Future<void> scheduleStreakReminder() async {}
  Future<void> scheduleMorningMotivation() async {}
  Future<void> scheduleWaterReminder() async {}
  Future<void> scheduleLunchReminder() async {}
  Future<void> scheduleWorkoutReminder() async {}
  Future<void> showStreakAchievement(int days) async {}
  Future<void> showGoalReached(String goalType) async {}
  Future<void> cancelNotification(int id) async {}
  Future<void> cancelAllNotifications() async {}
  Future<String?> getFCMToken() async => null;
  Future<void> subscribeToTopic(String topic) async {}
  Future<void> unsubscribeFromTopic(String topic) async {}
  void dispose() {}
}
