# Release Status - Trading Journal App

**Generated:** December 17, 2025  
**Version:** 1.0.0+1

---

## Summary

| Platform | Build Status | Deploy Status | Notes |
|----------|--------------|---------------|-------|
| **Web** | ✅ Built | ⚠️ Needs Firebase CLI | `build/web/` ready for deployment |
| **Android** | ⚠️ Config Ready | ⚠️ Needs signing setup | Missing `google-services.json` + keystore |
| **Windows** | ⚠️ Config Ready | N/A | Build command available |
| **macOS** | ⚠️ Requires Mac | N/A | Cannot build on Windows |
| **Linux** | ⚠️ Requires Linux | N/A | Cannot build on Windows |

---

## Environment Verification

### Flutter
```
Flutter 3.38.3 • channel stable
Dart 3.10.1 • DevTools 2.51.1
```

### Java
```
Java 25.0.1 LTS
```

### Platform Targets Enabled
- ✅ web
- ✅ android
- ✅ windows-desktop
- ✅ linux-desktop (build requires Linux)
- ✅ macos-desktop (build requires macOS)
- ✅ ios (build requires macOS)

---

## Build Artifacts

### Web Build ✅ COMPLETE
- **Location:** `build/web/`
- **Command used:** `flutter build web --release`
- **Size:** ~15MB (with CanvasKit)
- **Features:**
  - Tree-shaken fonts (99% reduction)
  - Custom loading screen
  - PWA manifest
  - Firebase Hosting config ready

### Android Build ⚠️ CONFIGURATION REQUIRED

**Missing Files:**

1. **`android/app/google-services.json`**
   - Download from: [Firebase Console](https://console.firebase.google.com)
   - Path: Project Settings → General → Your apps → Android → Download

2. **`android/key.properties`**
   - Template provided: `android/key.properties.example`
   - Create keystore first:
   ```bash
   keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```

**Build Commands:**
```bash
# APK (for testing)
flutter build apk --release

# AAB (for Play Store)
flutter build appbundle --release
```

**Expected Output:**
- APK: `build/app/outputs/flutter-apk/app-release.apk`
- AAB: `build/app/outputs/bundle/release/app-release.aab`

### Windows Build
**Command:**
```bash
flutter build windows --release
```
**Output:** `build/windows/x64/runner/Release/`

---

## Deployment Steps

### Web → Firebase Hosting

**Prerequisite:** Install Firebase CLI

```bash
# Option 1: npm (if PowerShell execution policy allows)
npm install -g firebase-tools

# Option 2: Standalone installer
# Download from: https://firebase.google.com/docs/cli#install-cli-windows
```

**Deploy:**
```bash
firebase login
firebase use trading-app-68902
firebase deploy --only hosting
```

**Expected URL:** `https://trading-app-68902.web.app`

### Android → Google Play Store

1. **Create app in Play Console:**
   - https://play.google.com/console

2. **Set up Internal Testing:**
   - Upload AAB to Internal Testing track
   - Add tester emails
   - Get opt-in link

3. **Production release:**
   - Complete store listing
   - Pass app review
   - Roll out to production

---

## Required Environment Variables

| Variable | Required | Purpose |
|----------|----------|---------|
| `FINNHUB_API_KEY` | No | Real market data (falls back to mock) |
| `API_BASE_URL` | No | Override API endpoint |
| `WS_URL` | No | Override WebSocket endpoint |

**Build with env vars:**
```bash
flutter build web --release \
  --dart-define=FINNHUB_API_KEY=your_key_here
```

---

## Security Checklist

- [x] `android/key.properties` is gitignored
- [x] `*.jks` and `*.keystore` are gitignored
- [x] `.env` files are gitignored
- [x] `tool/release.env` is gitignored
- [x] No API keys hardcoded in source
- [x] Firebase credentials are in generated files (okay to commit)

---

## Test Results

### Smoke Tests
- **Status:** ✅ All passed
- **Command:** `flutter test test/smoke_test.dart`

### Full Test Suite
- **Status:** ✅ 80 tests passed
- **Command:** `flutter test`

---

## Known Issues / Blockers

### 1. PowerShell Execution Policy
- **Issue:** npm scripts blocked on this system
- **Impact:** Cannot install Firebase CLI via npm
- **Workaround:** Use standalone Firebase CLI installer or run from CMD

### 2. Missing Firebase Android Config
- **Issue:** `google-services.json` not present
- **Impact:** Firebase features won't work on Android
- **Fix:** Download from Firebase Console

### 3. No Android Keystore
- **Issue:** Release signing not configured
- **Impact:** Cannot submit to Play Store
- **Fix:** Generate keystore and create `key.properties`

---

## Next Steps

### Immediate (Required for Release)

1. **Fix PowerShell or use CMD:**
   ```cmd
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```
   Or use CMD: `npm install -g firebase-tools`

2. **Download google-services.json:**
   - Go to Firebase Console → Project Settings → Android
   - Download and place in `android/app/`

3. **Generate Android keystore:**
   ```bash
   keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```

4. **Create key.properties:**
   ```
   storePassword=YOUR_PASSWORD
   keyPassword=YOUR_PASSWORD
   keyAlias=upload
   storeFile=../upload-keystore.jks
   ```

5. **Deploy Web:**
   ```bash
   firebase deploy --only hosting
   ```

6. **Build and test Android APK:**
   ```bash
   flutter build apk --release
   ```

### Before Public Release

- [ ] Add crash reporting (Firebase Crashlytics recommended)
- [ ] Create privacy policy
- [ ] Create terms of service
- [ ] Prepare store listing assets (screenshots, descriptions)
- [ ] Set up CI/CD (GitHub Actions recommended)

---

## Files Created This Session

| File | Purpose |
|------|---------|
| `tool/release.env.example` | Environment variable template |
| `tool/build-release.ps1` | PowerShell build script |
| `android/key.properties.example` | Signing config template |
| `.firebaserc` | Firebase project configuration |
| `RELEASE_STATUS.md` | This file |

---

## Commands Reference

```bash
# Clean build
flutter clean && flutter pub get

# Run tests
flutter test

# Build web
flutter build web --release

# Build Android APK
flutter build apk --release

# Build Android AAB (Play Store)
flutter build appbundle --release

# Build Windows
flutter build windows --release

# Deploy web to Firebase
firebase deploy --only hosting

# With environment variables
flutter build web --release --dart-define=FINNHUB_API_KEY=xxx
```

