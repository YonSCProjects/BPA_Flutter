# iOS Deployment Preparation Checklist

## 📅 Ready for Tomorrow's iOS Configuration Session

### 🎯 Current Status
- ✅ Flutter code is iOS-ready (FlutterSecureStorage updated)
- ✅ All dependencies support iOS
- ✅ Android functionality preserved and tested
- ⏳ iOS configuration files pending

## 📋 Tomorrow's Tasks (Windows)

### 1. Firebase iOS Setup (30 minutes)
- [ ] Go to [Firebase Console](https://console.firebase.google.com)
- [ ] Navigate to: Project Settings → Add App → iOS
- [ ] Enter Bundle ID: `com.bpa.student`
- [ ] Download `GoogleService-Info.plist`
- [ ] Save to: `ios/Runner/GoogleService-Info.plist`

### 2. Fix Bundle Identifier (15 minutes)
**File**: `ios/Runner.xcodeproj/project.pbxproj`

- [ ] Open in text editor (VS Code/Notepad++)
- [ ] Find & Replace ALL occurrences:
  ```
  FIND:    com.bpa.studenttracking.bpapp
  REPLACE: com.bpa.student
  ```
- [ ] Should be ~6 replacements (3 Debug, 3 Release)

### 3. Update Info.plist (15 minutes)
**File**: `ios/Runner/Info.plist`

- [ ] Open in text editor
- [ ] Add before the final `</dict>` tag:

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

<!-- Network permissions for API calls -->
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>

<!-- Optional: Camera permission for future features -->
<key>NSCameraUsageDescription</key>
<string>This app uses camera to scan documents for student data entry</string>

<!-- Optional: Photo library access -->
<key>NSPhotoLibraryUsageDescription</key>
<string>This app accesses photos to attach student work samples</string>
```

### 4. Verify Android Still Works (15 minutes)
```bash
# Clean and rebuild
flutter clean
flutter pub get

# Test Android build
flutter build apk --release

# Run on device
flutter run --release
```

### 5. Prepare for iOS Build (10 minutes)
```bash
# Test iOS build preparation (won't complete without Mac)
flutter build ios --release --no-codesign

# This will fail at the end (expected on Windows)
# But it verifies configuration is correct
```

## 📁 Files to Check/Edit

| File | Action | Location |
|------|--------|----------|
| `GoogleService-Info.plist` | Add new | `ios/Runner/` |
| `project.pbxproj` | Edit bundle ID | `ios/Runner.xcodeproj/` |
| `Info.plist` | Add URL schemes | `ios/Runner/` |

## ⚠️ Important Reminders

### DO NOT:
- ❌ Delete any Android files
- ❌ Change Android package name
- ❌ Modify `android/` folder
- ❌ Remove Android options from Dart code

### DO:
- ✅ Only ADD iOS files
- ✅ Only ADD iOS configurations
- ✅ Test Android after each change
- ✅ Commit changes frequently

## 🔧 Required Tools

### On Windows (for tomorrow):
- [x] Text editor (VS Code/Notepad++)
- [x] Web browser (for Firebase Console)
- [x] Flutter SDK
- [x] Android Studio/device for testing

### For Mac (later):
- [ ] Xcode 14+
- [ ] Apple Developer Account
- [ ] Mac with macOS 12+
- [ ] ~20GB free space

## 📊 Time Estimate

| Task | Duration |
|------|----------|
| Firebase setup | 30 min |
| Bundle ID fix | 15 min |
| Info.plist update | 15 min |
| Testing | 15 min |
| **Total** | **~1.5 hours** |

## 🚀 After Tomorrow's Preparation

You'll have:
1. iOS configuration complete ✅
2. Android still working ✅
3. Ready for Mac build when available ✅

## 💰 Mac Access Options (When Ready)

### Option A: Codemagic (Recommended for Testing)
- Free tier: 500 build minutes/month
- No credit card required
- Can build and test

### Option B: MacinCloud (For Final Submission)
- Pay-as-you-go: ~$1/hour
- Need ~2-3 hours total
- Total cost: ~$20-30

### Option C: Local Mac
- Borrow from friend/colleague
- University computer lab
- Local Apple Store (for quick tests)

## 📝 Notes Section

### Firebase Project Info:
- Project ID: `bpapp-firebase-485c1`
- Bundle ID to use: `com.bpa.student`
- Current Android package: `com.bpa.student` ✅

### OAuth Configuration:
- Client ID will be auto-created when adding iOS app
- No additional OAuth setup needed (uses existing)

### Questions to Consider:
1. Do you have an Apple Developer Account? ($99/year)
2. Preferred app name for iOS? (Currently: BPApp)
3. App Store category? (Education/Productivity)

## ✅ Success Criteria

Tomorrow's session is successful when:
- [ ] All iOS config files added
- [ ] Bundle ID matches Android (`com.bpa.student`)
- [ ] Android build still works
- [ ] No errors in `flutter doctor`
- [ ] Ready for Mac deployment

## 🔗 Quick Links

- [Firebase Console](https://console.firebase.google.com/project/bpapp-firebase-485c1)
- [Flutter iOS Docs](https://docs.flutter.dev/deployment/ios)
- [Apple Developer](https://developer.apple.com)
- [Codemagic](https://codemagic.io)
- [MacinCloud](https://www.macincloud.com)

## 📞 Troubleshooting

### Common Issues:

**Issue**: Can't find bundle identifier in project.pbxproj
**Solution**: Search for "PRODUCT_BUNDLE_IDENTIFIER"

**Issue**: Firebase won't let me add iOS app
**Solution**: Make sure you're using exactly `com.bpa.student`

**Issue**: Android build fails after changes
**Solution**: You modified something in `android/` folder - revert changes

**Issue**: Flutter build ios fails on Windows
**Solution**: Expected! It will fail at code signing. This is normal.

---

**Session Date**: Tomorrow
**Estimated Duration**: 1.5 hours
**Platform**: Windows
**Outcome**: iOS-ready configuration

**Remember**: We're only ADDING iOS files, never changing Android! 🎯