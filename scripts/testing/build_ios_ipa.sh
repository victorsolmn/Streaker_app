#!/bin/bash

# Streaks Flutter iOS IPA Build Script
# This script builds an IPA file for distribution

set -e  # Exit on error

echo "🏗️  Starting iOS build process for Streaks Flutter..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if we're in the right directory
if [ ! -f "pubspec.yaml" ]; then
    echo -e "${RED}Error: pubspec.yaml not found. Please run this script from the project root.${NC}"
    exit 1
fi

# Step 1: Clean previous builds
echo -e "${YELLOW}🧹 Cleaning previous builds...${NC}"
flutter clean
rm -rf ios/build

# Step 2: Get dependencies
echo -e "${YELLOW}📦 Getting dependencies...${NC}"
flutter pub get

# Step 3: Pod install
echo -e "${YELLOW}🔧 Installing iOS pods...${NC}"
cd ios
pod install
cd ..

# Step 4: Build iOS in release mode
echo -e "${YELLOW}🔨 Building Flutter iOS app in release mode...${NC}"
flutter build ios --release --no-codesign

# Step 5: Archive the app
echo -e "${YELLOW}📱 Creating iOS archive...${NC}"
cd ios

# Create ExportOptions.plist if it doesn't exist
if [ ! -f "ExportOptions.plist" ]; then
    echo -e "${YELLOW}Creating ExportOptions.plist...${NC}"
    cat > ExportOptions.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>ad-hoc</string>
    <key>teamID</key>
    <string>YOUR_TEAM_ID</string>
    <key>compileBitcode</key>
    <false/>
    <key>uploadBitcode</key>
    <false/>
    <key>uploadSymbols</key>
    <true/>
</dict>
</plist>
EOF
    echo -e "${RED}⚠️  Please update ExportOptions.plist with your Team ID${NC}"
fi

# Build archive
xcodebuild -workspace Runner.xcworkspace \
    -scheme Runner \
    -configuration Release \
    -archivePath build/Runner.xcarchive \
    -allowProvisioningUpdates \
    archive

# Check if archive was successful
if [ ! -d "build/Runner.xcarchive" ]; then
    echo -e "${RED}❌ Archive failed. Please check your code signing settings in Xcode.${NC}"
    exit 1
fi

# Step 6: Export IPA
echo -e "${YELLOW}📦 Exporting IPA file...${NC}"
xcodebuild -exportArchive \
    -archivePath build/Runner.xcarchive \
    -exportPath build/ipa \
    -exportOptionsPlist ExportOptions.plist \
    -allowProvisioningUpdates

# Check if IPA was created
if [ -f "build/ipa/Runner.ipa" ]; then
    echo -e "${GREEN}✅ IPA successfully created at: ios/build/ipa/Runner.ipa${NC}"
    
    # Get file size
    SIZE=$(du -h build/ipa/Runner.ipa | cut -f1)
    echo -e "${GREEN}📊 IPA Size: $SIZE${NC}"
    
    # Create distribution folder
    mkdir -p ../distribution
    cp build/ipa/Runner.ipa ../distribution/StreaksFlutter-$(date +%Y%m%d-%H%M%S).ipa
    
    echo -e "${GREEN}📁 IPA copied to distribution folder${NC}"
    echo ""
    echo -e "${GREEN}🎉 Build complete! You can now distribute your app using:${NC}"
    echo "  1. Firebase App Distribution"
    echo "  2. TestFlight (upload via Xcode or Transporter)"
    echo "  3. Diawi.com for quick sharing"
    echo "  4. Direct installation via Xcode"
else
    echo -e "${RED}❌ IPA creation failed. Please check the build logs above.${NC}"
    exit 1
fi

cd ..

# Optional: Upload to Firebase App Distribution
echo ""
echo -e "${YELLOW}📤 To upload to Firebase App Distribution, run:${NC}"
echo "firebase appdistribution:distribute distribution/StreaksFlutter-*.ipa \\"
echo "  --app YOUR_FIREBASE_APP_ID \\"
echo "  --groups 'testers' \\"
echo "  --release-notes 'Latest build'"