# Current BPApp Infrastructure Documentation

Last Updated: January 2025

## Project Status
✅ **MULTI-DESTINATION SAVING FULLY WORKING** - Teacher entries successfully save to both teacher and educator spreadsheets
✅ **EDUCATOR SELF-INITIALIZATION IMPLEMENTED** - Educators create their own spreadsheets with auto-sharing
✅ **ALL CRITICAL BUGS FIXED** - Smart insertion, validation, and sheet ID handling resolved
✅ **WEB ADMIN PORTAL DEPLOYED** - Live at https://bpapp-firebase-485c1.web.app
✅ **FIREBASE SECURITY RULES UPDATED** - Public read for Flutter app, authenticated write for admin portal
✅ **ALL FIRESTORE FIELDS DISPLAYED** - Web admin shows all fields including createdAt, active status, notes, etc.

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
4. **Working**: Multi-destination saving to educator sheets with smart insertion

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

## 2. Web Admin Portal (January 2025) ✅

### Production Deployment
- **Live URL**: https://bpapp-firebase-485c1.web.app
- **Hosting**: Firebase Hosting
- **Framework**: Next.js 15.5.2 with TypeScript
- **Authentication**: Firebase Auth (Google + Email/Password)
- **Database**: Direct Firestore integration

### Features Implemented
- Full CRUD operations for users, educators, students
- Bulk CSV import with validation
- Real-time statistics dashboard
- All Firestore fields displayed (including createdAt, active, grade, notes)
- Responsive design for mobile/tablet/desktop
- Role-based badges and status indicators

### Security Rules (firestore-safe.rules)
```javascript
// Public read for Flutter app, authenticated write for admin
allow read: if true;  // Flutter app needs this
allow write: if request.auth != null;  // Admin portal only
```

## 3. Firebase Project Configuration ✅

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
- ✅ Multi-destination saving to educator sheets WORKING

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
- **Working**: Entries successfully saved from teacher forms with smart insertion

### Service Account Access
- Service account has editor access to educator spreadsheets
- Should enable multi-destination saving
- Working correctly with proper sheet ID handling

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
  - Working correctly - uses service account for educator writes

## 7. Android Build Configuration

### SHA Certificates
- **Debug SHA-1**: `6D:23:55:3B:9B:CC:43:12:E2:BA:18:80:DF:11:2D:14:E8:46:19:DE`
- **Debug SHA-256**: `CA:E7:84:79:5E:8A:EF:DF:3B:A3:28:F4:BD:16:C3:C0:48:27:B5:0A:D9:CD:85:E4:45:3A:E3:09:DD:10:2A:B7`
- **Keystore Location**: `~/.android/debug.keystore`
- **Status**: Configured in Firebase Console

## 8. Recent Fixes (January 2025)

### Multi-Destination Saving Fixed ✅
**Solutions Implemented**:
1. ✅ Fixed service account authentication (removed impersonation)
2. ✅ Added educator initialization in service account mode
3. ✅ Implemented smart insertion logic for educator spreadsheets
4. ✅ Fixed sheet ID handling (was using ID 0, now gets actual sheet ID)
5. ✅ Added validation to prevent empty student/class names

**Features Now Working**:
- Teacher entries save to both teacher and educator spreadsheets
- Smart insertion maintains chronological order
- Proper 4-field matching for updates
- Validation prevents incomplete entries

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

### All Major Features Working ✅
- Multi-destination saving to educator spreadsheets
- Service account write access to educator sheets
- Proper initialization of service account for educator writes
- Smart insertion with chronological ordering
- Form validation for required fields

## 13. Web Admin Portal (NEW - January 2025)

### Overview
Full-featured web admin interface built with Next.js for managing Firebase collections.

### Tech Stack
- **Framework**: Next.js 15.5.2 with TypeScript
- **Styling**: Tailwind CSS
- **Database**: Firebase Firestore (same project)
- **Authentication**: Firebase Auth (Google OAuth + Email/Password)
- **File Processing**: Papa Parse for CSV imports
- **UI Components**: Lucide React icons, React Dropzone

### Features Implemented
1. **Authentication System**
   - Google OAuth integration
   - Email/password authentication
   - Protected routes with auth guards

2. **Dashboard**
   - Real-time statistics (users, educators, students, classes)
   - Recent activity feed
   - Quick action buttons
   - System information display

3. **Collection Management (Full CRUD)**
   - **Users Collection**: Add, edit, delete users with role assignment
   - **Educators Collection**: Manage educators with classes and spreadsheet IDs
   - **Students Collection**: Manage students and class assignments
   - Search functionality for all collections
   - Modal forms for add/edit operations

4. **Bulk Import System**
   - CSV file upload and parsing
   - Support for all three collections
   - Template download functionality
   - Validation and error reporting
   - Batch processing with transaction support

### File Structure
```
web-admin/
├── app/
│   ├── educators/page.tsx      # Educators management
│   ├── students/page.tsx       # Students management
│   ├── users/page.tsx          # Users management
│   ├── import/page.tsx         # Bulk import interface
│   ├── login/page.tsx          # Authentication page
│   └── page.tsx                # Main dashboard
├── components/
│   ├── DashboardLayout.tsx     # Main layout with sidebar
│   └── ProtectedRoute.tsx      # Auth guard component
├── contexts/
│   └── AuthContext.tsx         # Authentication context
└── lib/
    └── firebase-config.ts       # Firebase configuration
```

### Access Information
- **Local URL**: http://localhost:3000
- **Port**: 3000
- **Environment**: Development with hot reload

### Ready for Next Phase
✅ Admin backend management environment - COMPLETED
✅ Dashboard for monitoring all educators - COMPLETED
✅ Bulk data management tools - COMPLETED
⏳ Analytics and reporting features - Future enhancement

**Latest APK**: Release build at `build/app/outputs/flutter-apk/app-release.apk` (24.7MB)
**Current Branch**: `service-account-final`
**Repository**: https://github.com/YonSCProjects/BPA_Flutter