# Migration Testing Instructions

## Current Status: READY FOR TESTING

All code has been updated to support both legacy educators collection and new users collection through feature flags.

## Step 1: Backup Your Data (CRITICAL)

```bash
cd scripts
node backup_educators_collection.js
```

This creates a backup in `backups/` folder. Keep this safe!

## Step 2: Test Current Setup (Feature Flag OFF)

**Current Configuration:**
- Flutter: `AppConfig.useLegacyEducatorsCollection = true`
- Web Admin: `MigrationConfig.useLegacyEducatorsCollection = true`

### Test Checklist:
- [ ] Flutter app loads educator dropdowns
- [ ] Teachers can save student records
- [ ] Multi-destination saving works
- [ ] Web admin shows educators page
- [ ] Can add/edit/delete educators in web admin

## Step 3: Run Migration Script (DRY RUN First)

```bash
cd scripts
# First, do a dry run to see what will happen
node migrate_educators_to_users.js --dry-run --verbose

# Review the output, then run the actual migration
node migrate_educators_to_users.js --verbose
```

### What the Script Does:
1. Backs up all data
2. Copies educator fields to users collection
3. Updates student references (educatorId mappings)
4. Verifies migration success

## Step 4: Enable New Structure (Feature Flag ON)

### Flutter App:
Edit `lib/config/app_config.dart`:
```dart
static const bool useLegacyEducatorsCollection = false; // Changed to false
```

### Web Admin:
Edit `web-admin/lib/migration-config.ts`:
```typescript
useLegacyEducatorsCollection: false, // Changed to false
```

## Step 5: Test New Structure

### Critical Test Points:

#### 1. **Educator Auto-Initialization**
- Have an educator log in
- Check if their spreadsheetId auto-saves to users collection
- Verify service account sharing works

#### 2. **Multi-Destination Saving**
- Teacher saves a student record
- Verify it saves to both teacher and educator sheets
- Check educator lookup uses users collection

#### 3. **Firebase Dropdowns**
- Open student form
- Verify educator dropdown loads from users collection
- Check all educators appear correctly

#### 4. **Web Admin Portal**
- Navigate to educators page
- Verify it shows educators from users collection
- Test add/edit/delete operations
- Check import functionality

#### 5. **Student References**
- Verify students still linked to correct educators
- Check educatorId points to users collection docs

## Step 6: Monitor for Issues

### Watch for:
- [ ] Any Firebase permission errors
- [ ] Missing educator data
- [ ] Broken student-educator relationships
- [ ] Multi-destination save failures
- [ ] Dropdown loading issues

### Debug Commands:

Check migration status:
```javascript
// In Firebase Console or script
const users = await db.collection('users')
  .where('role', '==', 'educator').get();
console.log('Educators in users:', users.size);

const educators = await db.collection('educators').get();
console.log('Legacy educators:', educators.size);
```

## Step 7: Rollback (If Needed)

If ANY issues occur:

### Immediate Rollback:

1. **Flutter App:**
```dart
static const bool useLegacyEducatorsCollection = true; // Back to true
```

2. **Web Admin:**
```typescript
useLegacyEducatorsCollection: true, // Back to true
```

3. **Restore Data (if needed):**
```bash
cd scripts
node restore_educators_backup.js --file backups/educators_backup_latest.json
```

## Step 8: Final Cleanup (After 2 Weeks Stable)

Once everything is stable for 2 weeks:

1. **Remove Feature Flags:**
   - Remove `useLegacyEducatorsCollection` from both apps
   - Remove all legacy code paths

2. **Archive Educators Collection:**
   ```bash
   cd scripts
   node archive_and_delete_educators.js
   ```

3. **Update Documentation:**
   - Remove references to educators collection
   - Update all docs to reflect users collection

## Troubleshooting

### Issue: Educators not appearing in dropdowns
- Check Firebase security rules allow reading users collection
- Verify role='educator' filter is working
- Check console for Firebase errors

### Issue: Multi-destination save fails
- Verify educator has spreadsheetId in users collection
- Check service account permissions
- Review educator mappings configuration

### Issue: Web admin can't update educators
- Check collection permissions in Firebase
- Verify role field is being set correctly
- Check browser console for errors

### Issue: Student references broken
- Run verification script to check ID mappings
- May need to re-run student reference update
- Check students have valid educatorId

## Success Criteria

Migration is complete when:
- ✅ All educator data exists in users collection
- ✅ All features work with new structure
- ✅ No references to educators collection in active code
- ✅ 2 weeks of stable operation
- ✅ All tests pass consistently

## Contact for Issues

If you encounter problems:
1. Save error messages and screenshots
2. Note exact steps to reproduce
3. Check backup files are intact
4. Document which feature flag state you're in

---

**IMPORTANT**: This migration affects core functionality. Test thoroughly in development before applying to production!