import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
// import 'package:firebase_crashlytics/firebase_crashlytics.dart'; // Temporarily disabled
import 'firebase_options.dart';
import 'services/supabase_service.dart';
import 'services/enhanced_supabase_service.dart';
import 'services/firebase_analytics_service.dart';
import 'services/realtime_sync_service.dart';
import 'services/daily_reset_service.dart';
import 'services/permission_flow_manager.dart';
import 'services/database_sync_service.dart';
import 'services/secure_storage_service.dart';
import 'config/api_config.dart';
// Using Supabase providers for cloud storage
import 'providers/supabase_auth_provider.dart';
import 'providers/supabase_nutrition_provider.dart';
import 'providers/supabase_user_provider.dart';
// Also include local providers for compatibility
import 'providers/auth_provider.dart';
import 'providers/nutrition_provider.dart';
import 'providers/user_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/streak_provider.dart';
import 'providers/achievement_provider.dart';
import 'providers/weight_provider.dart';
import 'screens/auth/welcome_screen.dart';
import 'screens/onboarding/supabase_onboarding_screen.dart';
import 'screens/main/main_screen.dart';
import 'utils/app_theme.dart';
import 'widgets/app_wrapper.dart';
import 'widgets/app_lifecycle_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Supabase services
  await SupabaseService().initialize();
  await EnhancedSupabaseService().initialize();

  // Initialize Real-time Sync Service
  await RealtimeSyncService().initialize();

  // Initialize Daily Reset Service
  await DailyResetService().initialize();

  // Note: Background Sync Service removed (workmanager package removed)

  // Initialize API keys securely from api_config.dart (gitignored file)
  try {
    await SecureStorageService().initializeApiKeys(
      grokApiKey: ApiConfig.grokApiKey,
      enableGrokApi: true,
    );
    debugPrint('✅ GROK API key initialized securely');
  } catch (e) {
    debugPrint('⚠️ GROK API key initialization failed: $e');
  }

  // Initialize Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    
    // Initialize Firebase services
    FirebaseAnalyticsService().initialize();
    
    // Set up Crashlytics (only for non-web platforms)
    // Temporarily disabled due to iOS build issue
    // if (!kIsWeb) {
    //   FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    //   PlatformDispatcher.instance.onError = (error, stack) {
    //     FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    //     return true;
    //   };
    // }
    
    debugPrint('✅ Firebase initialized successfully'); // Debug reload updated
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
    // App can still run with Supabase only
  }
  
  final prefs = await SharedPreferences.getInstance();
  runApp(MyApp(prefs: prefs));
}

class MyApp extends StatelessWidget {
  final SharedPreferences prefs;

  const MyApp({Key? key, required this.prefs}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Using Supabase providers for cloud storage
        ChangeNotifierProvider(create: (_) => SupabaseAuthProvider()),
        ChangeNotifierProvider(create: (_) => SupabaseUserProvider()),
        ChangeNotifierProvider(create: (_) => SupabaseNutritionProvider()),
        // Local providers for compatibility
        ChangeNotifierProvider(create: (_) => AuthProvider(prefs)),
        ChangeNotifierProvider(create: (_) => UserProvider(prefs)),
        ChangeNotifierProvider(create: (_) => NutritionProvider(prefs)),
        ChangeNotifierProvider(create: (_) => ThemeProvider(prefs)),
        ChangeNotifierProvider(create: (_) => StreakProvider()),
        ChangeNotifierProvider(create: (_) => AchievementProvider()),
        ChangeNotifierProvider(create: (_) => WeightProvider()),
      ],
      child: Consumer3<SupabaseAuthProvider, SupabaseUserProvider, ThemeProvider>(
        builder: (context, auth, userProvider, themeProvider, _) {
          // Check if permission flow is active - if so, maintain current navigation state
          final permissionManager = PermissionFlowManager();
          final isPermissionFlowActive = permissionManager.isPermissionFlowActive;

          // Enhanced routing logic with email-based user validation
          // Only trigger profile load once per authentication session
          if (auth.isAuthenticated && !userProvider.hasProfile && !userProvider.isLoading && !userProvider.hasTriedLoading) {
            // Use a microtask instead of postFrameCallback to prevent rebuild loops
            Future.microtask(() async {
              // Double-check state before loading to prevent race conditions
              if (auth.isAuthenticated && !userProvider.hasProfile && !userProvider.isLoading && !userProvider.hasTriedLoading) {
                await userProvider.loadUserProfile();
              }
            });
          }

          Widget home;

          // If permission flow is active, keep user on MainScreen
          if (isPermissionFlowActive && auth.isAuthenticated && userProvider.hasProfile) {
            home = const MainScreen(); // Stay on home screen during permission flow
          } else if (auth.isLoading || (auth.isAuthenticated && userProvider.isLoading)) {
            // Show loading if auth is in loading state or user profile is loading
            home = const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          } else if (auth.isAuthenticated) {
            // Enhanced routing: existing users with complete profiles go to home
            if (userProvider.hasProfile && userProvider.hasCompletedOnboarding) {
              home = const MainScreen(); // Existing user with complete profile
            } else if (userProvider.hasProfile && !userProvider.hasCompletedOnboarding) {
              home = const SupabaseOnboardingScreen(); // Existing user with incomplete profile
            } else {
              // New user without profile - start onboarding
              home = const SupabaseOnboardingScreen();
            }
          } else {
            // Not authenticated
            home = const WelcomeScreen();
          }
          
          return AppLifecycleManager(
            child: MaterialApp(
              title: 'Streaker',
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: themeProvider.themeMode,
              home: AppWrapper(
                child: home,
              ),
              debugShowCheckedModeBanner: false,
            ),
          );
        },
      ),
    );
  }
}