const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

// Initialize Firebase Admin
const serviceAccount = require('../assets/service_account.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: `https://bpapp-firebase-485c1.firebaseio.com`
});

const db = admin.firestore();

async function backupEducatorsCollection() {
  console.log('📦 Starting educators collection backup...');
  
  try {
    // Create backups directory if it doesn't exist
    const backupDir = path.join(__dirname, '..', 'backups');
    if (!fs.existsSync(backupDir)) {
      fs.mkdirSync(backupDir);
    }
    
    // Fetch all educators
    const educatorsSnapshot = await db.collection('educators').get();
    console.log(`Found ${educatorsSnapshot.size} educators to backup`);
    
    // Convert to backup format
    const backup = {
      metadata: {
        backupDate: new Date().toISOString(),
        collection: 'educators',
        documentCount: educatorsSnapshot.size,
        backupVersion: '1.0'
      },
      documents: []
    };
    
    educatorsSnapshot.forEach(doc => {
      backup.documents.push({
        id: doc.id,
        data: doc.data(),
        createTime: doc.createTime?.toDate?.() || null,
        updateTime: doc.updateTime?.toDate?.() || null
      });
    });
    
    // Save to file with timestamp
    const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
    const filename = `educators_backup_${timestamp}.json`;
    const filepath = path.join(backupDir, filename);
    
    fs.writeFileSync(filepath, JSON.stringify(backup, null, 2));
    
    console.log('✅ Backup completed successfully!');
    console.log(`📁 Backup saved to: ${filepath}`);
    console.log(`📊 Total documents backed up: ${educatorsSnapshot.size}`);
    
    // Also create a latest backup for easy access
    const latestPath = path.join(backupDir, 'educators_backup_latest.json');
    fs.copyFileSync(filepath, latestPath);
    console.log(`📁 Latest backup also saved to: ${latestPath}`);
    
  } catch (error) {
    console.error('❌ Backup failed:', error);
    process.exit(1);
  }
}

// Run backup
backupEducatorsCollection().then(() => {
  console.log('🎉 Backup process completed');
  process.exit(0);
});