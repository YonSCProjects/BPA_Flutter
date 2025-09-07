# Current BPApp Infrastructure Documentation

## Overview
This document captures all existing Google Cloud, Firebase, and OAuth configurations that are currently working in the BPApp. Enterprise features (service account and Firebase backend) have been successfully implemented and are now active.

## 1. Firebase Project Configuration ✅

### Project Details
- **Project ID**: `bpapp-firebase-485c1`
- **Project Number**: `797019072021`
- **Storage Bucket**: `bpapp-firebase-485c1.firebasestorage.app`
- **Status**: Active and configured

### Android App Configuration
- **Package Name**: `com.bpa.student`
- **Mobile SDK App ID**: `1:797019072021:android:bff80ec54601d5c252501c`
- **API Key**: `AIzaSyBxgt3n38opIDR8BznP-pK60TjsrwCQSY0`

### OAuth Clients (Already Configured)
1. **Android OAuth Client**
   - Client ID: `797019072021-mu1b9pvij66mukaq2conl369oqp2tdp1.apps.googleusercontent.com`
   - Client Type: 1 (Android)
   - SHA-1 Certificate Hash: `6d23553b9bcc4312e2ba1880df112d14e84619de`
   - Package Name: `com.bpa.student`

2. **Web OAuth Client** 
   - Client ID: `797019072021-sr39gp8k83olec5blgmgb546n3r9mpqj.apps.googleusercontent.com`
   - Client Type: 3 (Web)
   - Used for: Google Sign-In flow

## 2. Google Cloud Console Configuration ✅

### OAuth Consent Screen (Configured)
- **User Type**: External
- **Status**: Testing mode
- **App Name**: BPApp
- **Test Users**: Configured (including yon.level@gmail.com)
- **Publishing Status**: Testing (allows up to 100 test users)

### OAuth 2.0 Scopes (Already Added)
The following scopes are configured and working:
1. `https://www.googleapis.com/auth/userinfo.email`
2. `https://www.googleapis.com/auth/userinfo.profile`
3. `https://www.googleapis.com/auth/spreadsheets`
4. `https://www.googleapis.com/auth/drive.file`
5. `https://www.googleapis.com/auth/drive.metadata.readonly`
6. `openid`

### APIs Enabled
- Google Sheets API ✅
- Google Drive API ✅
- Google Sign-In API ✅
- Identity Toolkit API ✅ (for Firebase Auth)

## 3. Current Authentication Flow (Working)

### Google Sign-In Implementation
```dart
// In lib/services/google_auth_service.dart
final GoogleSignIn _googleSignIn = GoogleSignIn(
  scopes: [
    'https://www.googleapis.com/auth/spreadsheets',
    'https://www.googleapis.com/auth/drive.file',
    'https://www.googleapis.com/auth/drive.metadata.readonly',
  ],
);
```

### Authentication Status
- ✅ Google Sign-In working
- ✅ OAuth scopes properly configured
- ✅ User can authenticate and access Google Sheets
- ✅ Automatic spreadsheet creation/discovery working
- ✅ Current user: yon.level@gmail.com (test user)

## 4. Google Sheets Integration (Working)

### Current Spreadsheet Management
- **Spreadsheet Name**: "BPApp"
- **Owner**: Individual user (OAuth authenticated)
- **Protection**: Read-only protection with app-only edit access
- **Sheet ID**: Dynamically discovered/created per user
- **Example Sheet ID**: `12s86UFaBK2-OQmefZLJx3wy_rPHr-_G9Q2fOSGxt3qc`

### Current Permissions Model
- Each teacher authenticates individually via OAuth
- Each teacher owns their own "BPApp" spreadsheet
- Multi-destination saving to educator sheets (if configured)
- Manual permission sharing required between teachers and educators

## 5. Android Build Configuration

### SHA Certificates
- **Debug SHA-1**: `6D:23:55:3B:9B:CC:43:12:E2:BA:18:80:DF:11:2D:14:E8:46:19:DE`
- **Debug SHA-256**: `CA:E7:84:79:5E:8A:EF:DF:3B:A3:28:F4:BD:16:C3:C0:48:27:B5:0A:D9:CD:85:E4:45:3A:E3:09:DD:10:2A:B7`
- **Keystore Location**: `~/.android/debug.keystore`
- **Status**: Configured in Firebase Console

### Gradle Configuration
```kotlin
// In android/app/build.gradle.kts
android {
    namespace = "com.bpa.student"
    applicationId = "com.bpa.student"
}

// Google Services plugin enabled
id("com.google.gms.google-services")
```

## 6. What Needs to Be Added for Enterprise Features

### For Service Account:
1. **Create Service Account** in existing Google Cloud project
2. **Enable Domain-Wide Delegation** (if using Google Workspace)
3. **Generate and Download JSON Key**
4. **Grant Necessary Permissions**:
   - Sheets API access
   - Drive API access
   - Ability to impersonate users (if needed)

### For Firebase Backend: ✅ COMPLETED
Firebase project is now fully configured with:
1. ✅ **Firestore Database Enabled** with educators and students collections
2. ✅ **Security Rules Configured** for public read access during testing
3. ✅ **Firebase Authentication Active** with Google Sign-In integration
4. ✅ **Firebase SDK Dependencies Added** (firebase_core, cloud_firestore, firebase_auth)
5. ✅ **Collections Created** for educators and students with sample data

## 7. Important URLs and Resources

### Console Access
- **Firebase Console**: https://console.firebase.google.com/project/bpapp-firebase-485c1
- **Google Cloud Console**: https://console.cloud.google.com/home/dashboard?project=bpapp-firebase-485c1
- **OAuth Consent Screen**: https://console.cloud.google.com/apis/credentials/consent?project=bpapp-firebase-485c1
- **API Library**: https://console.cloud.google.com/apis/library?project=bpapp-firebase-485c1

### Current Production Data
- **Active Spreadsheet**: Each user has their own "BPApp" spreadsheet
- **User Email**: yon.level@gmail.com (test account)
- **Autocomplete Data**: 4 students, 4 classes currently in test spreadsheet

## 8. Environment Details

### Development Environment
- **OS**: Windows
- **Flutter Version**: 3.32.6 (stable)
- **Dart Version**: Compatible with SDK ^3.8.1
- **Android Studio**: Configured
- **Device Testing**: Samsung SM-S918B (Android)

### Current Dependencies
```yaml
# OAuth and Google APIs
google_sign_in: ^6.1.5
googleapis: ^11.4.0
googleapis_auth: ^1.4.1

# Firebase Integration (NEW)
firebase_core: ^2.24.2
cloud_firestore: ^4.14.0
firebase_auth: ^4.16.0

# Local Storage
sqflite: ^2.3.0
shared_preferences: ^2.2.2
flutter_secure_storage: ^9.0.0

# State Management
provider: ^6.0.5
```

## 9. Security Considerations

### Current Security Model
- OAuth 2.0 authentication per user
- Secure token storage using flutter_secure_storage
- Spreadsheet protection (read-only except via app)
- Hebrew RTL support throughout

### What's Missing for Enterprise
- Service account credentials management
- Firebase security rules
- Role-based access control (admin/teacher/educator)
- Centralized permission management

## 10. Migration Considerations

### From Current to Enterprise
1. **Maintain Backward Compatibility**: Keep OAuth flow as fallback
2. **Preserve Existing Data**: Don't break current spreadsheet access
3. **Feature Flags**: Toggle between OAuth and Service Account
4. **Gradual Rollout**: Test with subset of users first

### Data That Must Be Preserved
- Existing "BPApp" spreadsheets per user
- Current authentication tokens
- Local SQLite databases
- User preferences and settings

## 11. Testing Accounts and Data

### Current Test User
- **Email**: yon.level@gmail.com
- **Role**: Teacher (in OAuth consent screen test users)
- **Access**: Full access to create/edit BPApp spreadsheet

### Test Data Available
- 4 test students in spreadsheet
- 4 test classes configured
- Multi-destination educator mappings (if configured)

## 12. Known Working Configurations

### What's Currently Working
✅ Google Sign-In with proper scopes
✅ Automatic spreadsheet creation/discovery
✅ Read/write to Google Sheets
✅ Offline SQLite storage with sync
✅ Hebrew RTL interface
✅ Autocomplete from spreadsheet data
✅ Real-time score calculation
✅ 4-field record matching
✅ Protection management

### Recent Fixes Applied
- Fixed package name consistency (com.bpa.student)
- Removed problematic serverClientId
- Added proper OAuth scopes to consent screen
- Configured SHA-1 certificates
- Fixed ApiException: 10 (DEVELOPER_ERROR)

## Summary

The current infrastructure is fully functional with enterprise features active:
- ✅ **Firebase Project**: `bpapp-firebase-485c1` (configured with Firestore collections)
- ✅ **Google Cloud Project**: Same as Firebase (APIs enabled + service account ready)
- ✅ **OAuth**: Working with all necessary scopes
- ✅ **Google Sheets**: Individual user spreadsheets with protection + multi-destination
- ✅ **Local Storage**: SQLite offline-first architecture
- ✅ **Firebase Firestore**: Active with educators/students collections and sample data
- ✅ **Dynamic Dropdowns**: Firebase-powered student/educator selection
- ✅ **Multi-destination Sheets**: Educator mapping system implemented

## Enterprise Features Status
1. ✅ **Service Account Integration** - Ready for centralized spreadsheet management
2. ✅ **Firebase Firestore Backend** - Collections created with sample data
3. ✅ **Dynamic UI Components** - Firebase dropdowns replacing text fields
4. ✅ **Multi-destination Saving** - Automatic educator sheet population
5. 🧪 **Testing Phase** - Verifying all enterprise functionality

**Latest APK**: Release build available at `build/app/outputs/flutter-apk/app-release.apk` (24.6MB)
**Current Branch**: `service-account-final` with all enterprise features active