#!/bin/bash

# Streaker App Screenshot Capture Script
# This script helps you capture all required screenshots for the website

echo "🔥 Streaker Screenshot Capture Tool"
echo "===================================="
echo ""

# Create screenshots directory
mkdir -p website/assets/screenshots

echo "📱 Please follow these steps:"
echo ""
echo "1. Run your Flutter app:"
echo "   cd /Users/Vicky/Streaks_Flutter"
echo "   flutter run"
echo ""
echo "2. For iOS Simulator (Recommended):"
echo "   - Use iPhone 14 Pro simulator"
echo "   - Navigate to each screen"
echo "   - Press Cmd+S to capture"
echo ""
echo "3. Required Screenshots:"
echo "   □ Dashboard (main view with all stats)"
echo "   □ Nutrition Tracking screen"
echo "   □ Sleep Tracking screen"
echo "   □ Steps/Activity screen"
echo "   □ Achievements/Badges screen"
echo "   □ Profile screen"
echo "   □ Streak Calendar view"
echo ""
echo "4. Optional Screenshots:"
echo "   □ Onboarding screens"
echo "   □ Settings screen"
echo "   □ Social features"
echo ""
echo "5. Screenshot Settings:"
echo "   - Size: 390 × 844px (iPhone 14 Pro)"
echo "   - Format: PNG"
echo "   - Quality: High"
echo ""
echo "6. Save screenshots to:"
echo "   /Users/Vicky/Streaks_Flutter/website/assets/screenshots/"
echo ""
echo "Press Enter when ready to open the Flutter app..."
read

# Launch Flutter app
cd /Users/Vicky/Streaks_Flutter
flutter run

echo ""
echo "✅ After capturing, your screenshots will be in:"
echo "   ~/Desktop (iOS Simulator)"
echo ""
echo "Move them to: website/assets/screenshots/"