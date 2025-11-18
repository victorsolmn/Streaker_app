# Daily Goals Sync Issue - Solution Implementation Plan

**Date:** November 18, 2025
**Issue:** Daily goals calculated during onboarding not displaying on homepage
**Root Cause:** Dual provider system mismatch (local vs remote data sources)
**Recommended Solution:** Switch to SupabaseUserProvider throughout the app

---

## Problem Summary

**Current Flow (Broken):**
```
Onboarding → Calculate 2500 cal → Save to Supabase ✅
           → Reload UserProvider (reads SharedPreferences) ❌
Homepage → Read UserProvider (SharedPreferences is empty) ❌
        → Falls back to default 2000 cal instead of 2500 cal
```

**Desired Flow (Fixed):**
```
Onboarding → Calculate 2500 cal → Save to Supabase ✅
           → Reload SupabaseUserProvider (reads from Supabase) ✅
Homepage → Read SupabaseUserProvider (gets 2500 from Supabase) ✅
        → Displays correct 2500 cal ✅
```

---

## Solution: Replace UserProvider with SupabaseUserProvider

### Phase 1: Update Onboarding Screen ✅

**File:** `lib/screens/onboarding/supabase_onboarding_screen.dart`

**Change Required:**
```dart
// BEFORE (Line 290)
final userProvider = Provider.of<UserProvider>(context, listen: false);
await userProvider.reloadUserData();

// AFTER
final userProvider = Provider.of<SupabaseUserProvider>(context, listen: false);
await userProvider.loadUserProfile();
```

**Also update import:**
```dart
// BEFORE (Line ~6)
import '../../providers/user_provider.dart';

// AFTER
import '../../providers/supabase_user_provider.dart';
```

---

### Phase 2: Update Nutrition Home Screen ✅

**File:** `lib/screens/main/nutrition_home_screen.dart`

**Change 1 - Update Import (Line 6):**
```dart
// BEFORE
import '../../providers/user_provider.dart';

// AFTER
import '../../providers/supabase_user_provider.dart';
```

**Change 2 - Update Consumer (Lines 458-463):**
```dart
// BEFORE
Consumer3<NutritionProvider, UserProvider, StreakProvider>(
  builder: (context, nutritionProvider, userProvider, streakProvider, child) {
    final profile = userProvider.profile;
    final caloriesTarget = profile?.dailyCaloriesTarget ?? 2000;

// AFTER
Consumer3<NutritionProvider, SupabaseUserProvider, StreakProvider>(
  builder: (context, nutritionProvider, userProvider, streakProvider, child) {
    final profile = userProvider.userProfile;  // Note: property name change
    final caloriesTarget = profile?.dailyCaloriesTarget ?? 2000;
```

---

### Phase 3: Find and Replace All Other Usages 🔍

**Step 1 - Search for all files using UserProvider:**
```bash
grep -r "UserProvider" lib/ --include="*.dart" | grep -v "supabase_user_provider.dart"
```

**Step 2 - For each file found, update:**
1. Import statement
2. Provider.of or Consumer references
3. Property access (`.profile` → `.userProfile`)

**Common property name differences:**
- `UserProvider.profile` → `SupabaseUserProvider.userProfile`
- `UserProvider.isAuthenticated` → Check `SupabaseUserProvider.userProfile != null`

---

### Phase 4: Update Main App Provider List 🔍

**File:** `lib/main.dart`

**Verify SupabaseUserProvider is in provider list:**
```dart
MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => SupabaseUserProvider()),
    // ... other providers
  ],
  child: MyApp(),
)
```

**If UserProvider is still listed, it can remain for:**
- Backward compatibility
- Non-authenticated flows
- But should NOT be used for authenticated Supabase users

---

## Implementation Steps (Ordered)

1. **Search Phase** 🔍
   - Find all files importing or using `UserProvider`
   - Document each usage location
   - Create checklist of files to update

2. **Update Phase** ✏️
   - Update `supabase_onboarding_screen.dart`
   - Update `nutrition_home_screen.dart`
   - Update all other identified files
   - Update any initialization logic in `main.dart`

3. **Test Phase** ✅
   - Complete fresh onboarding flow
   - Verify goals appear on homepage immediately
   - Test app restart (persistence)
   - Test with different goal values
   - Test edge cases (offline, slow network)

4. **Cleanup Phase** 🧹
   - Add deprecation notice to `UserProvider`
   - Update documentation
   - Add code comments explaining the change

---

## Files That Likely Need Updates

Based on typical Flutter app architecture, check these files:

**High Priority (Core Screens):**
- ✅ `lib/screens/onboarding/supabase_onboarding_screen.dart`
- ✅ `lib/screens/main/nutrition_home_screen.dart`
- 🔍 `lib/screens/main/main_screen.dart`
- 🔍 `lib/screens/main/profile_screen.dart`
- 🔍 `lib/screens/main/workout_screen.dart`
- 🔍 `lib/screens/main/progress_screen.dart`

**Medium Priority (Settings/Goals):**
- 🔍 `lib/screens/settings/*.dart`
- 🔍 Any goal-related screens

**Low Priority (Support Screens):**
- 🔍 Help, About, etc.

---

## Property Name Mapping

**UserProvider → SupabaseUserProvider:**

| UserProvider | SupabaseUserProvider | Notes |
|--------------|---------------------|-------|
| `.profile` | `.userProfile` | Main profile object |
| `.profile?.dailyCaloriesTarget` | `.userProfile?.dailyCaloriesTarget` | Same property name |
| `.profile?.dailyStepsTarget` | `.userProfile?.dailyStepsTarget` | Same property name |
| `.isAuthenticated` | `.userProfile != null` | Check null instead |
| `.reloadUserData()` | `.loadUserProfile()` | Method name differs |
| `.updateProfile()` | `.updateUserProfile()` | Method name differs |

---

## Testing Checklist

### Onboarding Flow Test
- [ ] Start fresh onboarding
- [ ] Enter personal info (age, weight, height)
- [ ] Select fitness goal (e.g., "Lose Weight")
- [ ] Select activity level (e.g., "Moderately Active")
- [ ] Verify calculated goals shown (e.g., 2500 cal, 8000 steps)
- [ ] Complete onboarding
- [ ] **Verify homepage shows EXACT same values immediately**

### Persistence Test
- [ ] Complete onboarding with custom goals
- [ ] Close app completely
- [ ] Reopen app
- [ ] Verify goals still match onboarding values

### Multi-Device Test (Future)
- [ ] Complete onboarding on Device A
- [ ] Login on Device B
- [ ] Verify same goals appear on Device B

### Edge Cases
- [ ] Test with very high goals (5000 cal)
- [ ] Test with minimum goals (1200 cal)
- [ ] Test goal updates from profile settings
- [ ] Test offline mode (goals should persist from last sync)

---

## Risk Assessment

**Low Risk Changes:**
- Onboarding screen update (isolated to one flow)
- Nutrition home screen update (visual display only)

**Medium Risk Changes:**
- Other screens using UserProvider (need careful testing)

**Zero Risk:**
- Backend logic unchanged
- Calculation formulas unchanged
- Supabase schema unchanged

**Mitigation:**
- Test thoroughly before deployment
- Keep UserProvider code intact as fallback
- Can rollback by reverting provider references

---

## Expected Outcome

**Before Fix:**
```
User completes onboarding → Sees 2500 cal goal ✅
User reaches homepage → Sees 2000 cal (default) ❌
User confused why goals don't match ❌
```

**After Fix:**
```
User completes onboarding → Sees 2500 cal goal ✅
User reaches homepage → Sees 2500 cal (from Supabase) ✅
User happy - goals are consistent! ✅
```

---

## Alternative Solutions (Not Recommended)

### Option 2: Sync Local Provider with Supabase
**Why Not:**
- Adds complexity (dual sync logic)
- Potential sync conflicts
- More code to maintain

### Option 3: Hybrid Approach
**Why Not:**
- Confusing architecture
- Hard to debug which provider is active
- Increases cognitive load

---

## Implementation Commands

**Step 1: Find all UserProvider usages**
```bash
cd /Users/Vicky/Streaker_app
grep -r "UserProvider" lib/ --include="*.dart" | grep -v "supabase_user_provider.dart" > user_provider_usages.txt
cat user_provider_usages.txt
```

**Step 2: Count files to update**
```bash
grep -r "UserProvider" lib/ --include="*.dart" -l | grep -v "supabase_user_provider.dart" | wc -l
```

**Step 3: After changes, verify no old references**
```bash
grep -r "Provider.of<UserProvider>" lib/ --include="*.dart"
grep -r "Consumer.*UserProvider" lib/ --include="*.dart"
```

---

## Conclusion

**Recommended Action:** Implement Option 1 (Switch to SupabaseUserProvider)

**Effort Estimate:**
- Search and document: 15 minutes
- Code updates: 30-45 minutes
- Testing: 30 minutes
- **Total: ~90 minutes**

**Benefits:**
- ✅ Fixes daily goals sync issue permanently
- ✅ Simplifies architecture (single source of truth)
- ✅ Future-proof for multi-device sync
- ✅ Minimal risk (no logic changes)

**Next Step:** Run search command to identify all files needing updates, then proceed with systematic replacement.
