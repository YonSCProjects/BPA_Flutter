# 🔒 SECURITY CHECKLIST - MUST DO BEFORE PRODUCTION

## ⚠️ CRITICAL: Firebase Security Rules

**Status: ❌ NOT CONFIGURED**

Before enabling Firebase features (`firebaseEnabled = true`), you MUST:

### 1. Configure Realtime Database Rules
```json
{
  "rules": {
    "classes": {
      ".read": "auth != null",
      ".write": "auth != null && auth.token.admin === true"
    },
    "students": {
      ".read": "auth != null", 
      ".write": "auth != null && auth.token.admin === true"
    },
    "records": {
      "$teacherId": {
        ".read": "$teacherId === auth.uid || auth.token.admin === true",
        ".write": "$teacherId === auth.uid || auth.token.admin === true"
      }
    }
  }
}
```

### 2. Configure Firestore Rules (if using)
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /classes/{classId} {
      allow read: if request.auth != null;
      allow write: if request.auth.token.admin == true;
    }
    match /students/{studentId} {
      allow read: if request.auth != null;
      allow write: if request.auth.token.admin == true;
    }
    match /records/{teacherId}/{recordId} {
      allow read, write: if request.auth.uid == teacherId || 
                           request.auth.token.admin == true;
    }
  }
}
```

### 3. Test Security Rules
- [ ] Test with authenticated user
- [ ] Test with unauthenticated user (should be denied)
- [ ] Test admin permissions
- [ ] Test teacher permissions
- [ ] Verify cross-teacher access is blocked

### 4. Service Account Security
- [ ] Verify service account JSON is in `.gitignore`
- [ ] Confirm service account has minimal required permissions
- [ ] Test service account access works
- [ ] Ensure no service account credentials in code

## 🚨 NEVER DO THESE:
- ❌ Enable Firebase without security rules
- ❌ Commit service account JSON to git
- ❌ Use overly permissive rules in production
- ❌ Skip testing security rules

## ✅ PRODUCTION READINESS:
Only set `firebaseEnabled = true` after ALL security items above are complete!

## 📍 WHERE TO CONFIGURE:
1. **Realtime Database Rules**: Firebase Console → Realtime Database → Rules tab
2. **Firestore Rules**: Firebase Console → Firestore Database → Rules tab
3. **Security Testing**: Firebase Console → Rules Playground