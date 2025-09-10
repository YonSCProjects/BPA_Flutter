# Database Migration Plan: Educators → Users Collection

## Executive Summary
Consolidate the redundant `educators` collection into the `users` collection to eliminate data duplication and sync issues. This migration affects 30+ files across Flutter app, web admin, and Firebase configuration.

## Current State Analysis

### Redundancy Problem
- **Users collection**: `{email, role: "educator", name, createdAt, updatedAt}`
- **Educators collection**: `{email, name, classes[], spreadsheetId, active}`
- **Duplication**: Email and name exist in both places
- **Risk**: Data can get out of sync between collections

### Dependencies Found
- **Flutter App**: 9 service files, 3 UI components
- **Web Admin**: 5 pages, navigation, import functionality
- **Firebase**: 4 security rule files
- **Data/Scripts**: Sample data, import scripts
- **Documentation**: Multiple MD files

## Migration Strategy

### Target Schema (Users Collection Enhanced)
```javascript
{
  // Existing fields
  email: string,
  name: string,
  role: "admin" | "educator" | "teacher",
  createdAt: timestamp,
  updatedAt: timestamp,
  
  // New fields (only for role="educator")
  active: boolean,        // Default: true
  classes: string[],      // Classes they manage
  spreadsheetId: string,  // Their Google Sheet ID
  autoInitialized: boolean, // Track if self-setup
  
  // Optional fields
  phoneNumber: string,
  address: string
}
```

## Phased Implementation Plan

### Phase 0: Pre-Migration Setup (Safety First)
1. **Create feature flag** in `app_config.dart`:
   ```dart
   static const bool useLegacyEducatorsCollection = true; // Start with legacy
   ```
2. **Backup Firestore data** via Firebase Console
3. **Create rollback script** to restore if needed
4. **Test in dev environment first**

### Phase 1: Schema Enhancement
**Goal**: Add educator fields to users collection without breaking anything

1. **Manual Firestore Update** (via Firebase Console or script):
   - Add fields to existing educator users:
     - `active: true`
     - `classes: []`
     - `spreadsheetId: ""`
   
2. **Update Firebase Security Rules** (`firestore.rules`):
   ```javascript
   // Add new function
   function isEducatorRole() {
     return request.auth != null && 
            get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'educator';
   }
   
   // Keep old isEducator() for now (backward compatibility)
   function isEducator() {
     return request.auth != null && 
            exists(/databases/$(database)/documents/educators/$(request.auth.uid));
   }
   ```

### Phase 2: Data Migration Script
**Goal**: Copy educator data to users collection

Create `scripts/migrate_educators_to_users.js`:
```javascript
async function migrateEducators() {
  // 1. Read all educators
  const educators = await db.collection('educators').get();
  
  // 2. For each educator
  for (const educatorDoc of educators.docs) {
    const educatorData = educatorDoc.data();
    
    // 3. Find matching user by email
    const userQuery = await db.collection('users')
      .where('email', '==', educatorData.email)
      .limit(1)
      .get();
    
    if (!userQuery.empty) {
      // 4. Update user with educator fields
      await userQuery.docs[0].ref.update({
        active: educatorData.active ?? true,
        classes: educatorData.classes ?? [],
        spreadsheetId: educatorData.spreadsheetId ?? '',
        migratedFromEducators: true,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });
    } else {
      // 5. Create new user if doesn't exist
      await db.collection('users').add({
        email: educatorData.email,
        name: educatorData.name,
        role: 'educator',
        active: educatorData.active ?? true,
        classes: educatorData.classes ?? [],
        spreadsheetId: educatorData.spreadsheetId ?? '',
        createdFromEducatorsMigration: true,
        createdAt: admin.firestore.FieldValue.serverTimestamp()
      });
    }
  }
}
```

### Phase 3: Flutter App Updates
**Goal**: Update app to use users collection with feature flag

1. **Update `firebase_data_service.dart`**:
   ```dart
   Future<void> _loadEducators() async {
     if (AppConfig.useLegacyEducatorsCollection) {
       // OLD: Use educators collection
       final snapshot = await _firestore!
           .collection(_educatorsCollection)
           .where('active', isEqualTo: true)
           .get();
     } else {
       // NEW: Use users collection with role filter
       final snapshot = await _firestore!
           .collection('users')
           .where('role', isEqualTo: 'educator')
           .where('active', isEqualTo: true)
           .get();
     }
   }
   ```

2. **Update `educator_initialization_service.dart`**:
   - Check both collections during transition
   - Prefer users collection when flag is off

3. **Update `multi_destination_sheets_service.dart`**:
   - Query users collection for educator spreadsheets

### Phase 4: Web Admin Updates
**Goal**: Unify educator management in users page

1. **Merge Educators into Users Page**:
   - Add role-based filtering tabs
   - Show educator-specific fields conditionally
   - Keep educators page during transition

2. **Update Import Functionality**:
   - Modify bulk import to handle educator fields
   - Support both old and new format

3. **Update Navigation** (after testing):
   - Remove educators link from sidebar
   - Redirect /educators to /users?role=educator

### Phase 5: Testing & Validation

#### Test Checklist:
- [ ] Educator login and spreadsheet creation
- [ ] Multi-destination saving to educator sheets
- [ ] Firebase security rules (both collections)
- [ ] Web admin CRUD operations
- [ ] Bulk import/export
- [ ] Student-educator relationships
- [ ] Offline sync functionality

#### Validation Queries:
```javascript
// Verify all educators migrated
const oldCount = await db.collection('educators').get();
const newCount = await db.collection('users')
  .where('role', '==', 'educator').get();
console.log(`Old: ${oldCount.size}, New: ${newCount.size}`);

// Check for missing spreadsheetIds
const missing = await db.collection('users')
  .where('role', '==', 'educator')
  .where('spreadsheetId', '==', '').get();
console.log(`Educators without spreadsheets: ${missing.size}`);
```

### Phase 6: Cleanup (After 2-Week Stability)

1. **Disable feature flag**:
   ```dart
   static const bool useLegacyEducatorsCollection = false;
   ```

2. **Remove legacy code**:
   - Delete educators collection references
   - Remove old security rules
   - Clean up duplicate functions

3. **Archive educators collection**:
   - Export to JSON for backup
   - Delete from Firestore

4. **Update documentation**:
   - Remove educators collection mentions
   - Update API docs
   - Update README files

## Rollback Plan

If issues arise at any phase:

1. **Immediate Rollback**:
   ```dart
   // Flip feature flag back
   static const bool useLegacyEducatorsCollection = true;
   ```

2. **Data Restoration** (if needed):
   ```javascript
   // Restore educators collection from backup
   const backup = require('./educators_backup.json');
   for (const doc of backup) {
     await db.collection('educators').doc(doc.id).set(doc.data);
   }
   ```

3. **Clear migration flags**:
   ```javascript
   // Remove migration markers from users
   const users = await db.collection('users')
     .where('migratedFromEducators', '==', true).get();
   for (const user of users.docs) {
     await user.ref.update({
       migratedFromEducators: admin.firestore.FieldValue.delete(),
       classes: admin.firestore.FieldValue.delete(),
       spreadsheetId: admin.firestore.FieldValue.delete(),
       active: admin.firestore.FieldValue.delete()
     });
   }
   ```

## Risk Mitigation

### Critical Risks:
1. **Data Loss**: Mitigated by backups and phased approach
2. **App Downtime**: Feature flags allow instant rollback
3. **Sync Issues**: Parallel operation during transition
4. **Auth Problems**: Keep both security rules active

### Monitoring During Migration:
- Firebase Console for errors
- App crash reports
- User feedback channel
- Database write patterns

## Success Criteria

Migration is complete when:
- ✅ All educator data exists in users collection
- ✅ No references to educators collection in code
- ✅ Multi-destination saving works perfectly
- ✅ Web admin shows unified user management
- ✅ 2 weeks of stable operation
- ✅ Educators collection deleted

## Timeline Estimate

- **Phase 0-1**: 1 day (Setup & Schema)
- **Phase 2**: 1 day (Migration Script)
- **Phase 3**: 2 days (Flutter Updates)
- **Phase 4**: 2 days (Web Admin)
- **Phase 5**: 2 days (Testing)
- **Stability Period**: 2 weeks
- **Phase 6**: 1 day (Cleanup)

**Total**: ~1 week active work + 2 weeks monitoring

## Next Steps

1. Review this plan with team
2. Set migration date
3. Create dev environment for testing
4. Begin Phase 0 setup

---

**Note**: This migration simplifies the entire system but requires careful execution. The feature flag approach ensures we can roll back instantly if any issues arise.