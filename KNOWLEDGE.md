# Streaker App Knowledge Base

This document contains important information about the Streaker fitness tracking app, its features, architecture, and recent updates.

## Latest Version: 1.0.10 (Build 12)
Released: September 29, 2025
Last Deployed: September 30, 2025 (Successfully installed on Android device R5CT32TLWGB)

## Recent Updates and Fixes

### Version 1.0.10 - Major Release (September 29, 2025)

#### 🎉 New Features
1. **AI-Powered Food Scanner with Gemini 2.5 Flash**
   - Integrated Google Gemini 2.5 Flash API for accurate nutrition analysis
   - Supports Indian foods and international cuisines
   - Real-time calorie and macro tracking
   - API Key stored in `lib/config/api_config.dart`
   - Fallback mechanisms for API failures

2. **Enhanced Weight Progress Tracking**
   - Fixed critical database query issues (profiles.user_id → profiles.id)
   - Added intuitive gradient + button for weight entries
   - Beautiful line chart visualization with fl_chart
   - Automatic sync between weight entries and profile
   - Improved empty state UI with clear CTAs

#### 🐛 Critical Bug Fixes
1. **Database Column Reference Fix**
   - Fixed "column profiles.user_id does not exist" error
   - Updated all 5 instances in WeightProvider
   - Created SQL migration for trigger fix
   - Applied to production Supabase instance

2. **Gemini API Model Updates**
   - Migrated from deprecated Gemini 1.x to 2.5 Flash
   - Updated model fallback chain
   - Fixed duplicate method definitions

3. **Build and Signing Issues**
   - Fixed Android AAB signing with original keystore
   - Incremented version code to 12 (11 was already used)
   - Resolved iOS provisioning profile issues

## Core Features

### 1. Health & Fitness Tracking
- Weight tracking with progress charts
- BMI calculation and monitoring
- Daily step counting
- Calorie tracking
- Workout logging
- Health data sync with Apple HealthKit and Android Health Connect

### 2. AI-Powered Features
- **Food Scanner**: Uses Gemini 2.5 Flash for nutrition analysis
- **Smart Recommendations**: Personalized fitness suggestions
- **Progress Insights**: AI-driven progress analysis

### 3. User Profile Management
- Comprehensive user profiles
- Goal setting (weight, fitness targets)
- Progress tracking
- Customizable units (metric/imperial)

## API Integrations

### Google Gemini AI
- **Purpose**: Food nutrition analysis via image recognition
- **Model**: gemini-2.5-flash (primary), with fallbacks
- **Configuration**: `lib/config/api_config.dart`
- **Service**: `lib/services/indian_food_nutrition_service.dart`
- **Features**:
  - Multi-model fallback system
  - Detailed nutrition extraction (calories, protein, carbs, fats)
  - Support for Indian and international cuisines
  - Error handling and default responses

### Supabase Backend
- **Database**: PostgreSQL with RLS policies
- **Tables**: profiles, weight_entries, users
- **Real-time**: Automatic weight sync via triggers
- **Authentication**: Integrated auth system
- **Connection**: Configured in `lib/services/supabase_service.dart`

## Technical Stack

### Frontend
- **Framework**: Flutter 3.x
- **Language**: Dart
- **State Management**: Provider pattern
- **UI Components**: Material Design 3

### Backend
- **Database**: Supabase (PostgreSQL)
- **Authentication**: Supabase Auth
- **Storage**: Supabase Storage
- **Real-time**: Supabase Realtime subscriptions

### Key Dependencies
- `flutter`: Core framework
- `provider`: State management
- `supabase_flutter`: Backend integration
- `google_generative_ai`: Gemini AI integration
- `health`: HealthKit/Health Connect integration
- `fl_chart`: Data visualization
- `camera`: Food scanning
- `firebase_core` & `firebase_analytics`: Analytics

## Deployment Information

### Android (Google Play Store)
- **Package Name**: com.streaker.streaker
- **Current Version**: 1.0.10 (Build 12)
- **Keystore**: streaker-release-key.jks
- **Keystore Location**: `/android/app/`
- **Key Alias**: streaker
- **Key Password**: str3ak3r2024
- **Min SDK**: API 26 (Android 8.0)
- **Target SDK**: API 36
- **AAB File**: Available on Desktop as `streaker_v1.0.10_build12.aab`
- **APK Size**: 61.3MB (Release build)
- **Last Test Device**: Samsung SM S908E (R5CT32TLWGB)
- **Last Successful Installation**: September 30, 2025

### iOS (App Store)
- **Bundle ID**: com.streaker.streaker
- **Team ID**: 94B23HD4LP
- **Provisioning**: Automatic signing enabled
- **Deployment Target**: iOS 13.0
- **Entitlements**: HealthKit enabled

## Database Schema

### profiles
- `id` (uuid, primary key)
- `user_id` (uuid, foreign key to auth.users)
- `name` (text)
- `weight` (numeric)
- `target_weight` (numeric)
- `height` (numeric)
- `age` (integer)
- `gender` (text)
- `weight_unit` (text)
- `created_at` (timestamp)
- `updated_at` (timestamp)

### weight_entries
- `id` (uuid, primary key)
- `user_id` (uuid, foreign key)
- `weight` (numeric)
- `date` (date)
- `created_at` (timestamp)

### Triggers
- `update_profile_weight_trigger`: Automatically updates profile weight when new weight entry is added

## Recent Development Resolutions

### Fixed Issues (September 2025)
1. ✅ Food nutrition scanner returning generic data (350 cal "mixed meal")
2. ✅ Weight progress widget showing "Error loading weight data"
3. ✅ Database trigger using incorrect column reference
4. ✅ Gemini API model deprecation errors
5. ✅ Google Play Store signing certificate mismatch
6. ✅ iOS "Untrusted Developer" installation issues

## Development Guidelines

### Code Organization
- `/lib/screens/` - UI screens
- `/lib/widgets/` - Reusable widgets
- `/lib/providers/` - State management
- `/lib/services/` - API and backend services
- `/lib/models/` - Data models
- `/lib/config/` - Configuration files
- `/lib/utils/` - Utility functions

### Testing
- Unit tests in `/test/`
- Integration tests in `/integration_test/`
- Run tests: `flutter test`

### Build Commands
- **Android Debug**: `flutter build apk --debug`
- **Android Release**: `flutter build appbundle --release`
- **iOS Debug**: `flutter build ios --debug`
- **iOS Release**: `flutter build ios --release`

### Environment Setup
- Flutter SDK: 3.x
- Dart SDK: 3.x
- Android Studio / Xcode required
- Environment variables in `.env` (not committed)

## Security Considerations
- API keys stored in `lib/config/api_config.dart`
- Keystore passwords in `android/key.properties`
- Never commit sensitive credentials
- Use environment variables for production

## Known Issues
- Wireless debugging on iOS may have connectivity issues
- Personal Hotspot can interfere with iOS debugging
- Some Android devices require manual Health Connect permissions

## Support & Resources
- GitHub Repository: https://github.com/victorsolmn/Streaks_Flutter.git
- Documentation: This file and fearchitecture.md
- Issue Tracking: GitHub Issues

## Future Roadmap
- [ ] Social features and challenges
- [ ] Advanced AI coaching
- [ ] Wearable device integration
- [ ] Meal planning features
- [ ] Exercise video library
- [ ] Community features

---
Last Updated: September 30, 2025
Version: 1.0.10
Deployment Status: ✅ Successfully deployed to test device