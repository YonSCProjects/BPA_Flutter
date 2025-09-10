# iOS Deployment Guide - BPA Flutter App

## Executive Summary
The BPA Flutter app is **iOS-ready** with cross-platform code. Only iOS-specific configuration and Mac access for building are needed.

## iOS Deployment Requirements Without Breaking Android

### ✅ Code Changes Already Made (Platform-Safe)
- **FlutterSecureStorage** updated with iOS options in `google_auth_service.dart`
- Both Android and iOS options coexist safely using platform-specific configurations

### 📋 iOS Configuration Required (Won't Affect Android)

#### 1. Fix Bundle Identifier
**File**: `ios/Runner.xcodeproj/project.pbxproj`
```
Change: com.bpa.studenttracking.bpapp
To:     com.bpa.student
```
**Impact**: iOS-only, Android unaffected

#### 2. Add Firebase iOS Configuration
1. Go to Firebase Console → Project Settings
2. Add iOS app with bundle ID: `com.bpa.student`
3. Download `GoogleService-Info.plist`
4. Place in `ios/Runner/GoogleService-Info.plist`

**Impact**: Separate file from Android's `google-services.json`

#### 3. Update Info.plist
**File**: `ios/Runner/Info.plist`

Add before `</dict>`:
```xml
<!-- Google Sign-In URL Scheme -->
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string>com.bpa.student</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>com.bpa.student</string>
        </array>
    </dict>
</array>

<!-- Network permissions -->
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
```

## 🔒 Why These Changes Are Safe for Android

### Platform Isolation
- **iOS folder** (`ios/`) - Ignored by Android builds
- **Android folder** (`android/`) - Remains untouched
- **Dart code** - Uses conditional platform options

### Shared Resources (Work on Both)
- `assets/service_account.json` - Platform agnostic
- Firebase backend - Same project, different configs
- Google Sheets API - HTTP-based
- Flutter UI - Renders identically

## 💻 Mac Requirements

### What You Can Do on Windows ✅
- All configuration file changes
- Firebase setup and downloads
- Code updates (already done)
- Android testing and deployment

### What Requires a Mac ❌
- Building iOS app (.ipa file)
- Testing on iOS Simulator/device
- Code signing with Apple certificates
- App Store submission

## 🚀 Mac Access Options

### 1. Cloud Services
| Service | Cost | Best For |
|---------|------|----------|
| **Codemagic** | Free tier (500 min/month) | Initial testing |
| **MacinCloud** | ~$1/hour | Final submission |
| **MacStadium** | $79/month | Long-term development |
| **AWS EC2 Mac** | ~$25/day | Not recommended (expensive) |

### 2. Local Options
- Borrow a friend's Mac (2-4 hours needed)
- Computer rental shops
- University/library Macs
- Local developer communities

### 3. CI/CD Approach (Recommended)
1. Use **Codemagic free tier** for builds
2. Rent **MacinCloud** for 2-3 hours for submission
3. Total cost: ~$20-30 one-time

## 📱 Deployment Process

### Phase 1: Preparation (Windows) ✅
```bash
# 1. Make configuration changes
# 2. Test on Android
flutter clean
flutter pub get
flutter run --release
```

### Phase 2: iOS Build (Mac/Cloud)
```bash
# 1. Clone repository
git clone https://github.com/YonSCProjects/BPA_Flutter.git
cd BPA_Flutter

# 2. Install dependencies
flutter pub get

# 3. Open Xcode
open ios/Runner.xcworkspace

# 4. Configure signing
# - Add Apple Developer account
# - Select team
# - Configure provisioning

# 5. Build
flutter build ios --release
```

### Phase 3: Testing
```bash
# Test on simulator
flutter run -d "iPhone 15"

# Test on device (if available)
flutter run --release
```

### Phase 4: App Store Submission
1. Archive in Xcode
2. Upload to App Store Connect
3. Submit for review

## 📊 Time Estimates

| Task | Duration | Platform |
|------|----------|----------|
| Configuration changes | 1-2 hours | Windows |
| Firebase setup | 30 minutes | Windows |
| Mac setup & build | 2-3 hours | Mac/Cloud |
| Testing | 1-2 hours | Mac/Cloud |
| App Store submission | 1-2 hours | Mac/Cloud |
| **Total** | **5-9 hours** | |

## ✅ Checklist

### Windows Tasks
- [ ] Update bundle identifier in project.pbxproj
- [ ] Download GoogleService-Info.plist from Firebase
- [ ] Update Info.plist with URL schemes
- [ ] Test Android build still works

### Mac Tasks
- [ ] Install Flutter and Xcode
- [ ] Configure code signing
- [ ] Run on iOS Simulator
- [ ] Build release IPA
- [ ] Submit to App Store

## 🎯 Expected Results

After implementation:
- **Android**: Continues working exactly as before ✅
- **iOS**: Full feature parity with Android ✅
- **Codebase**: Single codebase for both platforms ✅
- **Maintenance**: Updates deploy to both platforms ✅

## 🔄 Rollback Plan

If issues occur:
1. iOS changes are isolated in `ios/` folder
2. Remove iOS-specific options from Dart code
3. Continue with Android-only deployment
4. Address iOS separately later

## 📝 Important Notes

- All current dependencies support iOS
- No native code changes required
- Service account integration works identically
- Hebrew RTL support perfect on iOS
- Firebase dropdowns will work on iOS

## 🚨 Common Issues & Solutions

| Issue | Solution |
|-------|----------|
| Bundle ID mismatch | Ensure `com.bpa.student` everywhere |
| OAuth not working | Add URL schemes to Info.plist |
| Firebase crash | Add GoogleService-Info.plist |
| Build fails | Check Xcode signing configuration |

## 📚 Resources

- [Flutter iOS Setup](https://flutter.dev/docs/get-started/install/macos)
- [Firebase iOS Setup](https://firebase.google.com/docs/ios/setup)
- [Codemagic Documentation](https://docs.codemagic.io)
- [MacinCloud Setup](https://www.macincloud.com/flutter)

---

**Status**: Code ready, configuration pending
**Android Impact**: NONE - All changes are iOS-specific
**Estimated Cost**: $0-30 (using free/cheap cloud services)
**Timeline**: 1 day with Mac access

**Last Updated**: January 10, 2025