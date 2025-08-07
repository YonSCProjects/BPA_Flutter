# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

# BPApp - Hebrew Student Tracking System

## Project Overview
Hebrew-language cross-platform mobile application for teachers to track student performance and attendance through 11 structured input fields with automatic Google Sheets integration. Each user maintains their own private "BPApp" spreadsheet with real-time score calculation and smart record matching.
The development is done with claude code on windows.

## Tech Stack
- **Framework**: Flutter
- **Authentication**: Google OAuth 2.0
- **Backend**: Google Sheets API v4
- **Language**: Complete Hebrew with RTL support
- **Platform**: iOS and Android

## Core Functionality

### Data Storage & Synchronization
- **Personal Google Sheets Integration**: Each user maintains private "BPApp" spreadsheet in Google Drive
- **Automatic Authentication**: App checks Google Drive connection on startup
- **Real-time Sync**: Direct Google Sheets API integration for immediate data synchronization
- **Individual User Sheets**: Each teacher gets dedicated spreadsheet ensuring privacy

### Hebrew Input Fields (11 Total)

#### 1. תאריך (Date)
- **Type**: Date picker with popup calendar
- **Behavior**: Auto-populates with current date on app open
- **Format**: Hebrew-compatible date formatting
- **UI**: Tap-to-select calendar interface

#### 2. שם התלמיד (Student Name)
- **Type**: Text field with intelligent autocomplete
- **Data Source**: Previous submissions from user's spreadsheet
- **Trigger**: Autocomplete after 2+ characters
- **Function**: Ensures consistent name spelling

#### 3. שם הכיתה (Class Name)
- **Type**: Text field with autocomplete
- **Data Source**: Previous class names from spreadsheet
- **Trigger**: Suggestions after 2+ characters
- **Purpose**: Maintains class naming consistency

#### 4. מספר השיעור (Class Number)
- **Type**: Number picker (range 1-7)
- **Smart Default**: Auto-suggests next sequential number for current date
- **Logic**: If classes 1,2,3 exist today → suggests class 4
- **Validation**: Only allows 1,2,3,4,5,6,7

#### 5. כניסה (Entry On Time)
- **Type**: Number picker (range 0-1)
- **Values**: 0 = late arrival, 1 = on time
- **UI**: Binary toggle/selector
- **Scoring**: Contributes to total calculation

#### 6. שהייה (Staying in Class)
- **Type**: Number picker (range 0-3)
- **Scoring Logic**: Quarter-hour tracking system
  - 0 = Left early (less than 15 minutes)
  - 1 = Stayed 15 minutes (one quarter)
  - 2 = Stayed 30 minutes (two quarters)
  - 3 = Stayed full class (45+ minutes)

#### 7. אווירה (Attitude)
- **Type**: Number picker (range 0-2)
- **Purpose**: Student behavior and engagement rating
- **Scale**: 3-point evaluation (0,1,2)
- **Assessment**: Behavioral participation aspects

#### 8. ביצוע (Performance)
- **Type**: Number picker (range 0-2)
- **Purpose**: Academic and task performance evaluation
- **Scale**: 3-point system matching attitude
- **Assessment**: Academic achievement focus

#### 9. מטרה אישית (Personal Goal)
- **Type**: Number picker (range 0-2)
- **Purpose**: Individual student objective tracking
- **Integration**: Included in scoring calculation
- **Assessment**: Personal target achievement

#### 10. בונוס (Bonus)
- **Type**: Number picker (range 0-1)
- **Values**: 0 = no bonus, 1 = bonus awarded
- **Purpose**: Extra credit or special recognition
- **Impact**: Contributes to total score

#### 11. הערות (Comments)
- **Type**: Free text field
- **Purpose**: Open-ended notes and observations
- **Validation**: No restrictions
- **Function**: Qualitative information capture

### Advanced Logic & Automation

#### Record Matching System
- **Four-Field Combination**: תאריך + שם התלמיד + שם הכיתה + מספר השיעור
- **Exact Match Required**: All 4 fields must match for auto-population
- **Update vs Create Logic**:
  - **UPDATE Mode**: If all 4 match → Auto-populate fields 5-11 for editing
  - **CREATE Mode**: If no match → Create new spreadsheet row
- **Data Integrity**: Prevents duplicates while allowing updates

#### Real-Time Scoring System
- **Calculated Fields**: Automatically sums inputs 5-10
- **Numeric Inputs**: כניסה(0-1) + שהייה(0-3) + אווירה(0-2) + ביצוע(0-2) + מטרה אישית(0-2) + בונוס(0-1)
- **Maximum Score**: 11 points total
- **Display**: Running total at bottom of form
- **Updates**: Score updates immediately as fields change
- **Storage**: Total saved as additional spreadsheet column

#### Smart Default Behaviors
- **Date Auto-Fill**: Current date on app open
- **Sequential Class Numbers**: Next available number for current date
- **Session Continuity**: Logical daily class tracking flow

## Development Commands

### Project Setup
```bash
# Create Flutter project (if not already created)
flutter create --project-name bpa_flutter --org com.bpa.app .

# Get dependencies
flutter pub get

# Check Flutter installation and setup
flutter doctor

# Configure Android Studio path if needed
flutter config --android-studio-dir "C:\Program Files\Android\Android Studio"
```

### Development
```bash
# Run on Android device/emulator
flutter run -d android

# Run on iOS simulator (macOS only)
flutter run -d ios

# Run in debug mode with hot reload
flutter run

# Run in release mode
flutter run --release

# List available devices
flutter devices

# Check for issues and analyze code
flutter analyze

# Format code
flutter format .

# Run tests
flutter test

# Run specific test file
flutter test test/widget_test.dart

# Run tests with coverage
flutter test --coverage
```

### Build & Release
```bash
# Build Android APK (debug)
flutter build apk

# Build Android APK (release)
flutter build apk --release

# Build Android App Bundle (recommended for Play Store)
flutter build appbundle --release

# Build iOS (requires macOS and Xcode)
flutter build ios --release

# Clean build files
flutter clean
```

## Project Structure & Architecture

### Key Architecture Decisions
- **State Management**: Provider/Riverpod for state management with reactive UI updates
- **Navigation**: Flutter's built-in Navigator 2.0 with named routes for deep linking
- **RTL Support**: Built-in Flutter Directionality widget with Hebrew locale configuration
- **Error Handling**: Comprehensive error boundary with Hebrew error messages and logging
- **Testing**: Widget tests, integration tests, and unit tests with mockito for API mocking
- **Dependency Injection**: GetIt service locator pattern for clean architecture

### Directory Structure
```
lib/
├── main.dart                    # App entry point with Material App setup
├── core/                        # Core functionality and utilities
│   ├── constants/              # App constants, strings, colors
│   ├── utils/                  # Helper functions and utilities
│   ├── errors/                 # Custom error classes and handling
│   └── theme/                  # App theme configuration with RTL support
├── data/                       # Data layer
│   ├── models/                 # Data models (Student, Class, Record)
│   ├── repositories/           # Repository implementations
│   └── datasources/            # API and local data sources
├── domain/                     # Business logic layer
│   ├── entities/               # Business entities
│   ├── repositories/           # Repository interfaces
│   └── usecases/               # Business use cases
├── presentation/               # UI layer
│   ├── pages/                  # Screen widgets
│   ├── widgets/                # Reusable UI components
│   ├── providers/              # State management providers
│   └── theme/                  # UI theme and styling
└── services/                   # External services
    ├── google_auth_service.dart
    ├── google_sheets_service.dart
    └── storage_service.dart

test/
├── widget_test.dart            # Widget tests
├── unit/                       # Unit tests
├── integration/                # Integration tests
└── mocks/                      # Mock objects for testing
```

## Google Sheets Integration

### Core Service Architecture
- **GoogleSheetsService**: Main service class in `lib/services/google_sheets_service.dart`
- **Authentication**: Integrated with GoogleAuthService for token management  
- **Error Handling**: Comprehensive error handling with Hebrew error messages
- **Rate Limiting**: Built-in handling for Google Sheets API limits (100 requests/100 seconds/user)

### Key Service Methods
- `findExistingSpreadsheet()`: Searches user's Drive for "BPApp" spreadsheet
- `createSpreadsheet()`: Creates new spreadsheet with Hebrew headers
- `findMatchingRecord()`: Implements 4-field matching logic (תאריך + שם התלמיד + שם הכיתה + מספר השיעור)
- `updateRecord()` / `appendRecord()`: Update existing or create new records
- `fetchAutocompleteData()`: Loads student/class suggestions for autocomplete

### Authentication Flow
```dart
1. Check stored credentials in secure storage
2. If expired/missing -> Launch Google Sign-In flow
3. Obtain OAuth 2.0 tokens with Sheets API scope
4. Store tokens securely using flutter_secure_storage
5. Initialize GoogleSheetsService with authenticated client
6. Handle token refresh automatically
```

### Data Schema
| תאריך | שם התלמיד | שם הכיתה | מספר השיעור | כניסה | שהייה | אווירה | ביצוע | מטרה אישית | בונוס | סה"כ | הערות |

## Language & Localization

### Full Hebrew Implementation
- **Interface Language**: Complete Hebrew UI including buttons, messages, prompts, labels
- **RTL Support**: Right-to-left text alignment and layout throughout application
- **Hebrew Typography**: Proper Hebrew font support and character rendering
- **Date Formatting**: Hebrew-compatible date display and input systems
- **Google Sheets**: Hebrew column headers matching input field names
- **Error Messages**: All validation and error messages in Hebrew
- **Authentication**: Google Drive prompts in Hebrew

### Hebrew RTL Technical Requirements
- **Text Direction**: Right-to-left layout for all Hebrew content
- **Layout Mirroring**: Interface elements positioned for RTL reading
- **Font Selection**: Hebrew-optimized fonts (Rubik, Assistant, etc.)
- **Number Formatting**: Hebrew interface with numeric input compatibility
- **Mixed Content**: Hebrew text with numeric values support
- **Keyboard Support**: Hebrew keyboard input handling
- **Navigation**: RTL-aware navigation patterns

### RTL Implementation Details
```dart
// Main app configuration
MaterialApp(
  localizationsDelegates: [
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: [Locale('he', 'IL')],
  locale: Locale('he', 'IL'),
  builder: (context, child) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: child!,
    );
  },
)

// Text styling for Hebrew
TextStyle(
  fontFamily: 'Rubik', // Hebrew-optimized font
  fontSize: 16,
  fontWeight: FontWeight.w400,
)

// Form field RTL alignment
TextField(
  textDirection: TextDirection.rtl,
  textAlign: TextAlign.right,
  decoration: InputDecoration(
    labelText: 'שם התלמיד',
    alignLabelWithHint: true,
  ),
)
```

### Input Validation & User Experience
- **Range Enforcement**: UI controls prevent invalid values
- **Number Pickers**: Physical controls eliminate input errors
- **Binary Choices**: Toggle controls for 0/1 values
- **Autocomplete Performance**: 2+ character activation threshold
- **Hebrew Input**: Proper Hebrew keyboard and text handling

## Git Workflow
 - claude code will manage all version control activitied (adding, commiting, pushing to github etc...)
 = the github repository is https://github.com/YonSCProjects/BPA_Flutter
### Branch Strategy
- `main`: Production-ready code
- `develop`: Integration branch
- `feature/*`: New features
- `hotfix/*`: Critical fixes

### Commit Convention
```
type(scope): description in English

feat(auth): add Google OAuth integration
fix(forms): resolve Hebrew input validation
docs(readme): update setup instructions
```

## Security Considerations
- Secure storage for tokens
- API key protection
- Data validation
- Network security (HTTPS only)

## Testing Strategy
- Unit tests: Components and utilities
- Integration tests: API interactions
- E2E tests: Critical user flows
- RTL layout testing

## Performance Optimization
- Lazy loading components
- Image optimization
- Bundle size monitoring
- Memory leak prevention

## User Workflow

### App Launch Sequence
1. **Authentication Check**: Verify Google Drive connection status
2. **Credential Prompt**: Request Google authentication if not connected
3. **Spreadsheet Verification**: Check for "BPApp" spreadsheet in user's Drive
4. **Spreadsheet Creation**: Create "BPApp" with Hebrew headers if missing
5. **Direct Navigation**: Proceed to input form interface

### Data Entry Process
1. **Smart Defaults**: Date pre-filled, class number auto-suggested
2. **Form Completion**: Fill all 11 fields with real-time score display
3. **Record Matching**: Check for existing record (4-field combination)
4. **Auto-Population**: If match found, populate existing data for editing
5. **Score Updates**: Running total updates continuously
6. **Data Submission**: UPDATE existing row or CREATE new record
7. **Immediate Sync**: Real-time Google Sheets synchronization

### Update vs Create Logic Flow
```
Input 4 Key Fields (תאריך + שם התלמיד + שם הכיתה + מספר השיעור)
↓
Search Existing Spreadsheet Records
↓
Exact Match Found?
├─ YES → Auto-populate fields 5-11 → Edit mode → Update existing row
└─ NO → Blank form → Create mode → Add new row
```

## Development Workflow & Testing

### Code Quality Requirements
- **Code Analysis**: Run `flutter analyze` before every commit - zero warnings/errors
- **Formatting**: Use `flutter format .` to maintain consistent code style
- **Testing**: Minimum 80% code coverage for business logic and UI components
- **Performance**: Profile widget builds and minimize rebuilds
- **Accessibility**: Test with TalkBack/VoiceOver for Hebrew RTL accessibility

### Test Structure
```
test/
├── widget_test.dart                    # Basic widget tests
├── unit/
│   ├── services/
│   │   ├── google_sheets_service_test.dart
│   │   └── google_auth_service_test.dart
│   ├── models/
│   │   ├── student_record_test.dart
│   │   └── class_session_test.dart
│   └── utils/
│       ├── date_utils_test.dart
│       └── hebrew_validation_test.dart
├── widget/
│   ├── student_form_test.dart
│   ├── date_picker_test.dart
│   └── score_calculator_test.dart
└── integration/
    ├── google_sheets_integration_test.dart
    └── end_to_end_flow_test.dart
```

### Key Testing Patterns
- **Widget Testing**: Test Hebrew RTL layout, input validation, and state changes
- **Unit Testing**: Mock Google Sheets API calls, test scoring algorithms
- **Integration Testing**: Full authentication and data sync flows
- **Golden Tests**: Visual regression testing for Hebrew UI components


## Known Issues & Limitations
- iOS Hebrew keyboard behavior variations
- Android RTL layout edge cases with keyboards  
- Google Sheets API rate limits (100 requests/100 seconds/user)
- Offline mode requires additional caching implementation (OfflineStorageService exists)
- Hebrew date formatting cross-platform differences

## Environment Variables
```
GOOGLE_CLIENT_ID=your_google_oauth_client_id
GOOGLE_CLIENT_SECRET=your_google_oauth_secret
SHEETS_API_KEY=your_google_sheets_api_key
ANDROID_GOOGLE_SERVICES_JSON=path_to_google_services_json
IOS_GOOGLE_SERVICES_PLIST=path_to_google_services_plist
```

## Security & Privacy
- **Personal Storage**: User data in private Google Drive only
- **OAuth 2.0**: Secure Google authentication flow
- **No Central Database**: App doesn't store user data centrally
- **Minimal Permissions**: Only Google Sheets API access required
- **Data Ownership**: Users control all their spreadsheet data

## Key Dependencies (pubspec.yaml)
```yaml
dependencies:
  flutter:
    sdk: flutter
  google_sign_in: ^6.1.5           # Google OAuth authentication
  googleapis: ^11.4.0              # Google Sheets API client  
  provider: ^6.0.5                 # State management
  flutter_secure_storage: ^9.0.0   # Secure token storage
  intl: ^0.18.1                    # Hebrew localization
  shared_preferences: ^2.2.2       # Local app preferences
  http: ^1.1.0                     # HTTP client for API calls

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0           # Linting rules
  mockito: ^5.4.2                 # Mocking for tests
  build_runner: ^2.4.7            # Code generation
```

## Deployment

### Android Deployment
```bash
# Generate signed APK for testing
flutter build apk --release

# Generate App Bundle for Play Store
flutter build appbundle --release

# Install release APK on device
flutter install --release
```

### iOS Deployment  
```bash
# Build iOS app (requires macOS)
flutter build ios --release

# Open in Xcode for App Store submission
open ios/Runner.xcworkspace
```

**Distribution Workflow**: Local testing → Internal testing (TestFlight/Internal App Sharing) → Beta testing → Production release

## Support & Maintenance
- Regular dependency updates
- Google API compatibility checks
- Hebrew localization updates
- Performance monitoring

## Codebase-Specific Instructions

### Important Reminders
- Do what has been asked; nothing more, nothing less
- NEVER create files unless they're absolutely necessary for achieving your goal
- ALWAYS prefer editing an existing file to creating a new one
- NEVER proactively create documentation files (*.md) or README files. Only create documentation files if explicitly requested by the User

### Running the Application on Windows
Since development is done on Windows, use the following commands:
```bash
# Run on connected Android device or emulator
flutter run

# If multiple devices are connected, specify Android
flutter run -d android

# Run with verbose output for debugging
flutter run -v

# Build APK for Android testing
flutter build apk --debug
```

### Common Windows-Specific Issues & Solutions
- **Android SDK Path**: If Android SDK is not found, set ANDROID_HOME environment variable
- **Flutter Doctor Issues**: Run `flutter doctor -v` for detailed diagnostics
- **Gradle Issues**: Check `android/gradle/wrapper/gradle-wrapper.properties` for correct Gradle version
- **Google Services**: Ensure `android/app/google-services.json` is present and correctly configured

### Firebase/Google Services Setup
The app uses Google OAuth and Sheets API. Configuration files:
- **Android**: `android/app/google-services.json` (already present)
- **iOS**: `ios/Runner/GoogleService-Info.plist` (needs to be added for iOS development)

### Current Implementation Status
Based on the codebase analysis:
- ✅ Project structure created with proper Hebrew RTL support
- ✅ Google Authentication service (`lib/services/google_auth_service.dart`)
- ✅ Google Sheets service (`lib/services/google_sheets_service.dart`)
- ✅ Form provider for state management (`lib/presentation/providers/form_provider.dart`)
- ✅ Hebrew theme and constants configured
- ✅ Main student form page (`lib/presentation/pages/student_form_page.dart`)
- ✅ Custom Hebrew input widgets (date picker, number picker, text field)
- ✅ Score display widget
- ✅ Data models (student record, form field config, autocomplete data)

### Dependency Version Notes
Current versions in pubspec.yaml:
- Flutter SDK: ^3.8.1
- intl: ^0.20.2 (note: updated from ^0.18.1 mentioned earlier)
- flutter_lints: ^5.0.0 (note: updated from ^3.0.0 mentioned earlier)