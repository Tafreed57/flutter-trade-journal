# 🔧 Trading Journal Setup Guide

Complete setup instructions for running the Trading Journal app with Firebase authentication.

## Prerequisites

- Flutter SDK 3.10+
- Dart 3.0+
- Firebase account (free tier works)
- Android Studio or VS Code
- Node.js (for Firebase CLI)

---

## Step 1: Clone and Install Dependencies

```bash
git clone https://github.com/yourusername/trade_journal_app.git
cd trade_journal_app
flutter pub get
```

---

## Step 2: Firebase Project Setup

### 2.1 Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Add Project"
3. Name it (e.g., "trading-journal")
4. Disable Google Analytics (optional)
5. Click "Create Project"

### 2.2 Enable Authentication

1. In Firebase Console, go to **Build → Authentication**
2. Click "Get Started"
3. Go to **Sign-in method** tab
4. Enable **Email/Password**:
   - Click "Email/Password"
   - Toggle "Enable"
   - Click "Save"
5. Enable **Google**:
   - Click "Google"
   - Toggle "Enable"
   - Select a support email
   - Click "Save"

### 2.3 Set Up Firestore

1. Go to **Build → Firestore Database**
2. Click "Create Database"
3. Choose "Start in test mode" (for development)
4. Select a region close to you
5. Click "Enable"

### 2.4 Firestore Security Rules (Production)

Replace the default rules with:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can only read/write their own data
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Default deny all
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

---

## Step 3: Configure Flutter App with Firebase

### 3.1 Install FlutterFire CLI

```bash
dart pub global activate flutterfire_cli
```

### 3.2 Configure Firebase

```bash
cd trade_journal_app
flutterfire configure
```

This will:
- Detect your Firebase projects
- Ask which platforms to configure (select Android, iOS, Web, Windows as needed)
- Generate `lib/firebase_options.dart`
- Create platform-specific config files

### 3.3 Android-Specific Setup (for Google Sign-In)

1. Get your SHA-1 fingerprint:
   ```bash
   cd android
   ./gradlew signingReport
   ```
   Copy the SHA-1 from the debug variant.

2. In Firebase Console:
   - Go to **Project Settings → General**
   - Scroll to your Android app
   - Click "Add fingerprint"
   - Paste the SHA-1

3. Download the new `google-services.json`:
   - In Project Settings, click the download icon for Android
   - Replace `android/app/google-services.json`

### 3.4 iOS-Specific Setup (for Google Sign-In)

1. In Firebase Console, download `GoogleService-Info.plist`
2. Add it to `ios/Runner/` in Xcode
3. Add URL scheme to `ios/Runner/Info.plist`:
   ```xml
   <key>CFBundleURLTypes</key>
   <array>
     <dict>
       <key>CFBundleTypeRole</key>
       <string>Editor</string>
       <key>CFBundleURLSchemes</key>
       <array>
         <string>com.googleusercontent.apps.YOUR_REVERSED_CLIENT_ID</string>
       </array>
     </dict>
   </array>
   ```
   (Get the reversed client ID from GoogleService-Info.plist)

---

## Step 4: Environment Variables

Create a `.env` file in the project root:

```bash
# Market Data API (optional - app works with mock data without this)
FINNHUB_API_KEY=your_finnhub_api_key

# Note: Firebase config is in firebase_options.dart (auto-generated)
# Do NOT put Firebase keys in .env
```

### Get Finnhub API Key (Optional)

1. Go to [finnhub.io](https://finnhub.io/)
2. Sign up for free
3. Copy your API key from the dashboard
4. Add to `.env` file

---

## Step 5: Run the App

### Development

```bash
# Run on connected device/emulator
flutter run

# Run on specific platform
flutter run -d chrome    # Web
flutter run -d windows   # Windows
flutter run -d android   # Android
flutter run -d ios       # iOS
```

### Build for Production

```bash
# Android APK
flutter build apk --release

# iOS
flutter build ios --release

# Web
flutter build web --release
```

---

## Step 6: Verify Everything Works

### Check for Errors

```bash
# Analyze code
flutter analyze

# Run tests
flutter test
```

### Test Auth Flow

1. Run the app
2. You should see the login screen
3. Try signing up with email/password
4. Try Google Sign-In
5. Check Firebase Console → Authentication → Users
6. Check Firestore → users collection

---

## Troubleshooting

### "No Firebase App" Error
- Make sure `flutterfire configure` completed successfully
- Check that `firebase_options.dart` has your actual config

### Google Sign-In Not Working (Android)
- Verify SHA-1 fingerprint is added in Firebase Console
- Re-download `google-services.json` after adding SHA-1

### Google Sign-In Not Working (iOS)
- Check URL scheme in Info.plist
- Make sure GoogleService-Info.plist is added to Xcode project

### Firestore Permission Denied
- Check security rules allow authenticated users
- Verify the user is logged in before database operations

---

## Environment Summary

| Variable | Required | Description |
|----------|----------|-------------|
| `FINNHUB_API_KEY` | No | Market data API (mock data used if missing) |
| Firebase config | Yes | Auto-generated via `flutterfire configure` |

---

## Commands Cheat Sheet

```bash
# Install dependencies
flutter pub get

# Generate Hive adapters (after model changes)
flutter pub run build_runner build

# Analyze code
flutter analyze

# Run tests
flutter test

# Run specific test file
flutter test test/services/analytics_service_test.dart

# Run app
flutter run -d <device>

# Build
flutter build apk --release
```

---

## Support

If you encounter issues:
1. Run `flutter doctor -v` and check for problems
2. Check the [Flutter documentation](https://docs.flutter.dev/)
3. Check [Firebase Flutter documentation](https://firebase.flutter.dev/)

