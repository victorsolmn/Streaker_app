# Quick Deploy Guide - Streaker App

## 📱 Android Device Installation

### Prerequisites
- Android device connected via USB
- USB debugging enabled
- ADB tools installed

### Quick Deploy Commands
```bash
# 1. Check connected devices
adb devices

# 2. Build release APK
cd /tmp/streaker_app
flutter build apk --release

# 3. Install on device (handles signature conflicts)
adb install -r -d build/app/outputs/flutter-apk/app-release.apk

# 4. Launch app
adb shell am start -n com.streaker.streaker/.MainActivity
```

### Troubleshooting

#### Signature Conflict Error
Use the `-r -d` flags with adb install to replace and allow downgrade:
```bash
adb install -r -d app-release.apk
```

#### App Already Running
Force stop before reinstalling:
```bash
adb shell am force-stop com.streaker.streaker
```

#### Complete Uninstall
```bash
adb uninstall com.streaker.streaker
```

## 📦 Build Information
- **Package**: com.streaker.streaker
- **Version**: 1.0.10 (Build 12)
- **APK Size**: ~61.3MB
- **Build Output**: `/build/app/outputs/flutter-apk/app-release.apk`

## ✅ Last Successful Deployment
- **Date**: September 30, 2025
- **Device**: Samsung SM S908E (R5CT32TLWGB)
- **Method**: USB Cable installation
- **Status**: Successfully installed and launched

## 🔗 Related Files
- Knowledge base: `knowledge.md`
- Architecture: `fearchitecture.md`
- Deployment log: `DEPLOYMENT_LOG.md`
- Play Store AAB: `/Users/Vicky/Desktop/streaker_v1.0.10_build12.aab`