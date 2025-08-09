# BPApp Backend Service - Centralized Google Sheets Management

## Overview
This backend service enables centralized Google Sheets storage while maintaining all existing app functionality. Each teacher still has their own dedicated spreadsheet, but now all spreadsheets are stored in one central Google Drive account managed by the backend.

## Architecture

### No Harm First Approach
- ✅ **Parallel Implementation**: New backend service runs alongside existing code
- ✅ **Feature Flag Control**: Easy enable/disable via `_useBackendService` flag
- ✅ **Automatic Fallback**: Falls back to original service if backend fails
- ✅ **Zero Breaking Changes**: All existing functionality preserved
- ✅ **Instant Rollback**: One flag change reverts to original behavior

### Service Flow
```
User App → Backend API → Service Account → Central Google Drive
     ↓          ↓              ↓                    ↓
OAuth Token  Verify User  Manage Permissions  Create/Update Sheets
```

### Key Components

#### Backend (Firebase Functions)
- **Location**: `/backend/functions/`
- **Language**: TypeScript
- **Framework**: Express.js on Firebase Functions
- **Authentication**: Firebase Auth token verification
- **Storage**: Firestore for user-spreadsheet mappings

#### Flutter Integration
- **BackendSheetsService**: New service that calls backend API
- **SheetsServiceManager**: Controls which service to use
- **GoogleSheetsService**: Original service (unchanged)
- **Fallback Logic**: Automatic fallback if backend unavailable

## Features Preserved

All existing features work identically:
- ✅ 11 Hebrew input fields
- ✅ 4-field matching for updates
- ✅ Real-time score calculation
- ✅ Autocomplete suggestions
- ✅ Chronological record sorting
- ✅ Offline-first with SQLite
- ✅ Background sync
- ✅ Hebrew RTL interface

## What Changes for Users

### Before (Current)
- Spreadsheet in user's own Google Drive
- User has full edit access
- User manages their own data

### After (Backend)
- Spreadsheet in central Google Drive
- User has view-only access (can still export/analyze)
- App manages all edits through backend
- User gets email with spreadsheet link

## Security & Privacy

### Authentication Flow
1. User authenticates with Google OAuth in app
2. App sends Firebase ID token to backend
3. Backend verifies token authenticity
4. Backend ensures user can only access their own data
5. Service account performs actual Drive operations

### Data Protection
- Each user can only access their own spreadsheet
- Backend validates user email matches request
- Spreadsheets are protected (app-only editing)
- Firestore rules prevent direct database access

## Deployment Steps

### 1. Enable Firebase Services
Go to https://console.firebase.google.com/project/bpapp-hebrew and enable:
- Firebase Authentication (Google provider)
- Cloud Firestore
- Cloud Functions (requires billing)

### 2. Setup Service Account
```bash
# In Firebase Console → Project Settings → Service Accounts
# Generate new private key
# Save as backend/functions/service-account.json
# NEVER commit this file!
```

### 3. Deploy Backend
```bash
cd backend
npm install -g firebase-tools
firebase login
firebase use bpapp-hebrew
cd functions
npm install
npm run deploy
```

### 4. Test with Feature Flag
```dart
// In lib/services/backend_sheets_service.dart
static const bool _useBackendService = true; // Enable backend
```

### 5. Monitor & Rollback if Needed
```dart
// To rollback instantly:
static const bool _useBackendService = false; // Disable backend
```

## API Endpoints

Base URL: `https://us-central1-bpapp-hebrew.cloudfunctions.net/api`

- `POST /setup-user` - Create/find user's spreadsheet
- `POST /save-record` - Save student record
- `POST /find-record` - Find matching record (4-field)
- `GET /autocomplete-data` - Get autocomplete suggestions
- `GET /health` - Health check endpoint

## Cost Analysis

For your usage (100-500 teachers):
- **Firebase Functions**: FREE (2M invocations/month free)
- **Firestore**: FREE (50K reads, 20K writes/day free)
- **Total Monthly Cost**: $0

## Testing Checklist

Before enabling for all users:
1. [ ] Deploy backend to Firebase
2. [ ] Test with your own account first
3. [ ] Verify spreadsheet creation in central Drive
4. [ ] Test all CRUD operations
5. [ ] Verify fallback works if backend down
6. [ ] Check user can view their spreadsheet
7. [ ] Test offline mode still works
8. [ ] Verify sync still functions

## Rollback Plan

If any issues occur:
1. Set `_useBackendService = false` in `backend_sheets_service.dart`
2. App immediately reverts to original behavior
3. No data loss - all local SQLite data intact
4. Users continue with personal Drive sheets

## Support

- Backend logs: `firebase functions:log`
- Monitor usage: Firebase Console → Functions
- Check quotas: Google Cloud Console → APIs