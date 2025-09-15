# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

# BPApp - Hebrew Student Tracking System

## Project Overview
Hebrew-language cross-platform mobile application for teachers to track student performance and attendance through structured input fields with automatic Google Sheets integration. Each user maintains their own private "BPApp" spreadsheet with real-time score calculation and smart record matching.

## Current Status (January 2025)
✅ **PRODUCTION READY** - All features complete and tested
✅ **ATTENDANCE SYSTEM**: Complete attendance tracking with secretary role management
✅ **LATE ARRIVALS**: Teachers can add students who arrive late with visual indicators
✅ **BATCH SCORING**: Next student functionality with queue management
✅ **SERVICE ACCOUNT**: Centralized educator spreadsheet management working
✅ **FIREBASE INTEGRATION**: Dynamic dropdowns with smart filtering by class
✅ **MULTI-DESTINATION SAVES**: Records save to both teacher and educator sheets
✅ **WEB ADMIN PORTAL**: Live at https://bpapp-firebase-485c1.web.app (permissions fixed)
✅ **DEPLOYMENT READY**: Release APK built (25.1MB)
📋 **See `DEPLOYMENT_GUIDE.md`** for deployment instructions and options
📘 **See `WEB_ADMIN_GUIDE.md`** for admin portal documentation
🚀 **Current branch**: `service-account-final` - READY FOR DEPLOYMENT

## Critical Project Information
- **Firebase Project**: `bpapp-firebase-485c1` (DO NOT create new)
- **Package Name**: `com.bpa.student` (DO NOT change)
- **Development OS**: Windows
- **Test User**: yon.level@gmail.com

## Tech Stack
- **Framework**: Flutter 3.32.6 (stable)
- **Authentication**: Google OAuth 2.0 + Service Account (working)
- **Backend**: Google Sheets API v4 + Firebase Firestore (working)
- **Local Storage**: SQLite offline-first (working)
- **Language**: Complete Hebrew RTL support
- **Platform**: Android (tested), iOS (ready)
- **Enterprise**: Service account, Firebase dropdowns, multi-destination sheets

## Core Features (All Working)
1. **Google Sign-In + Service Account** with proper OAuth scopes
2. **Automatic spreadsheet** creation/discovery with centralized management
3. **Hebrew input fields** with validation and conditional display
4. **Real-time score calculation** with dynamic max scores:
   - Classes 2-6: 0-7 points (all fields)
   - Classes 1 & 7: 0-6 points (no Personal Goal field)
5. **Offline-first SQLite** with background sync
6. **4-field record matching** for updates
7. **Multi-destination saving** to educator sheets with mappings
8. **Batch scoring mode** with "תלמיד/ה הבא/ה" button
9. **Firebase Firestore** backend with educators/students collections
10. **Dynamic dropdowns** with smart filtering (students by selected class)
11. **Enterprise configuration** with phase-based feature flags
12. **Attendance Tracking System**:
    - Centralized attendance spreadsheet managed by secretary
    - Daily attendance submission by teachers
    - Late arrival tracking with "הוספת תלמידים מאחרים" feature
    - Visual indicators for late students ("מאחר" badge)
    - Automatic spreadsheet discovery and sharing with service account
13. **Web Admin Portal** with full CRUD operations for Firebase data

## Scoring System Details

### Point Ranges (Updated January 2025)
The app uses a dynamic scoring system based on class number:

**Classes 2-6 (7 points maximum):**
- כניסה (Entry): 0-1 points
- שהייה (Staying): 0-2 points  
- אווירה (Attitude): 0-1 points
- ביצוע (Performance): 0-1 points
- מטרה אישית (Personal Goal): 0-1 points
- בונוס (Bonus): 0-1 points

**Classes 1 & 7 (6 points maximum):**
- כניסה (Entry): 0-1 points
- שהייה (Staying): 0-2 points
- אווירה (Attitude): 0-1 points
- ביצוע (Performance): 0-1 points
- בונוס (Bonus): 0-1 points
- *Personal Goal field is hidden and automatically set to 0*

## Development Workflow

### Running the Application
```bash
# Clean build issues
rm -rf build && flutter clean

# Run on Android
flutter run

# Build APK
flutter build apk --release
```

### Common Issues & Solutions
1. **Build errors**: Delete build folder with `rm -rf build`
2. **Auth issues**: Check OAuth consent screen test users
3. **Sheets access**: Verify all 5 OAuth scopes are configured

## Project Structure
```
BPA_Flutter/
├── lib/                         # Flutter mobile app
│   ├── main.dart                # App entry point with Firebase initialization
│   ├── config/
│   │   └── app_config.dart      # Enterprise feature flags configuration
│   ├── services/                # Core services
│   │   ├── google_auth_service.dart # OAuth authentication
│   │   ├── google_sheets_service.dart # Sheets integration
│   │   ├── firebase_data_service.dart # Firebase Firestore integration
│   │   ├── local_storage_service.dart # SQLite offline storage
│   │   └── multi_destination_sheets_service.dart # Multi-save logic
│   ├── presentation/
│   │   ├── pages/               # Main screens
│   │   ├── widgets/             # Hebrew UI components + Firebase dropdown
│   │   └── providers/           # State management
│   ├── core/
│   │   ├── educator_mappings.dart # Class-to-educator mapping configuration
│   │   └── theme/               # Hebrew RTL theme
│   └── data/                    # Models and constants
└── web-admin/                   # Next.js admin portal
    ├── app/                     # Pages and routes
    ├── components/              # Reusable components
    ├── contexts/                # React contexts
    └── lib/                     # Firebase config
```

## Latest Features (January 2025)
All features implemented and tested:
1. ✅ **Attendance System** - Complete attendance tracking with secretary role
2. ✅ **Late Arrivals** - Add students who arrive late with visual indicators
3. ✅ **Batch Scoring** - Queue multiple students with "next" button
4. ✅ **Smart Filtering** - Students filtered by selected class
5. ✅ **Service Account** - Centralized educator spreadsheet management
6. ✅ **Multi-destination Saves** - Automatic saving to both sheets
7. ✅ **Web Admin Portal** - Full CRUD interface for Firebase data (permissions fixed)
8. ✅ **Gender-Inclusive UI** - Updated Hebrew text throughout
9. ✅ **Multi-role Support** - Users can have multiple roles (educator + secretary)

## Important Reminders
- ✅ Authentication and APIs are WORKING - don't break them
- ✅ Use EXISTING Firebase/Google Cloud project
- ✅ Maintain backward compatibility with current OAuth flow
- ✅ Test all changes with existing user data
- ✅ Keep Hebrew RTL support throughout

## Documentation Files
- `DEPLOYMENT_GUIDE.md` - Complete deployment instructions and options
- `CURRENT_INFRASTRUCTURE.md` - Detailed existing configuration
- `WEB_ADMIN_GUIDE.md` - Admin portal documentation
- `FUTURE_WORK.md` - Long-term improvements roadmap

## Git Workflow
Claude Code manages all version control. Current branch: `service-account-final`
Repository: https://github.com/YonSCProjects/BPA_Flutter
**Latest APK**: Release build ready at `build/app/outputs/flutter-apk/app-release.apk` (25.1MB)

## Testing Credentials
- Google Account: yon.level@gmail.com (configured as test user)
- Existing spreadsheet with 4 students and 4 classes for testing

## DO NOT
- ❌ Create new Firebase/Google Cloud projects
- ❌ Change package name from `com.bpa.student`
- ❌ Modify working OAuth configuration
- ❌ Break existing Google Sheets integration
- ❌ Remove offline SQLite functionality

## Developer Reminders
- TODO: Add your reminders here
- TODO: move to dedicated folder on My Drive
- TODO: create iOS version release
- FIXME: Important issues to address
- NOTE: Key information to remember

## Contact for Issues
Report issues at: https://github.com/anthropics/claude-code/issues