# Firestore Sample Data Import Instructions

## Method 1: Manual Import in Firebase Console

1. **For educators collection:**
   - Go to Firebase Console → Firestore
   - Click "Start collection" → Collection ID: `educators`
   - For each educator in `educators.json`:
     - Click "Add document" → Auto-generate ID
     - Copy the fields from JSON
     - Note the auto-generated document ID

2. **For students collection:**
   - Create collection: `students`
   - For each student in `students.json`:
     - Replace `EDUCATOR_1_ID`, `EDUCATOR_2_ID`, etc. with actual educator document IDs from step 1
     - Add document with auto-generated ID
     - Copy the fields

3. **For users collection:**
   - Create collection: `users`
   - Document ID: Use your Google Auth UID (or use "admin" for testing)
   - Copy fields from `users.json`

4. **For config collection:**
   - Create collection: `config`
   - Document ID: **MUST BE EXACTLY** `app_settings`
   - Copy the entire object from `config.json`

## Method 2: Using Firebase Admin SDK Script

Create a Node.js script to import all data at once:

```javascript
const admin = require('firebase-admin');
const serviceAccount = require('./path-to-service-account.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'bpapp-firebase-485c1'
});

const db = admin.firestore();

async function importData() {
  // Import educators
  const educators = require('./educators.json');
  const educatorIds = {};
  
  for (const educator of educators) {
    const docRef = await db.collection('educators').add(educator);
    educatorIds[educator.name] = docRef.id;
    console.log(`Added educator: ${educator.name} with ID: ${docRef.id}`);
  }
  
  // Import students with correct educator IDs
  const students = require('./students.json');
  for (const student of students) {
    // Map educator name to actual ID
    student.educatorId = educatorIds[student.educatorName];
    await db.collection('students').add(student);
    console.log(`Added student: ${student.name}`);
  }
  
  // Import config
  await db.collection('config').doc('app_settings').set({
    version: "1.0.0",
    maintenanceMode: false,
    features: {
      useServiceAccount: true,
      useFirebaseData: false
    }
  });
  
  console.log('Import complete!');
}

importData().catch(console.error);
```

## Method 3: Using Firebase CLI Import (Easiest)

Unfortunately, Firebase CLI doesn't have a direct import command for Firestore, but you can use the Firebase Admin SDK as shown above.

## Important Notes:

1. **educatorId in students**: Must match actual document IDs from educators collection
2. **config document**: The document ID must be exactly `app_settings`
3. **Timestamps**: Firebase Console will automatically convert the timestamp format
4. **Hebrew text**: Should display correctly in Firebase Console

## Quick Manual Steps:

1. Create all 4 collections first
2. Add educators first and note their IDs
3. Update student records with correct educator IDs
4. Ensure config document ID is exactly `app_settings`