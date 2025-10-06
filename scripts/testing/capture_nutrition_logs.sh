#!/bin/bash

# Nutrition Feature Log Capture Script
# This script captures logs from your Android device when testing the nutrition feature

ADB_PATH=~/Library/Android/sdk/platform-tools/adb

echo "🔍 ====================================="
echo "📱 NUTRITION FEATURE LOG CAPTURE"
echo "🔍 ====================================="
echo ""

# Check if ADB is available
if [ ! -f "$ADB_PATH" ]; then
    echo "❌ ADB not found at $ADB_PATH"
    echo "Please install Android SDK platform tools"
    exit 1
fi

# Check connected devices
echo "📱 Checking for connected devices..."
DEVICES=$($ADB_PATH devices | grep -v "List" | grep "device")

if [ -z "$DEVICES" ]; then
    echo "❌ No Android device connected!"
    echo ""
    echo "📝 To connect your Android device:"
    echo "1. Enable Developer Options on your phone:"
    echo "   - Go to Settings → About Phone"
    echo "   - Tap 'Build Number' 7 times"
    echo ""
    echo "2. Enable USB Debugging:"
    echo "   - Go to Settings → Developer Options"
    echo "   - Enable 'USB Debugging'"
    echo ""
    echo "3. Connect your phone via USB cable"
    echo "4. Accept the 'Allow USB debugging' popup on your phone"
    echo "5. Run this script again"
    exit 1
fi

echo "✅ Device connected: $DEVICES"
echo ""

# Clear existing logs
echo "🧹 Clearing old logs..."
$ADB_PATH logcat -c

echo "📝 Starting log capture..."
echo "📱 Now open the Streaks app on your phone and test the nutrition feature"
echo "📸 Try scanning food with: Rice, Dal, Vegetable Salad"
echo ""
echo "🔍 Capturing logs (press Ctrl+C to stop)..."
echo "=========================================="
echo ""

# Capture logs with nutrition-related filters
$ADB_PATH logcat -v time | grep -E "(flutter|nutrition|NUTRITION|Food|food|FOOD|Gemini|gemini|Indian|Analyzing|calories|Calories|📸|🍴|📱|✅|❌|⚠️|🔑|📊)"