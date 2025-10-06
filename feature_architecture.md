# Feature Architecture Documentation

## Overview
This document outlines the architecture and implementation details of major features in the Streaker app, providing context for future development and maintenance.

## Weight Progress Feature

### Migration from Profile to Progress Screen
**Date**: December 2024
**Status**: Completed

#### Architecture Overview
The weight progress feature has been migrated from the Profile screen to the Progress screen to better align with the app's user experience design. The feature now appears as the second widget in the Progress tab, positioned below the weekly progress chart.

#### Component Structure

##### 1. Provider Layer (`lib/providers/weight_provider.dart`)
- **Purpose**: State management for weight data using Provider pattern
- **Key Features**:
  - Supabase integration for data persistence
  - Cache management with 5-minute validity
  - Graceful error handling for missing database tables
  - Real-time weight tracking and trend calculations

**Error Handling Strategy**:
```dart
// Handles missing weight_entries table gracefully
try {
  entriesResponse = await _supabase.from('weight_entries').select()...
} catch (e) {
  debugPrint('weight_entries table not found or error: $e');
  entriesResponse = []; // Continue with empty entries
}
```

##### 2. Widget Components

**WeightProgressChart** (`lib/widgets/weight_progress_chart.dart`)
- Interactive line graph using fl_chart library
- Two display modes:
  - Compact mode: For Progress screen overview
  - Full mode: For detailed view in WeightDetailsScreen
- Features:
  - Touch interactions for viewing specific data points
  - Animated transitions
  - Actual weight line vs target weight line
  - Dynamic Y-axis scaling

**Integration Points**:
- Progress Screen: Displays compact chart with navigation to details
- Weight Details Screen: Full chart with complete history

##### 3. Database Architecture

**Tables**:
- `weight_entries`: Stores individual weight measurements
  - Fields: id, user_id, weight, timestamp, note
  - RLS policies for user data isolation

- `profiles`: Extended with weight-related fields
  - Fields: weight, target_weight, weight_unit

**Triggers**:
- `update_profile_weight`: Automatically syncs latest weight entry to profile
- Maintains data consistency between tables

##### 4. Screen Integration

**Progress Screen** (`lib/screens/main/progress_screen_new.dart`)
- Widget Order (after reordering):
  1. Milestone Progress Ring (centered, main feature)
  2. Weekly Progress Chart
  3. Weight Progress Chart (newly added)
  4. Other widgets...

**Profile Screen** (`lib/screens/main/profile_screen.dart`)
- Weight section completely removed
- All weight-related methods and imports cleaned up
- Users now navigate to Progress tab for weight tracking

#### Data Flow
1. User adds weight entry → WeightProvider → Supabase
2. Trigger updates profile table with latest weight
3. Provider notifies listeners → UI updates
4. Chart displays historical data with trend lines

#### Migration Checklist
- [x] Create WeightProvider with Supabase integration
- [x] Implement WeightProgressChart widget with fl_chart
- [x] Create WeightDetailsScreen for management
- [x] Add database migration script
- [x] Integrate into Progress screen
- [x] Remove from Profile screen
- [x] Handle missing database table errors
- [x] Reorder widgets (Milestone first)
- [x] Test on physical devices

## Profile Screen Enhancement

### Fitness Goals Card Feature
**Date**: September 28, 2025
**Status**: Completed

#### Architecture Overview
The Profile screen's fitness goals section has been redesigned from a verbose, space-consuming layout to a compact, professional card interface. This change significantly improves the user experience by reducing scrolling and presenting information more efficiently.

#### Component Structure

##### 1. FitnessGoalsCard Widget (`lib/widgets/fitness_goals_card.dart`)
- **Purpose**: Compact display of user's fitness goals and metrics
- **Design**: Professional card layout with 2x2 grid structure
- **Theme Support**: Full dark/light mode compatibility

**Layout Architecture**:
```
FitnessGoalsCard
├── Header Section
│   ├── Title: "Fitness Goals"
│   └── Edit Button (navigates to EditGoalsScreen)
├── 2x2 Grid Layout
│   ├── Top Row
│   │   ├── Goal (Primary fitness objective)
│   │   └── Activity Level (Exercise frequency)
│   └── Bottom Row
│       ├── Experience Level (Fitness background)
│       └── Consistency (Workout schedule)
└── BMI Section (conditional)
    ├── BMI Value & Category
    ├── Color-coded status
    └── Professional styling
```

**Key Features**:
- **Space Efficiency**: 70% reduction in vertical space usage
- **Color Coding**: Each goal item has themed background and icon colors
- **Responsive Design**: Text overflow handled with ellipsis
- **Accessibility**: Proper contrast ratios and touch targets

##### 2. Integration Points

**Profile Screen** (`lib/screens/main/profile_screen.dart`)
- Replaced `_buildFitnessGoalsSection()` with `FitnessGoalsCard` widget
- Separated daily targets into dedicated `_buildDailyTargetsSection()`
- Maintained data flow through `SupabaseUserProvider`

**Data Dependencies**:
- Uses `UserProfile` model from `lib/models/user_model.dart`
- Integrates with existing provider pattern
- No database schema changes required

#### Design System

##### Color Palette
- **Goal**: `AppTheme.primaryAccent` (brand color)
- **Activity**: `Colors.blue` (energy/movement)
- **Experience**: `Colors.green` (growth/knowledge)
- **Consistency**: `Colors.orange` (warmth/commitment)
- **BMI**: Dynamic based on health ranges

##### Typography
- **Header**: 18px bold for section title
- **Labels**: 10-11px medium for goal labels
- **Values**: 12-16px semibold for goal values
- **BMI**: 16px bold for value, 11px semibold for category

##### Spacing System
- **Card Margin**: 16px top only
- **Internal Padding**: 16px all sides
- **Grid Spacing**: 12px between items
- **Icon-Text Gap**: 4-10px based on context

#### Implementation Details

**Technical Improvements**:
- Fixed import error: Corrected `../models/user_profile.dart` to `../models/user_model.dart`
- Ensured compatibility with existing `SupabaseUserProvider` data structure
- Added proper null safety for optional profile fields

**Error Handling**:
- Graceful handling of missing profile data
- Fallback values ("Not set") for empty fields
- Safe BMI calculations with null checks

#### Migration Notes

**Before** (Old Implementation):
- Verbose vertical list layout
- Individual rows for each goal item
- Excessive white space usage
- Separate BMI calculation section

**After** (New Implementation):
- Compact 2x2 grid layout
- Integrated BMI display
- Professional card styling
- 70% space reduction

#### Performance Considerations
- Lightweight widget with minimal rebuild requirements
- Efficient use of Consumer widget for targeted updates
- No heavy computations or complex animations

#### Future Enhancements
1. **Goal Progress Indicators**: Add progress bars for quantifiable goals
2. **Interactive Elements**: Tap individual goal items for quick editing
3. **Animation**: Subtle animations on data updates
4. **Customization**: User-selectable color themes for goal categories

## Milestone Progress Feature

### Architecture
The milestone progress ring is the primary visual element in the Progress screen, displaying user's overall streak achievement.

#### Components
- **MilestoneProgressRing**: Custom circular progress widget
- Positioned as the first element in Progress screen for maximum visibility
- Size: 160px with 16px stroke width
- Centered with max width constraint of 300px

## Weekly Progress Chart

### Architecture
Displays user's weekly activity patterns and consistency.

#### Integration
- Positioned between Milestone Ring and Weight Progress
- Uses similar charting patterns as Weight Progress for consistency
- Shares color scheme and animation patterns

## Navigation Architecture

### Bottom Navigation Structure
1. **Home Tab**: Dashboard and quick actions
2. **Progress Tab**:
   - Milestone achievements
   - Weekly progress
   - Weight tracking (newly added)
3. **Profile Tab**: User settings and preferences (weight section removed)

## State Management

### Provider Pattern Implementation
- All features use Provider for state management
- Providers initialized at app root level
- Lazy loading with cache management for performance

### Cache Strategy
- 5-minute cache validity for weight data
- Force refresh available via pull-to-refresh
- Automatic refresh on data mutations

## Error Handling Philosophy

### Graceful Degradation
- Features continue to work even if backend tables don't exist
- Clear error messages with retry options
- Fallback to cached data when available

### User Feedback
- Success notifications for data operations
- Clear error messages with actionable solutions
- Loading states for all async operations

## Future Enhancements

### Planned Features
1. **Data Export**: Allow users to export weight history
2. **Advanced Analytics**: BMI calculations, body composition
3. **Goal Setting**: Multiple weight goals with timelines
4. **Social Features**: Share progress with accountability partners

### Technical Debt
1. Consider migrating to Riverpod for better type safety
2. Implement offline-first architecture with sync
3. Add comprehensive widget tests for chart components

## Testing Strategy

### Unit Tests
- Provider logic with mock Supabase client
- Calculation methods (trends, projections)

### Widget Tests
- Chart rendering with various data sets
- Error state handling
- User interactions

### Integration Tests
- Complete user flows from adding weight to viewing trends
- Database trigger verification
- Navigation between screens

## Performance Considerations

### Optimizations Implemented
- Lazy loading of chart data
- Debounced chart animations
- Efficient list rendering with Dismissible widgets

### Monitoring Points
- Chart rendering performance with large datasets
- Database query optimization
- Memory usage during chart animations

## Security Considerations

### Row Level Security
- All weight_entries protected by user_id policies
- Users can only access their own data
- Triggers respect RLS policies

### Data Validation
- Weight range validation (1-500 kg/lbs)
- Timestamp validation for entries
- Input sanitization for notes

## Deployment Notes

### Database Migration
Run migration script before deploying:
```sql
-- Creates weight_entries table with RLS
-- Adds weight fields to profiles
-- Creates necessary triggers
```

### Version Compatibility
- Minimum Flutter SDK: 2.0.0
- fl_chart: ^0.68.0
- Supabase Flutter: ^2.0.0

## Documentation References
- [Weight Provider Implementation](lib/providers/weight_provider.dart)
- [Weight Chart Widget](lib/widgets/weight_progress_chart.dart)
- [Database Schema](supabase/migrations/weight_entries_table.sql)
- [Knowledge Base](knowledge.md)