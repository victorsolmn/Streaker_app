# Push Notifications Setup Guide

## Overview
This guide walks you through setting up push notifications for the Streaker app using Firebase Cloud Messaging (FCM) and Supabase Edge Functions.

## Prerequisites
- Firebase project with FCM enabled
- Supabase project
- Firebase Server Key
- Supabase CLI installed

---

## Step 1: Firebase Configuration

### 1.1 Get Firebase Server Key
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your Streaker project
3. Navigate to **Project Settings** (gear icon) > **Cloud Messaging** tab
4. Under "Cloud Messaging API (Legacy)", copy the **Server key**
5. Save this key securely - you'll need it in Step 3

### 1.2 Enable Firebase Cloud Messaging
- FCM should already be enabled with your Firebase project
- If not, enable it in the Cloud Messaging tab

---

## Step 2: Supabase Database Setup

### 2.1 Run Database Migration
1. Open [Supabase Dashboard](https://app.supabase.com/)
2. Navigate to your project
3. Go to **SQL Editor** in the left sidebar
4. Click **New query**
5. Copy the entire contents of `supabase/migrations/create_user_devices_table.sql`
6. Paste into the SQL editor
7. Click **Run** to execute the migration

### 2.2 Verify Table Creation
1. Go to **Table Editor** in Supabase Dashboard
2. You should see a new table called `user_devices`
3. Verify it has these columns:
   - id (uuid)
   - user_id (uuid)
   - fcm_token (text)
   - platform (text)
   - is_active (boolean)
   - created_at (timestamptz)
   - updated_at (timestamptz)

---

## Step 3: Deploy Supabase Edge Function

### 3.1 Install Supabase CLI (if not already installed)
```bash
# macOS
brew install supabase/tap/supabase

# Or using npm
npm install -g supabase
```

### 3.2 Login to Supabase
```bash
supabase login
```
Follow the prompts to authenticate.

### 3.3 Link to Your Project
```bash
# Navigate to your project directory
cd ~/Documents/Streaker_app

# Link to your Supabase project
supabase link --project-ref [your-project-ref]
```

**To find your project ref:**
- Go to Supabase Dashboard
- Project Settings > General
- Copy "Reference ID"

### 3.4 Deploy the Edge Function
```bash
# Deploy the send-notification function
supabase functions deploy send-notification
```

### 3.5 Set Environment Variables
```bash
# Set the Firebase Server Key from Step 1.1
supabase secrets set FCM_SERVER_KEY=[your-firebase-server-key]
```

Verify the secret was set:
```bash
supabase secrets list
```

---

## Step 4: iOS-Specific Setup (Required for iOS)

### 4.1 Open Project in Xcode
```bash
cd ~/Documents/Streaker_app/ios
open Runner.xcworkspace
```

### 4.2 Enable Push Notifications Capability
1. Select **Runner** project in left sidebar
2. Select **Runner** target
3. Go to **Signing & Capabilities** tab
4. Click **+ Capability** button
5. Search for and add **Push Notifications**

### 4.3 Enable Background Modes
1. Still in **Signing & Capabilities** tab
2. Click **+ Capability** again
3. Search for and add **Background Modes**
4. Check the following boxes:
   - ✅ **Remote notifications**
   - ✅ **Background fetch** (optional)

### 4.4 Upload APNs Certificate to Firebase
1. Go to [Apple Developer Portal](https://developer.apple.com/account/)
2. Navigate to **Certificates, Identifiers & Profiles**
3. Create an APNs certificate for your app bundle ID (`com.streaker.streaker`)
4. Download the certificate (.p12 file)
5. Go to Firebase Console > Project Settings > Cloud Messaging
6. Under **Apple app configuration**, upload the APNs certificate

---

## Step 5: Testing the Setup

### 5.1 Test FCM Token Registration
1. Build and run the app on a device or simulator
2. Check the console logs for:
   ```
   ✅ FCM Token: [token-string]
   ✅ FCM token saved to Supabase
   ```
3. Verify in Supabase Dashboard:
   - Go to **Table Editor** > **user_devices**
   - You should see a row with your FCM token

### 5.2 Test from Firebase Console
1. Go to Firebase Console > **Cloud Messaging**
2. Click **Send your first message**
3. Enter:
   - **Notification title**: "Test Notification"
   - **Notification text**: "This is a test from Firebase"
4. Click **Next**
5. Select your app
6. Click **Review** > **Publish**
7. You should receive a notification on your device

### 5.3 Test from Supabase Edge Function
```bash
curl -X POST https://[your-project-ref].supabase.co/functions/v1/send-notification \
  -H "Authorization: Bearer [your-supabase-anon-key]" \
  -H "Content-Type: application/json" \
  -d '{
    "user_ids": ["your-user-uuid"],
    "title": "🔥 Test from Edge Function",
    "body": "This notification was sent via Supabase!",
    "type": "general",
    "screen": "home"
  }'
```

**To find your anon key:**
- Supabase Dashboard > Project Settings > API
- Copy "anon public" key

**To find your user UUID:**
- Supabase Dashboard > Authentication > Users
- Copy your user's UUID

---

## Step 6: Production Deployment

### 6.1 Update Version Number
1. Open `pubspec.yaml`
2. Update version to `1.0.20+24`:
   ```yaml
   version: 1.0.20+24
   ```

### 6.2 Build Release AAB
```bash
cd ~/Documents/Streaker_app

# Clean previous builds
flutter clean

# Build release AAB
flutter build appbundle --release
```

### 6.3 Upload to Google Play
1. Go to Google Play Console
2. Navigate to your app
3. Go to **Release** > **Production**
4. Click **Create new release**
5. Upload the AAB file from:
   `build/app/outputs/bundle/release/app-release.aab`
6. Add release notes mentioning push notifications
7. Review and roll out

---

## Notification Use Cases

### Daily Streak Reminder (Automated)
Create a Supabase Database Function to run daily:
```sql
-- Trigger at 8 PM every day
SELECT cron.schedule(
  'daily-streak-reminder',
  '0 20 * * *',
  $$
  SELECT net.http_post(
    url := 'https://[project-ref].supabase.co/functions/v1/send-notification',
    headers := '{"Authorization": "Bearer [service-role-key]", "Content-Type": "application/json"}',
    body := jsonb_build_object(
      'topic', 'all_users',
      'title', '🔥 Time to log your meals!',
      'body', 'Don''t forget to track your nutrition today.',
      'type', 'streak',
      'screen', 'nutrition'
    )
  );
  $$
);
```

### Achievement Unlock (Triggered)
Add to your achievement unlock logic:
```dart
// When achievement is unlocked
final response = await supabase.functions.invoke(
  'send-notification',
  body: {
    'user_ids': [userId],
    'title': '🏆 Achievement Unlocked!',
    'body': 'You\'ve completed $achievementName!',
    'type': 'achievement',
    'screen': 'achievements',
  },
);
```

### Goal Completion Alert
```dart
// When user completes daily goal
final response = await supabase.functions.invoke(
  'send-notification',
  body: {
    'user_ids': [userId],
    'title': '💪 Goal Achieved!',
    'body': 'You hit your calorie target today!',
    'type': 'goal',
    'screen': 'nutrition',
  },
);
```

---

## Troubleshooting

### Issue: "FCM token not generated"
**Solution:**
- Check Firebase configuration files are present:
  - `android/app/google-services.json`
  - `ios/Runner/GoogleService-Info.plist`
- Ensure Firebase is initialized in `main.dart`
- Check app has notification permissions

### Issue: "Notifications not showing on Android"
**Solution:**
- Verify POST_NOTIFICATIONS permission in AndroidManifest.xml
- Check notification channel is created
- Test on Android 13+ device (permission required)
- Ensure app is not in battery optimization mode

### Issue: "Notifications not showing on iOS"
**Solution:**
- Verify Push Notifications capability is enabled in Xcode
- Check Background Modes > Remote notifications is enabled
- Ensure APNs certificate is uploaded to Firebase
- Test on physical device (not simulator for push)

### Issue: "Edge Function returns 500 error"
**Solution:**
- Verify FCM_SERVER_KEY is set correctly:
  ```bash
  supabase secrets list
  ```
- Check Edge Function logs:
  ```bash
  supabase functions logs send-notification
  ```
- Ensure user_devices table has RLS policies set

### Issue: "Invalid FCM token"
**Solution:**
- Tokens expire when:
  - App is uninstalled and reinstalled
  - User clears app data
  - Token refresh is triggered by FCM
- The Edge Function automatically cleans up invalid tokens
- Ensure token refresh listener is working in NotificationService

---

## Security Best Practices

1. **Never expose FCM Server Key in client code**
   - Always use Supabase Edge Functions for sending
   - Store server key in Supabase secrets

2. **Use Row Level Security (RLS)**
   - Already configured in migration script
   - Users can only access their own tokens

3. **Validate notification data**
   - Don't send sensitive user data in notifications
   - Fetch data from database when notification is tapped

4. **Rate limiting**
   - Supabase automatically rate limits Edge Functions
   - Implement app-side throttling for notification triggers

5. **Token cleanup**
   - Invalid tokens are auto-removed by Edge Function
   - Tokens are deleted on user logout

---

## Next Steps

### Recommended Enhancements:
1. **Scheduled Notifications**
   - Implement time-zone aware reminders
   - Allow users to set preferred notification times in settings

2. **Notification Preferences**
   - Add settings UI for users to control notification types
   - Store preferences in user_profile table

3. **Analytics**
   - Track notification open rates
   - A/B test notification copy
   - Analyze optimal sending times

4. **Smart Notifications**
   - Use ML to predict best notification times
   - Personalize notification content based on user behavior
   - Send notifications only when user is likely to engage

---

## Support Resources

- [Firebase Cloud Messaging Documentation](https://firebase.google.com/docs/cloud-messaging)
- [Supabase Edge Functions Guide](https://supabase.com/docs/guides/functions)
- [Flutter Local Notifications Plugin](https://pub.dev/packages/flutter_local_notifications)
- [Firebase Messaging Flutter Plugin](https://pub.dev/packages/firebase_messaging)

---

## Summary

You've successfully implemented a complete push notification system with:
- ✅ Firebase Cloud Messaging integration
- ✅ Supabase backend for sending notifications
- ✅ Multi-channel Android notifications
- ✅ iOS APNs integration
- ✅ Automated token management
- ✅ Deep linking support

The system is now ready for testing and production deployment!
