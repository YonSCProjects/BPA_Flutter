import { google } from 'googleapis';
import * as admin from 'firebase-admin';

class SheetsService {
  private sheets: any;
  private drive: any;
  private serviceAccountEmail: string = '';
  private initialized: boolean = false;
  
  constructor() {
    // Don't initialize here - will be done on first use
  }

  private async ensureInitialized() {
    if (!this.initialized) {
      await this.initializeGoogleAPIs();
      this.initialized = true;
    }
  }

  private async initializeGoogleAPIs() {
    try {
      // Use service account credentials (stored in environment variables)
      const auth = new google.auth.GoogleAuth({
        keyFilename: 'service-account.json.json', // Path to service account file
        scopes: [
          'https://www.googleapis.com/auth/spreadsheets',
          'https://www.googleapis.com/auth/drive'
        ],
      });

      await auth.getClient(); // Initialize the auth client
      this.serviceAccountEmail = (await auth.getCredentials()).client_email || '';
      
      this.sheets = google.sheets({ version: 'v4', auth: auth });
      this.drive = google.drive({ version: 'v3', auth: auth });
    } catch (error) {
      console.error('Failed to initialize Google APIs:', error);
      throw error;
    }
  }

  async setupUserSpreadsheet(userEmail: string) {
    await this.ensureInitialized();
    try {
      // Check if user already has a spreadsheet
      const existingSheet = await this.findUserSpreadsheet(userEmail);
      
      if (existingSheet) {
        return {
          success: true,
          spreadsheetId: existingSheet.id,
          spreadsheetUrl: `https://docs.google.com/spreadsheets/d/${existingSheet.id}`,
          message: 'Existing spreadsheet found'
        };
      }

      // Create new spreadsheet
      const spreadsheet = await this.sheets.spreadsheets.create({
        requestBody: {
          properties: {
            title: `BPApp - ${userEmail}`,
            locale: 'he_IL',
          },
          sheets: [{
            properties: {
              title: 'נתונים',
              rightToLeft: true,
              gridProperties: {
                frozenRowCount: 1
              }
            }
          }]
        }
      });

      const spreadsheetId = spreadsheet.data.spreadsheetId;

      // Add headers
      await this.sheets.spreadsheets.values.update({
        spreadsheetId,
        range: 'נתונים!A1:L1',
        valueInputOption: 'RAW',
        requestBody: {
          values: [[
            'תאריך',
            'שם התלמיד',
            'שם הכיתה',
            'מספר השיעור',
            'כניסה',
            'שהייה',
            'אווירה',
            'ביצוע',
            'מטרה אישית',
            'בונוס',
            'סה"כ',
            'הערות'
          ]]
        }
      });

      // Share with user (read-only)
      await this.drive.permissions.create({
        fileId: spreadsheetId,
        requestBody: {
          type: 'user',
          role: 'reader',
          emailAddress: userEmail,
          sendNotificationEmail: true,
          emailMessage: 'הגיליון האלקטרוני שלך ב-BPApp מוכן! תוכל לצפות בנתונים שלך בכל עת.'
        }
      });

      // Protect the sheet (only service account can edit)
      await this.protectSpreadsheet(spreadsheetId);

      // Store user-spreadsheet mapping in Firestore
      await this.storeUserMapping(userEmail, spreadsheetId);

      return {
        success: true,
        spreadsheetId,
        spreadsheetUrl: `https://docs.google.com/spreadsheets/d/${spreadsheetId}`,
        message: 'New spreadsheet created and shared'
      };
    } catch (error: any) {
      console.error('Setup user spreadsheet error:', error);
      throw error;
    }
  }

  async saveRecord(userEmail: string, record: any) {
    await this.ensureInitialized();
    try {
      // Get user's spreadsheet ID
      const spreadsheetId = await this.getUserSpreadsheetId(userEmail);
      
      if (!spreadsheetId) {
        throw new Error('User spreadsheet not found');
      }

      // Check for existing record (4-field matching)
      const existingRow = await this.findExistingRow(spreadsheetId, record);
      
      if (existingRow > 0) {
        // Update existing record
        await this.sheets.spreadsheets.values.update({
          spreadsheetId,
          range: `נתונים!A${existingRow}:L${existingRow}`,
          valueInputOption: 'RAW',
          requestBody: {
            values: [[
              record.date,
              record.studentName,
              record.className,
              record.classNumber,
              record.entry,
              record.staying,
              record.attitude,
              record.performance,
              record.personalGoal,
              record.bonus,
              record.totalScore,
              record.comments
            ]]
          }
        });

        return {
          success: true,
          action: 'updated',
          row: existingRow
        };
      } else {
        // Find insertion position for chronological order
        const insertPosition = await this.findInsertPosition(spreadsheetId, record);
        
        // Insert new record at the correct position
        await this.insertRecordAtPosition(spreadsheetId, record, insertPosition);
        
        return {
          success: true,
          action: 'created',
          row: insertPosition
        };
      }
    } catch (error: any) {
      console.error('Save record error:', error);
      throw error;
    }
  }

  async findMatchingRecord(userEmail: string, matchFields: any) {
    await this.ensureInitialized();
    try {
      const spreadsheetId = await this.getUserSpreadsheetId(userEmail);
      
      if (!spreadsheetId) {
        return { found: false };
      }

      const response = await this.sheets.spreadsheets.values.get({
        spreadsheetId,
        range: 'נתונים!A:L',
      });

      const rows = response.data.values || [];
      
      for (let i = 1; i < rows.length; i++) {
        const row = rows[i];
        if (
          row[0] === matchFields.date &&
          row[1] === matchFields.studentName &&
          row[2] === matchFields.className &&
          String(row[3]) === String(matchFields.classNumber)
        ) {
          return {
            found: true,
            data: {
              entry: row[4],
              staying: row[5],
              attitude: row[6],
              performance: row[7],
              personalGoal: row[8],
              bonus: row[9],
              comments: row[11]
            }
          };
        }
      }

      return { found: false };
    } catch (error: any) {
      console.error('Find matching record error:', error);
      throw error;
    }
  }

  async getAutocompleteData(userEmail: string) {
    await this.ensureInitialized();
    try {
      const spreadsheetId = await this.getUserSpreadsheetId(userEmail);
      
      if (!spreadsheetId) {
        return { studentNames: [], classNames: [] };
      }

      const response = await this.sheets.spreadsheets.values.get({
        spreadsheetId,
        range: 'נתונים!B:C',
      });

      const rows = response.data.values || [];
      const studentNames = new Set<string>();
      const classNames = new Set<string>();

      for (let i = 1; i < rows.length; i++) {
        if (rows[i][0]) studentNames.add(rows[i][0]);
        if (rows[i][1]) classNames.add(rows[i][1]);
      }

      return {
        studentNames: Array.from(studentNames),
        classNames: Array.from(classNames)
      };
    } catch (error: any) {
      console.error('Get autocomplete data error:', error);
      throw error;
    }
  }

  private async findUserSpreadsheet(userEmail: string) {
    try {
      // First check Firestore mapping
      const mapping = await this.getUserMapping(userEmail);
      if (mapping?.spreadsheetId) {
        // Verify it still exists
        try {
          const file = await this.drive.files.get({
            fileId: mapping.spreadsheetId,
            fields: 'id, trashed'
          });
          if (!file.data.trashed) {
            return { id: mapping.spreadsheetId };
          }
        } catch (error) {
          // File doesn't exist or is inaccessible
          console.log('Stored spreadsheet not found, searching Drive...');
        }
      }

      // Search in Drive
      const response = await this.drive.files.list({
        q: `name contains 'BPApp - ${userEmail}' and mimeType='application/vnd.google-apps.spreadsheet' and trashed=false`,
        fields: 'files(id, name)',
      });

      return response.data.files?.[0] || null;
    } catch (error) {
      console.error('Find user spreadsheet error:', error);
      return null;
    }
  }

  private async protectSpreadsheet(spreadsheetId: string) {
    try {
      const sheetId = 0; // First sheet
      
      await this.sheets.spreadsheets.batchUpdate({
        spreadsheetId,
        requestBody: {
          requests: [{
            addProtectedRange: {
              protectedRange: {
                range: {
                  sheetId: sheetId,
                },
                description: 'הגנה על גיליון BPApp - רק האפליקציה יכולה לערוך',
                warningOnly: false,
                editors: {
                  users: [this.serviceAccountEmail]
                }
              }
            }
          }]
        }
      });
    } catch (error) {
      console.error('Protect spreadsheet error:', error);
      // Non-critical error - continue even if protection fails
    }
  }

  private async findExistingRow(spreadsheetId: string, record: any): Promise<number> {
    const response = await this.sheets.spreadsheets.values.get({
      spreadsheetId,
      range: 'נתונים!A:D',
    });

    const rows = response.data.values || [];
    
    for (let i = 1; i < rows.length; i++) {
      if (
        rows[i][0] === record.date &&
        rows[i][1] === record.studentName &&
        rows[i][2] === record.className &&
        String(rows[i][3]) === String(record.classNumber)
      ) {
        return i + 1; // Sheets rows are 1-indexed
      }
    }
    
    return -1;
  }

  private async findInsertPosition(spreadsheetId: string, record: any): Promise<number> {
    const response = await this.sheets.spreadsheets.values.get({
      spreadsheetId,
      range: 'נתונים!A:D',
    });

    const rows = response.data.values || [];
    
    // Parse the incoming date
    const [day, month, year] = record.date.split('/').map(Number);
    const recordDate = new Date(year, month - 1, day);
    const recordClassNum = parseInt(record.classNumber);
    
    // Find the right position
    for (let i = 1; i < rows.length; i++) {
      const rowDate = rows[i][0];
      const rowClassNum = parseInt(rows[i][3]);
      
      const [rowDay, rowMonth, rowYear] = rowDate.split('/').map(Number);
      const currentDate = new Date(rowYear, rowMonth - 1, rowDay);
      
      // Insert before this row if:
      // 1. Current row date is later than record date, OR
      // 2. Same date but current row class number is higher
      if (currentDate > recordDate || 
          (currentDate.getTime() === recordDate.getTime() && rowClassNum > recordClassNum)) {
        return i + 1; // Sheets rows are 1-indexed
      }
    }
    
    // If we get here, append at the end
    return rows.length + 1;
  }

  private async insertRecordAtPosition(spreadsheetId: string, record: any, position: number) {
    // Get sheet ID
    const spreadsheetInfo = await this.sheets.spreadsheets.get({
      spreadsheetId,
      fields: 'sheets.properties'
    });
    
    const sheetId = spreadsheetInfo.data.sheets[0].properties.sheetId;
    
    // Insert empty row at position
    await this.sheets.spreadsheets.batchUpdate({
      spreadsheetId,
      requestBody: {
        requests: [{
          insertDimension: {
            range: {
              sheetId: sheetId,
              dimension: 'ROWS',
              startIndex: position - 1,
              endIndex: position
            }
          }
        }]
      }
    });
    
    // Add the data to the new row
    await this.sheets.spreadsheets.values.update({
      spreadsheetId,
      range: `נתונים!A${position}:L${position}`,
      valueInputOption: 'RAW',
      requestBody: {
        values: [[
          record.date,
          record.studentName,
          record.className,
          record.classNumber,
          record.entry,
          record.staying,
          record.attitude,
          record.performance,
          record.personalGoal,
          record.bonus,
          record.totalScore,
          record.comments
        ]]
      }
    });
  }

  // Firestore methods for user-spreadsheet mapping
  private async storeUserMapping(userEmail: string, spreadsheetId: string) {
    try {
      const db = admin.firestore();
      await db.collection('userSpreadsheets').doc(userEmail).set({
        spreadsheetId,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        lastAccessed: admin.firestore.FieldValue.serverTimestamp()
      });
    } catch (error) {
      console.error('Store user mapping error:', error);
      // Non-critical - continue even if mapping fails
    }
  }

  private async getUserMapping(userEmail: string) {
    try {
      const db = admin.firestore();
      const doc = await db.collection('userSpreadsheets').doc(userEmail).get();
      
      if (doc.exists) {
        // Update last accessed
        await doc.ref.update({
          lastAccessed: admin.firestore.FieldValue.serverTimestamp()
        });
        return doc.data();
      }
      return null;
    } catch (error) {
      console.error('Get user mapping error:', error);
      return null;
    }
  }

  private async getUserSpreadsheetId(userEmail: string): Promise<string | null> {
    const mapping = await this.getUserMapping(userEmail);
    return mapping?.spreadsheetId || null;
  }
}

export const sheetsService = new SheetsService();