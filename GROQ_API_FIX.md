# Fix for Workout Chat Feature - Groq API Key Setup

## ⚠️ Issue Identified
The workout chat feature is failing because the Groq API key is not configured. It's currently set to a placeholder value.

## ✅ Quick Fix Instructions

### Step 1: Get Your FREE Groq API Key
1. Visit: https://console.groq.com/
2. Click "Sign Up" for a free account
3. Verify your email
4. Go to "API Keys" in the left sidebar
5. Click "Create API Key"
6. Copy the generated key (starts with "gsk_...")

### Step 2: Add API Key to Your App

Edit the file: `/tmp/streaker_app/lib/config/api_config.dart`

Replace line 14:
```dart
static const String grokApiKey = 'YOUR_GROQ_API_KEY_HERE';
```

With your actual key:
```dart
static const String grokApiKey = 'gsk_YOUR_ACTUAL_KEY_HERE';
```

### Step 3: Rebuild and Deploy
```bash
cd /tmp/streaker_app
flutter build apk --release
adb install -r -d build/app/outputs/flutter-apk/app-release.apk
```

## 📝 Important Notes

### About Groq vs Grok
- **Groq** (what we're using): Fast AI inference service with free tier
- **Grok** (X.AI): Different service, not what this app uses
- The naming confusion exists in the codebase but doesn't affect functionality

### Free Tier Limits
Groq provides generous free tier:
- 30 requests per minute
- 14,400 requests per day
- Perfect for personal fitness coaching

### Security Best Practices
- Don't commit the API key to Git
- Consider using environment variables for production
- Each user could potentially use their own API key

## 🧪 Testing the Fix
After adding your API key:
1. Open the app
2. Go to the AI Coach / Chat screen
3. Ask a question like "How can I lose weight?"
4. You should get a personalized response instead of the error

## 🚀 Alternative Models
If you want to experiment, Groq supports these models:
- `mixtral-8x7b-32768` (current - best for detailed responses)
- `llama3-70b-8192` (very capable)
- `llama3-8b-8192` (faster, lighter)

Change the model in `api_config.dart` line 15.

## 🤝 Need Help?
- Groq Console: https://console.groq.com/
- Groq Docs: https://console.groq.com/docs/quickstart