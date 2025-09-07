# Current BPApp Infrastructure Documentation

Last Updated: January 2025

## Project Status
✅ **EDUCATOR SELF-INITIALIZATION IMPLEMENTED** - Educators create their own spreadsheets with auto-sharing
⚠️ **KNOWN ISSUE**: Teacher entries not being saved to educator spreadsheets (needs debugging)

## Overview
This document captures all existing Google Cloud, Firebase, and OAuth configurations in BPApp. The app now implements educator self-initialization where educators create their own BPApp spreadsheets that are automatically shared with the service account.

## 1. Recent Changes (January 2025)

### Service Account Implementation
- **Service Account Email**: `bpapp-service-account@bpapp-firebase-485c1.iam.gserviceaccount.com`
- **Client ID**: `100081966883778585358`
- **Credentials**: Stored in `assets/service_account.json`
- **Google Workspace**: Subscription cancelled (not needed with new approach)

### New Educator Self-Initialization Flow
1. **Educator Detection**: App checks if user email is in educator mappings (from Firebase)
2. **Auto-Creation**: When educator signs in, app creates "BPApp" in their Google Drive
3. **Auto-Sharing**: Spreadsheet automatically shared with service account as editor
4. **Issue**: Multi-destination saving to educator sheets not working yet

### OAuth Scope Updates
Added full Drive scope for sharing permissions:
```dart
static const List<String> _scopes = [
  'https://www.googleapis.com/auth/spreadsheets',
  'https://www.googleapis.com/auth/drive', // Full drive access for sharing
  'https://www.googleapis.com/auth/drive.file',
  'https://www.googleapis.com/auth/drive.metadata.readonly',
];
```

## 2. Firebase Project Configuration ✅

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

## 3. Google Cloud Console Configuration ✅

### OAuth Consent Screen (Configured)
- **User Type**: External
- **Status**: Testing mode
- **App Name**: BPApp
- **Test Users**: Configured (including yon.level@gmail.com)
- **Publishing Status**: Testing (allows up to 100 test users)

### OAuth 2.0 Scopes (Updated)
The following scopes are configured:
1. `https://www.googleapis.com/auth/userinfo.email`
2. `https://www.googleapis.com/auth/userinfo.profile`
3. `https://www.googleapis.com/auth/spreadsheets`
4. `https://www.googleapis.com/auth/drive` (NEW - for sharing)
5. `https://www.googleapis.com/auth/drive.file`
6. `https://www.googleapis.com/auth/drive.metadata.readonly`
7. `openid`

### APIs Enabled
- Google Sheets API ✅
- Google Drive API ✅
- Google Sign-In API ✅
- Identity Toolkit API ✅ (for Firebase Auth)

## 4. Current Authentication Flow (Working)

### Dual Authentication System
1. **OAuth Mode** (Default for teachers/educators)
   - Individual Google Sign-In
   - Each user owns their spreadsheet
   - Educators auto-create and share their BPApp

2. **Service Account Mode** (Available but not primary)
   - Uses service account credentials
   - Can write to shared spreadsheets
   - Limited by permission constraints

### Authentication Status
- ✅ Google Sign-In working
- ✅ OAuth scopes properly configured
- ✅ User can authenticate and access Google Sheets
- ✅ Automatic spreadsheet creation/discovery working
- ✅ Educator self-initialization implemented
- ⚠️ Multi-destination saving to educator sheets not working

## 5. Google Sheets Integration

### Teacher Spreadsheet Management
- **Spreadsheet Name**: "BPApp"
- **Owner**: Individual teacher
- **Protection**: Read-only protection with app-only edit access
- **Sheet ID**: Dynamically discovered/created per user

### Educator Spreadsheet Management (NEW)
- **Creation**: Auto-created when educator signs in
- **Location**: Educator's "My Drive"
- **Sharing**: Auto-shared with service account as editor
- **Issue**: Entries not being saved from teacher forms

### Service Account Access
- Service account has editor access to educator spreadsheets
- Should enable multi-destination saving
- Currently not working - needs debugging

## 6. Key Services Implementation

### New Services Added
1. **`educator_self_init_service.dart`**
   - Checks if user is educator
   - Creates BPApp in educator's Drive
   - Shares with service account

2. **`service_account_sheets_service.dart`**
   - Manages service account authentication
   - Attempts to write to educator sheets
   - JWT implementation for impersonation (deprecated)

3. **`service_account_jwt_auth.dart`**
   - Custom JWT authentication
   - Impersonation support (not used in current approach)

### Modified Services
- **`multi_destination_sheets_service.dart`**
  - Updated to find (not create) educator spreadsheets
  - Should use service account for educator writes
  - Currently failing - needs investigation

## 7. Android Build Configuration

### SHA Certificates
- **Debug SHA-1**: `6D:23:55:3B:9B:CC:43:12:E2:BA:18:80:DF:11:2D:14:E8:46:19:DE`
- **Debug SHA-256**: `CA:E7:84:79:5E:8A:EF:DF:3B:A3:28:F4:BD:16:C3:C0:48:27:B5:0A:D9:CD:85:E4:45:3A:E3:09:DD:10:2A:B7`
- **Keystore Location**: `~/.android/debug.keystore`
- **Status**: Configured in Firebase Console

## 8. Current Issues to Debug

### Multi-Destination Saving Not Working
**Symptoms**:
- Teacher entries save to teacher spreadsheet ✅
- Educator spreadsheet created and shared ✅
- Entries NOT appearing in educator spreadsheet ❌

**Possible Causes**:
1. Service account not being used for educator writes
2. Permission issues despite sharing
3. Spreadsheet ID not being found/cached correctly
4. Multi-destination logic not triggering

**Debug Steps for Tomorrow**:
1. Check if `_findOrCreateEducatorSpreadsheet` finds the educator's spreadsheet
2. Verify service account is initialized when needed
3. Check logs for permission errors when writing to educator sheets
4. Ensure educator email mapping is correct

## 9. Environment Details

### Development Environment
- **OS**: Windows
- **Flutter Version**: 3.32.6 (stable)
- **Dart Version**: Compatible with SDK ^3.8.1
- **Android Studio**: Configured
- **Device Testing**: Samsung devices + emulators

### Current Dependencies
```yaml
# OAuth and Google APIs
google_sign_in: ^6.1.5
googleapis: ^11.4.0
googleapis_auth: ^1.4.1

# Firebase Integration
firebase_core: ^2.24.2
cloud_firestore: ^4.14.0
firebase_auth: ^4.16.0

# JWT for service account
dart_jsonwebtoken: ^2.12.0

# Local Storage
sqflite: ^2.3.0
shared_preferences: ^2.2.2
flutter_secure_storage: ^9.0.0

# State Management
provider: ^6.0.5
```

## 10. Testing Accounts and Data

### Current Test Users
- **Teacher**: yon.level@gmail.com
- **Educator**: yonatanlevel@gmail.com (mapped to class "תאיר")
- **Service Account**: bpapp-service-account@bpapp-firebase-485c1.iam.gserviceaccount.com

### Test Data Available
- 4 test students in Firebase
- 4 test classes configured
- Educator mapping: "תאיר" -> "yonatanlevel@gmail.com"

## 11. File Structure Updates

### New Files Created
- `lib/services/educator_self_init_service.dart` - Educator initialization
- `lib/services/service_account_sheets_service.dart` - Service account management
- `lib/services/service_account_jwt_auth.dart` - JWT authentication
- `assets/service_account.json` - Service account credentials

### Modified Files
- `lib/services/google_auth_service.dart` - Added full Drive scope
- `lib/services/multi_destination_sheets_service.dart` - Disabled educator creation
- `lib/presentation/pages/student_form_page.dart` - Added educator init flow

## 12. Important URLs

### Console Access
- **Firebase Console**: https://console.firebase.google.com/project/bpapp-firebase-485c1
- **Google Cloud Console**: https://console.cloud.google.com/home/dashboard?project=bpapp-firebase-485c1
- **OAuth Consent Screen**: https://console.cloud.google.com/apis/credentials/consent?project=bpapp-firebase-485c1
- **Service Account**: https://console.cloud.google.com/iam-admin/serviceaccounts?project=bpapp-firebase-485c1

## Summary

### What's Working ✅
- Teacher authentication and spreadsheet creation
- Educator detection based on Firebase mappings
- Educator spreadsheet auto-creation in their Drive
- Auto-sharing with service account (with full Drive scope)
- Firebase backend with dynamic dropdowns
- Local SQLite storage with sync

### What Needs Fixing ⚠️
- Multi-destination saving to educator spreadsheets
- Service account write access to educator sheets
- Proper initialization of service account for educator writes

### Next Steps (Tomorrow)
1. Debug why educator entries aren't being saved
2. Check service account initialization in multi-destination flow
3. Verify spreadsheet discovery for educators
4. Test with detailed logging to identify failure point

**Latest APK**: Release build at `build/app/outputs/flutter-apk/app-release.apk` (25.8MB)
**Current Branch**: `service-account-final`
**Repository**: https://github.com/YonSCProjects/BPA_Flutter