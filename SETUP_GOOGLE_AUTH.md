# Google Sign-In Setup Guide

Depois que terminar essa configuração, execute com:
```bash
flutter run --dart-define=ENABLE_GOOGLE_SIGN_IN=true
flutter build apk --dart-define=ENABLE_GOOGLE_SIGN_IN=true
flutter build ios --dart-define=ENABLE_GOOGLE_SIGN_IN=true
```

## Android Setup

### 1. Get SHA-1 and SHA-256

Run from project root:
```bash
cd android
./gradlew signingReport
cd ..
```

Ou (Windows):
```bash
gradlew.bat signingReport
```

Copy the output values for **debugAndroidDebugKey** (usually both SHA-1 and SHA-256)

### 2. Add SHA-1/SHA-256 to Firebase Console

- Go to [Firebase Console](https://console.firebase.google.com)
- Select your project
- Navigate: **Project Settings** (gear icon) → **Your Apps** → Select Android app
- Under **SHA certificate fingerprints**, add both:
  - SHA-1
  - SHA-256

### 3. Download Updated google-services.json

- In Firebase Console: **Project Settings** → **Your Apps** → **Android**
- Download **google-services.json**
- Replace file at: `android/app/google-services.json`

---

## iOS Setup

### 1. Get Bundle ID

- Open `ios/Runner.xcodeproj` with Xcode
- Select **Runner** project → **Build Settings**
- Search for **Bundle Identifier**
- Copy the value (e.g., `com.example.dante-sleep`)

### 2. Add/Update iOS App in Firebase

- Firebase Console → **Project Settings** → **Your Apps**
- Click **Add App** (if not already added) → **iOS**
- Enter Bundle ID
- Download **GoogleService-Info.plist**

### 3. Add GoogleService-Info.plist to Xcode

- In Xcode, right-click **Runner** folder
- Select **Add Files to "Runner"**
- Select the downloaded **GoogleService-Info.plist**
- Ensure **Copy items if needed** is checked
- Target membership: **Runner**

### 4. Configure URL Scheme

- Xcode: Select **Runner** project → **Runner** target → **Info** tab
- Look for **URL Types** (or add it if missing)
- Add new URL Type:
  - **Identifier**: `com.googleusercontent.apps.YOUR_REVERSED_CLIENT_ID`
  - **URL Schemes**: `com.googleusercontent.apps.YOUR_REVERSED_CLIENT_ID`

To find YOUR_REVERSED_CLIENT_ID:
- Open **GoogleService-Info.plist** with text editor
- Look for `REVERSED_CLIENT_ID` value
- Example: `com.googleusercontent.apps.123456789-abcdefghijk.apps.googleusercontent.com`

### 5. Update Info.plist

- In Xcode, open **Info.plist** (under Runner)
- Add these keys (copy from GoogleService-Info.plist if needed):
  - `CFBundleIdentifier` (already set usually)
  - `CFBundleDisplayName` (e.g., Dante Sleep)

---

## Firebase Console - Google Provider

### Enable Google Sign-In

- Firebase Console → Your Project → **Authentication** → **Sign-in method**
- Click **Google**
- Toggle **Enable**
- Set **Project public name**: `Dante Sleep` (or your app name)
- **Support email**: your email
- Click **Save**

---

## Testing

1. **Clean builds**:
```bash
flutter clean
rm -rf ios/Pods
rm ios/Podfile.lock
```

2. **Run on Android**:
```bash
flutter run --dart-define=ENABLE_GOOGLE_SIGN_IN=true
```

3. **Run on iOS**:
```bash
flutter run --dart-define=ENABLE_GOOGLE_SIGN_IN=true
```

4. **Test flow**:
   - Launch app
   - Tap "Continue with Google" button (now visible)
   - Select Google account
   - Verify automatic login and redirect to main app

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| `PlatformException (google_sign_in, 10, ...)` on Android | SHA-1/SHA-256 mismatch. Re-run `gradlew signingReport` and update Firebase |
| App crashes on iOS after Google tap | GoogleService-Info.plist missing or URL scheme incorrect |
| Google button doesn't appear | `ENABLE_GOOGLE_SIGN_IN` flag not set or `bool.fromEnvironment` default is false |
| Settings not syncing after login | Check user document created in Firestore under `users/{uid}` |

---

## After Setup

Once everything works, update this repo with:
1. Updated `android/app/google-services.json`
2. Updated `ios/Runner/GoogleService-Info.plist`
3. Commit with message: `feat: enable Google Sign-In`

Then run:
```bash
flutter run --dart-define=ENABLE_GOOGLE_SIGN_IN=true
```

to confirm the button appears and authentication works.
