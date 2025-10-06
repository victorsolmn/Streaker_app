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
│   │   ├── home_screen_clean.dart     # Primary home screen
│   │   ├── progress_screen_new.dart   # Progress tracking
│   │   ├── profile_screen.dart        # User profile
│   │   └── main_screen.dart          # Navigation container
│   └── legal/                   # Legal screens
│       ├── privacy_policy_screen.dart
│       └── terms_conditions_screen.dart
├── providers/                   # State management
│   ├── supabase_user_provider.dart   # User profile state
│   ├── health_provider.dart          # Health metrics state
│   ├── nutrition_provider.dart       # Nutrition tracking
│   ├── streak_provider.dart          # Streak management
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
│   └── health_metrics_model.dart
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

#### Nutrition Data Flow
```
User Input
    → NutritionProvider
    → SupabaseService
    → Supabase (nutrition_entries)
    → UI Updates
```

#### Profile Settings Flow
```
Supabase (profiles)
    → SupabaseUserProvider
    → UI Components
    → User Updates
    → Supabase (profiles)
```

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
- `protein`, `carbs`, `fat` (float)
- `created_at` (timestamp)

**streaks**
- `user_id` (uuid, primary key)
- `current_streak` (integer)
- `longest_streak` (integer)
- `last_completed_date` (date)
- `grace_days_used` (integer)

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
- Health Connect integration
- Samsung Health priority
- Native permission handling via MainActivity.kt
- Background service for sync

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

### Release Checklist
- Database migrations
- API compatibility
- Force update configuration
- Privacy policy updates
- Store listing updates

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