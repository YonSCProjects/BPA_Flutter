import { Request, Response, NextFunction } from 'express';
import * as admin from 'firebase-admin';
import axios from 'axios';

export interface AuthRequest extends Request {
  user?: admin.auth.DecodedIdToken | { email: string, uid: string };
}

// Verify Google OAuth access token
async function verifyGoogleToken(accessToken: string): Promise<{ email: string, uid: string }> {
  try {
    const response = await axios.get(`https://www.googleapis.com/oauth2/v1/tokeninfo?access_token=${accessToken}`);
    const tokenInfo = response.data;
    
    if (!tokenInfo.email || !tokenInfo.verified_email) {
      throw new Error('Invalid or unverified token');
    }
    
    return {
      email: tokenInfo.email,
      uid: tokenInfo.user_id || tokenInfo.email // Use email as fallback uid
    };
  } catch (error: any) {
    console.error('Google token verification failed:', error.response?.data || error.message);
    throw new Error('Invalid Google OAuth token');
  }
}

export async function authMiddleware(
  req: AuthRequest, 
  res: Response, 
  next: NextFunction
) {
  try {
    const authHeader = req.headers.authorization;
    
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      res.status(401).json({ error: 'No authorization token provided' });
      return;
    }

    const token = authHeader.split('Bearer ')[1];
    let userInfo: admin.auth.DecodedIdToken | { email: string, uid: string };
    
    try {
      // Try Firebase ID token first
      console.log('Attempting Firebase ID token verification...');
      userInfo = await admin.auth().verifyIdToken(token);
      console.log('Firebase ID token verified successfully');
    } catch (firebaseError: any) {
      console.log('Firebase ID token failed, trying Google OAuth...', firebaseError.code);
      
      try {
        // Fallback to Google OAuth access token
        userInfo = await verifyGoogleToken(token);
        console.log('Google OAuth token verified successfully');
      } catch (googleError: any) {
        console.error('Both Firebase and Google token verification failed:', googleError.message);
        res.status(401).json({ error: 'Invalid authorization token' });
        return;
      }
    }
    
    req.user = userInfo;
    
    // Verify the user email matches the request
    const requestEmail = req.body.userEmail || req.query.userEmail;
    if (requestEmail && requestEmail !== userInfo.email) {
      res.status(403).json({ 
        error: 'User email mismatch',
        message: 'You can only access your own data' 
      });
      return;
    }
    
    next();
  } catch (error: any) {
    console.error('Auth middleware unexpected error:', error);
    res.status(401).json({ error: 'Authentication failed' });
    return;
  }
}