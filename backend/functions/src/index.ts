import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import express from 'express';
import cors from 'cors';
import { sheetsService } from './services/sheetsService';
import { authMiddleware } from './middleware/auth';

// Initialize Firebase Admin
admin.initializeApp();

// Initialize Express app
const app = express();
app.use(cors({ origin: true }));
app.use(express.json());

// Health check endpoint
app.get('/health', (req: express.Request, res: express.Response) => {
  res.json({ 
    status: 'healthy', 
    timestamp: new Date().toISOString(),
    version: '1.0.0'
  });
});

// Main API endpoints - all protected by auth middleware
app.post('/api/setup-user', authMiddleware, async (req: express.Request, res: express.Response): Promise<void> => {
  try {
    const userEmail = req.body.userEmail;
    if (!userEmail) {
      res.status(400).json({ error: 'User email required' });
      return;
    }

    const result = await sheetsService.setupUserSpreadsheet(userEmail);
    res.json(result);
  } catch (error: any) {
    console.error('Setup user error:', error);
    res.status(500).json({ 
      error: 'Failed to setup user spreadsheet',
      details: error.message 
    });
  }
});

app.post('/api/save-record', authMiddleware, async (req: express.Request, res: express.Response): Promise<void> => {
  try {
    const { userEmail, record } = req.body;
    if (!userEmail || !record) {
      res.status(400).json({ error: 'Missing required fields' });
      return;
    }

    const result = await sheetsService.saveRecord(userEmail, record);
    res.json(result);
  } catch (error: any) {
    console.error('Save record error:', error);
    res.status(500).json({ 
      error: 'Failed to save record',
      details: error.message 
    });
  }
});

app.post('/api/find-record', authMiddleware, async (req: express.Request, res: express.Response): Promise<void> => {
  try {
    const { userEmail, matchFields } = req.body;
    if (!userEmail || !matchFields) {
      res.status(400).json({ error: 'Missing required fields' });
      return;
    }

    const result = await sheetsService.findMatchingRecord(userEmail, matchFields);
    res.json(result);
  } catch (error: any) {
    console.error('Find record error:', error);
    res.status(500).json({ 
      error: 'Failed to find record',
      details: error.message 
    });
  }
});

app.get('/api/autocomplete-data', authMiddleware, async (req: express.Request, res: express.Response): Promise<void> => {
  try {
    const userEmail = req.query.userEmail as string;
    if (!userEmail) {
      res.status(400).json({ error: 'User email required' });
      return;
    }

    const result = await sheetsService.getAutocompleteData(userEmail);
    res.json(result);
  } catch (error: any) {
    console.error('Autocomplete data error:', error);
    res.status(500).json({ 
      error: 'Failed to get autocomplete data',
      details: error.message 
    });
  }
});

// Export Firebase Function
export const api = functions.https.onRequest(app);