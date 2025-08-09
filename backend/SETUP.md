# Firebase Backend Setup Instructions

## Prerequisites
1. Node.js 18+ installed
2. Firebase CLI installed: `npm install -g firebase-tools`
3. Google Cloud project with billing enabled

## Setup Steps

### 1. Use Existing Firebase Project
Your project `bpapp-hebrew` is already configured. Access it at:
https://console.firebase.google.com/project/bpapp-hebrew

Enable these services in Firebase Console:
1. Firebase Authentication (Google provider)
2. Firestore Database
3. Cloud Functions (requires billing account)

### 2. Configure Service Account
1. Go to Firebase Console → Project Settings → Service Accounts
2. Generate new private key
3. Save as `backend/functions/service-account.json`
4. **IMPORTANT**: Add to `.gitignore` - never commit this file!

### 3. Initialize Firebase
```bash
cd backend
firebase login
firebase use bpapp-hebrew  # Use your existing project
```

### 4. Install Dependencies
```bash
cd functions
npm install
```

### 5. Set Environment Variables
```bash
# Set service account for local development
set GOOGLE_APPLICATION_CREDENTIALS=service-account.json

# Or for Firebase Functions deployment
firebase functions:config:set google.application_credentials="service-account.json"
```

### 6. Test Locally
```bash
npm run serve
# API will be available at http://localhost:5001/YOUR_PROJECT/us-central1/api
```

### 7. Deploy to Firebase
```bash
npm run deploy
# Note the Function URL that's displayed after deployment
```

## Important URLs After Deployment
- API Endpoint: `https://us-central1-bpapp-hebrew.cloudfunctions.net/api`
- Health Check: `https://us-central1-bpapp-hebrew.cloudfunctions.net/api/health`

## Flutter App Configuration
Update the Flutter app with your Firebase backend URL:
```dart
// lib/services/backend_sheets_service.dart
static const String _backendUrl = 'https://us-central1-bpapp-hebrew.cloudfunctions.net/api';
```

## Security Notes
1. **NEVER** commit `service-account.json` to git
2. Enable App Check in production for additional security
3. Monitor Firebase usage to stay within free tier
4. Set up budget alerts in Google Cloud Console

## Troubleshooting
- If deployment fails: Check Firebase billing is enabled
- If authentication fails: Verify service account has correct permissions
- If quota errors: Check Google Sheets API quotas in Cloud Console