# Google Play Appeal Response - Health Connect Issue
## Streaker App v1.0.22+26

**Response to:** Insufficient Information to Determine App Functionality for Health Connect

---

## ISSUE SUMMARY

Google Play reviewers rejected our app because they could not understand why we requested 13 Health Connect permissions for steps, heart rate, sleep, blood pressure, etc.

**The reason is simple: WE DON'T USE THOSE PERMISSIONS.**

---

## ROOT CAUSE

The previous version (1.0.21+25) incorrectly declared 13 Health Connect permissions that the app does NOT actually use. This was a configuration error carried over from an earlier template.

---

## CORRECTIVE ACTION TAKEN

**Version 1.0.22+26 has REMOVED all Health Connect permissions.**

### Permissions Removed:
1. READ_STEPS
2. READ_HEART_RATE
3. READ_RESTING_HEART_RATE
4. READ_ACTIVE_CALORIES_BURNED
5. READ_TOTAL_CALORIES_BURNED
6. READ_DISTANCE
7. READ_SLEEP
8. READ_HYDRATION
9. READ_WEIGHT (from Health Connect)
10. READ_OXYGEN_SATURATION
11. READ_BLOOD_PRESSURE
12. READ_EXERCISE
13. READ_BASAL_METABOLIC_RATE
14. ACTIVITY_RECOGNITION

**Also removed:** Health Connect activity aliases and query declarations

---

## WHAT THE APP ACTUALLY DOES

**Streaker is a simple nutrition and weight tracking app with 4 core features:**

### 1. Manual Nutrition Tracking
- Users manually enter what they ate
- Users can take photos of meals for AI analysis
- AI estimates calories and macronutrients (protein, fat, carbs)
- **NO automatic syncing from fitness trackers or health apps**

### 2. Manual Weight Tracking
- Users manually enter their weight
- App displays weight trends over time
- **NO automatic syncing from scales or health apps**

### 3. AI Chat Assistant
- Users can ask nutrition and fitness questions
- Powered by AI chat service
- Provides advice and recommendations

### 4. E-commerce
- Users can view fitness products
- Clicking "Buy" redirects to WhatsApp for purchase
- Simple product catalog

---

## PERMISSIONS NOW USED (Only 3)

### 1. Camera Permission
**Purpose:** Take photos of meals for AI nutrition analysis  
**Justification:** Core feature - users photograph their food and our AI estimates nutritional content  
**User Control:** Users can decline and manually enter nutrition data instead

### 2. Storage Permissions
**Purpose:** Temporarily store meal photos during AI analysis  
**Justification:** Required to save photos taken by camera before sending to AI  
**Scope:** Temporary storage only, deleted after analysis

### 3. Notification Permission (Android 13+)
**Purpose:** Send daily streak reminders to users  
**Justification:** Helps users maintain their nutrition tracking streak  
**User Control:** Users can disable in app settings

---

## DATA COLLECTION CLARIFICATION

**What We Collect:**
- Email address and name (account creation)
- Nutrition data (manually entered by user or AI-analyzed from photos)
- Weight data (manually entered by user)
- Meal photos (for AI analysis, not stored permanently)
- Chat conversations with AI assistant

**What We DON'T Collect:**
- ❌ Steps or activity data
- ❌ Heart rate
- ❌ Sleep data
- ❌ Blood pressure
- ❌ Oxygen saturation
- ❌ Cycling or exercise data from fitness trackers
- ❌ ANY data from Health Connect or fitness apps

**All health data is MANUALLY ENTERED by the user.**

---

## APP DESCRIPTION UPDATE

We have clarified the app description to accurately reflect its functionality:

**Streaker - Simple Nutrition & Weight Tracker**

Track your nutrition and weight with ease! 

✨ Features:
• Take photos of your meals for instant nutrition analysis
• Manually log calories and macronutrients
• Track your weight over time
• Get AI-powered nutrition advice
• Browse fitness products

📝 Manual Entry Only:
This app does NOT automatically sync with fitness trackers, step counters, or health apps. All nutrition and weight data is manually entered by you.

📸 AI Photo Analysis:
Take a picture of your meal and our AI estimates the nutritional content. Simple and fast!

---

## PLAY CONSOLE DATA SAFETY DECLARATION UPDATE

We will update the Data Safety section to accurately reflect:

**Data Collected:**
- Personal info: Email, name
- Nutrition data: Meal photos, calories, macros (manually entered)
- Weight data: Weight entries (manually entered)
- Photos: Meal photos for analysis
- App activity: Usage analytics

**NOT Collected:**
- Steps, heart rate, sleep, or any automatic fitness data
- Location data
- Health Connect data

---

## WHY THIS ISSUE OCCURRED

1. **Template carryover:** The AndroidManifest.xml was based on a template that included Health Connect permissions for potential future features
2. **Never implemented:** We never actually implemented Health Connect integration
3. **Oversight:** We failed to remove unused permissions before submission
4. **Now corrected:** Version 1.0.22+26 only declares permissions we actually use

---

## TESTING VERIFICATION

We have verified that version 1.0.22+26:
- ✅ Builds successfully without Health Connect permissions
- ✅ All nutrition tracking features work (manual entry + AI photo)
- ✅ Weight tracking works
- ✅ AI chat works
- ✅ E-commerce works
- ✅ No code references Health Connect APIs
- ✅ Privacy policy updated to reflect actual data collection

---

## CONCLUSION

**The rejection was justified.** We incorrectly declared 13 Health Connect permissions for features we don't use.

**The issue is now resolved.** Version 1.0.22+26 accurately declares only the 3 permissions we actually need (Camera, Storage, Notifications).

**The app's functionality is simple:** Manual nutrition tracking with optional AI photo analysis, manual weight tracking, AI chat, and e-commerce.

We apologize for the confusion and appreciate the reviewer's diligence in catching this error.

---

## REQUEST

Please review version 1.0.22+26 which accurately reflects our app's actual functionality and permissions.

Thank you for your time and consideration.

**Novatrient Team**  
Email: novatrient@gmail.com

---

**Version:** 1.0.22+26  
**Build:** app-release.aab (32.1 MB)  
**Date:** December 2024
