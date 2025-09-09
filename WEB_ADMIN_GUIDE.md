# BPApp Web Admin Portal Guide

## Production URL
🌐 **https://bpapp-firebase-485c1.web.app**

## Overview
The BPApp Web Admin Portal is a comprehensive web interface for managing Firebase collections (users, educators, students) with full CRUD operations and bulk import capabilities. Now deployed and accessible worldwide via Firebase Hosting.

## Quick Start

### Running the Admin Portal
```bash
cd web-admin
npm install  # First time only
npm run dev  # Start development server
```

Access at: **http://localhost:3000**

## Features

### 1. Authentication
- **Google Sign-In**: Use your Google account for quick access
- **Email/Password**: Traditional authentication method
- **Protected Routes**: All admin pages require authentication

### 2. Dashboard
The main dashboard provides:
- **Real-time Statistics**: Live counts of users, educators, students, and classes
- **Recent Activity**: Shows the last 5 students added to the system
- **Quick Actions**: Direct links to common tasks
- **System Information**: Firebase project details and version info

### 3. Collections Management

#### Users Collection (/users)
Manages system users with different roles:
- **Roles**: Admin, Educator, Teacher
- **Fields**: Email, Name (optional), Role
- **Features**: Search, Add, Edit, Delete
- **Visual Indicators**: Role badges with colors

#### Educators Collection (/educators)
Manages educator information:
- **Fields**: Name, Email, Classes (multiple), Spreadsheet ID
- **Features**: Search, Add, Edit, Delete
- **Class Management**: Comma-separated list of classes
- **Spreadsheet Tracking**: Optional spreadsheet ID for Google Sheets integration

#### Students Collection (/students)
Manages student records:
- **Fields**: Name, Class
- **Features**: Search, Add, Edit, Delete
- **Statistics**: Total students, classes, and average per class
- **Visual Grouping**: Students organized by class

### 4. Bulk Import (/import)

#### Supported Collections
- Students
- Educators
- Users

#### Import Process
1. **Select Collection**: Choose which collection to import to
2. **Download Template**: Get a CSV template with correct headers
3. **Prepare Data**: Fill the CSV with your data
4. **Upload File**: Drag and drop or click to upload
5. **Preview**: Review data before import
6. **Import**: Process the batch with validation
7. **Review Results**: See success/failure counts and errors

#### CSV Templates

**Students Template**:
```csv
name,class
John Doe,Class A
Jane Smith,Class B
```

**Educators Template**:
```csv
name,email,classes,spreadsheetId
Dr. Smith,smith@school.edu,"Math,Science",1234567890
Prof. Jones,jones@school.edu,"English,History",
```

**Users Template**:
```csv
email,role,name
admin@school.edu,admin,System Admin
teacher@school.edu,teacher,John Teacher
```

## Navigation Structure

```
/ (Dashboard)
├── /login (Authentication)
├── /users (Users Management)
├── /educators (Educators Management)
├── /students (Students Management)
└── /import (Bulk Import)
```

## Technical Details

### Firebase Collections Structure

**users**
```javascript
{
  email: string,
  role: "admin" | "educator" | "teacher",
  name?: string,
  createdAt: Date,
  updatedAt: Date
}
```

**educators**
```javascript
{
  name: string,
  email: string,
  classes: string[],
  spreadsheetId?: string,
  createdAt: Date,
  updatedAt: Date
}
```

**students**
```javascript
{
  name: string,
  class: string,
  createdAt: Date,
  updatedAt: Date
}
```

### Environment Variables
Located in `web-admin/.env.local`:
```env
NEXT_PUBLIC_FIREBASE_API_KEY=...
NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN=...
NEXT_PUBLIC_FIREBASE_PROJECT_ID=...
NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET=...
NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID=...
NEXT_PUBLIC_FIREBASE_APP_ID=...
```

## Best Practices

### Data Management
1. **Always validate** data before bulk import
2. **Use templates** to ensure correct format
3. **Test with small batches** before large imports
4. **Keep backups** of your data

### Security
1. **Limit admin access** to trusted personnel
2. **Use strong passwords** for email authentication
3. **Regularly review** user roles and permissions
4. **Monitor activity** through the dashboard

### Performance
1. **Batch operations** for bulk updates
2. **Use search** to filter large datasets
3. **Paginate** when dealing with many records (future enhancement)

## Troubleshooting

### Common Issues

**Cannot Login**
- Verify Firebase Auth is enabled
- Check if user exists in Firebase Console
- Ensure correct project configuration

**Import Fails**
- Check CSV format matches template
- Verify required fields are present
- Look for special characters in data
- Review error messages for specific issues

**Data Not Showing**
- Refresh the page
- Check Firebase Console for data
- Verify collection names are correct
- Check browser console for errors

## Future Enhancements

### Planned Features
- [ ] Analytics and reporting dashboards
- [ ] Export functionality for all collections
- [ ] Advanced filtering and sorting
- [ ] Pagination for large datasets
- [ ] Audit logs for all operations
- [ ] Batch edit operations
- [ ] Data validation rules configuration
- [ ] Custom fields support
- [ ] Email notifications for important events
- [ ] Role-based access control (RBAC)

### Integration Possibilities
- Google Sheets sync status monitoring
- Direct spreadsheet viewing/editing
- Automated data synchronization
- Mobile app user activity tracking
- Performance metrics and usage statistics

## Support

For issues or questions:
1. Check this guide first
2. Review error messages in the UI
3. Check browser console for detailed errors
4. Report issues at: https://github.com/YonSCProjects/BPA_Flutter/issues

## Development

### Tech Stack
- **Framework**: Next.js 15.5.2
- **Language**: TypeScript
- **Styling**: Tailwind CSS
- **Database**: Firebase Firestore
- **Authentication**: Firebase Auth
- **Icons**: Lucide React
- **CSV Processing**: Papa Parse
- **File Upload**: React Dropzone
- **Notifications**: Sonner

### Project Structure
```
web-admin/
├── app/              # Next.js app directory
├── components/       # Reusable components
├── contexts/         # React contexts
├── lib/              # Utilities and config
├── public/           # Static assets
└── package.json      # Dependencies
```

### Building for Production
```bash
cd web-admin
npm run build
npm start  # Production server
```

### Deploying to Firebase Hosting
```bash
cd web-admin
npm run build
firebase deploy --only hosting
```

## Recent Updates (January 9, 2025)

### Firebase Security Rules
Updated to support both Flutter app and web admin:
- **Public read access** - Flutter app can read without authentication
- **Authenticated write** - Only logged-in admin users can modify data

### UI Enhancements
- Added `createdAt` field display to all collection tables
- Added `active` status field for educators and students
- Added `grade` and `notes` fields for students
- Fixed educators page array/string handling for classes field
- Improved date formatting for Firestore timestamps

### Deployment Configuration
- Configured for static export with Next.js
- Firebase Hosting setup with proper rewrites
- ESLint and TypeScript errors bypassed for rapid deployment

## Version History
- **v1.0.0** (January 2025): Initial release with full CRUD and bulk import
- **v1.1.0** (January 9, 2025): Deployed to Firebase Hosting, added all Firestore fields, fixed security rules