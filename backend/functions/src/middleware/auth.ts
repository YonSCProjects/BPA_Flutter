import { Request, Response, NextFunction } from 'express';
import * as admin from 'firebase-admin';

export interface AuthRequest extends Request {
  user?: admin.auth.DecodedIdToken;
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
    
    // Verify the ID token using Firebase Admin SDK
    const decodedToken = await admin.auth().verifyIdToken(token);
    req.user = decodedToken;
    
    // Verify the user email matches the request
    const requestEmail = req.body.userEmail || req.query.userEmail;
    if (requestEmail && requestEmail !== decodedToken.email) {
      res.status(403).json({ 
        error: 'User email mismatch',
        message: 'You can only access your own data' 
      });
      return;
    }
    
    next();
  } catch (error: any) {
    console.error('Auth middleware error:', error);
    
    if (error.code === 'auth/id-token-expired') {
      res.status(401).json({ error: 'Token expired' });
      return;
    }
    
    res.status(401).json({ error: 'Invalid authorization token' });
    return;
  }
}