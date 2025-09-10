

## 1. Test the System (Important!)
Run the Flutter app and verify:
- Educator dropdowns load correctly
- Student records save properly
- Multi-destination saving works
- Educators can log in and auto-initialize their spreadsheets

## 2. Deploy Web Admin Changes
```bash
cd web-admin
npm run build
firebase deploy --only hosting
```
This will deploy the updated admin portal that uses the new structure.

## 3. Monitor for 1-2 Weeks
Watch for any issues:
- Check Firebase console for errors
- Ensure educators can access their spreadsheets
- Verify student data saves correctly

## 4. After Stable Period (Optional Cleanup)
Once everything works perfectly for 1-2 weeks:
- Delete the old `educators` collection from Firebase
- Remove feature flags from code
- Clean up migration scripts

### To remove educators collection (after stability confirmed):
```javascript
// In Firebase Console or script:
const batch = db.batch();
const snapshot = await db.collection('educators').get();
snapshot.docs.forEach(doc => {
  batch.delete(doc.ref);
});
await batch.commit();
```

### To remove feature flags:
1. Remove `useLegacyEducatorsCollection` from:
   - `lib/config/app_config.dart`
   - `web-admin/lib/migration-config.ts`
2. Remove all conditional logic checking the flag
3. Clean up legacy code paths

## 5. Update Documentation
- Update README to reflect new structure
- Document that educators are now in users collection
- Update any API documentation

## Immediate Action Recommended
**Test the Flutter app** to make sure everything works with the new structure. Try:
1. Opening the student form
2. Selecting an educator from dropdown
3. Saving a record
4. Checking if it saves to both teacher and educator sheets

## Rollback Instructions (If Needed)
If any critical issues arise:

### Quick Rollback:
1. **Flutter App**: 
   ```dart
   // In lib/config/app_config.dart
   static const bool useLegacyEducatorsCollection = true; // Change back
   ```

2. **Web Admin**:
   ```typescript
   // In web-admin/lib/migration-config.ts
   useLegacyEducatorsCollection: true, // Change back
   ```

3. Rebuild and redeploy both apps

### Data Restoration (if needed):
```bash
cd scripts
node restore_from_backup.js --file ../backups/educators_backup_latest.json
```

## Success Checklist
- [ ] Flutter app loads educators from users collection
- [ ] Web admin shows educators correctly
- [ ] Student records save to both destinations
- [ ] Educator auto-initialization works
- [ ] No Firebase permission errors
- [ ] All dropdowns populate correctly
- [ ] Student-educator relationships intact

## Migration Summary
- **Date**: 2025-09-10
- **Educators Migrated**: 2
- **Student References Updated**: 1
- **Backup Location**: `backups/migration_backup_2025-09-10T03-02-25-210Z.json`
- **Feature Flag Status**: Set to `false` (using new structure)

## Contact for Issues
If you encounter problems:
1. Check backup files in `backups/` folder
2. Review migration logs
3. Use feature flags for instant rollback
4. Report issues at: https://github.com/YonSCProjects/BPA_Flutter/issues