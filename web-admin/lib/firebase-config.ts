import { initializeApp, getApps } from 'firebase/app';
import { getAuth } from 'firebase/auth';
import { getFirestore } from 'firebase/firestore';

const firebaseConfig = {
  apiKey: "AIzaSyBxgt3n38opIDR8BznP-pK60TjsrwCQSY0",
  authDomain: "bpapp-firebase-485c1.firebaseapp.com",
  projectId: "bpapp-firebase-485c1",
  storageBucket: "bpapp-firebase-485c1.firebasestorage.app",
  messagingSenderId: "797019072021",
  appId: "1:797019072021:android:bff80ec54601d5c252501c"
};

// Initialize Firebase only if it hasn't been initialized
const app = getApps().length === 0 ? initializeApp(firebaseConfig) : getApps()[0];
export const auth = getAuth(app);
export const db = getFirestore(app);