const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

// Initialize Firebase Admin
const serviceAccount = require('../firebase-service-account.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: `https://bpapp-firebase-485c1.firebaseio.com`
});

const db = admin.firestore();

// Migration configuration
const DRY_RUN = process.argv.includes('--dry-run');
const VERBOSE = process.argv.includes('--verbose') || DRY_RUN;

console.log('🚀 Educators to Users Collection Migration');
console.log(DRY_RUN ? '⚠️  DRY RUN MODE - No changes will be made' : '✅ LIVE MODE - Changes will be applied');
console.log('');

async function migrateEducators() {
  const stats = {
    educatorsFound: 0,
    usersUpdated: 0,
    usersCreated: 0,
    errors: [],
    studentReferencesUpdated: 0
  };
  
  try {
    // Step 1: Backup first (safety)
    console.log('📦 Creating backup before migration...');
    await createBackup();
    
    // Step 2: Read all educators
    console.log('\n📖 Reading educators collection...');
    const educatorsSnapshot = await db.collection('educators').get();
    stats.educatorsFound = educatorsSnapshot.size;
    console.log(`Found ${stats.educatorsFound} educators to migrate`);
    
    // Step 3: Create ID mapping for student references
    const idMapping = {};
    
    // Step 4: Process each educator
    console.log('\n🔄 Processing educators...');
    for (const educatorDoc of educatorsSnapshot.docs) {
      const educatorData = educatorDoc.data();
      const educatorId = educatorDoc.id;
      
      if (VERBOSE) {
        console.log(`\n  Processing educator: ${educatorData.name} (${educatorData.email})`);
      }
      
      try {
        // Find matching user by email
        const userQuery = await db.collection('users')
          .where('email', '==', educatorData.email)
          .limit(1)
          .get();
        
        if (!userQuery.empty) {
          // Update existing user
          const userDoc = userQuery.docs[0];
          const userId = userDoc.id;
          
          // Map old educator ID to new user ID
          idMapping[educatorId] = userId;
          
          const updateData = {
            // Add educator-specific fields
            active: educatorData.active !== undefined ? educatorData.active : true,
            classes: educatorData.classes || [],
            spreadsheetId: educatorData.spreadsheetId || '',
            
            // Ensure role is set
            role: 'educator',
            
            // Migration tracking
            migratedFromEducators: true,
            educatorCollectionId: educatorId,
            updatedAt: admin.firestore.FieldValue.serverTimestamp()
          };
          
          if (!DRY_RUN) {
            await userDoc.ref.update(updateData);
          }
          
          stats.usersUpdated++;
          if (VERBOSE) {
            console.log(`    ✅ Updated user ${userId} with educator data`);
            if (educatorData.spreadsheetId) {
              console.log(`    📊 Spreadsheet ID: ${educatorData.spreadsheetId}`);
            }
            if (educatorData.classes?.length > 0) {
              console.log(`    📚 Classes: ${educatorData.classes.join(', ')}`);
            }
          }
          
        } else {
          // Create new user (educator not in users collection)
          const newUserId = db.collection('users').doc().id;
          idMapping[educatorId] = newUserId;
          
          const newUserData = {
            email: educatorData.email,
            name: educatorData.name,
            role: 'educator',
            active: educatorData.active !== undefined ? educatorData.active : true,
            classes: educatorData.classes || [],
            spreadsheetId: educatorData.spreadsheetId || '',
            
            // Migration tracking
            createdFromEducatorsMigration: true,
            educatorCollectionId: educatorId,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp()
          };
          
          if (!DRY_RUN) {
            await db.collection('users').doc(newUserId).set(newUserData);
          }
          
          stats.usersCreated++;
          if (VERBOSE) {
            console.log(`    ✨ Created new user ${newUserId} from educator data`);
          }
        }
        
      } catch (error) {
        stats.errors.push({
          educator: educatorData.email,
          error: error.message
        });
        console.error(`    ❌ Error processing ${educatorData.email}:`, error.message);
      }
    }
    
    // Step 5: Update student references
    console.log('\n🔄 Updating student educator references...');
    await updateStudentReferences(idMapping, stats);
    
    // Step 6: Verify migration
    console.log('\n🔍 Verifying migration...');
    await verifyMigration(stats);
    
  } catch (error) {
    console.error('\n❌ Migration failed:', error);
    throw error;
  }
  
  return stats;
}

async function updateStudentReferences(idMapping, stats) {
  console.log(`  Found ${Object.keys(idMapping).length} educator ID mappings`);
  
  if (Object.keys(idMapping).length === 0) {
    console.log('  No ID mappings to process');
    return;
  }
  
  // Get all students
  const studentsSnapshot = await db.collection('students').get();
  console.log(`  Found ${studentsSnapshot.size} students to check`);
  
  let updateCount = 0;
  const batch = db.batch();
  let batchCount = 0;
  
  for (const studentDoc of studentsSnapshot.docs) {
    const studentData = studentDoc.data();
    const oldEducatorId = studentData.educatorId;
    
    if (oldEducatorId && idMapping[oldEducatorId]) {
      const newEducatorId = idMapping[oldEducatorId];
      
      if (VERBOSE) {
        console.log(`    Updating student ${studentData.name}: ${oldEducatorId} → ${newEducatorId}`);
      }
      
      if (!DRY_RUN) {
        batch.update(studentDoc.ref, {
          educatorId: newEducatorId,
          educatorIdMigrated: true,
          oldEducatorId: oldEducatorId,
          updatedAt: admin.firestore.FieldValue.serverTimestamp()
        });
        
        batchCount++;
        updateCount++;
        
        // Commit batch every 500 operations (Firestore limit)
        if (batchCount >= 500) {
          await batch.commit();
          batchCount = 0;
        }
      } else {
        updateCount++;
      }
    }
  }
  
  // Commit remaining batch operations
  if (!DRY_RUN && batchCount > 0) {
    await batch.commit();
  }
  
  stats.studentReferencesUpdated = updateCount;
  console.log(`  ✅ Updated ${updateCount} student references`);
}

async function verifyMigration(stats) {
  // Check that all educators are now in users collection
  const usersWithEducatorRole = await db.collection('users')
    .where('role', '==', 'educator')
    .get();
  
  console.log(`  Educators in original collection: ${stats.educatorsFound}`);
  console.log(`  Users with educator role: ${usersWithEducatorRole.size}`);
  console.log(`  Users updated: ${stats.usersUpdated}`);
  console.log(`  Users created: ${stats.usersCreated}`);
  console.log(`  Total processed: ${stats.usersUpdated + stats.usersCreated}`);
  
  // Check for educators with missing spreadsheet IDs
  let missingSpreadsheets = 0;
  usersWithEducatorRole.forEach(doc => {
    const data = doc.data();
    if (!data.spreadsheetId || data.spreadsheetId === '') {
      missingSpreadsheets++;
      if (VERBOSE) {
        console.log(`  ⚠️  ${data.name} (${data.email}) has no spreadsheet ID`);
      }
    }
  });
  
  if (missingSpreadsheets > 0) {
    console.log(`  ⚠️  ${missingSpreadsheets} educators without spreadsheet IDs (will auto-initialize on login)`);
  }
}

async function createBackup() {
  const backupDir = path.join(__dirname, '..', 'backups');
  if (!fs.existsSync(backupDir)) {
    fs.mkdirSync(backupDir);
  }
  
  // Backup educators
  const educatorsSnapshot = await db.collection('educators').get();
  const educatorsBackup = [];
  educatorsSnapshot.forEach(doc => {
    educatorsBackup.push({
      id: doc.id,
      data: doc.data()
    });
  });
  
  // Backup users (current state)
  const usersSnapshot = await db.collection('users').get();
  const usersBackup = [];
  usersSnapshot.forEach(doc => {
    usersBackup.push({
      id: doc.id,
      data: doc.data()
    });
  });
  
  // Backup students (for reference tracking)
  const studentsSnapshot = await db.collection('students').get();
  const studentsBackup = [];
  studentsSnapshot.forEach(doc => {
    studentsBackup.push({
      id: doc.id,
      data: doc.data()
    });
  });
  
  const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
  const backup = {
    timestamp,
    educators: educatorsBackup,
    users: usersBackup,
    students: studentsBackup
  };
  
  const backupPath = path.join(backupDir, `migration_backup_${timestamp}.json`);
  fs.writeFileSync(backupPath, JSON.stringify(backup, null, 2));
  
  console.log(`  ✅ Backup saved to: ${backupPath}`);
}

// Run migration
async function main() {
  console.log('\n========================================');
  console.log('  EDUCATORS TO USERS MIGRATION TOOL');
  console.log('========================================\n');
  
  if (DRY_RUN) {
    console.log('To run the actual migration, remove --dry-run flag\n');
  }
  
  try {
    const stats = await migrateEducators();
    
    console.log('\n========================================');
    console.log('  MIGRATION SUMMARY');
    console.log('========================================');
    console.log(`  Educators found: ${stats.educatorsFound}`);
    console.log(`  Users updated: ${stats.usersUpdated}`);
    console.log(`  Users created: ${stats.usersCreated}`);
    console.log(`  Student references updated: ${stats.studentReferencesUpdated}`);
    
    if (stats.errors.length > 0) {
      console.log(`\n  ⚠️  Errors encountered: ${stats.errors.length}`);
      stats.errors.forEach(err => {
        console.log(`     - ${err.educator}: ${err.error}`);
      });
    }
    
    if (DRY_RUN) {
      console.log('\n✅ Dry run completed successfully!');
      console.log('Review the output and run without --dry-run to apply changes.');
    } else {
      console.log('\n✅ Migration completed successfully!');
      console.log('Next steps:');
      console.log('1. Test the app with the feature flag enabled');
      console.log('2. Monitor for any issues');
      console.log('3. After validation, flip the feature flag in app_config.dart');
    }
    
  } catch (error) {
    console.error('\n❌ Migration failed:', error);
    process.exit(1);
  }
}

// Handle command line arguments
if (process.argv.includes('--help')) {
  console.log('Usage: node migrate_educators_to_users.js [options]');
  console.log('');
  console.log('Options:');
  console.log('  --dry-run   Run without making changes (preview mode)');
  console.log('  --verbose   Show detailed output');
  console.log('  --help      Show this help message');
  process.exit(0);
}

main().then(() => process.exit(0));