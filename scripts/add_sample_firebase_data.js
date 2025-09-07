// Script to add sample data to Firebase Firestore
// Run this in Firebase Console or using Firebase Admin SDK

const sampleEducators = [
  {
    name: "מורה דוגמה 1",
    email: "teacher1@example.com",
    active: true,
    createdAt: new Date()
  },
  {
    name: "מורה דוגמה 2", 
    email: "teacher2@example.com",
    active: true,
    createdAt: new Date()
  },
  {
    name: "מורה דוגמה 3",
    email: "teacher3@example.com",
    active: true,
    createdAt: new Date()
  }
];

const sampleStudents = [
  {
    name: "תלמיד א",
    educatorId: "educator1",
    educatorName: "מורה דוגמה 1",
    active: true,
    createdAt: new Date(),
    grade: "כיתה א"
  },
  {
    name: "תלמיד ב",
    educatorId: "educator1",
    educatorName: "מורה דוגמה 1",
    active: true,
    createdAt: new Date(),
    grade: "כיתה א"
  },
  {
    name: "תלמיד ג",
    educatorId: "educator2",
    educatorName: "מורה דוגמה 2",
    active: true,
    createdAt: new Date(),
    grade: "כיתה ב"
  },
  {
    name: "תלמיד ד",
    educatorId: "educator2",
    educatorName: "מורה דוגמה 2",
    active: true,
    createdAt: new Date(),
    grade: "כיתה ב"
  }
];

// Add to Firestore
// In Firebase Console, navigate to Firestore Database
// Create collections: 'educators' and 'students'
// Add documents with the above data

console.log("Sample educators:", sampleEducators);
console.log("Sample students:", sampleStudents);