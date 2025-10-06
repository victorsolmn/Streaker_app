#!/bin/bash

echo "🚀 Building and distributing Streaker app..."

# Clean the project
echo "Cleaning project..."
flutter clean
flutter pub get

# Build the APK (we'll use a simple build without health features)
echo "Building APK..."
flutter build apk --debug

# Check if build was successful
if [ $? -eq 0 ]; then
    echo "✅ APK built successfully!"
    echo "📱 APK location: build/app/outputs/flutter-apk/app-debug.apk"
    
    # Distribute via Firebase App Distribution
    echo "Distributing via Firebase App Distribution..."
    firebase appdistribution:distribute build/app/outputs/flutter-apk/app-debug.apk \
        --app 1:250385454172:android:9ed1e4caa6d5f882e7c299 \
        --groups testers \
        --release-notes "Latest build with Supabase + Firebase integration"
else
    echo "❌ Build failed. Please check the errors above."
    exit 1
fi