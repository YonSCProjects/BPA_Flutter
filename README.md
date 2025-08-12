# BPApp - Hebrew Student Tracking System

A Hebrew-language cross-platform mobile application designed for teachers and instructors to track student performance and attendance through 11 structured input fields, with automatic Google Sheets integration.

## 🎯 Overview

BPApp enables educators to efficiently track student progress using a comprehensive scoring system (11 point maximum) while maintaining complete data privacy through personal Google Drive integration. Each user maintains their own private "BPApp" spreadsheet with real-time synchronization.

## ✨ Key Features

- **11 Hebrew Input Fields**: Mix of date picker, autocomplete text fields, number pickers, and toggles
- **Smart Record Matching**: Automatic UPDATE vs CREATE logic based on 4-field combination
- **Real-time Score Calculation**: Live calculation of 6 numeric inputs (max 11 points)
- **Google Sheets Integration**: Personal "BPApp" spreadsheet for each user
- **Multi-Destination Saving**: ⭐ **NEW** - Save records to both teacher and educator spreadsheets
- **Offline-First Storage**: SQLite local database with background sync
- **Full Hebrew RTL Support**: Complete right-to-left interface with proper text direction
- **Smart Defaults**: Auto-population of current date and sequential class numbers
- **Autocomplete**: Student and class name suggestions from previous entries
- **Educator Collaboration**: Class-to-educator mapping with automatic sharing

## 📱 Input Fields (Hebrew)

1. **תאריך (Date)** - Date picker with Hebrew calendar
2. **שם התלמיד (Student Name)** - Text field with autocomplete
3. **שם הכיתה (Class Name)** - Text field with autocomplete
4. **מספר השיעור (Class Number)** - Number picker (1-7)
5. **כניסה (Entry On Time)** - Toggle (0/1)
6. **שהייה (Staying in Class)** - Number picker (0-3)
7. **אווירה (Attitude)** - Number picker (0-2)
8. **ביצוע (Performance)** - Number picker (0-2)
9. **מטרה אישית (Personal Goal)** - Number picker (0-2)
10. **בונוס (Bonus)** - Toggle (0/1)
11. **הערות (Comments)** - Free text field

## 🏗️ Technical Stack

- **Framework**: Flutter (cross-platform iOS/Android)
- **Authentication**: Google OAuth 2.0
- **Backend**: Google Sheets API v4
- **Local Storage**: SQLite database for offline-first data storage
- **Language**: Complete Hebrew with RTL support
- **State Management**: Provider pattern
- **Storage**: Secure token storage with flutter_secure_storage
- **Multi-Destination**: Advanced spreadsheet discovery and sharing

## 📋 Development Commands

### Project Setup
```bash
# Create Flutter project (if not already created)
flutter create --project-name bpa_flutter --org com.bpa.app .

# Get dependencies
flutter pub get

# Check Flutter installation
flutter doctor
```

### Development
```bash
# Run on Android
flutter run -d android

# Run on iOS (macOS only)
flutter run -d ios

# Run with hot reload
flutter run

# Check for issues
flutter analyze

# Format code
flutter format .

# Run tests
flutter test

# Run tests with coverage
flutter test --coverage
```

### Build & Release
```bash
# Build Android APK
flutter build apk --release

# Build Android App Bundle (Play Store)
flutter build appbundle --release

# Build iOS (macOS only)
flutter build ios --release

# Clean build files
flutter clean
```

## 🔒 Security & Privacy

- **Personal Data Storage**: Each user's data stored in their private Google Drive
- **OAuth 2.0**: Secure Google authentication flow
- **No Central Database**: App doesn't store user data centrally
- **Data Ownership**: Users retain full control of their spreadsheet data

## 📊 Data Flow

1. **Authentication**: Google OAuth with Sheets API scope
2. **Spreadsheet Discovery**: Search for "BPApp" in user's Drive
3. **Auto-Creation**: Create "BPApp" with Hebrew headers if missing
4. **Record Matching**: 4-field combination check (Date + Student + Class + Number)
5. **Smart Logic**: UPDATE existing row or CREATE new based on match results
6. **Multi-Destination Save**: ⭐ **NEW** - Save to both teacher and educator spreadsheets
7. **Offline-First Storage**: Instant SQLite save with background Google Sheets sync
8. **Real-time Sync**: Automatic synchronization with intelligent retry logic

## 🌐 Hebrew RTL Implementation

- **Complete Hebrew UI**: All interface elements in Hebrew
- **RTL Layout**: Proper right-to-left text direction
- **Hebrew Fonts**: Optimized typography (Rubik, Assistant)
- **Hebrew Keyboard**: Native Hebrew input support
- **Date Formatting**: Hebrew-compatible date display

## 🚀 Getting Started

1. **Prerequisites**: Flutter SDK, Android Studio/Xcode
2. **Clone Repository**: `git clone [repository-url]`
3. **Install Dependencies**: `flutter pub get`
4. **Configure Google APIs**: Add Google Services configuration files
5. **Run Application**: `flutter run`

## 📁 Project Structure

```
lib/
├── main.dart                    # App entry point with Hebrew RTL setup
├── core/
│   └── educator_mappings.dart   # ⭐ NEW: Class-to-educator mapping
├── data/                        # Data models and repositories
├── domain/                      # Business logic layer
├── presentation/
│   └── pages/
│       └── educator_settings_page.dart  # ⭐ NEW: Settings for educator sharing
└── services/
    ├── google_auth_service.dart
    ├── google_sheets_service.dart
    ├── local_storage_service.dart       # ⭐ NEW: SQLite offline storage
    └── multi_destination_sheets_service.dart  # ⭐ NEW: Multi-destination saving
```

## 🧪 Testing

- **Unit Tests**: Business logic and data models
- **Widget Tests**: Hebrew UI components and RTL layout
- **Integration Tests**: Google Sheets API flows
- **Golden Tests**: Visual regression testing

## 📈 Scoring System

Real-time calculation of fields 5-10:
- **כניסה (Entry)**: 0-1 points
- **שהייה (Staying)**: 0-3 points  
- **אווירה (Attitude)**: 0-2 points
- **ביצוע (Performance)**: 0-2 points
- **מטרה אישית (Personal Goal)**: 0-2 points
- **בונוס (Bonus)**: 0-1 points
- **Maximum Total**: 11 points

## 🔄 Multi-Destination Saving

### Teacher-Educator Collaboration
Teachers can configure classes to automatically share records with educators:

1. **Configure Mappings**: Use the settings page to map class names to educator emails
2. **Automatic Sharing**: Records save to both teacher and educator spreadsheets
3. **Smart Discovery**: Advanced 3-strategy system finds educator spreadsheets
4. **Fallback Protection**: Creates "Teacher Input" sheets when main sheets are protected
5. **Hebrew Interface**: Complete RTL interface for configuration

### How It Works
- Teacher saves a record → Instantly saved to their own spreadsheet
- If class has mapped educator → Also saved to educator's BPApp spreadsheet
- Intelligent sorting maintains chronological order in both spreadsheets
- Automatic protection management ensures teachers can write to educator sheets

## 🤝 Contributing

This project follows clean architecture principles and Hebrew localization best practices. See [CLAUDE.md](CLAUDE.md) for detailed development guidelines including the new multi-destination saving architecture.

## 📄 License

[Add your license information here]

---

**Built with Flutter 💙 | Hebrew RTL Support 🇮🇱 | Multi-Destination Google Sheets 📊 | Offline-First SQLite 💾**