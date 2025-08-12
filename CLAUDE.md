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
- **Local Storage**: SQLite database for offline-first data storage
- **Language**: Complete Hebrew with RTL support
- **Platform**: iOS and Android

## Core Functionality

### Data Storage & Synchronization - OFFLINE-FIRST ARCHITECTURE
- **SQLite Offline-First**: Local SQLite database provides instant data saves without network dependency
- **Background Sync**: Automatic synchronization with Google Sheets when connectivity available
- **Personal Google Sheets Integration**: Each user maintains private "BPApp" spreadsheet in Google Drive
- **Multi-Destination Saving**: Teachers can configure records to save to both their own and educator spreadsheets
- **Intelligent Spreadsheet Discovery**: Advanced search strategies to find shared educator spreadsheets
- **Spreadsheet Protection**: BPApp spreadsheets are read-only protected - only app can modify data
- **Automatic Authentication**: App checks Google Drive connection on startup
- **Real-time Sync**: Direct Google Sheets API integration with intelligent retry logic
- **Individual User Sheets**: Each teacher gets dedicated spreadsheet ensuring privacy
- **Data Safety**: Multiple fallback layers prevent data loss in any connectivity scenario

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
│   ├── educator_mappings.dart   # Class-to-educator mapping configuration
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
│   │   ├── educator_settings_page.dart  # NEW: Configure class-educator mappings
│   │   ├── home_page.dart      # Main navigation page
│   │   └── student_form_page.dart  # Primary data entry form
│   ├── widgets/                # Reusable UI components
│   ├── providers/              # State management providers
│   └── theme/                  # UI theme and styling
└── services/                   # External services
    ├── google_auth_service.dart
    ├── google_sheets_service.dart
    ├── local_storage_service.dart        # SQLite offline storage
    └── multi_destination_sheets_service.dart  # NEW: Multi-destination saving

test/
├── widget_test.dart            # Widget tests
├── unit/                       # Unit tests
├── integration/                # Integration tests
└── mocks/                      # Mock objects for testing
```

## Google Sheets Integration

### Core Service Architecture
- **GoogleSheetsService**: Main service class in `lib/services/google_sheets_service.dart`
- **LocalStorageService**: SQLite service class in `lib/services/local_storage_service.dart` 
- **Authentication**: Integrated with GoogleAuthService for token management  
- **Error Handling**: Comprehensive error handling with Hebrew error messages
- **Rate Limiting**: Built-in handling for Google Sheets API limits (100 requests/100 seconds/user)

### Key Service Methods
- `findExistingSpreadsheet()`: Searches user's Drive for "BPApp" spreadsheet
- `createSpreadsheet()`: Creates new spreadsheet with Hebrew headers and RTL configuration
- `findMatchingRecord()`: Implements 4-field matching logic (תאריך + שם התלמיד + שם הכיתה + מספר השיעור)
- `saveRecord()`: **ENHANCED** - Offline-first saving with local SQLite then Google Sheets sync
- `updateRecord()` / `appendRecord()`: Update existing or create new records with sorted insertion
- `fetchAutocompleteData()`: Loads student/class suggestions for autocomplete
- `syncPendingRecords()`: **NEW** - Background sync of locally stored records to Google Sheets
- `_checkAndRecoverFromTrash()`: Automatically detects and recovers deleted BPApp spreadsheets
- `_findInsertPosition()`: Intelligently determines chronological insertion point for new records
- `_insertRecordAtPosition()`: Inserts records maintaining date/class number sorting
- `_protectSpreadsheet()`: **NEW** - Makes BPApp spreadsheets read-only protected

### Multi-Destination Service Methods (NEW)
- `saveRecord()`: **ENHANCED** - Saves to both teacher and educator spreadsheets automatically
- `_findOrRequestEducatorSpreadsheet()`: Advanced search strategies for educator spreadsheets
- `_saveToEducatorSpreadsheet()`: Handles saving records to educator's shared spreadsheet
- `_fixEducatorSpreadsheetProtection()`: Auto-configures protection to allow teacher writes
- `_appendToFallbackSheet()`: Creates fallback "Teacher Input" sheet when main sheet is protected
- `clearEducatorCache()`: Clears cached educator spreadsheet references

### Authentication Flow
```dart
1. Check stored credentials in secure storage
2. If expired/missing -> Launch Google Sign-In flow
3. Obtain OAuth 2.0 tokens with Sheets API scope
4. Store tokens securely using flutter_secure_storage
5. Initialize GoogleSheetsService with authenticated client
6. Handle token refresh automatically
```

### Advanced Features (Latest Implementation)

#### Automatic Trash Recovery System
- **Smart Detection**: App automatically checks Google Drive trash for deleted "BPApp" spreadsheets
- **Recovery Process**: Seamlessly restores deleted spreadsheets without data loss
- **User Notification**: Hebrew success message confirms recovery: "הגיליון האלקטרוני שלך שוחזר בהצלחה מהפח!"
- **Fallback Creation**: Only creates new spreadsheet if no recoverable version exists
- **Implementation**: `_checkAndRecoverFromTrash()`, `_recoverFromTrash()` in GoogleSheetsService

#### Intelligent Record Sorting & Insertion
- **Chronological Ordering**: New records automatically inserted in correct chronological position
- **Multi-Level Sorting**: Primary sort by date, secondary sort by class number (1-7)
- **Smart Insertion**: `_findInsertPosition()` determines optimal placement
- **Sheet ID Handling**: Proper sheet ID resolution for batch update operations
- **Performance**: Efficient insertion without requiring full data reload

#### Enhanced Authentication & Error Handling
- **Debug Logging**: Comprehensive authentication state tracking and debug output
- **Error Messages**: All error messages displayed in Hebrew with context
- **Token Validation**: Enhanced `hasValidToken()` method with robust error handling
- **Session Persistence**: Improved secure credential storage and retrieval
- **OAuth Flow**: Refined Google Sign-In process with better error recovery

#### Spreadsheet Protection System
- **Read-Only Protection**: BPApp spreadsheets automatically protected from manual user edits
- **App-Only Access**: Only authenticated app can modify spreadsheet data
- **Protection Applied**: New spreadsheets, existing spreadsheets, and recovered spreadsheets
- **Hebrew Description**: Protection includes Hebrew description "הגנה על גיליון BPApp - רק האפליקציה יכולה לערוך"
- **Non-Critical**: Graceful fallback if protection fails - app continues working normally

### Data Schema
| תאריך | שם התלמיד | שם הכיתה | מספר השיעור | כניסה | שהייה | אווירה | ביצוע | מטרה אישית | בונוס | סה"כ | הערות |

## Multi-Destination Saving Feature

### Overview
The app supports **multi-destination saving** where teachers can configure their records to be automatically saved to both their own spreadsheet AND an educator's spreadsheet. This enables seamless collaboration between professional teachers and educational supervisors.

### Core Components

#### EducatorMappings (`lib/core/educator_mappings.dart`)
- **Class-to-Educator Configuration**: Maps specific class names to educator email addresses
- **Persistent Storage**: Mappings stored in SharedPreferences for persistence across sessions
- **Initialization System**: Async initialization ensures mappings are loaded before use
- **Real-time Updates**: Changes propagate immediately to multi-destination service

#### Key Methods
- `initialize()`: Loads mappings from persistent storage on app startup
- `getEducatorEmail(className)`: Returns associated educator email for a class
- `hasEducator(className)`: Checks if a class has an assigned educator
- `updateMappings(newMappings)`: Updates and persists new class-educator mappings
- `getMappings()`: Returns current mappings for settings UI

### MultiDestinationSheetsService Architecture

#### Core Functionality
```dart
MultiDestinationSheetsService {
  GoogleSheetsService primaryService;     // Teacher's own spreadsheet
  Map<String, String> educatorSpreadsheetIds;  // Cache of educator spreadsheet IDs
  GoogleAuthService authService;          // Authentication management
}
```

#### Save Process Flow
```
1. Teacher submits record
   ↓
2. ALWAYS save to teacher's own spreadsheet (primary success)
   ↓
3. Check if class has associated educator (EducatorMappings)
   ↓
4. IF educator exists → Find/access educator's BPApp spreadsheet
   ↓
5. Apply intelligent sorting and save to educator spreadsheet
   ↓
6. Return success based on primary save (educator save is bonus)
```

### Advanced Spreadsheet Discovery

#### Multi-Strategy Search System
The service implements sophisticated spreadsheet discovery using three fallback strategies:

**Strategy 1: Shared BPApp Search**
- Query: `sharedWithMe and name contains 'BPApp' and mimeType='application/vnd.google-apps.spreadsheet'`
- Filters by educator ownership and edit permissions
- Most reliable method for properly shared spreadsheets

**Strategy 2: Accessible BPApp Search**  
- Query: `name contains 'BPApp' and mimeType='application/vnd.google-apps.spreadsheet'`
- Broader search across all accessible BPApp spreadsheets
- Fallback when sharedWithMe doesn't capture all cases

**Strategy 3: Legacy Owner Search**
- Query: `name contains 'BPApp' and '[educator_email]' in owners`
- Direct owner-based search for older sharing configurations
- Final fallback for legacy setups

#### Protection Management System
```dart
_fixEducatorSpreadsheetProtection() {
  // Remove broad protections that block teacher writes
  // Add header-only protection with teacher as allowed editor
  // Maintains data integrity while enabling collaboration
}
```

### Fallback Mechanisms

#### Unprotected Helper Sheet
When the main educator sheet is protected and blocks writes:
1. **Create Fallback Sheet**: "קלט מהמורה" (Teacher Input) 
2. **Preserve Data**: Same Hebrew headers and RTL formatting
3. **Maintain Functionality**: Full record tracking in dedicated sheet
4. **Zero User Impact**: Teachers never see save failures

#### Error Handling & Diagnostics
- **Comprehensive Logging**: Detailed debug output for troubleshooting
- **Hebrew Error Messages**: User-friendly error reporting in Hebrew
- **Diagnostic Guidance**: Automatic suggestions for fixing sharing issues
- **Graceful Degradation**: App continues working if educator saves fail

### Settings & Configuration

#### EducatorSettingsPage (`lib/presentation/pages/educator_settings_page.dart`)
- **Hebrew RTL Interface**: Complete Hebrew UI with proper text direction
- **Class-Educator Mapping**: Input fields for class names and educator emails
- **Real-time Validation**: Email format validation and duplicate checking
- **Persistent Storage**: Automatic saving to SharedPreferences
- **Visual Feedback**: Success/error notifications in Hebrew

#### Settings Features
- **Add Mappings**: Pair class names with educator email addresses
- **Remove Mappings**: Delete obsolete class-educator associations
- **Email Validation**: Basic validation for email format correctness
- **Sharing Instructions**: Built-in guidance for educators on spreadsheet sharing

### User Experience Enhancements

#### Seamless Integration
- **Zero Breaking Changes**: Existing single-destination workflow unchanged
- **Enhanced Notifications**: Status indicators show sharing success
- **Background Processing**: Multi-destination saves don't block UI
- **Intelligent Caching**: Educator spreadsheet IDs cached for performance

#### Visual Indicators
- **Save Status Display**: Clear indication when records save to both destinations
- **Sharing Configuration**: Visual cues about which classes have educators
- **Error Recovery**: Helpful guidance when educator access is needed

### Technical Implementation

#### Service Integration
```dart
FormProvider.saveRecord() {
  // Uses MultiDestinationSheetsService automatically
  // Maintains same boolean return contract
  // Enhanced with educator sharing capability
}
```

#### Authentication & Permissions
- **Google Drive Metadata Scope**: Enhanced OAuth scope for file metadata access
- **Automatic Permission Fixes**: Auto-adds teacher as editor to protected ranges  
- **Educator Verification**: Confirms spreadsheet ownership before saving
- **Security Validation**: Prevents accidental saves to wrong spreadsheets

#### Performance Optimizations
- **Parallel Operations**: Primary and educator saves run concurrently when possible
- **Intelligent Caching**: Spreadsheet IDs cached to avoid repeated searches
- **Optimistic Responses**: Teachers get immediate confirmation from primary save
- **Background Sync**: Educator saves complete asynchronously

### Data Consistency & Integrity

#### 4-Field Matching Logic
Both primary and educator spreadsheets use identical matching logic:
- **Same Record Detection**: תאריך + שם התלמיד + שם הכיתה + מספר השיעור
- **Update vs Create**: Consistent behavior across both destinations
- **Chronological Sorting**: Intelligent insertion maintains date/class order

#### Protection Schemes
- **Header Protection**: Headers remain protected in both spreadsheets  
- **Data Row Access**: Teachers can write to data rows in educator sheets
- **Fallback Sheets**: Dedicated teacher input areas when needed
- **Ownership Verification**: Confirms correct educator ownership before writes

### Troubleshooting & Support

#### Common Issues & Solutions
1. **Educator Spreadsheet Not Found**
   - Educator needs to share their BPApp spreadsheet with teacher
   - Teacher email must be added as Editor (not Viewer)
   - Both users must have BPApp spreadsheets with standard naming

2. **Permission Denied Errors**
   - Service automatically attempts to fix protection settings
   - Fallback to dedicated "Teacher Input" sheet if blocked
   - Educators can manually adjust sharing permissions if needed

3. **Sync Status Monitoring**
   - Clear indicators show multi-destination save status
   - Failed educator saves don't impact primary data safety
   - Manual retry capabilities for failed educator syncs

#### Debug & Diagnostics
- **Comprehensive Logging**: Detailed debug output with prefixed identifiers
- **Search Strategy Reporting**: Shows which discovery method succeeded
- **Permission Analysis**: Reports on spreadsheet access and edit capabilities
- **Hebrew Error Messages**: User-friendly error reporting and guidance

## SQLite Offline-First Storage

### Architecture Overview
The app implements a robust **offline-first data storage system** using SQLite to ensure teachers never lose data due to connectivity issues while maintaining all existing Google Sheets functionality.

### Core Components

#### LocalStorageService (`lib/services/local_storage_service.dart`)
- **SQLite Database**: Cross-platform local database using `sqflite` package
- **Self-Contained**: Zero external dependencies - everything built into APK
- **ACID Compliance**: Reliable data integrity with proper transaction handling
- **Sync Status Tracking**: Each record tracks pending/synced/failed status

#### Database Schema
```sql
CREATE TABLE student_records (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  date TEXT NOT NULL,                    -- תאריך (DD/MM/YYYY format)
  student_name TEXT NOT NULL,            -- שם התלמיד
  class_name TEXT NOT NULL,              -- שם הכיתה  
  class_number INTEGER NOT NULL,         -- מספר השיעור (1-7)
  entry INTEGER NOT NULL,                -- כניסה (0-1)
  staying INTEGER NOT NULL,              -- שהייה (0-3)
  attitude INTEGER NOT NULL,             -- אווירה (0-2)
  performance INTEGER NOT NULL,          -- ביצוע (0-2)
  personal_goal INTEGER NOT NULL,        -- מטרה אישית (0-2)
  bonus INTEGER NOT NULL,                -- בונוס (0-1)
  total_score INTEGER NOT NULL,          -- סה"כ (calculated)
  comments TEXT,                         -- הערות
  sync_status TEXT DEFAULT 'pending',   -- Sync status tracking
  created_at TEXT NOT NULL,              -- Local creation timestamp
  synced_at TEXT NULL,                   -- Successful sync timestamp
  retry_count INTEGER DEFAULT 0         -- Failed sync retry counter
);
```

### Offline-First Data Flow

#### Save Process (Enhanced saveRecord Method)
```
1. LOCAL SAVE FIRST → Instant confirmation to teacher
   ↓
2. ATTEMPT ONLINE SYNC → Background Google Sheets upload
   ↓  
3. UPDATE SYNC STATUS → Mark as synced/pending based on result
   ↓
4. RETURN SUCCESS → Based on local save (instant feedback)
```

#### Background Synchronization
- **App Launch Sync**: Automatically syncs pending records when app starts
- **Intelligent Retry**: Failed syncs retry with exponential backoff
- **Rate Limited**: 100ms delays prevent API overwhelming
- **Sorted Insertion**: Maintains chronological order during sync using existing intelligent sorting
- **Autocomplete Update**: Synced records update autocomplete suggestions

### Key Features

#### Instant Teacher Feedback
- **Local Save First**: Data saved immediately to SQLite regardless of network
- **No Network Wait**: Teachers get instant confirmation without connectivity delays
- **Progress Indicators**: Clear visual feedback about save and sync status
- **Offline Capable**: App fully functional without internet connection

#### Data Safety & Reliability
- **Multiple Fallbacks**: Local storage → Google Sheets → Emergency fallback
- **Zero Data Loss**: Records preserved locally even during complete network failure  
- **4-Field Matching**: Same matching logic as Google Sheets for consistency
- **Automatic Recovery**: Pending records sync automatically when connectivity returns

#### Feature Flags & Safety
```dart
// Safe rollback capability
static const bool _offlineFirstEnabled = true;
static const bool _offlineStorageEnabled = true;
```

#### Service Methods
- `saveRecord()`: Enhanced offline-first save with local SQLite then background sync
- `getPendingRecords()`: Retrieve all locally stored records awaiting sync
- `syncPendingRecords()`: Background batch sync to Google Sheets with intelligent sorting
- `getSyncStatus()`: Get counts of synced/pending/failed records for UI
- `manualSync()`: Manual sync trigger for user control
- `markAsSynced()`: Update record status after successful Google Sheets sync
- `cleanupOldRecords()`: Remove old synced records (30+ days) to manage storage

### Integration Benefits
- ✅ **Zero Breaking Changes**: All existing FormProvider, UI, and logic work identically
- ✅ **Same Interface**: `saveRecord()` method maintains exact same boolean return contract
- ✅ **Enhanced Reliability**: Network issues no longer cause data loss
- ✅ **Graceful Degradation**: Falls back to online-only if local storage fails
- ✅ **Performance**: Instant saves improve user experience significantly

### Cross-Platform Support
- **Android**: Native SQLite integration via Android SDK
- **iOS**: Native SQLite integration via iOS SDK  
- **Flutter**: `sqflite` package provides unified API across platforms
- **Self-Contained**: All dependencies compiled into APK/IPA - no external requirements

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
  googleapis_auth: ^1.4.1          # Google APIs authentication library  
  provider: ^6.0.5                 # State management
  flutter_secure_storage: ^9.0.0   # Secure token storage
  shared_preferences: ^2.2.2       # Local app preferences
  sqflite: ^2.3.0                  # SQLite local database for offline storage
  path: ^1.8.3                     # File path utilities for database
  intl: ^0.20.2                    # Hebrew localization support
  http: ^1.1.0                     # HTTP client for API calls

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0            # Linting rules
  mockito: ^5.4.2                  # Mocking for tests
  build_runner: ^2.4.7             # Code generation
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
- IGNORE the file "For me.md" - this file is for user's personal usage and Claude Code should not read, modify, or reference it in any way

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

### Development Environment Configuration

#### VS Code Workspace Setup
The project includes optimized VS Code settings in `.vscode/settings.json`:
```json
{
  "dart.flutterSdkPath": null,
  "editor.formatOnSave": true,
  "dart.lineLength": 100
}
```

**Benefits:**
- **Auto-formatting**: Code automatically formats on save following Dart conventions
- **Line Length**: Consistent 100-character line limit for readability
- **Flutter SDK**: Automatic SDK path detection for Windows development
- **RTL Support**: Proper handling of Hebrew text direction in editor

**Recommended VS Code Extensions:**
- Dart
- Flutter  
- Hebrew Language Pack (for UI localization)
- GitLens (for version control visualization)
- Error Lens (for inline error display)

### Firebase/Google Services Setup
The app uses Google OAuth and Sheets API. Configuration files:
- **Android**: `android/app/google-services.json` (already present)
- **iOS**: `ios/Runner/GoogleService-Info.plist` (needs to be added for iOS development)

### Current Implementation Status
Based on the latest codebase analysis:
- ✅ Project structure created with proper Hebrew RTL support
- ✅ Google Authentication service (`lib/services/google_auth_service.dart`) with enhanced error handling
- ✅ Google Sheets service (`lib/services/google_sheets_service.dart`) with trash recovery and sorted insertion
- ✅ Form provider for state management (`lib/presentation/providers/form_provider.dart`)
- ✅ Hebrew theme and constants configured with complete RTL support
- ✅ Main student form page (`lib/presentation/pages/student_form_page.dart`) with recovery notifications
- ✅ Custom Hebrew input widgets (date picker, number picker, text field) with enhanced UX
- ✅ Score display widget with real-time calculation
- ✅ Data models (student record, form field config, autocomplete data)
- ✅ **NEW**: Automatic trash recovery system for deleted spreadsheets
- ✅ **NEW**: Intelligent chronological record insertion and sorting
- ✅ **NEW**: Enhanced authentication with comprehensive debug logging
- ✅ **NEW**: VS Code workspace configuration for optimal Flutter/Dart development

### Dependency Version Notes
Current versions in pubspec.yaml:
- Flutter SDK: ^3.8.1 (Compatible with Flutter 3.32.6 stable)
- Google APIs: googleapis ^11.4.0, google_sign_in ^6.1.5, googleapis_auth ^1.4.1
- State Management: provider ^6.0.5
- Storage: flutter_secure_storage ^9.0.0, shared_preferences ^2.2.2, **sqflite ^2.3.0, path ^1.8.3**
- Localization: intl ^0.20.2, flutter_localizations (SDK)
- Development: flutter_lints ^5.0.0, mockito ^5.4.2, build_runner ^2.4.7
- HTTP: http ^1.1.0

## Current Implementation Status - LATEST (August 2025)

### ✅ COMPLETED FEATURES
1. **SQLite Offline-First Storage System**
   - LocalStorageService with comprehensive SQLite database
   - Offline-first saving with instant teacher feedback
   - Background sync with intelligent retry logic
   - Zero breaking changes to existing functionality

2. **Enhanced Google Sheets Integration**
   - Spreadsheet protection (read-only for users, app-only editing)
   - Intelligent record sorting and insertion (chronological by date, secondary by class number)
   - Automatic trash recovery system
   - Enhanced authentication and error handling with Hebrew messages

3. **Multi-Destination Saving System** ⭐ **NEW**
   - Teachers can save records to both their own AND educator spreadsheets simultaneously
   - Class-to-educator mapping configuration with persistent storage
   - Advanced 3-strategy spreadsheet discovery system
   - Automatic protection management and fallback sheet creation
   - Hebrew RTL settings page for educator configuration
   - Intelligent caching and performance optimizations

4. **Data Safety & Reliability**
   - Multiple fallback layers prevent any data loss scenarios
   - Same 4-field matching logic maintained across local, remote, and educator storage
   - Feature flags allow safe rollback if needed
   - Graceful degradation when components fail

5. **Self-Contained Installation**
   - All SQLite functionality built into APK - zero external dependencies
   - Cross-platform support (Android/iOS) with native SQLite integration
   - No additional apps or setup required for end users

### 🔧 CURRENT ARCHITECTURE
```
Teacher Input → FormProvider → MultiDestinationSheetsService.saveRecord()
                                    ↓
                             [ENHANCED METHOD]
                                    ↓
        ┌─────────────────────────────────────────────────────────┐
        │                                                         │
        ▼                                                         ▼
1. PRIMARY: GoogleSheetsService.saveRecord()          2. EDUCATOR: Check EducatorMappings
        ↓                                                         ↓
   LocalStorageService.saveRecord() (Instant)         Find/Access Educator Spreadsheet
        ↓                                                         ↓
   Background Google Sheets sync                      Save with Intelligent Sorting
        ↓                                                         ↓
   Update sync status                                 Fallback to "Teacher Input" sheet
        ↓                                                         ↓
   Return success (primary)          ←──────────────── Complete (background)
```

### 📁 KEY FILES TO UNDERSTAND
- `lib/services/local_storage_service.dart` - SQLite offline storage implementation
- `lib/services/google_sheets_service.dart` - Enhanced with offline-first saving
- `lib/services/multi_destination_sheets_service.dart` - **NEW**: Multi-destination saving orchestrator
- `lib/core/educator_mappings.dart` - **NEW**: Class-to-educator mapping configuration
- `lib/presentation/pages/educator_settings_page.dart` - **NEW**: Hebrew RTL settings interface
- `lib/presentation/providers/form_provider.dart` - Unchanged, works with enhanced services
- `lib/data/models/student_record.dart` - Core data model used by all storage systems
- `pubspec.yaml` - Updated dependencies including sqflite and path packages

### 🚀 READY FOR PRODUCTION
The BPApp is now production-ready with enterprise-grade offline capabilities and advanced collaboration features:
- ✅ Teachers never lose data due to connectivity issues
- ✅ Instant save confirmation improves user experience  
- ✅ Background sync maintains Google Sheets integration
- ✅ **NEW**: Multi-destination saving enables seamless teacher-educator collaboration
- ✅ **NEW**: Advanced spreadsheet discovery with 3-strategy fallback system
- ✅ **NEW**: Automatic protection management and fallback sheet creation
- ✅ Same familiar interface with enhanced reliability and sharing capabilities
- ✅ Self-contained APK requires no external setup from users

### 🔮 NEXT PHASE: Service Account & Firebase System
**Development Plan**: See [DEVELOPMENT_ROADMAP.md](DEVELOPMENT_ROADMAP.md) for complete implementation plan.
- **Target**: Admin-controlled Firebase database with Google Service Account
- **Benefits**: Zero manual sharing, dropdown class selection, centralized management
- **Branch**: `feature/service-account-firebase-system`
- **Rollback**: Tagged stable version `v3.0-last-stable-version` always available