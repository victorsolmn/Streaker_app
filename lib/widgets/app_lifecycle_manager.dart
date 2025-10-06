import 'package:flutter/material.dart';
import '../services/database_sync_service.dart';

/// Widget that manages app lifecycle events and triggers database sync
class AppLifecycleManager extends StatefulWidget {
  final Widget child;

  const AppLifecycleManager({
    Key? key,
    required this.child,
  }) : super(key: key);

  @override
  State<AppLifecycleManager> createState() => _AppLifecycleManagerState();
}

class _AppLifecycleManagerState extends State<AppLifecycleManager>
    with WidgetsBindingObserver {
  final DatabaseSyncService _dbSync = DatabaseSyncService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Sync on app startup (after first frame)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncOnStartup();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    debugPrint('📱 App lifecycle changed: $state');

    switch (state) {
      case AppLifecycleState.resumed:
        // App came to foreground - sync data
        _syncOnResume();
        break;
      case AppLifecycleState.paused:
        // App going to background - nothing needed (triggers will handle)
        break;
      case AppLifecycleState.inactive:
        // App is inactive (e.g., phone call) - nothing needed
        break;
      case AppLifecycleState.detached:
        // App is detached - nothing needed
        break;
      case AppLifecycleState.hidden:
        // App is hidden - nothing needed
        break;
    }
  }

  Future<void> _syncOnStartup() async {
    try {
      debugPrint('🚀 App started - syncing data...');
      await _dbSync.syncToday();
      debugPrint('✅ Startup sync completed');
    } catch (e) {
      debugPrint('⚠️ Startup sync failed: $e');
    }
  }

  Future<void> _syncOnResume() async {
    try {
      debugPrint('▶️ App resumed - syncing data...');
      await _dbSync.syncToday();
      debugPrint('✅ Resume sync completed');
    } catch (e) {
      debugPrint('⚠️ Resume sync failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
