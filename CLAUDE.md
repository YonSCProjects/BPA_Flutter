# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

# BPApp - Hebrew Student Tracking System

## Project Overview
Hebrew-language cross-platform mobile application for teachers to track student performance and attendance through 11 structured input fields with automatic Google Sheets integration. Each user maintains their own private "BPApp" spreadsheet with real-time score calculation and smart record matching.

## Current Status (September 2024)
✅ **ENTERPRISE FEATURES ACTIVE** - Firebase integration with service account and dynamic dropdowns
✅ **Phase 1 Complete**: Service account integration for centralized spreadsheet management
✅ **Phase 2 Complete**: Firebase backend with Firestore collections for educators/students
✅ **Phase 3 Complete**: Dynamic dropdowns powered by Firebase data
📋 **See `CURRENT_INFRASTRUCTURE.md`** for complete existing configuration details
🚀 **Current branch**: `service-account-final` with all enterprise features

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
3. **11 Hebrew input fields** with validation
4. **Real-time score calculation** (0-11 points)
5. **Offline-first SQLite** with background sync
6. **4-field record matching** for updates
7. **Multi-destination saving** to educator sheets with mappings
8. **Spreadsheet protection** (read-only, app-only edit)
9. **Firebase Firestore** backend with educators/students collections
10. **Dynamic dropdowns** for student and educator selection
11. **Enterprise configuration** with phase-based feature flags

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
lib/
├── main.dart                    # App entry point with Firebase initialization
├── config/
│   └── app_config.dart          # Enterprise feature flags configuration
├── services/                    # Core services
│   ├── google_auth_service.dart # OAuth authentication
│   ├── google_sheets_service.dart # Sheets integration
│   ├── firebase_data_service.dart # Firebase Firestore integration
│   ├── local_storage_service.dart # SQLite offline storage
│   └── multi_destination_sheets_service.dart # Multi-save logic
├── presentation/
│   ├── pages/                   # Main screens
│   ├── widgets/                 # Hebrew UI components + Firebase dropdown
│   └── providers/               # State management
├── core/
│   ├── educator_mappings.dart   # Class-to-educator mapping configuration
│   └── theme/                   # Hebrew RTL theme
└── data/                        # Models and constants
```

## Enterprise Features Status
All enterprise features are now implemented and active:
1. ✅ **Service Account Integration** - Centralized spreadsheet management
2. ✅ **Firebase Backend** - Student/educator data with dropdown menus  
3. ✅ **Dynamic Dropdowns** - Firebase-powered student/educator selection
4. ✅ **Multi-destination Sheets** - Automatic saving to educator sheets
5. 🧪 **Testing Phase** - Verifying multi-destination functionality

## Important Reminders
- ✅ Authentication and APIs are WORKING - don't break them
- ✅ Use EXISTING Firebase/Google Cloud project
- ✅ Maintain backward compatibility with current OAuth flow
- ✅ Test all changes with existing user data
- ✅ Keep Hebrew RTL support throughout

## Documentation Files
- `CURRENT_INFRASTRUCTURE.md` - Detailed existing configuration
- `ENTERPRISE_FEATURES_PLAN.md` - Next phase implementation plan
- `FUTURE_WORK.md` - Long-term improvements roadmap

## Git Workflow
Claude Code manages all version control. Current branch: `service-account-final`
Repository: https://github.com/YonSCProjects/BPA_Flutter
**Latest APK**: Release build ready at `build/app/outputs/flutter-apk/app-release.apk` (24.6MB)

## Testing Credentials
- Google Account: yon.level@gmail.com (configured as test user)
- Existing spreadsheet with 4 students and 4 classes for testing

## DO NOT
- ❌ Create new Firebase/Google Cloud projects
- ❌ Change package name from `com.bpa.student`
- ❌ Modify working OAuth configuration
- ❌ Break existing Google Sheets integration
- ❌ Remove offline SQLite functionality

## Contact for Issues
Report issues at: https://github.com/anthropics/claude-code/issues