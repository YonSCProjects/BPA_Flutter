# Testing Educator Self-Initialization

## Test Scenario

### Prerequisites
1. Create an educator entry in Firebase (either educators or users collection) with:
   - email: test.educator@example.com
   - role: "educator" (if in users collection)
   - NO spreadsheetId field (or empty string)

### Test Steps

1. **Login as Educator**
   - Sign in with the educator email
   - App should authenticate successfully

2. **Automatic Spreadsheet Creation**
   - Google Sheets service creates "BPApp" spreadsheet
   - Spreadsheet ID is generated (e.g., "1abc123...")

3. **Automatic Firestore Update**
   - The new `EducatorInitializationService` detects:
     - User is an educator
     - Has no spreadsheetId in database
   - Service automatically:
     - Updates Firestore with the new spreadsheetId
     - Shares spreadsheet with service account
     - Adds `autoInitialized: true` flag

4. **Verification**
   - Check Firestore - educator document should now have:
     ```json
     {
       "email": "test.educator@example.com",
       "spreadsheetId": "1abc123...",
       "autoInitialized": true,
       "updatedAt": <timestamp>
     }
     ```
   - Check Google Drive - spreadsheet should be shared with:
     - `bpapp-service-account@bpapp-firebase-485c1.iam.gserviceaccount.com`

5. **Multi-destination Saving**
   - When teachers save student records
   - System can now find educator's spreadsheetId
   - Records save to both teacher's and educator's sheets

## Debug Logs to Watch

Look for these in console:
- `[EDUCATOR_INIT] ✅ Updated educator spreadsheet ID`
- `[EDUCATOR_INIT] ✅ Successfully shared spreadsheet with service account`
- `[INIT] Spreadsheet setup complete: <spreadsheetId>`

## Edge Cases Handled

1. **Educator Already Has SpreadsheetId**
   - No update performed
   - Log: "Educator already has spreadsheet ID"

2. **Non-Educator User**
   - No update attempted
   - Normal user flow continues

3. **Service Account Already Has Access**
   - Skip sharing step
   - Log: "Service account already has access"

## Benefits

- **Zero Manual Setup**: Educators self-initialize on first login
- **Automatic Sharing**: Service account gets access immediately
- **Multi-destination Ready**: Educator sheets available for centralized saving
- **Audit Trail**: `autoInitialized` flag tracks self-setup