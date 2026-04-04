# 🔥 Firebase Setup Guide - Step by Step

## Complete Firebase Configuration for Vehicle Chatbot

---

## 📋 Table of Contents

1. [Create Firebase Project](#1-create-firebase-project)
2. [Setup Firestore Database](#2-setup-firestore-database)
3. [Setup Firebase Storage](#3-setup-firebase-storage)
4. [Setup Firebase Authentication](#4-setup-firebase-authentication)
5. [Get Firebase Credentials](#5-get-firebase-credentials)
6. [Configure Python Backend](#6-configure-python-backend)
7. [Setup Flutter App](#7-setup-flutter-app-optional)
8. [Test Firebase Connection](#8-test-firebase-connection)

---

## 1. Create Firebase Project

### Step 1.1: Go to Firebase Console

1. Open your browser and go to: **https://console.firebase.google.com**
2. Sign in with your Google account
3. Click **"Add project"** or **"Create a project"**

### Step 1.2: Project Setup

**Project Name:**
```
vehicle-chatbot-sl
```
(or any name you prefer)

**Enable Google Analytics:** (Optional)
- You can choose "Enable" or "Not right now"
- For this chatbot, it's optional

Click **"Create Project"**

Wait for Firebase to set up your project (30-60 seconds)

Click **"Continue"** when ready

---

## 2. Setup Firestore Database

### Step 2.1: Navigate to Firestore

1. In Firebase Console, click **"Firestore Database"** from left menu
2. Click **"Create database"**

### Step 2.2: Choose Security Mode

**Select:** Production mode
- We'll configure custom rules later
- Click **"Next"**

### Step 2.3: Choose Location

**Recommended for Sri Lanka:**
```
asia-south1 (Mumbai)
```
or
```
asia-southeast1 (Singapore)
```

These are closest to Sri Lanka for best performance.

Click **"Enable"**

Wait for database creation (1-2 minutes)

### Step 2.4: Create Collections

Your database is now ready! The collections will be created automatically when your app runs, but you can create them manually:

Click **"Start collection"**

**Create these collections:**

1. **users**
   - Collection ID: `users`
   - Add a test document:
     - Document ID: (auto-generated)
     - Field: `name`, Type: `string`, Value: `Test User`

2. **conversations**
   - Collection ID: `conversations`
   - Skip adding document for now

3. **warning_light_scans**
   - Collection ID: `warning_light_scans`
   - Skip adding document

4. **feedback**
   - Collection ID: `feedback`
   - Skip adding document

### Step 2.5: Set Security Rules

Go to **"Rules"** tab in Firestore

Replace the default rules with:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // Allow all authenticated users to read/write
    // For testing purposes - tighten this in production
    match /{document=**} {
      allow read, write: if request.auth != null;
    }

    // Users collection
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }

    // Conversations
    match /conversations/{sessionId} {
      allow read, write: if request.auth != null;

      match /messages/{messageId} {
        allow read, write: if request.auth != null;
      }
    }

    // Warning light scans
    match /warning_light_scans/{scanId} {
      allow read, write: if request.auth != null;
    }

    // Feedback
    match /feedback/{feedbackId} {
      allow create: if request.auth != null;
      allow read: if request.auth != null;
    }
  }
}
```

Click **"Publish"**

---

## 3. Setup Firebase Storage

### Step 3.1: Navigate to Storage

1. Click **"Storage"** from left menu
2. Click **"Get started"**

### Step 3.2: Configure Security Rules

**Choose:** Start in test mode (for now)
- Click **"Next"**

**Location:** Same as Firestore
- `asia-south1` or `asia-southeast1`
- Click **"Done"**

### Step 3.3: Create Folders

In Storage, create these folders:
1. Click **"Create folder"** → Name: `dashboard_images`
2. Click **"Create folder"** → Name: `voice_recordings`

### Step 3.4: Update Storage Rules

Go to **"Rules"** tab in Storage

Replace with:

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {

    // Dashboard images
    match /dashboard_images/{allPaths=**} {
      allow read: if request.auth != null;
      allow write: if request.auth != null
                   && request.resource.size < 5 * 1024 * 1024 // 5MB limit
                   && request.resource.contentType.matches('image/.*');
    }

    // Voice recordings
    match /voice_recordings/{allPaths=**} {
      allow read: if request.auth != null;
      allow write: if request.auth != null
                   && request.resource.size < 10 * 1024 * 1024 // 10MB limit
                   && request.resource.contentType.matches('audio/.*');
    }
  }
}
```

Click **"Publish"**

---

## 4. Setup Firebase Authentication

### Step 4.1: Navigate to Authentication

1. Click **"Authentication"** from left menu
2. Click **"Get started"**

### Step 4.2: Enable Anonymous Authentication

1. Go to **"Sign-in method"** tab
2. Find **"Anonymous"** in the list
3. Click on it
4. Toggle **"Enable"**
5. Click **"Save"**

**Why Anonymous?**
- Users can use the chatbot without creating accounts
- Firebase still assigns them a unique ID
- Good for initial testing and MVP

### Step 4.3: (Optional) Enable Email Authentication

If you want users to create accounts later:

1. Find **"Email/Password"** in providers list
2. Click on it
3. Toggle **"Enable"**
4. Click **"Save"**

---

## 5. Get Firebase Credentials

### Step 5.1: Get Service Account Key (for Python Backend)

1. Click **⚙️ (Settings icon)** next to "Project Overview"
2. Click **"Project settings"**
3. Go to **"Service accounts"** tab
4. Click **"Generate new private key"**
5. Click **"Generate key"**

**IMPORTANT:** A JSON file will download - this contains your credentials!

**Rename the file to:** `firebase-credentials.json`

**Move it to:** `e:\research\gamage new\data\`

**⚠️ SECURITY WARNING:**
- Never share this file
- Never commit to Git
- Keep it safe!

### Step 5.2: Get Firebase Config (for Flutter App)

#### For Android:

1. In Project Settings, scroll to **"Your apps"**
2. Click Android icon (🤖)
3. **Android package name:** `com.vehiclechatbot.app` (or your choice)
4. **App nickname:** `Vehicle Chatbot`
5. Click **"Register app"**
6. Download **`google-services.json`**
7. Save it for later (you'll need it for Flutter)

#### For iOS:

1. Click iOS icon (🍎)
2. **iOS bundle ID:** `com.vehiclechatbot.app`
3. **App nickname:** `Vehicle Chatbot`
4. Click **"Register app"**
5. Download **`GoogleService-Info.plist`**
6. Save it for later

### Step 5.3: Get Project Details

In **Project Settings → General**, note down:

```
Project ID: vehicle-chatbot-sl
Storage Bucket: vehicle-chatbot-sl.appspot.com
```

You'll need these for configuration.

---

## 6. Configure Python Backend

### Step 6.1: Verify Credentials File

Make sure `firebase-credentials.json` is in your data folder:

```
e:\research\gamage new\data\firebase-credentials.json
```

### Step 6.2: Install Firebase Admin SDK

```cmd
cd "e:\research\gamage new\data"
pip install firebase-admin
```

### Step 6.3: Update API Server

The `api_server.py` file is already configured to use Firebase!

**It will automatically:**
- Look for `firebase-credentials.json` in the same folder
- Initialize Firebase when the server starts
- Use your project's storage bucket

### Step 6.4: Test Firebase Connection

Create a test script:

```python
# test_firebase.py
import firebase_admin
from firebase_admin import credentials, firestore, storage

# Initialize Firebase
cred = credentials.Certificate('firebase-credentials.json')
firebase_admin.initialize_app(cred, {
    'storageBucket': 'vehicle-chatbot-sl.appspot.com'  # Replace with your bucket
})

# Test Firestore
db = firestore.client()
print("✓ Firestore connected!")

# Test write
test_ref = db.collection('users').document('test_user')
test_ref.set({
    'name': 'Test User',
    'created_at': firestore.SERVER_TIMESTAMP
})
print("✓ Firestore write successful!")

# Test read
doc = test_ref.get()
if doc.exists:
    print(f"✓ Firestore read successful: {doc.to_dict()}")

# Test Storage
bucket = storage.bucket()
print(f"✓ Storage bucket connected: {bucket.name}")

print("\n✓✓✓ All Firebase tests passed!")
```

Save as `test_firebase.py` and run:

```cmd
python test_firebase.py
```

---

## 7. Setup Flutter App (Optional)

### Step 7.1: Install Firebase CLI

```cmd
npm install -g firebase-tools
```

Or download from: https://firebase.google.com/docs/cli

### Step 7.2: Login to Firebase

```cmd
firebase login
```

### Step 7.3: Install FlutterFire CLI

```cmd
dart pub global activate flutterfire_cli
```

### Step 7.4: Configure Flutter App

```cmd
cd your_flutter_app_folder
flutterfire configure
```

This will:
- Automatically detect your Firebase project
- Generate configuration files
- Setup Android & iOS

### Step 7.5: Add Firebase Dependencies

In `pubspec.yaml`:

```yaml
dependencies:
  firebase_core: ^2.24.2
  cloud_firestore: ^4.13.6
  firebase_storage: ^11.5.6
  firebase_auth: ^4.15.3
```

Run:
```cmd
flutter pub get
```

### Step 7.6: Initialize Firebase in Flutter

In `lib/main.dart`:

```dart
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(MyApp());
}
```

---

## 8. Test Firebase Connection

### Test 1: Python Backend

```cmd
cd "e:\research\gamage new\data"
python test_firebase.py
```

**Expected output:**
```
✓ Firestore connected!
✓ Firestore write successful!
✓ Firestore read successful: {'name': 'Test User', 'created_at': ...}
✓ Storage bucket connected: vehicle-chatbot-sl.appspot.com

✓✓✓ All Firebase tests passed!
```

### Test 2: Start Server with Firebase

```cmd
python api_server.py
```

**Expected output:**
```
✅ Firebase initialized
✅ Chatbot initialized
INFO: Uvicorn running on http://0.0.0.0:8000
```

### Test 3: Test API with Firebase

```cmd
curl -X POST http://localhost:8000/api/conversation/start ^
  -H "Content-Type: application/json" ^
  -d "{\"user_id\": \"test123\", \"language\": \"english\"}"
```

Check Firebase Console → Firestore → conversations
You should see a new document created!

---

## 9. Update API Server Configuration

### Step 9.1: Update Storage Bucket Name

Open `api_server.py` and find this line (around line 60):

```python
firebase_admin.initialize_app(cred, {
    'storageBucket': 'your-project-id.appspot.com'
})
```

**Replace with your actual bucket name:**
```python
firebase_admin.initialize_app(cred, {
    'storageBucket': 'vehicle-chatbot-sl.appspot.com'
})
```

### Step 9.2: Verify File Paths

Make sure these files exist:
```
e:\research\gamage new\data\firebase-credentials.json  ✓
e:\research\gamage new\data\api_server.py              ✓
```

---

## 10. Firebase Console - Quick Reference

### Firestore Dashboard
**URL:** https://console.firebase.google.com/project/vehicle-chatbot-sl/firestore

**What to check:**
- Collections: users, conversations, warning_light_scans, feedback
- Documents created by your app
- Real-time updates

### Storage Dashboard
**URL:** https://console.firebase.google.com/project/vehicle-chatbot-sl/storage

**What to check:**
- dashboard_images folder
- voice_recordings folder
- Uploaded files

### Authentication Dashboard
**URL:** https://console.firebase.google.com/project/vehicle-chatbot-sl/authentication

**What to check:**
- Anonymous users created
- User count

---

## 11. Common Issues & Solutions

### Issue 1: "Firebase credentials not found"

**Solution:**
```cmd
# Check if file exists
dir firebase-credentials.json

# Make sure it's in the same folder as api_server.py
cd "e:\research\gamage new\data"
```

### Issue 2: "Permission denied" in Firestore

**Solution:**
- Go to Firestore → Rules
- Make sure rules allow authenticated users
- For testing, you can temporarily use:
```javascript
allow read, write: if true;  // Allow all (testing only!)
```

### Issue 3: "Storage bucket not found"

**Solution:**
- Check your bucket name in Firebase Console → Storage
- Update api_server.py with correct bucket name
- Format: `your-project-id.appspot.com`

### Issue 4: "Module 'firebase_admin' not found"

**Solution:**
```cmd
pip install firebase-admin
```

---

## 12. Security Best Practices

### For Development:
✓ Use test mode for Storage
✓ Allow authenticated users in Firestore
✓ Keep credentials file secure

### For Production:
✓ Tighten Firestore rules (user-specific access)
✓ Add file size limits in Storage rules
✓ Enable App Check
✓ Use environment variables for credentials
✓ Enable billing alerts

---

## 13. Environment Variables (Optional)

Instead of hardcoding, use environment variables:

**Windows:**
```cmd
set FIREBASE_PROJECT_ID=vehicle-chatbot-sl
set FIREBASE_STORAGE_BUCKET=vehicle-chatbot-sl.appspot.com
```

**In api_server.py:**
```python
import os

firebase_admin.initialize_app(cred, {
    'storageBucket': os.getenv('FIREBASE_STORAGE_BUCKET')
})
```

---

## 14. Monitoring & Analytics

### Enable Cloud Functions (Optional)

For automated tasks like:
- Cleaning old conversations
- Daily analytics
- Scheduled reports

Go to: **Functions** in Firebase Console

### Setup Usage Quotas

Go to: **Usage and billing**

**Free Tier Limits:**
- Firestore: 50K reads/day, 20K writes/day
- Storage: 1GB stored, 10GB/month transfer
- Authentication: Unlimited

**Monitor usage to avoid overages!**

---

## ✅ Checklist

Use this to verify your Firebase setup:

- [ ] Firebase project created
- [ ] Firestore database enabled (asia-south1 or asia-southeast1)
- [ ] Firestore collections created (or auto-create enabled)
- [ ] Firestore security rules configured
- [ ] Storage enabled
- [ ] Storage folders created (dashboard_images, voice_recordings)
- [ ] Storage security rules configured
- [ ] Anonymous authentication enabled
- [ ] Service account key downloaded (`firebase-credentials.json`)
- [ ] Service account key placed in data folder
- [ ] `firebase-admin` package installed
- [ ] Storage bucket name updated in api_server.py
- [ ] Firebase connection tested successfully
- [ ] API server starts with Firebase initialized

---

## 🎉 You're Done!

Your Firebase backend is now ready to use with your vehicle chatbot!

**Next Steps:**
1. Test with: `python test_firebase.py`
2. Start server: `python api_server.py`
3. Make API calls and verify data appears in Firebase Console

**Need Help?**
- Firebase Documentation: https://firebase.google.com/docs
- Firebase Console: https://console.firebase.google.com

---

**Created for:** Vehicle Troubleshooting Chatbot
**Last Updated:** December 2025
