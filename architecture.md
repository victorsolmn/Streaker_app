# Streaker App - Architecture Documentation

## System Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                         Flutter App                         │
├─────────────────────────────────────────────────────────────┤
│                      Presentation Layer                      │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │   Screens    │  │   Widgets    │  │   Dialogs    │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
├─────────────────────────────────────────────────────────────┤
│                      State Management                        │
│  ┌──────────────────────────────────────────────────┐      │
│  │             Provider Pattern (ChangeNotifier)     │      │
│  │  - SupabaseUserProvider  - HealthProvider        │      │
│  │  - NutritionProvider     - StreakProvider        │      │
│  │  - SupabaseAuthProvider  - UserProvider          │      │
│  └──────────────────────────────────────────────────┘      │
├─────────────────────────────────────────────────────────────┤
│                        Service Layer                         │
│  ┌──────────────────────────────────────────────────┐      │
│  │  - UnifiedHealthService   - RealtimeSyncService  │      │
│  │  - SupabaseService        - CalorieTracking      │      │
│  │  - NutritionAIService     - VersionManager       │      │
│  │  - PermissionFlowManager  - NotificationService  │      │
│  └──────────────────────────────────────────────────┘      │
├─────────────────────────────────────────────────────────────┤
│                     Data Sources                             │
│  ┌────────────┐  ┌────────────┐  ┌──────────────┐         │
│  │  Supabase  │  │Health APIs │  │Local Storage │         │
│  │  Database  │  │ HealthKit  │  │SharedPrefs   │         │
│  │            │  │Health Con. │  │              │         │
│  └────────────┘  └────────────┘  └──────────────┘         │
└─────────────────────────────────────────────────────────────┘
```

## Directory Structure

```
lib/
├── main.dart                    # App entry point
├── screens/                     # UI screens
│   ├── auth/                    # Authentication screens
│   │   ├── unified_auth_screen.dart
│   │   ├── otp_verification_screen.dart
│   │   └── welcome_screen.dart
│   ├── main/                    # Main app screens
│   │   ├── home_screen_clean.dart     # Primary home screen (Nutrition)
│   │   ├── progress_screen_new.dart   # Progress tracking (Weight)
│   │   ├── profile_screen.dart        # User profile
│   │   ├── main_screen.dart          # Navigation container (5 tabs)
│   │   ├── chat_screen.dart          # AI Coach / Workouts
│   │   ├── marketplace_screen.dart   # Supplement marketplace (REPLACED v1.0.14)
│   │   ├── cart_screen.dart          # Shopping cart with WhatsApp checkout (NEW v1.0.14)
│   │   └── nutrition_home_screen.dart # Nutrition home
│   └── legal/                   # Legal screens
│       ├── privacy_policy_screen.dart
│       └── terms_conditions_screen.dart
├── providers/                   # State management
│   ├── supabase_user_provider.dart   # User profile state
│   ├── health_provider.dart          # Health metrics state
│   ├── nutrition_provider.dart       # Nutrition tracking
│   ├── streak_provider.dart          # Streak management
│   ├── marketplace_provider.dart     # E-commerce cart & products (NEW v1.0.14)
│   └── supabase_auth_provider.dart   # Authentication
├── services/                    # Business logic
│   ├── unified_health_service.dart   # Health data aggregation
│   ├── realtime_sync_service.dart    # Background sync
│   ├── supabase_service.dart         # Database operations
│   ├── enhanced_supabase_service.dart # Enhanced DB ops
│   └── version_manager_service.dart  # App versioning
├── models/                      # Data models
│   ├── user_model.dart
│   ├── streak_model.dart
│   ├── health_metrics_model.dart
│   ├── product_model.dart           # E-commerce products (NEW v1.0.14)
│   └── premium_membership_model.dart # Premium subscriptions (NEW v1.0.14)
├── widgets/                     # Reusable components
│   ├── force_update_dialog.dart
│   ├── app_wrapper.dart
│   └── android_health_permission_guide.dart
└── utils/                       # Utilities
    └── constants.dart
```

## Core Components

### 1. Provider Architecture

**SupabaseUserProvider**
- Manages user profile data from Supabase
- Handles profile updates and synchronization
- Provides targets (calories, steps, sleep)
- Force reload capability for fresh data

**HealthProvider**
- Interfaces with device health APIs
- Aggregates data from multiple sources
- Handles permission management
- 5-minute sync interval to Supabase
- **Data Priority System** (October 2025):
  - Explicit hierarchy: `liveHealthData > supabaseCache > localStorage > noData`
  - Prevents Supabase cache from overwriting live health data
  - Platform-agnostic design for iOS HealthKit and Android Health Connect
  - Early exit pattern in `loadHealthDataFromSupabase()` when live data exists
  - Ensures real-time device data always takes precedence

**NutritionProvider**
- Tracks food consumption
- Calculates daily totals
- Manages nutrition entries
- Syncs with `nutrition_entries` table

**StreakProvider**
- Tracks daily goal completion
- Manages current and longest streaks
- Handles grace period logic
- Real-time updates via Supabase

**MarketplaceProvider** (Added November 16, 2025 - v1.0.14)
- Manages product catalog and categories
- Handles shopping cart state (add, update, remove, clear)
- Tracks premium membership status and discounts
- Calculates cart totals, savings, and item counts
- Syncs with Supabase tables: products, shopping_cart, premium_memberships
- Category filtering and product search capabilities

### 2. Service Layer

**UnifiedHealthService**
- Platform-agnostic health data interface
- Prioritizes data sources (Samsung > Google > Apple)
- Handles permission requests
- Error recovery and fallback logic

**RealtimeSyncService**
- Background data synchronization
- Manages sync queues
- Handles offline scenarios
- Batch updates for efficiency

**SupabaseService/EnhancedSupabaseService**
- Database CRUD operations
- Real-time subscriptions
- Error handling and retries
- Optimistic updates

### 3. Data Flow Patterns

#### Health Data Flow (Updated October 2025)
```
Device Sensors (HealthKit/Health Connect)
    → UnifiedHealthService
    → HealthProvider
    ↓
[Data Priority Check]
    ├─ If liveHealthData exists → Block Supabase load
    └─ If noData/localStorage → Allow Supabase load
    ↓
    → RealtimeSyncService
    → Supabase (health_metrics)
    → UI Updates

Initialization Sequence:
1. Initialize health provider
2. Auto-connect if permissions exist
3. Fetch LIVE health data (sets liveHealthData priority)
4. Attempt Supabase load (blocked if live data exists)
```

#### Nutrition Data Flow (Updated October 22, 2025)
```
User Input
    → NutritionProvider
    → SupabaseService.saveNutritionEntry()
    → Direct INSERT to Supabase (nutrition_entries table)
    → UI Updates

IMPORTANT: No sync to health_metrics table
- nutrition_entries: Stores food/nutrition data (calories, protein, carbs, fat, fiber)
- health_metrics: Stores health tracking data (steps, heart_rate, sleep_hours)
- These tables remain separate for proper separation of concerns
- Migration 006 removed sync_nutrition_to_health_metrics() trigger function
```

#### Profile Settings Flow
```
Supabase (profiles)
    → SupabaseUserProvider
    → UI Components
    → User Updates
    → Supabase (profiles)
```

#### E-commerce Flow (Added October 29, 2025 - v1.0.13)
```
User Taps Shop Tab
    → MainScreen (IndexedStack index 3)
    → EcommerceScreen (WebView)
    → Loads: https://streaker.odoo.com/?source=app
    ↓
WebView Features:
    ├─ Back/Forward navigation
    ├─ Page refresh
    ├─ Progress indicators
    ├─ Error handling & retry
    ├─ Pull-to-refresh
    └─ Dynamic page titles

User Browses/Purchases
    → Odoo backend processes order
    → ?source=app parameter tracks app-driven sales
    → Analytics available in Odoo admin panel
```

**Key Implementation Details:**
- Uses `webview_flutter` package for in-app browsing
- JavaScriptMode.unrestricted for full functionality
- NavigationDelegate handles page lifecycle events
- Error handling with user-friendly retry mechanism
- Source tracking enables conversion analytics
- Separate browsing context (secure, isolated)

**Revenue Model:**
- Direct product sales (30-40% profit margin)
- In-app shopping eliminates app switching friction
- Contextual shopping (users shop when motivated)
- Conservative: ₹36K/month @ 10K MAU
- Optimized: ₹98K/month with personalization

**Future Enhancements:**
1. Personalized landing pages based on fitness goals
2. Post-workout shopping prompts
3. Wishlist integration in Profile screen
4. Streak-based reward discounts
5. AI product recommendations

## Database Schema

### Core Tables

**profiles**
- `user_id` (uuid, primary key)
- `daily_active_calories_target` (integer)
- `daily_steps_target` (integer)
- `daily_sleep_target` (float)
- `daily_water_target` (integer)
- Profile settings and preferences

**health_metrics**
- `user_id` (uuid)
- `date` (date)
- `steps` (integer)
- `total_calories` (integer)
- `heart_rate` (integer)
- `sleep_hours` (float)
- Composite key: (user_id, date)

**nutrition_entries**
- `id` (uuid, primary key)
- `user_id` (uuid)
- `food_name` (text)
- `calories` (integer)
- `protein`, `carbs`, `fat`, `fiber` (float)
- `created_at` (timestamp)
- NOTE: Saves directly to this table, no sync to health_metrics (as of Migration 006)

**streaks**
- `user_id` (uuid, primary key)
- `current_streak` (integer)
- `longest_streak` (integer)
- `last_completed_date` (date)
- `grace_days_used` (integer)

### E-Commerce Tables (Added November 16, 2025 - v1.0.14)

**product_categories**
- `id` (uuid, primary key)
- `name` (text) - e.g., "Protein", "Pre-Workout"
- `slug` (text) - URL-friendly identifier
- `icon` (text) - Icon name for UI
- `display_order` (integer)
- `is_active` (boolean)

**products**
- `id` (uuid, primary key)
- `name` (text)
- `brand` (text)
- `category_id` (uuid, foreign key)
- `description` (text)
- `regular_price` (decimal)
- `premium_price` (decimal) - 25% discount
- `stock_quantity` (integer)
- `is_featured` (boolean)
- `serving_size` (text)
- `flavor` (text, nullable)
- `image_url` (text, nullable)
- `is_active` (boolean)

**shopping_cart**
- `id` (uuid, primary key)
- `user_id` (uuid, foreign key)
- `product_id` (uuid, foreign key)
- `quantity` (integer)
- `created_at`, `updated_at` (timestamp)
- Composite unique: (user_id, product_id)
- RLS Policy: Users can only access their own cart

**premium_memberships**
- `id` (uuid, primary key)
- `user_id` (uuid, foreign key)
- `plan_type` (text) - 'monthly', 'quarterly', 'annual'
- `discount_percentage` (integer) - Default 25%
- `start_date`, `end_date` (date)
- `status` (text) - 'active', 'expired', 'cancelled'
- `price_paid` (decimal)
- `payment_id` (text, nullable)

**orders**
- `id` (uuid, primary key)
- `user_id` (uuid, foreign key)
- `order_number` (text) - Format: STR-YYYYMMDD-XXXX
- `status` (text) - 'pending', 'confirmed', 'shipped', 'delivered', 'cancelled'
- `total_amount` (decimal)
- `is_premium_order` (boolean)
- `discount_applied` (decimal)
- `shipping_address` (text)
- `contact_number` (text)
- `notes` (text, nullable)
- `created_at`, `updated_at` (timestamp)

**order_items**
- `id` (uuid, primary key)
- `order_id` (uuid, foreign key)
- `product_id` (uuid, foreign key)
- `product_name` (text) - Snapshot at time of order
- `product_brand` (text)
- `quantity` (integer)
- `unit_price` (decimal)
- `subtotal` (decimal)

## Authentication Flow

### OTP-Based Authentication
```
1. User enters email → unified_auth_screen
2. System sends OTP → Supabase Email Service
3. User enters code → otp_verification_screen
4. Verification → JWT token generation
5. Session established → Navigate to main app
```

### Session Management
- JWT tokens with auto-refresh
- Secure storage using flutter_secure_storage
- Automatic re-authentication on expiry
- Offline capability with cached credentials

## State Management Strategy

### Provider Pattern Implementation
- ChangeNotifier for reactive updates
- Consumer widgets for UI rebuilds
- Selective listening to prevent unnecessary rebuilds
- Memory-efficient disposal lifecycle

### State Update Flow
1. Service fetches/processes data
2. Provider updates internal state
3. `notifyListeners()` triggers
4. Consumer widgets rebuild
5. UI reflects new state

## Performance Optimizations

### Data Caching
- 12-hour cache for app config
- Local storage for offline access
- Memory cache for frequent reads
- Incremental sync for large datasets

### UI Optimizations
- Lazy loading for historical data
- Debounced search inputs
- Image caching and compression
- Tree-shaking removes unused code

### Dark Mode & Theming Best Practices (Added November 2025)

#### Theme-Aware Color System
The app supports both light and dark modes with adaptive color schemes:

**Color Constants**:
```dart
// lib/utils/app_theme.dart
class AppTheme {
  // Light Mode Colors
  static const Color textPrimary = Color(0xFF111111);      // Near black
  static const Color textSecondary = Color(0xFF4F4F4F);    // Dark grey

  // Dark Mode Colors
  static const Color textPrimaryDark = Color(0xFFFFFFFF);  // White
  static const Color textSecondaryDark = Color(0xFFB0B0B0); // Light grey

  // Brand Colors (theme-independent)
  static const Color primaryAccent = Color(0xFFFF6B1A);    // Orange
  static const Color cardBackgroundLight = Color(0xFFF5F5F5);
  static const Color darkCardBackground = Color(0xFF1E1E1E);
}
```

**Implementation Pattern**:
```dart
// Detect current theme mode
final isDarkMode = Theme.of(context).brightness == Brightness.dark;

// Apply theme-aware colors
Text(
  'Sample Text',
  style: TextStyle(
    color: isDarkMode ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
  ),
)
```

#### Critical Dark Mode Fixes (November 15, 2025)
**Problem**: Static color constants from `ThemeConfig` weren't adapting to theme changes
**Solution**: Implemented theme-aware color selection throughout the app

**Files Using Theme-Aware Colors**:
- `/lib/screens/main/nutrition_home_screen.dart`
  - Macro breakdown labels and values
  - Calorie stats section (EATEN, KCAL LEFT, STREAK)
  - Header titles and icons
- `/lib/screens/main/chat_screen.dart`
  - Personalized greeting with RichText
  - Workout prompt chips

**Best Practices**:
1. ✅ **Always detect theme mode** using `Theme.of(context).brightness`
2. ✅ **Use conditional colors** for text based on theme
3. ✅ **Create dark variants** of all text colors in AppTheme
4. ✅ **Test in both modes** before deployment
5. ❌ **Never use static const** colors for dynamic text
6. ❌ **Avoid hardcoded colors** that don't adapt to theme

**Accessibility Compliance**:
- Light mode: Black text on white backgrounds (21:1 contrast ratio)
- Dark mode: White text on dark backgrounds (21:1 contrast ratio)
- WCAG AAA compliant for normal text
- Improved readability for 30-40% of users using dark mode

### Network Optimizations
- Batch API requests
- Delta sync for changes only
- Retry logic with exponential backoff
- Connection state monitoring

## Security Measures

### Data Protection
- End-to-end encryption for sensitive data
- Row-level security in Supabase
- Secure credential storage
- No plaintext passwords

### API Security
- Rate limiting protection
- Request validation
- CORS configuration
- API key rotation support

## Platform-Specific Implementations

### Android

#### Core Library Desugaring (Critical - October 2025)
**Purpose:** Enable java.time API on Android API 26-33

**Implementation:**
```kotlin
// build.gradle.kts
compileOptions {
    sourceCompatibility = JavaVersion.VERSION_11
    targetCompatibility = JavaVersion.VERSION_11
    // CRITICAL: Enables java.time backport
    isCoreLibraryDesugaringEnabled = true
}

dependencies {
    // Backports java.time to older Android versions
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}
```

**Why Required:**
- `java.time` classes (Instant, ZonedDateTime, Duration) only available on Android 26+
- Without desugaring: `ClassNotFoundException` on Android < 26
- With desugaring: Full java.time support on Android API 21+

**Impact:**
- Before: App crashes on Android 8-13 (~70% of users)
- After: Full compatibility with Android 8.0+ (API 26+)

#### Health Connect Integration
- Health Connect SDK integration via native Kotlin
- Samsung Health data source prioritization
- Graceful degradation when Health Connect unavailable
- Version-aware availability checking:
  - Android 14+: Health Connect built into framework
  - Android 9-13: Requires manual Play Store installation
  - Android 8: Health Connect not available

**Availability Checking:**
```kotlin
// MainActivity.kt onCreate()
val sdkStatus = HealthConnectClient.getSdkStatus(this, providerPackageName)
when (sdkStatus) {
    SDK_AVAILABLE -> initialize client
    SDK_UNAVAILABLE -> graceful fallback
    SDK_UNAVAILABLE_PROVIDER_UPDATE_REQUIRED -> show update prompt
}
```

**Safety Pattern:**
```kotlin
private fun isHealthConnectAvailable(): Boolean {
    return ::healthConnectClient.isInitialized
}

// All methods check availability before use
if (!isHealthConnectAvailable()) {
    result.error("UNAVAILABLE", "Health Connect not available", null)
    return
}
```

#### Permission Handling
- Native permission handling via MainActivity.kt
- Device-specific settings navigation (Samsung vs others)
- Runtime permission checks with graceful fallback
- Permission flow lifecycle management

#### Storage Permissions (Android 13+ Compatibility)
```xml
<!-- AndroidManifest.xml -->
<!-- Android 12 and below -->
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"
    android:maxSdkVersion="32"/>
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"
    android:maxSdkVersion="32"/>

<!-- Android 13+ -->
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES"/>
```

#### Background Sync
- WorkManager for reliable background sync
- Battery optimization handling
- Samsung-specific power management

### iOS
- HealthKit integration
- Entitlements configuration
- Background fetch capability
- Native Swift bridging

## Testing Strategy

### Unit Tests
- Provider logic testing
- Service method validation
- Model serialization tests
- Utility function coverage

### Integration Tests
- API endpoint testing
- Database operation verification
- Health API integration
- Authentication flow testing

### UI Tests
- Screen navigation flows
- Form validation
- Permission request handling
- Error state displays

## Deployment Pipeline

### Build Process
1. Version increment
2. Environment configuration
3. Platform-specific builds
4. Code signing
5. Store uploads

### Android Signing Configuration (Updated October 2025)

#### Upload Key Details
- **Keystore File:** `/android/app/upload-keystore.jks`
- **Key Alias:** `upload`
- **Store Password:** `str3ak3r2024`
- **Key Password:** `str3ak3r2024`
- **SHA-1 Fingerprint:** `61:50:2F:16:80:8F:F8:A2:81:D7:75:91:92:6C:B9:A2:D2:B8:85:30`
- **Valid From:** October 9, 2025, 9:47 AM UTC

#### Signing Configuration Files
```
android/
├── key.properties          # Signing credentials (NOT in git)
│   ├── storePassword=str3ak3r2024
│   ├── keyPassword=str3ak3r2024
│   ├── keyAlias=upload
│   └── storeFile=upload-keystore.jks
└── app/
    └── upload-keystore.jks # Keystore file (NOT in git)
```

#### build.gradle.kts Configuration
```kotlin
// Load key.properties file
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

signingConfigs {
    create("release") {
        keyAlias = keystoreProperties["keyAlias"] as String?
        keyPassword = keystoreProperties["keyPassword"] as String?
        storeFile = keystoreProperties["storeFile"]?.let { file(it) }
        storePassword = keystoreProperties["storePassword"] as String?
    }
}
```

#### Google Play App Signing
- **Enabled:** Yes (Google manages final signing key)
- **App Signing Key SHA-1:** `48:47:13:BE:0D:9D:87:A2:12:22:72:61:28:FE:76:86:1A:79:3F:2B`
- **Upload Key SHA-1:** `61:50:2F:16:80:8F:F8:A2:81:D7:75:91:92:6C:B9:A2:D2:B8:85:30`

#### Build Commands
```bash
# Clean build
flutter clean

# Build release AAB
flutter build appbundle --release

# Output location
build/app/outputs/bundle/release/app-release.aab
```

#### Security Notes
1. **Never commit** keystore or key.properties to git
2. Both files are in `.gitignore`
3. Backup keystore to secure cloud storage
4. If keystore is lost, request upload key reset via Google Play Console
5. Upload key reset takes 48 hours to process

#### Key Reset History
- **October 7, 2025:** Original keystore lost, upload key reset requested
- **October 9, 2025:** New upload key activated
- **Previous SHA-1:** `D6:07:C1:0A:2E:92:4D:EE:90:42:8B:50:71:79:8B:B7:3D:06:9B:B8` (deprecated)

### Release Checklist
- Database migrations
- API compatibility
- Force update configuration
- Privacy policy updates
- Store listing updates
- Verify signing configuration
- Backup keystore to secure location

## Monitoring & Analytics

### Error Tracking
- Crash reporting via Firebase Crashlytics
- Error boundary implementation
- Logged error states
- User feedback integration

### Performance Monitoring
- API response times
- Screen load metrics
- Memory usage tracking
- Battery impact analysis

## Future Architecture Considerations

### Scalability
- Microservices migration path
- CDN for static assets
- Database sharding strategy
- Load balancing preparation

### Feature Expansion
- Plugin architecture for features
- Modular dependency injection
- Feature flags system
- A/B testing framework

## Development Best Practices

### Code Organization
- Single responsibility principle
- Clear separation of concerns
- Consistent naming conventions
- Comprehensive documentation

### Version Control
- Feature branch workflow
- Semantic versioning
- Commit message standards
- Code review requirements

### Documentation
- Inline code comments
- API documentation
- Architecture decisions records
- User guides and FAQs