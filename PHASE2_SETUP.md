# Phase 2: Firebase Backend Setup Instructions

## 🎯 Understanding the Data Model

### User Roles & Relationships:
1. **Teachers** - Regular users who record student data
2. **Educators** - Teachers who ALSO lead a class (dual role)
   - Have their own class named after them
   - Receive copies of data when OTHER teachers record their students
   - When they record their OWN students, data saves only once

### Collection Relationships:
- `users` → All app users (teachers, educators, admins)
- `educators` → Classes/groups (named after their educator)  
- `students` → Students belonging to specific classes
- Email field in `educators` links to the user who owns that class

### Key Relationships:
1. **users.email** ↔ **educators.email** (identifies which user owns which class)
2. **educators.id** ↔ **students.educatorId** (links students to their class)
3. Regular teachers can record data for ANY student
4. Data routing depends on educator email matching

## 🚀 Quick Setup Guide

### Step 1: Enable Firestore Database (5 minutes)

1. **Open Firebase Console**:
   ```
   https://console.firebase.google.com/project/bpapp-firebase-485c1/firestore
   ```

2. **Create Database**:
   - Click "Create database"
   - Choose **"Start in production mode"**
   - Select location: **eur3 (europe-west)** or nearest to Israel
   - Click "Enable"

### Step 2: Deploy Security Rules (2 minutes)

1. **Install Firebase CLI** (if not installed):
   ```bash
   npm install -g firebase-tools
   ```

2. **Login to Firebase**:
   ```bash
   firebase login
   ```

3. **Initialize Firebase in project**:
   ```bash
   cd C:\BPA_Sup\BPA_Fllutter
   firebase init firestore
   # Select: Use an existing project
   # Choose: bpapp-firebase-485c1
   # Accept default for rules file (firestore.rules)
   # Skip indexes file for now
   ```

4. **Deploy the rules**:
   ```bash
   firebase deploy --only firestore:rules
   ```

### Step 3: Create Initial Collections (5 minutes)

In Firebase Console, manually create these collections with sample documents:

#### 1. **users** collection (All app users - teachers and admins):

**Example 1 - Admin User:**
```json
Document ID: [Google Auth UID for yon.level@gmail.com]
{
  "email": "yon.level@gmail.com",
  "name": "יון לבל",
  "role": "admin",
  "createdAt": [Server Timestamp],
  "lastLogin": [Server Timestamp]
}
```

**Example 2 - Educator User (dual role - teacher + class leader):**
```json
Document ID: [Google Auth UID for moshe.cohen@school.edu]
{
  "email": "moshe.cohen@school.edu",
  "name": "משה כהן",
  "role": "teacher",  // or "educator" - both work
  "createdAt": [Server Timestamp],
  "lastLogin": [Server Timestamp]
}
```

**Example 3 - Regular Teacher (not a class leader):**
```json
Document ID: [Google Auth UID for sarah.levi@school.edu]
{
  "email": "sarah.levi@school.edu",
  "name": "שרה לוי",
  "role": "teacher",
  "createdAt": [Server Timestamp],
  "lastLogin": [Server Timestamp]
}
```

#### 2. **educators** collection (Classes/Groups named after their educator):

**Example 1 - Class led by Moshe Cohen:**
```json
Document ID: [Auto-generated, e.g., "edu_001"]
{
  "name": "משה כהן",  // Class name shown in dropdown
  "email": "moshe.cohen@school.edu",  // MUST match the educator's email in users collection
  "active": true,
  "createdAt": [Server Timestamp]
}
```

**Example 2 - Class led by Rachel Green:**
```json
Document ID: [Auto-generated, e.g., "edu_002"]
{
  "name": "רחל גרין",
  "email": "rachel.green@school.edu",
  "active": true,
  "createdAt": [Server Timestamp]
}
```

**Example 3 - Class led by David Miller:**
```json
Document ID: [Auto-generated, e.g., "edu_003"]
{
  "name": "דוד מילר",
  "email": "david.miller@school.edu",
  "active": true,
  "createdAt": [Server Timestamp]
}
```

**Important**: 
- The email MUST match a user in the users collection who is the educator
- When Sarah Levi (regular teacher) records data for students in "משה כהן" class, it saves to both Sarah's spreadsheet AND Moshe's spreadsheet
- When Moshe Cohen records his own students, it saves only once (to his spreadsheet)

#### 3. **students** collection (Students belonging to specific classes):

**Students in Moshe Cohen's class:**
```json
Document ID: [Auto-generated]
{
  "name": "יוסי ישראלי",
  "educatorId": "edu_001",  // Links to Moshe Cohen's educator document
  "educatorName": "משה כהן",  // Denormalized for quick display
  "grade": "כיתה ג",
  "notes": "",
  "active": true,
  "createdAt": [Server Timestamp]
}
```

```json
Document ID: [Auto-generated]
{
  "name": "מיכל אברהם",
  "educatorId": "edu_001",
  "educatorName": "משה כהן",
  "grade": "כיתה ג",
  "notes": "תלמידה מצטיינת",
  "active": true,
  "createdAt": [Server Timestamp]
}
```

**Students in Rachel Green's class:**
```json
Document ID: [Auto-generated]
{
  "name": "דני כץ",
  "educatorId": "edu_002",  // Links to Rachel Green's educator document
  "educatorName": "רחל גרין",
  "grade": "כיתה ב",
  "notes": "",
  "active": true,
  "createdAt": [Server Timestamp]
}
```

```json
Document ID: [Auto-generated]
{
  "name": "נועה שמש",
  "educatorId": "edu_002",
  "educatorName": "רחל גרין",
  "grade": "כיתה ב",
  "notes": "",
  "active": true,
  "createdAt": [Server Timestamp]
}
```

Add 4-6 students per class/educator.

#### 4. **config** collection:
```json
Document ID: app_settings
{
  "version": "1.0.0",
  "maintenanceMode": false,
  "features": {
    "useServiceAccount": true,
    "useFirebaseData": false
  }
}
```

### Example Data Flow:

When **Sarah Levi** (regular teacher) records data for **יוסי ישראלי** (student in Moshe Cohen's class):
1. Data saves to Sarah's "BPApp" spreadsheet
2. Data ALSO saves to Moshe Cohen's "BPApp" spreadsheet (because he's the educator)

When **Moshe Cohen** (educator) records data for **יוסי ישראלי** (his own student):
1. Data saves ONLY to Moshe's "BPApp" spreadsheet (no duplication)

When **Sarah Levi** records data for a student with no educator mapping:
1. Data saves ONLY to Sarah's "BPApp" spreadsheet

### Step 4: Update App Configuration (2 minutes)

1. **Edit** `lib/config/app_config.dart`:
   ```dart
   // Change this line:
   static const bool useFirebaseBackend = true;  // Enable Firebase
   ```

2. **Initialize Firebase in main.dart** (should already be done):
   ```dart
   // Check that main.dart has:
   await Firebase.initializeApp();
   ```

### Step 5: Test the Integration (5 minutes)

1. **Run the app**:
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```

2. **Verify**:
   - App starts without errors
   - Firebase console shows read operations
   - Check debug console for: `[FIREBASE_DATA] Firebase data service initialization successful`

## 📝 Checklist

- [ ] Firestore database enabled in Firebase Console
- [ ] Security rules deployed
- [ ] Initial collections created with sample data
- [ ] app_config.dart updated to enable Firebase
- [ ] App runs and connects to Firestore

## 🔧 Troubleshooting

### "Permission Denied" errors:
1. Check that user is authenticated
2. Verify security rules are deployed
3. Ensure user document exists in 'users' collection with proper role

### "Firebase not initialized":
1. Ensure `Firebase.initializeApp()` is called in main.dart
2. Check that google-services.json is in android/app/

### No data showing:
1. Check Firestore has sample data
2. Verify `useFirebaseBackend = true` in app_config.dart
3. Check network connectivity

## 📊 Monitor Usage

Track your Firestore usage:
```
https://console.firebase.google.com/project/bpapp-firebase-485c1/firestore/usage
```

Free tier limits:
- 50,000 reads/day
- 20,000 writes/day
- 20,000 deletes/day
- 1GB storage

## 🎯 Next Steps

After setup is complete:
1. Test dropdown functionality with Firebase data
2. Implement admin interface for data management
3. Add CSV import functionality
4. Test offline caching behavior

## 📚 Resources

- [Firestore Documentation](https://firebase.google.com/docs/firestore)
- [Security Rules Guide](https://firebase.google.com/docs/firestore/security/get-started)
- [Flutter Firebase Setup](https://firebase.google.com/docs/flutter/setup)

---

**Status**: Ready to implement
**Time Required**: ~20 minutes
**Difficulty**: Medium