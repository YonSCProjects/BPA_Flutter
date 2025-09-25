# iOS Deployment Guide for BPApp

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Apple Developer Account Setup](#apple-developer-account-setup)
3. [App Configuration](#app-configuration)
4. [Codemagic Setup](#codemagic-setup)
5. [Firebase App Distribution Setup](#firebase-app-distribution-setup)
6. [Build and Distribution Process](#build-and-distribution-process)
7. [Testing iOS Without Physical Devices](#testing-ios-without-physical-devices)
8. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Required Accounts
- ✅ Apple Developer Account ($99/year) - `yon.scprojects@gmail.com`
- ✅ Firebase Project - `bpapp-firebase-485c1`
- ✅ GitHub Repository - `https://github.com/YonSCProjects/BPA_Flutter`
- ⬜ Codemagic Account (free tier available)

### Required Information
- **Bundle ID**: `com.bpa.student`
- **App Name**: BPApp
- **Team ID**: (Found in Apple Developer Portal)
- **Firebase Project ID**: `bpapp-firebase-485c1`

---

## Apple Developer Account Setup

### Step 1: Create App ID
1. Log into [Apple Developer Portal](https://developer.apple.com) with `yon.scprojects@gmail.com`
2. Navigate to **Certificates, Identifiers & Profiles**
3. Click **Identifiers** → **+** button
4. Select **App IDs** → **App** → **Continue**
5. Fill in:
   - **Description**: BPApp Student Tracker
   - **Bundle ID**: Explicit → `com.bpa.student`
   - **Capabilities**: Enable:
     - ✅ Sign In with Apple (if needed)
     - ✅ Push Notifications (for Firebase)
6. Click **Continue** → **Register**

### Step 2: Create Development Certificate
1. Go to **Certificates** → **+** button
2. Select **iOS App Development** → **Continue**
3. Follow instructions to create Certificate Signing Request (CSR):
   - Since you're on Windows, use OpenSSL:
   ```bash
   # Install OpenSSL if not available
   # Download from: https://slproweb.com/products/Win32OpenSSL.html

   # Generate private key
   openssl genrsa -out ios_dev.key 2048

   # Create CSR
   openssl req -new -key ios_dev.key -out CertificateSigningRequest.certSigningRequest -subj "/emailAddress=yon.scprojects@gmail.com/CN=BPApp Development/C=US"
   ```
4. Upload CSR file
5. Download certificate as `ios_development.cer`
6. Convert to P12 (required for Codemagic):
   ```bash
   # Download Apple WWDR certificate first
   curl -o AppleWWDRCA.cer https://developer.apple.com/certificationauthority/AppleWWDRCA.cer

   # Convert certificates
   openssl x509 -in ios_development.cer -inform DER -out ios_development.pem -outform PEM
   openssl x509 -in AppleWWDRCA.cer -inform DER -out AppleWWDRCA.pem -outform PEM

   # Create P12 file (set a password when prompted)
   openssl pkcs12 -export -out ios_development.p12 -inkey ios_dev.key -in ios_development.pem -certfile AppleWWDRCA.pem
   ```

### Step 3: Create Distribution Certificate
1. Repeat Step 2 but select **iOS Distribution** certificate type
2. Save as `ios_distribution.p12`

### Step 4: Create Provisioning Profiles

#### Development Profile
1. Go to **Profiles** → **+** button
2. Select **iOS App Development** → **Continue**
3. Select App ID: `com.bpa.student` → **Continue**
4. Select your Development certificate → **Continue**
5. Select **All Devices** (or specific test devices) → **Continue**
6. Name: `BPApp Development Profile` → **Generate**
7. Download as `BPApp_Dev.mobileprovision`

#### App Store Profile
1. Go to **Profiles** → **+** button
2. Select **App Store** → **Continue**
3. Select App ID: `com.bpa.student` → **Continue**
4. Select your Distribution certificate → **Continue**
5. Name: `BPApp App Store Profile` → **Generate**
6. Download as `BPApp_AppStore.mobileprovision`

#### Ad Hoc Profile (for Firebase Distribution)
1. Go to **Profiles** → **+** button
2. Select **Ad Hoc** → **Continue**
3. Select App ID: `com.bpa.student` → **Continue**
4. Select your Distribution certificate → **Continue**
5. Select test devices (add UDIDs later) → **Continue**
6. Name: `BPApp Ad Hoc Profile` → **Generate**
7. Download as `BPApp_AdHoc.mobileprovision`

---

## App Configuration

### Step 1: Update iOS Project Settings
1. Open `ios/Runner.xcodeproj/project.pbxproj` in text editor
2. Verify/Update:
   ```
   PRODUCT_BUNDLE_IDENTIFIER = com.bpa.student;
   DEVELOPMENT_TEAM = [Your Team ID];
   ```

### Step 2: Update Info.plist
Edit `ios/Runner/Info.plist`:
```xml
<key>CFBundleDisplayName</key>
<string>BPApp</string>
<key>CFBundleName</key>
<string>BPApp</string>
<key>CFBundleIdentifier</key>
<string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>

<!-- Google Sign-In Configuration -->
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <!-- Replace with your REVERSED_CLIENT_ID from GoogleService-Info.plist -->
            <string>com.googleusercontent.apps.YOUR_CLIENT_ID</string>
        </array>
    </dict>
</array>

<!-- Camera/Photo permissions if needed -->
<key>NSCameraUsageDescription</key>
<string>This app needs camera access to take photos</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>This app needs photo library access to select images</string>
```

### Step 3: Add Firebase iOS Configuration
1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select `bpapp-firebase-485c1` project
3. Click **Settings** → **Project Settings**
4. Under **Your apps**, click **Add app** → **iOS**
5. Enter:
   - **iOS bundle ID**: `com.bpa.student`
   - **App nickname**: BPApp iOS
   - **App Store ID**: (leave blank for now)
6. Download `GoogleService-Info.plist`
7. Place in `ios/Runner/` directory
8. Ensure it's added to Runner target in Xcode (or manually add to project)

---

## Codemagic Setup

### Step 1: Create Codemagic Account
1. Go to [Codemagic](https://codemagic.io/signup)
2. Sign up with GitHub (use same account as repository)
3. Authorize Codemagic to access your repositories

### Step 2: Add Application
1. Click **Add application**
2. Select **GitHub** as repository provider
3. Choose `YonSCProjects/BPA_Flutter` repository
4. Select **Flutter App** as project type

### Step 3: Configure iOS Build Settings

#### Environment Variables
Add in Codemagic UI → **Environment variables**:
```
# Certificate password
IOS_CERTIFICATE_PASSWORD = [your p12 password]

# App Store Connect (optional for TestFlight)
APP_STORE_CONNECT_API_KEY = [if using TestFlight]
APP_STORE_CONNECT_ISSUER_ID = [if using TestFlight]
APP_STORE_CONNECT_KEY_ID = [if using TestFlight]

# Firebase
FIREBASE_TOKEN = [get with: firebase login:ci]
```

#### Code Signing
1. Go to **Code signing** → **iOS code signing**
2. Upload files:
   - **Certificate**: `ios_distribution.p12`
   - **Certificate password**: [your password]
   - **Provisioning profile**: `BPApp_AdHoc.mobileprovision`

### Step 4: Create codemagic.yaml
Create `codemagic.yaml` in project root:
```yaml
workflows:
  ios-workflow:
    name: iOS Workflow
    instance_type: mac_mini_m1
    max_build_duration: 60
    environment:
      flutter: stable
      xcode: latest
      cocoapods: default
      vars:
        BUNDLE_ID: "com.bpa.student"
        APP_NAME: "BPApp"
      groups:
        - ios_credentials

    scripts:
      - name: Set up local properties
        script: |
          echo "flutter.sdk=$HOME/programs/flutter" > "$CM_BUILD_DIR/android/local.properties"

      - name: Get Flutter packages
        script: |
          flutter packages pub get

      - name: Install pods
        script: |
          find . -name "Podfile" -execdir pod install \;

      - name: Flutter build ipa
        script: |
          flutter build ipa --release \
            --build-name=1.0.0 \
            --build-number=$(($(app-store-connect get-latest-testflight-build-number "$APP_NAME" 2>/dev/null) + 1)) \
            --export-options-plist=/Users/builder/export_options.plist

    artifacts:
      - build/ios/ipa/*.ipa
      - build/ios/archive/*.xcarchive
      - flutter_drive.log

    publishing:
      firebase:
        firebase_token: $FIREBASE_TOKEN
        ios:
          app_id: "1:YOUR_FIREBASE_APP_ID:ios:YOUR_IOS_APP_ID"
          groups:
            - testers

      email:
        recipients:
          - yon.scprojects@gmail.com
        notify:
          success: true
          failure: true
```

---

## Firebase App Distribution Setup

### Step 1: Enable App Distribution
1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select `bpapp-firebase-485c1` project
3. Navigate to **Release & Monitor** → **App Distribution**
4. Click **Get started**

### Step 2: Add iOS App
1. Click **Add app** (if not already added)
2. Select your iOS app (`com.bpa.student`)
3. Configure distribution groups:
   - Create group: `testers`
   - Add emails of testers

### Step 3: Install Firebase CLI
On Windows:
```bash
# Install Node.js first if not installed
# Download from: https://nodejs.org/

# Install Firebase CLI
npm install -g firebase-tools

# Login and get CI token
firebase login:ci
# Save the token for Codemagic
```

### Step 4: Configure Distribution
Create `firebase.json` in project root:
```json
{
  "hosting": {
    "public": "web-admin/out",
    "ignore": ["firebase.json", "**/.*", "**/node_modules/**"]
  },
  "appDistribution": {
    "apps": {
      "ios": {
        "appId": "1:YOUR_FIREBASE_APP_ID:ios:YOUR_IOS_APP_ID",
        "releaseNotes": "Latest BPApp iOS build",
        "groups": ["testers"]
      },
      "android": {
        "appId": "1:YOUR_FIREBASE_APP_ID:android:YOUR_ANDROID_APP_ID",
        "releaseNotes": "Latest BPApp Android build",
        "groups": ["testers"]
      }
    }
  }
}
```

---

## Build and Distribution Process

### Step 1: Trigger Build
1. Commit and push changes to GitHub:
   ```bash
   git add .
   git commit -m "Configure iOS build"
   git push origin service-account-final
   ```

2. In Codemagic:
   - Go to your app
   - Click **Start new build**
   - Select branch: `service-account-final`
   - Select workflow: `ios-workflow`
   - Click **Start new build**

### Step 2: Monitor Build
- Watch build progress in Codemagic dashboard
- Check email for build notifications
- Build typically takes 15-30 minutes

### Step 3: Distribution
Once build succeeds:
1. IPA automatically uploads to Firebase App Distribution
2. Testers receive email invitations
3. Testers install via Firebase App Distribution app

---

## Testing iOS Without Physical Devices

### Option 1: BrowserStack App Live (Recommended)
1. Sign up for [BrowserStack](https://www.browserstack.com/app-live) (free trial available)
2. Upload your IPA file
3. Test on real iOS devices in cloud
4. Features:
   - Real device testing
   - Various iOS versions
   - Network conditions simulation
   - Screenshots and videos

**Steps:**
```bash
# Upload IPA to BrowserStack
curl -u "YOUR_USERNAME:YOUR_ACCESS_KEY" \
  -X POST "https://api-cloud.browserstack.com/app-live/upload" \
  -F "file=@/path/to/app.ipa"

# Test via web interface
# Go to: https://app-live.browserstack.com
```

### Option 2: Appetize.io
1. Go to [Appetize.io](https://appetize.io)
2. Upload IPA file (free for 100 minutes/month)
3. Get shareable link for testing
4. Test in browser-based iOS simulator

**Steps:**
```bash
# Upload to Appetize.io
curl https://api.appetize.io/v1/apps \
  -F "file=@/path/to/app.ipa" \
  -F "platform=ios" \
  -F "token=YOUR_API_TOKEN"
```

### Option 3: TestFlight Beta Testing
1. Upload to App Store Connect via Codemagic
2. Invite external testers with iOS devices
3. Testers install via TestFlight app
4. Get feedback from real users

**Setup in codemagic.yaml:**
```yaml
publishing:
  app_store_connect:
    api_key: $APP_STORE_CONNECT_API_KEY
    key_id: $APP_STORE_CONNECT_KEY_ID
    issuer_id: $APP_STORE_CONNECT_ISSUER_ID
    submit_to_testflight: true
    beta_groups:
      - External Testers
```

### Option 4: Remote iOS Device Services
- **MacinCloud**: Rent Mac/iOS devices remotely
- **MacStadium**: Cloud-hosted Mac infrastructure
- **AWS Device Farm**: Test on real devices in AWS cloud

### Option 5: Find Beta Testers
1. Post in Flutter communities
2. Use services like:
   - BetaList
   - TestFlight public link
   - Reddit r/TestFlight
3. Offer incentives for testing

---

## Testing Checklist

### Pre-Launch Testing
- [ ] Google Sign-In works
- [ ] Service account authentication successful
- [ ] Google Sheets creation/access working
- [ ] Firebase data loading correctly
- [ ] Offline mode functioning
- [ ] Hebrew RTL display correct
- [ ] All input fields working
- [ ] Score calculations accurate
- [ ] Multi-destination saves working
- [ ] Attendance system functional

### Performance Testing
- [ ] App launches within 3 seconds
- [ ] Smooth scrolling and transitions
- [ ] No memory leaks
- [ ] Battery usage acceptable
- [ ] Network usage optimized

### Device Testing
- [ ] iPhone SE (small screen)
- [ ] iPhone 13/14 (standard)
- [ ] iPhone 15 Pro Max (large)
- [ ] iPad (tablet layout)
- [ ] iOS 15+ compatibility

---

## Troubleshooting

### Common Issues

#### Build Fails on Codemagic
```yaml
# Check these settings:
- Flutter version matches local (3.32.6)
- Xcode version is latest stable
- Certificates and profiles are valid
- Bundle ID matches exactly
```

#### Code Signing Errors
```bash
# Verify certificate:
openssl x509 -in ios_distribution.cer -text -noout

# Check provisioning profile:
security cms -D -i BPApp_AdHoc.mobileprovision
```

#### Firebase Authentication Issues
- Ensure `GoogleService-Info.plist` is in `ios/Runner/`
- Verify URL schemes in Info.plist
- Check Firebase project settings

#### App Crashes on Launch
- Check crash logs in Firebase Crashlytics
- Verify all dependencies are included
- Test with development build first

### Getting Help
1. Codemagic Support: support@codemagic.io
2. Firebase Support: Firebase Console → Help
3. Apple Developer Forums: developer.apple.com/forums
4. Flutter Discord: discord.gg/flutter

---

## Cost Breakdown

### Required Costs
- Apple Developer Account: $99/year
- Domain (if custom): ~$12/year

### Optional Costs
- Codemagic: Free tier (500 build minutes/month)
  - Pro: $38/month for more builds
- BrowserStack: $39/month (or free trial)
- Appetize.io: Free tier (100 minutes/month)
  - Premium: $40/month unlimited

### Estimated Total
- Minimum: $99/year (Apple Developer only)
- Recommended: $99/year + $39/month testing = ~$570/year
- Enterprise: Custom pricing based on needs

---

## Next Steps

1. **Immediate Actions**:
   - [ ] Complete Apple Developer setup
   - [ ] Generate certificates and profiles
   - [ ] Add iOS app to Firebase
   - [ ] Set up Codemagic account

2. **Configuration**:
   - [ ] Update iOS project settings
   - [ ] Add GoogleService-Info.plist
   - [ ] Create codemagic.yaml
   - [ ] Configure environment variables

3. **Testing**:
   - [ ] Run first build on Codemagic
   - [ ] Set up cloud testing service
   - [ ] Distribute to beta testers
   - [ ] Collect feedback

4. **Production**:
   - [ ] Finalize App Store listing
   - [ ] Submit for App Review
   - [ ] Plan release strategy
   - [ ] Monitor crash reports

---

## Important Notes

- **Bundle ID**: Must remain `com.bpa.student` to match Android
- **Certificates**: Keep P12 files and passwords secure
- **Testing**: Start with Ad Hoc distribution before App Store
- **Compliance**: Ensure GDPR/privacy policy for EU users
- **Hebrew Support**: Verify RTL layout on all iOS versions

## Support Contacts
- Developer: yon.scprojects@gmail.com
- Repository: https://github.com/YonSCProjects/BPA_Flutter
- Issues: https://github.com/YonSCProjects/BPA_Flutter/issues

---

*Last Updated: January 2025*
*Version: 1.0.0*