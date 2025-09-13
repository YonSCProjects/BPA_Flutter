/// Google Apps Script code for automatic BPApp backups
/// This code will be injected into each user's spreadsheet on first creation

class AppsScriptBackupCode {
  static const String backupScript = r'''
// BPApp Automatic Backup System
// This script runs on Google's servers and creates 7 backups per day

function onOpen() {
  // Add menu for manual backup
  SpreadsheetApp.getUi()
    .createMenu('BPApp גיבויים')
    .addItem('גבה עכשיו', 'createManualBackup')
    .addItem('הצג גיבויים', 'showBackups')
    .addItem('הגדרות גיבוי', 'configureBackups')
    .addToUi();
}

// Main backup function - runs 7 times daily
function performScheduledBackup() {
  try {
    const BACKUP_HOURS = [8, 10, 12, 14, 16, 18, 20]; // 7 backup times
    const currentHour = new Date().getHours();
    
    // Only backup at scheduled hours
    if (!BACKUP_HOURS.includes(currentHour)) {
      console.log('Not a scheduled backup hour: ' + currentHour);
      return;
    }
    
    // Get the spreadsheet
    const spreadsheet = SpreadsheetApp.getActiveSpreadsheet();
    const spreadsheetFile = DriveApp.getFileById(spreadsheet.getId());
    
    // Get or create backup folder
    const backupFolder = getOrCreateBackupFolder();
    
    // Create backup filename with date and time
    const now = new Date();
    const dateStr = Utilities.formatDate(now, Session.getScriptTimeZone(), 'yyyy-MM-dd_HH-mm');
    const backupName = 'BPApp_Backup_' + dateStr;
    
    // Create the backup
    const backup = spreadsheetFile.makeCopy(backupName, backupFolder);
    console.log('Backup created: ' + backup.getName());
    
    // Clean old backups (keep last 30 days = 210 backups)
    cleanOldBackups(backupFolder, 210);
    
    // Log success
    logBackup(backup.getName(), 'scheduled');
    
  } catch (error) {
    console.error('Backup failed: ' + error.toString());
    logBackup('FAILED', 'error: ' + error.toString());
  }
}

// Manual backup function
function createManualBackup() {
  try {
    const spreadsheet = SpreadsheetApp.getActiveSpreadsheet();
    const spreadsheetFile = DriveApp.getFileById(spreadsheet.getId());
    const backupFolder = getOrCreateBackupFolder();
    
    const now = new Date();
    const dateStr = Utilities.formatDate(now, Session.getScriptTimeZone(), 'yyyy-MM-dd_HH-mm-ss');
    const backupName = 'BPApp_Manual_Backup_' + dateStr;
    
    const backup = spreadsheetFile.makeCopy(backupName, backupFolder);
    
    // Show success message
    SpreadsheetApp.getUi().alert('גיבוי נוצר בהצלחה!\n' + backup.getName());
    
    logBackup(backup.getName(), 'manual');
    
  } catch (error) {
    SpreadsheetApp.getUi().alert('שגיאה ביצירת גיבוי:\n' + error.toString());
  }
}

// Get or create the backup folder
function getOrCreateBackupFolder() {
  const folderName = 'BPApp_Backups';
  
  // Check if folder exists
  const folders = DriveApp.getFoldersByName(folderName);
  if (folders.hasNext()) {
    return folders.next();
  }
  
  // Create new folder
  const newFolder = DriveApp.createFolder(folderName);
  newFolder.setDescription('גיבויים אוטומטיים של BPApp - נוצרים 7 פעמים ביום');
  return newFolder;
}

// Clean old backups
function cleanOldBackups(folder, maxBackups) {
  const files = folder.getFiles();
  const backupFiles = [];
  
  // Collect all backup files
  while (files.hasNext()) {
    const file = files.next();
    if (file.getName().includes('BPApp_Backup') || file.getName().includes('BPApp_Manual_Backup')) {
      backupFiles.push({
        file: file,
        date: file.getDateCreated()
      });
    }
  }
  
  // Sort by date (newest first)
  backupFiles.sort((a, b) => b.date - a.date);
  
  // Delete old backups
  for (let i = maxBackups; i < backupFiles.length; i++) {
    try {
      backupFiles[i].file.setTrashed(true);
      console.log('Deleted old backup: ' + backupFiles[i].file.getName());
    } catch (e) {
      console.error('Failed to delete backup: ' + e.toString());
    }
  }
}

// Log backup activity
function logBackup(backupName, type) {
  const sheet = SpreadsheetApp.getActiveSpreadsheet().getSheetByName('נתוני תלמידים');
  if (!sheet) return;
  
  // Store last backup info in document properties
  const props = PropertiesService.getDocumentProperties();
  props.setProperty('lastBackup', new Date().toISOString());
  props.setProperty('lastBackupName', backupName);
  props.setProperty('lastBackupType', type);
}

// Show list of backups
function showBackups() {
  try {
    const folder = getOrCreateBackupFolder();
    const files = folder.getFiles();
    let backupList = 'רשימת גיבויים:\n\n';
    let count = 0;
    
    const backups = [];
    while (files.hasNext() && count < 20) {
      const file = files.next();
      if (file.getName().includes('Backup')) {
        backups.push({
          name: file.getName(),
          date: file.getDateCreated()
        });
        count++;
      }
    }
    
    // Sort by date (newest first)
    backups.sort((a, b) => b.date - a.date);
    
    // Format list
    backups.forEach(backup => {
      const dateStr = Utilities.formatDate(backup.date, Session.getScriptTimeZone(), 'dd/MM/yyyy HH:mm');
      backupList += dateStr + ' - ' + backup.name + '\n';
    });
    
    if (count === 0) {
      backupList = 'לא נמצאו גיבויים';
    } else if (count === 20) {
      backupList += '\n(מוצגים 20 הגיבויים האחרונים)';
    }
    
    SpreadsheetApp.getUi().alert(backupList);
    
  } catch (error) {
    SpreadsheetApp.getUi().alert('שגיאה בטעינת רשימת גיבויים:\n' + error.toString());
  }
}

// Configure backup settings
function configureBackups() {
  const ui = SpreadsheetApp.getUi();
  const props = PropertiesService.getDocumentProperties();
  
  const lastBackup = props.getProperty('lastBackup');
  const lastBackupName = props.getProperty('lastBackupName');
  
  let message = 'הגדרות גיבוי אוטומטי:\n\n';
  message += '• זמני גיבוי: 08:00, 10:00, 12:00, 14:00, 16:00, 18:00, 20:00\n';
  message += '• גיבויים נשמרים: 30 ימים אחרונים\n';
  message += '• מיקום: תיקיית BPApp_Backups\n\n';
  
  if (lastBackup) {
    const date = new Date(lastBackup);
    const dateStr = Utilities.formatDate(date, Session.getScriptTimeZone(), 'dd/MM/yyyy HH:mm');
    message += 'גיבוי אחרון: ' + dateStr + '\n';
    message += 'שם הקובץ: ' + lastBackupName;
  } else {
    message += 'טרם בוצע גיבוי';
  }
  
  ui.alert(message);
}

// Initial setup - called once when script is installed
function setupBackupTriggers() {
  // Remove any existing triggers
  const triggers = ScriptApp.getProjectTriggers();
  triggers.forEach(trigger => {
    if (trigger.getHandlerFunction() === 'performScheduledBackup') {
      ScriptApp.deleteTrigger(trigger);
    }
  });
  
  // Create hourly trigger (will check if it's a backup hour)
  ScriptApp.newTrigger('performScheduledBackup')
    .timeBased()
    .everyHours(1)
    .create();
    
  console.log('Backup triggers set up successfully');
  
  // Create initial backup folder
  getOrCreateBackupFolder();
  
  // Log setup
  const props = PropertiesService.getDocumentProperties();
  props.setProperty('backupSystemInstalled', new Date().toISOString());
}

// Run this once to set everything up
function installBackupSystem() {
  setupBackupTriggers();
  SpreadsheetApp.getUi().alert(
    'מערכת גיבוי הותקנה בהצלחה!\n\n' +
    'גיבויים אוטומטיים יתבצעו 7 פעמים ביום.\n' +
    'ניתן לבצע גיבוי ידני בכל עת מהתפריט.'
  );
}
''';

  /// Get the script code ready for injection
  static String getBackupScript() {
    return backupScript;
  }
  
  /// Get the setup function that should be called after script creation
  static String getSetupFunctionName() {
    return 'installBackupSystem';
  }
}