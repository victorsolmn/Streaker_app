import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/app_theme.dart';
import '../../providers/nutrition_provider.dart';
import '../../providers/health_provider.dart';
import '../../providers/supabase_auth_provider.dart';
import '../../services/toast_service.dart';
import '../../services/popup_service.dart';
import '../../services/health_onboarding_service.dart';
import '../../widgets/sync_status_indicator.dart';
import '../../widgets/health_permission_dialog.dart';
import 'home_screen_clean.dart';
import 'progress_screen_new.dart';
import 'nutrition_screen.dart';
import 'chat_screen.dart';
import 'profile_screen.dart';

class MainScreen extends StatefulWidget {
  final int initialIndex;
  
  const MainScreen({Key? key, this.initialIndex = 0}) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;
  bool _isDataLoaded = false;
  bool _isSyncing = false;
  DateTime? _lastSyncTime;
  GlobalKey? _profileKey;

  // Centralized health permission management
  static bool _hasShownHealthDialog = false;
  static bool _isShowingHealthDialog = false;
  HealthOnboardingService? _healthOnboardingService;

  @override
  void initState() {
    super.initState();
    // Set initial index from widget parameter
    _currentIndex = widget.initialIndex;
    _profileKey = GlobalKey();
    // Add observer for app lifecycle events
    WidgetsBinding.instance.addObserver(this);
    // Initialize toast service
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ToastService().initialize(context);
      }
    });
    // Load data and sync health on startup
    _loadUserDataAndSyncHealth();
    
    // If navigating to profile page, show smartwatch integration after delay
    if (widget.initialIndex == 4) {
      Future.delayed(Duration(milliseconds: 800), () {
        if (mounted && _profileKey?.currentState != null) {
          // Trigger smartwatch integration dialog in profile screen
          // Try to call the method if the state exists
          try {
            final profileState = _profileKey?.currentState as dynamic;
            profileState?.showSmartwatchIntegrationDialog();
          } catch (e) {
            debugPrint('Could not trigger smartwatch dialog: $e');
          }
        }
      });
    }
  }

  @override
  void dispose() {
    // Remove observer when widget is disposed
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final healthProvider = Provider.of<HealthProvider>(context, listen: false);
    final nutritionProvider = Provider.of<NutritionProvider>(context, listen: false);
    
    // Handle app lifecycle changes
    if (state == AppLifecycleState.resumed) {
      // App has come to foreground - only sync if needed (with throttling)
      _syncHealthDataIfNeeded();
      // Note: _syncHealthDataIfNeeded already handles loading data if needed
    } else if (state == AppLifecycleState.paused) {
      // App is going to background - sync data to Supabase
      healthProvider.syncOnPause();
      nutritionProvider.syncOnPause();
    }
  }

  Future<void> _loadUserDataAndSyncHealth() async {
    if (_isDataLoaded) return;

    // Early return if widget is not mounted
    if (!mounted) return;

    // Show sync indicator
    setState(() {
      _isSyncing = true;
    });

    try {
      // Check mounted before accessing context
      if (!mounted) return;

      // Load nutrition data from Supabase
      final nutritionProvider = Provider.of<NutritionProvider>(context, listen: false);
      await nutritionProvider.loadDataFromSupabase();

      // Check mounted after async operation
      if (!mounted) return;

      // Load and sync health data
      final healthProvider = Provider.of<HealthProvider>(context, listen: false);

      // 🔥 CRITICAL CHANGE FOR iOS FIX: Changed initialization order
      // FIRST: Initialize health provider (sets up HealthKit/Health Connect)
      if (!healthProvider.isInitialized) {
        debugPrint('📊 [MainScreen] Initializing health provider...');
        await healthProvider.initialize();
      }

      // Check mounted after async operation
      if (!mounted) return;

      // SECOND: Auto-connect if permissions already exist and fetch LIVE data
      debugPrint('📊 [MainScreen] Performing smart permission check...');
      final autoConnected = await healthProvider.healthService.checkAndAutoConnect();
      if (autoConnected) {
        debugPrint('📊 [MainScreen] ✅ Auto-connected to health source!');

        // IMPORTANT: Immediately sync health data after successful connection
        // This fetches LIVE data from HealthKit/Health Connect
        debugPrint('📊 [MainScreen] Fetching LIVE health data after auto-connect...');
        await healthProvider.syncWithHealth();

        // Save the live data to Supabase
        await healthProvider.saveHealthDataToSupabase();

        debugPrint('📊 [MainScreen] Live health data priority set - Supabase will NOT override');
      } else {
        debugPrint('📊 [MainScreen] No existing permissions found, manual connection required');
      }

      // Check mounted after async operation
      if (!mounted) return;

      // THIRD: Load from Supabase ONLY as fallback if no live data was fetched
      // The loadHealthDataFromSupabase() method now checks data priority and won't overwrite live data
      debugPrint('📊 [MainScreen] Attempting Supabase load (will be blocked if live data exists)...');
      await healthProvider.loadHealthDataFromSupabase();

      // Check mounted after async operation
      if (!mounted) return;

      // Check if we need to sync (in case auto-connect didn't work)
      if (!autoConnected && healthProvider.isHealthSourceConnected) {
        debugPrint('MainScreen: Auto-syncing health data on app startup...');
        await healthProvider.syncWithHealth();

        // Check mounted after async operation
        if (!mounted) return;

        _lastSyncTime = DateTime.now();

        // Show success message
        if (mounted && context.mounted) {
          ToastService().showSuccess('Health data synced successfully! 📊');
        }
      } else {
        debugPrint('MainScreen: Health source not connected, skipping auto-sync');
      }

      // Check mounted after all health operations
      if (!mounted) return;

      // CENTRALIZED HEALTH PERMISSION CHECK: Only show if not auto-connected
      if (!healthProvider.isHealthSourceConnected) {
        await _checkAndShowHealthPermissionDialog();
      }

      if (mounted) {
        setState(() {
          _isDataLoaded = true;
          _isSyncing = false;
        });
      }
    } catch (e) {
      debugPrint('MainScreen: Error during initial data load: $e');
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
        // Only show popup if still mounted and context is valid
        if (mounted && context.mounted) {
          // Show network error popup with retry option
          PopupService.showNetworkError(
            context,
            onRetry: () => _loadUserDataAndSyncHealth(),
            customMessage: 'Failed to load health data. Please check your connection and try again.',
          );
        }
      }
    }
  }
  
  Future<void> _syncHealthDataIfNeeded() async {
    // Prevent multiple simultaneous syncs
    if (_isSyncing) {
      debugPrint('MainScreen: Sync already in progress, skipping');
      return;
    }

    // Check if we should sync (throttle to prevent excessive syncing)
    if (_lastSyncTime != null) {
      final timeSinceLastSync = DateTime.now().difference(_lastSyncTime!);
      // Only sync if it's been more than 60 seconds since last sync (increased from 30)
      if (timeSinceLastSync.inSeconds < 60) {
        debugPrint('MainScreen: Skipping sync, last sync was ${timeSinceLastSync.inSeconds} seconds ago');
        return;
      }
    }

    final healthProvider = Provider.of<HealthProvider>(context, listen: false);

    // Smart permission check on app resume
    debugPrint('MainScreen: Checking for existing permissions on app resume...');
    final autoConnected = await healthProvider.healthService.checkAndAutoConnect();
    if (autoConnected) {
      debugPrint('MainScreen: ✅ Auto-connected on resume!');
    }

    // Only sync if health source is connected
    if (!healthProvider.isHealthSourceConnected) {
      debugPrint('MainScreen: Health source not connected, skipping auto-sync');
      return;
    }
    
    if (mounted) {
      setState(() {
        _isSyncing = true;
      });
    }
    
    try {
      debugPrint('MainScreen: Auto-syncing health data on app resume...');
      await healthProvider.syncWithHealth();
      _lastSyncTime = DateTime.now();
      
      // Show subtle sync indicator
      if (mounted && context.mounted) {
        ToastService().showInfo('Health data updated! 🔄');
      }
    } catch (e) {
      debugPrint('MainScreen: Error syncing health data: $e');
      // Only show popup if still mounted and context is valid
      if (mounted && context.mounted) {
        // Show network error popup with retry option
        PopupService.showNetworkError(
          context,
          onRetry: () => _syncHealthDataIfNeeded(),
          customMessage: 'Failed to sync health data. Please check your connection and try again.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }

  /// CENTRALIZED HEALTH PERMISSION DIALOG - Single source of truth
  Future<void> _checkAndShowHealthPermissionDialog() async {
    // MUTEX LOCK: Prevent multiple dialogs from being shown simultaneously
    if (_isShowingHealthDialog || _hasShownHealthDialog) {
      debugPrint('MainScreen: Health dialog already shown/showing, skipping');
      return;
    }

    _isShowingHealthDialog = true;
    debugPrint('MainScreen: Checking if health permission dialog should be shown...');

    try {
      // Initialize health onboarding service if not already done
      if (_healthOnboardingService == null) {
        final prefs = await SharedPreferences.getInstance();
        final healthProvider = Provider.of<HealthProvider>(context, listen: false);
        _healthOnboardingService = HealthOnboardingService(
          prefs: prefs,
          healthProvider: healthProvider,
        );
      }

      // Check if we should show the health permission dialog
      final shouldShow = await _healthOnboardingService!.shouldShowHealthPrompt();
      if (!shouldShow || !mounted) {
        debugPrint('MainScreen: Should not show health dialog or widget unmounted');
        return;
      }

      // Wait for UI to be fully rendered (reduced from 800ms to 500ms for better UX)
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;

      // CRITICAL: Check real-time health connection status before showing dialog
      final healthProvider = Provider.of<HealthProvider>(context, listen: false);

      // Final permission check with auto-connect attempt
      debugPrint('MainScreen: Final health permission check before showing dialog...');
      final isConnected = await healthProvider.healthService.checkAndAutoConnect();

      if (isConnected || healthProvider.isHealthSourceConnected) {
        debugPrint('MainScreen: Health auto-connected during final check, skipping dialog');
        return;
      }

      // Mark that we're showing the dialog to prevent duplicates
      _hasShownHealthDialog = true;

      // Check if it's a re-engagement
      final isReengagement = await SharedPreferences.getInstance()
          .then((prefs) => prefs.getBool('health_prompt_shown') ?? false);

      debugPrint('MainScreen: 🔥 Showing health permission dialog (re-engagement: $isReengagement)');

      // Show the health permission dialog
      if (mounted && context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => HealthPermissionDialog(
            isReengagement: isReengagement,
            onConnect: () async {
              Navigator.of(context).pop();
              await _handleHealthPermissionRequest();
            },
            onDismiss: () async {
              Navigator.of(context).pop();
              await _healthOnboardingService!.markHealthPromptDismissed();

              // Show a subtle reminder
              if (mounted && context.mounted) {
                ToastService().showInfo('You can connect health data anytime from Settings');
              }
            },
          ),
        );

        // Mark that we've shown the prompt
        await _healthOnboardingService!.markHealthPromptShown();
      }

    } catch (e) {
      debugPrint('MainScreen: Error in health permission check: $e');
    } finally {
      _isShowingHealthDialog = false;
    }
  }

  /// Handle health permission request
  Future<void> _handleHealthPermissionRequest() async {
    if (_healthOnboardingService == null) return;

    try {
      debugPrint('MainScreen: Handling health permission request...');
      final result = await _healthOnboardingService!.requestHealthPermissions(context);

      if (result.success) {
        // Show success message
        if (mounted && context.mounted) {
          ToastService().showSuccess(result.message);
        }

        // Refresh health data immediately
        final healthProvider = Provider.of<HealthProvider>(context, listen: false);
        await healthProvider.syncWithHealth();

        // Force UI update
        if (mounted) {
          setState(() {
            _isDataLoaded = true; // Ensure UI reflects connected state
          });
        }

        debugPrint('MainScreen: ✅ Health permission granted and data synced');
      } else {
        // Show error message
        if (mounted && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(result.message),
                  if (result.actionRequired != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      result.actionRequired!,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ],
              ),
              backgroundColor: AppTheme.errorRed,
              duration: const Duration(seconds: 5),
            ),
          );
        }
        debugPrint('MainScreen: ❌ Health permission request failed: ${result.message}');
      }
    } catch (e) {
      debugPrint('MainScreen: Error handling health permission request: $e');
      if (mounted && context.mounted) {
        ToastService().showError('Failed to connect health data. Please try again.');
      }
    }
  }

  List<Widget> get _screens => [
    const HomeScreenClean(),
    const ProgressScreenNew(),
    const NutritionScreen(),
    const ChatScreen(),
    ProfileScreen(key: _profileKey),
  ];

  final List<BottomNavigationBarItem> _bottomNavItems = [
    const BottomNavigationBarItem(
      icon: Icon(Icons.home_outlined),
      activeIcon: Icon(Icons.home_rounded),
      label: 'Home',
    ),
    BottomNavigationBarItem(
      icon: SizedBox(
        width: 24,
        height: 24,
        child: SvgPicture.asset(
          'assets/images/streaker_logo.svg',
          colorFilter: ColorFilter.mode(
            AppTheme.textSecondary,
            BlendMode.srcIn,
          ),
        ),
      ),
      activeIcon: SizedBox(
        width: 24,
        height: 24,
        child: SvgPicture.asset(
          'assets/images/streaker_logo.svg',
          colorFilter: ColorFilter.mode(
            AppTheme.primaryAccent,
            BlendMode.srcIn,
          ),
        ),
      ),
      label: 'Streaks',
    ),
    const BottomNavigationBarItem(
      icon: Icon(Icons.restaurant_outlined),
      activeIcon: Icon(Icons.restaurant_rounded),
      label: 'Nutrition',
    ),
    const BottomNavigationBarItem(
      icon: Icon(Icons.fitness_center_outlined),
      activeIcon: Icon(Icons.fitness_center_rounded),
      label: 'Workouts',
    ),
    const BottomNavigationBarItem(
      icon: Icon(Icons.person_outline_rounded),
      activeIcon: Icon(Icons.person_rounded),
      label: 'Profile',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: _screens,
          ),
          // Sync status indicator - only show on home screen
          if (_currentIndex == 0) // Only show on home screen
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              right: 16,
              child: const SyncStatusIndicator(),
            ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: Theme.of(context).dividerColor,
              width: 1,
            ),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          items: _bottomNavItems,
        ),
      ),
    );
  }
}