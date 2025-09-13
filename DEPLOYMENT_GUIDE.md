# BPApp Deployment Guide

## 📦 Current Release
- **Version**: 1.0.0 (January 2025)
- **APK Location**: `build\app\outputs\flutter-apk\app-release.apk`
- **APK Size**: 24.8MB
- **Branch**: `service-account-final`

## 🚀 Deployment Options for Private Distribution

### Option 1: **Google Play Store - Private/Managed Publishing** (RECOMMENDED)
Best option for controlled distribution to specific teacher groups.

#### **A. Managed Google Play (For Organizations)**
1. **Requirements:**
   - Google Play Console account ($25 one-time fee)
   - Google Workspace or Cloud Identity account
   
2. **Setup Steps:**
   - Create app in Play Console as "Private App"
   - Enable **Managed Publishing** in Play Console
   - Set up **Organization** in Google Admin Console
   - Add approved teachers/devices to organization
   - App only visible to organization members

3. **Benefits:**
   - ✅ Automatic updates through Play Store
   - ✅ Controlled access to specific users
   - ✅ Enterprise-grade distribution
   - ✅ No manual APK sharing needed

#### **B. Closed Testing Track (Simpler Alternative)**
1. **Setup in Play Console:**
   - Create new app in Google Play Console
   - Navigate to **Release > Testing > Closed testing**
   - Create new closed testing track
   - Add teacher emails (supports 100-200 testers)
   - Upload signed APK

2. **Benefits:**
   - ✅ Easy setup process
   - ✅ Testers receive invite link via email
   - ✅ Automatic updates through Play Store
   - ✅ Limited to specific email addresses

### Option 2: **Firebase App Distribution** (FREE)
Perfect integration with existing Firebase project.

1. **Setup Commands:**
   ```bash
   npm install -g firebase-tools
   firebase login
   firebase init hosting
   ```

2. **Distribution Steps:**
   - Open Firebase Console > App Distribution
   - Upload `app-release.apk`
   - Add teacher email addresses
   - Teachers receive installation invite

3. **Benefits:**
   - ✅ Free for up to 500 testers
   - ✅ Integrates with existing Firebase project
   - ✅ No Play Store account needed
   - ✅ Easy tester management

### Option 3: **Direct APK Distribution** (Simplest)
For immediate distribution without infrastructure.

1. **Sharing Methods:**
   - Google Drive with access control
   - Private website with authentication
   - Email (check file size limits)
   - WhatsApp/Telegram groups

2. **Installation Requirements:**
   - Users enable "Install from Unknown Sources"
   - Manual installation of updates
   - Direct communication for new versions

### Option 4: **MDM Solutions** (Enterprise Scale)
For large educational institutions:
- Microsoft Intune
- VMware Workspace ONE  
- Google Endpoint Management
- MobileIron

## 🔐 Security & Architecture

### Current Implementation:
- **Authentication**: Google OAuth 2.0
- **Data Storage**: Google Sheets (teacher-owned)
- **Educator Sheets**: Service account managed
- **Backend**: Firebase Firestore
- **Local Cache**: SQLite for offline support

### Security Features:
- ✅ No sensitive data stored on device
- ✅ OAuth consent screen restricted to test users
- ✅ Service account with minimal permissions
- ✅ Educator spreadsheets with controlled access
- ✅ Automatic data sync and backup

## 📋 Pre-Deployment Checklist

### Technical Requirements:
- [x] APK signed with release keystore
- [x] Service account configured (`assets/service_account.json`)
- [x] Firebase project active (`bpapp-firebase-485c1`)
- [x] Google OAuth configured
- [x] Test users added to OAuth consent screen

### Configuration Files:
- [x] `google-services.json` in place
- [x] `AppConfig` set to production mode
- [x] Service account enabled in config
- [x] Educator mappings configured

### Testing:
- [x] Login flow tested
- [x] Student scoring tested
- [x] Batch mode tested
- [x] Educator sheet saving tested
- [x] Offline mode tested

## 🎯 Recommended Deployment Path

For your specific use case (private group of teachers):

1. **Primary**: Google Play **Closed Testing**
   - Easy distribution
   - Automatic updates
   - Professional appearance
   
2. **Backup**: Firebase App Distribution
   - Quick testing cycles
   - Beta features testing
   
3. **Emergency**: Direct APK sharing
   - Immediate access
   - Bypass all systems

## 📱 Installation Instructions for Teachers

### For Closed Testing (Play Store):
1. Teacher receives invitation email
2. Click "Accept Invite" link
3. Join testing program
4. Install from Play Store
5. Sign in with approved Google account

### For Firebase Distribution:
1. Accept Firebase App Tester invitation
2. Download Firebase App Tester app
3. Install BPApp through tester app
4. Sign in with approved Google account

### For Direct APK:
1. Download APK file
2. Open Settings > Security
3. Enable "Unknown Sources"
4. Install APK
5. Sign in with approved Google account

## 🔄 Update Process

### Automatic Updates (Play Store/Firebase):
- Updates download automatically
- Users notified of new version
- Seamless upgrade process

### Manual Updates (Direct APK):
- Notify users via WhatsApp/Email
- Share new APK
- Users install over existing app
- Data preserved automatically

## 📞 Support Information

### Common Issues:
1. **"App not installed"**: Clear space, enable unknown sources
2. **Login fails**: Check OAuth test users list
3. **Sheets not saving**: Verify permissions
4. **Students not showing**: Check Firebase data

### Contact:
- GitHub Issues: https://github.com/YonSCProjects/BPA_Flutter/issues
- Email: [Your support email]

## 📈 Current Status (January 2025)

### Completed Features:
- ✅ Batch scoring system
- ✅ Service account integration
- ✅ Firebase dynamic dropdowns
- ✅ Multi-destination saving
- ✅ Offline support
- ✅ Hebrew RTL interface
- ✅ Smart student filtering

### Latest Changes:
- Removed "צפייה בלבד" indicator
- Fixed save functionality
- Removed backup instructions sheet
- Optimized service account flow

### Known Limitations:
- OAuth consent screen in testing mode (100 users max)
- Manual educator onboarding required
- Service account needs pre-shared access

## 🚦 Go-Live Steps

1. **Choose deployment method** from options above
2. **Prepare teacher list** with Gmail addresses
3. **Add teachers** to OAuth consent screen
4. **Deploy APK** via chosen method
5. **Send invitations** with instructions
6. **Monitor initial** usage and feedback
7. **Iterate based** on teacher feedback

---

**APK Ready**: `build\app\outputs\flutter-apk\app-release.apk` (24.8MB)
**Last Build**: January 2025
**Package**: `com.bpa.student`