# Service Account Ownership Implementation Plan

## Executive Summary
This document outlines the complete implementation plan for transitioning BPApp to a service-account-owned spreadsheet architecture where all spreadsheets are created and owned by the service account, with users having read-only access.

## Table of Contents
1. [Architecture Overview](#architecture-overview)
2. [Benefits & Drawbacks](#benefits--drawbacks)
3. [Prerequisites](#prerequisites)
4. [Implementation Phases](#implementation-phases)
5. [Technical Changes Required](#technical-changes-required)
6. [Data Migration Strategy](#data-migration-strategy)
7. [Rollback Plan](#rollback-plan)
8. [Testing Strategy](#testing-strategy)
9. [Security Considerations](#security-considerations)
10. [Future Maintenance](#future-maintenance)

## Architecture Overview

### Current Architecture
```
USER owns spreadsheet
├── Created by: User's Google Account
├── Shared with: Service Account (editor)
└── Location: User's "My Drive"

EDUCATOR owns spreadsheet  
├── Created by: Educator's Google Account
├── Shared with: Service Account (editor)
└── Location: Educator's "My Drive"
```

### New Architecture
```
SERVICE ACCOUNT owns ALL spreadsheets
├── Created by: Service Account
├── Shared with: User (viewer only)
└── Location: User sees in "Shared with me"
```

## Benefits & Drawbacks

### ✅ Benefits
1. **True Read-Only Access**: Users cannot edit or delete data
2. **Centralized Control**: Service account manages everything
3. **Consistent Permissions**: No variation in access levels
4. **Protection from Accidental Deletion**: Users can't delete what they don't own
5. **Simplified Multi-Destination**: Service account owns all sheets

### ⚠️ Drawbacks
1. **User Psychology**: Data appears in "Shared with me" not "My Drive"
2. **Single Point of Failure**: Service account becomes critical
3. **No User Control**: Users can't export/manage their own data directly
4. **GDPR Concerns**: Users don't "own" their data
5. **Rate Limits**: All operations count against service account quota

## Prerequisites

### 1. Service Account Configuration
- Verify service account has necessary scopes:
  - `https://www.googleapis.com/auth/spreadsheets`
  - `https://www.googleapis.com/auth/drive.file`
  - `https://www.googleapis.com/auth/drive`

### 2. Firestore Structure
```javascript
users/{userId} {
  email: string,
  displayName: string,
  role: "teacher" | "educator",
  spreadsheetId: string,  // Service account's sheet for this user
  createdAt: timestamp,
  lastSync: timestamp
}

educator_mappings/{className} {
  educatorEmail: string,
  educatorName: string,
  spreadsheetId: string  // Educator's sheet ID
}
```

### 3. Backup System
- Implement backup/recovery feature FIRST (already completed)
- Ensure all users backup their data before migration

## Implementation Phases

### Phase 1: Service Account Authentication Enhancement
**Duration**: 2 days  
**Risk**: Low

1. Modify `ServiceAccountSheetsService` to handle all operations
2. Add Firestore access for user/educator lookups
3. Implement spreadsheet creation with viewer sharing

### Phase 2: Update Core Services
**Duration**: 3 days  
**Risk**: Medium

1. Modify `GoogleSheetsService` to route all operations through service account
2. Update `_createSpreadsheet()` to use service account
3. Change `_findExistingSpreadsheet()` logic for new ownership model
4. Update multi-destination service

### Phase 3: User Interface Updates
**Duration**: 1 day  
**Risk**: Low

1. Update UI to reflect read-only status
2. Add export functionality since users can't download directly
3. Update help text and user guidance

### Phase 4: Migration of Existing Users
**Duration**: 2-3 days  
**Risk**: High

1. Create migration script
2. For each existing user:
   - Service account creates new spreadsheet
   - Copy all data from user's spreadsheet
   - Share new sheet with user (viewer)
   - Update Firestore with new sheet ID

### Phase 5: Testing & Validation
**Duration**: 2 days  
**Risk**: Low

1. Test all CRUD operations
2. Verify multi-destination saving
3. Test backup/recovery with new architecture
4. Performance testing

## Technical Changes Required

### 1. Service Account Spreadsheet Creation
```dart
// lib/services/service_account_sheets_service.dart

Future<String?> createUserSpreadsheet(String userEmail, String userName) async {
  // Create spreadsheet owned by service account
  final spreadsheet = sheets.Spreadsheet(
    properties: sheets.SpreadsheetProperties(
      title: 'BPApp - $userName',
      locale: 'he_IL',
      timeZone: 'Asia/Jerusalem',
    ),
  );
  
  final response = await _sheetsApi!.spreadsheets.create(spreadsheet);
  final spreadsheetId = response.spreadsheetId!;
  
  // Share with user as viewer only
  await _shareAsViewer(spreadsheetId, userEmail);
  
  // Update Firestore
  await _updateUserSpreadsheetId(userEmail, spreadsheetId);
  
  return spreadsheetId;
}

Future<void> _shareAsViewer(String spreadsheetId, String userEmail) async {
  final permission = drive.Permission()
    ..type = 'user'
    ..role = 'reader'  // Viewer only!
    ..emailAddress = userEmail;
    
  await _driveApi!.permissions.create(
    permission,
    spreadsheetId,
    sendNotificationEmail: true,
  );
}
```

### 2. Modified Save Flow
```dart
// All saves go through service account
Future<bool> saveRecord(StudentRecord record, String currentUserEmail) async {
  // Get user's spreadsheet (owned by service account)
  final userSpreadsheetId = await _getUserSpreadsheetId(currentUserEmail);
  
  if (userSpreadsheetId == null) {
    // Create new spreadsheet for user
    userSpreadsheetId = await createUserSpreadsheet(currentUserEmail, userName);
  }
  
  // Write to user's spreadsheet (service account has owner access)
  await _writeToSpreadsheet(userSpreadsheetId, record);
  
  // Check for educator mapping and write if needed
  final educatorEmail = await _getEducatorForClass(record.className);
  if (educatorEmail != null) {
    final educatorSpreadsheetId = await _getUserSpreadsheetId(educatorEmail);
    if (educatorSpreadsheetId != null) {
      await _writeToSpreadsheet(educatorSpreadsheetId, record);
    }
  }
  
  return true;
}
```

### 3. Firestore Integration
```dart
// Get user's spreadsheet ID from Firestore
Future<String?> _getUserSpreadsheetId(String userEmail) async {
  final querySnapshot = await FirebaseFirestore.instance
    .collection('users')
    .where('email', isEqualTo: userEmail)
    .limit(1)
    .get();
    
  if (querySnapshot.docs.isNotEmpty) {
    return querySnapshot.docs.first.data()['spreadsheetId'];
  }
  
  return null;
}

// Update user's spreadsheet ID in Firestore
Future<void> _updateUserSpreadsheetId(String userEmail, String spreadsheetId) async {
  final querySnapshot = await FirebaseFirestore.instance
    .collection('users')
    .where('email', isEqualTo: userEmail)
    .limit(1)
    .get();
    
  if (querySnapshot.docs.isNotEmpty) {
    await querySnapshot.docs.first.reference.update({
      'spreadsheetId': spreadsheetId,
      'lastSync': FieldValue.serverTimestamp(),
    });
  }
}
```

### 4. Discovery Logic Changes
```dart
// Find user's spreadsheet (now owned by service account)
Future<String?> findUserSpreadsheet(String userEmail) async {
  // First check Firestore cache
  final cachedId = await _getUserSpreadsheetId(userEmail);
  if (cachedId != null) {
    // Verify it still exists
    if (await _verifySpreadsheetExists(cachedId)) {
      return cachedId;
    }
  }
  
  // Search Drive for service-account-owned sheets shared with user
  final query = "name contains 'BPApp' and "
               "mimeType='application/vnd.google-apps.spreadsheet' and "
               "'${_serviceAccountEmail}' in owners and "
               "'$userEmail' in readers";
               
  final response = await _driveApi!.files.list(
    q: query,
    spaces: 'drive',
  );
  
  if (response.files != null && response.files!.isNotEmpty) {
    final spreadsheetId = response.files!.first.id!;
    await _updateUserSpreadsheetId(userEmail, spreadsheetId);
    return spreadsheetId;
  }
  
  return null;
}
```

## Data Migration Strategy

### Step 1: Pre-Migration Backup
```dart
// Force backup for all active users
Future<void> preMigrationBackup(String userEmail) async {
  final backupService = BackupRecoveryService(...);
  final success = await backupService.createBackup();
  
  if (!success) {
    throw Exception('Backup failed for user: $userEmail');
  }
  
  // Log backup completion
  await logMigrationStep(userEmail, 'backup_completed');
}
```

### Step 2: Migration Process
```dart
Future<void> migrateUserToServiceAccount(String userEmail) async {
  try {
    // 1. Create service-account-owned spreadsheet
    final newSpreadsheetId = await createUserSpreadsheet(userEmail, userName);
    
    // 2. Copy all data from old spreadsheet
    final oldData = await fetchAllDataFromUserSpreadsheet(oldSpreadsheetId);
    await writeAllDataToSpreadsheet(newSpreadsheetId, oldData);
    
    // 3. Update Firestore
    await updateUserSpreadsheetId(userEmail, newSpreadsheetId);
    
    // 4. Rename old spreadsheet to indicate migration
    await renameSpreadsheet(oldSpreadsheetId, 'BPApp - MIGRATED - $userName');
    
    // 5. Log success
    await logMigrationStep(userEmail, 'migration_completed');
    
  } catch (e) {
    await logMigrationStep(userEmail, 'migration_failed', error: e.toString());
    throw e;
  }
}
```

### Step 3: Verification
```dart
Future<bool> verifyMigration(String userEmail) async {
  // 1. Check new spreadsheet exists
  final newId = await _getUserSpreadsheetId(userEmail);
  if (newId == null) return false;
  
  // 2. Verify service account ownership
  final file = await _driveApi!.files.get(newId);
  if (file.owners?.first.emailAddress != _serviceAccountEmail) return false;
  
  // 3. Verify user has viewer access
  if (!file.permissions?.any((p) => 
    p.emailAddress == userEmail && p.role == 'reader')) return false;
  
  // 4. Check data integrity
  final recordCount = await countRecordsInSpreadsheet(newId);
  return recordCount > 0;
}
```

## Rollback Plan

### Immediate Rollback (Phase 1-2)
1. Revert code changes via Git
2. Deploy previous version
3. No data changes needed

### Post-Migration Rollback (Phase 4+)
1. Keep old user spreadsheets (renamed but intact)
2. Update Firestore to point back to old sheet IDs
3. Remove viewer permissions from service account sheets
4. Deploy previous code version

### Rollback Verification
```dart
Future<bool> verifyRollback(String userEmail) async {
  // Check user owns their spreadsheet again
  final spreadsheetId = await findUserOwnedSpreadsheet(userEmail);
  return spreadsheetId != null;
}
```

## Testing Strategy

### Unit Tests
```dart
test('Service account creates spreadsheet with correct permissions', () async {
  final spreadsheetId = await service.createUserSpreadsheet(
    'test@example.com',
    'Test User'
  );
  
  expect(spreadsheetId, isNotNull);
  
  // Verify ownership
  final file = await driveApi.files.get(spreadsheetId);
  expect(file.owners.first.emailAddress, equals(serviceAccountEmail));
  
  // Verify viewer permission
  expect(
    file.permissions.any((p) => 
      p.emailAddress == 'test@example.com' && 
      p.role == 'reader'
    ),
    isTrue
  );
});
```

### Integration Tests
1. Create user account → Verify spreadsheet creation
2. Save record → Verify write through service account
3. Multi-destination save → Verify both sheets updated
4. User attempts edit → Verify read-only enforcement

### Performance Tests
- Measure API quota usage under load
- Test with 100+ concurrent users
- Monitor rate limit hits

## Security Considerations

### 1. Service Account Credentials
```yaml
# Enhanced security measures:
- Store credentials in secure storage (not in repo)
- Rotate private keys regularly
- Monitor for unauthorized access
- Implement audit logging
```

### 2. Access Control
```dart
// Verify user identity before operations
Future<bool> verifyUserAccess(String claimedEmail, String authToken) async {
  final decodedToken = await FirebaseAuth.instance.verifyIdToken(authToken);
  return decodedToken.email == claimedEmail;
}
```

### 3. Data Privacy
- Users can only see their own spreadsheet
- Educators only see educator spreadsheets
- Implement data export for GDPR compliance

### 4. Audit Logging
```dart
// Log all service account operations
Future<void> logOperation(String operation, String userEmail, String spreadsheetId) async {
  await FirebaseFirestore.instance.collection('audit_logs').add({
    'operation': operation,
    'userEmail': userEmail,
    'spreadsheetId': spreadsheetId,
    'timestamp': FieldValue.serverTimestamp(),
    'serviceAccount': _serviceAccountEmail,
  });
}
```

## Future Maintenance

### Monthly Tasks
1. Review audit logs for anomalies
2. Check API quota usage trends
3. Rotate service account credentials
4. Backup service account spreadsheets

### Monitoring
```dart
// Health check endpoint
Future<Map<String, dynamic>> healthCheck() async {
  return {
    'serviceAccountActive': await checkServiceAccountAuth(),
    'apiQuotaRemaining': await getQuotaStatus(),
    'totalSpreadsheets': await countServiceAccountSpreadsheets(),
    'recentErrors': await getRecentErrors(hours: 24),
  };
}
```

### Scaling Considerations
- If exceeding 100 users: Consider multiple service accounts
- If exceeding quota: Implement request batching
- If performance degrades: Add caching layer

## Implementation Checklist

### Pre-Implementation
- [ ] Backup all existing user data
- [ ] Document current spreadsheet IDs
- [ ] Notify users of upcoming changes
- [ ] Set up monitoring and logging

### Implementation
- [ ] Phase 1: Service Account Enhancement
- [ ] Phase 2: Core Services Update
- [ ] Phase 3: UI Updates
- [ ] Phase 4: User Migration
- [ ] Phase 5: Testing & Validation

### Post-Implementation
- [ ] Verify all users migrated successfully
- [ ] Monitor for 48 hours
- [ ] Document any issues encountered
- [ ] Update user documentation
- [ ] Remove old spreadsheet references after 30 days

## Risk Matrix

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| Service account compromise | Low | Critical | Credential rotation, monitoring |
| API quota exceeded | Medium | High | Request batching, multiple accounts |
| User rejection | Medium | Medium | Clear communication, training |
| Migration data loss | Low | Critical | Comprehensive backups |
| Rollback needed | Low | High | Keep old sheets for 30 days |

## Support Documentation

### For Users
- "Your data is now more secure"
- "Find your data in 'Shared with me'"
- "Use export feature for local copies"

### For Developers
- Service account operations guide
- Troubleshooting common issues
- Migration script documentation

## Conclusion

This architecture provides maximum data protection at the cost of user ownership. The implementation is technically feasible with regular Google accounts and provides true read-only access for users while maintaining full functionality through the service account.

**Estimated Total Implementation Time**: 8-10 days  
**Recommended Go-Live**: After thorough testing with subset of users

---

*Document Version: 1.0*  
*Last Updated: January 2025*  
*Author: BPApp Development Team*