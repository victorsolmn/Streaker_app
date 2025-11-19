# Android Release Keystore Information

## Important - Keep This Information Secure!

### Keystore Details
- **Keystore File:** `android/app/streaker-release-key.jks`
- **Key Alias:** streaker
- **Validity:** 10,000 days (until 2053)
- **Certificate CN:** Streaker, OU=Development, O=Streaker Inc

### Security Notes
1. **NEVER commit the keystore file to public repositories**
2. **Back up the keystore file in a secure location**
3. **Keep the passwords secure and never share them**
4. **The `key.properties` file contains sensitive data - keep it private**

### Lost Keystore Recovery
If you lose this keystore:
- You won't be able to update your app on Google Play
- You'll need to create a new app with a different package name
- Users won't be able to update from the old app

### Backup Recommendations
1. Store a copy in a secure cloud storage (encrypted)
2. Keep a physical backup (USB drive in safe location)
3. Document the passwords in a password manager

### Files to Keep Private (already in .gitignore)
- `/android/key.properties`
- `/android/app/streaker-release-key.jks`

### Verification Command
To verify the AAB is properly signed:
```bash
jarsigner -verify -verbose -certs build/app/outputs/bundle/release/app-release.aab
```

### Build Command
To build a release AAB:
```bash
flutter build appbundle --release
```