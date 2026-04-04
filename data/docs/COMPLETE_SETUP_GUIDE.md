# Vehicle Troubleshooting Chatbot - Complete Setup Guide

## 🎯 Project Overview

A complete AI-powered vehicle troubleshooting chatbot for Sri Lankan drivers featuring:
- ✅ Natural language conversation (English & Sinhala)
- ✅ Knowledge base of 250+ vehicle issues (Aqua, Prius, Corolla, Alto, Vitz)
- ✅ Intelligent fallback system with diagnostic questions
- ✅ Dashboard warning light recognition using Gemini Vision
- ✅ Voice input/output support
- ✅ Firebase backend + Flutter mobile app
- ✅ Real-time severity assessment

---

## 📋 Table of Contents

1. [Prerequisites](#prerequisites)
2. [Backend Setup](#backend-setup)
3. [Firebase Configuration](#firebase-configuration)
4. [Flutter App Setup](#flutter-app-setup)
5. [Deployment](#deployment)
6. [Testing](#testing)
7. [Project Structure](#project-structure)

---

## 1. Prerequisites

### Required Software
```
- Python 3.11+
- Node.js 18+
- Flutter SDK 3.16+
- Firebase CLI
- Git
```

### Required API Keys
1. **Google Gemini API Key**
   - Go to: https://makersuite.google.com/app/apikey
   - Create new API key
   - Save as environment variable: `GEMINI_API_KEY`

2. **Firebase Project**
   - Go to: https://console.firebase.google.com
   - Create new project
   - Enable Firestore Database
   - Enable Firebase Storage
   - Enable Firebase Authentication

---

## 2. Backend Setup

### Step 1: Install Python Dependencies

```bash
cd "e:\research\gamage new\data"
pip install -r requirements.txt
```

### Step 2: Additional Backend Dependencies

```bash
pip install fastapi uvicorn firebase-admin python-multipart
```

### Step 3: Set Environment Variables

**Windows:**
```cmd
set GEMINI_API_KEY=your_gemini_api_key_here
set FIREBASE_PROJECT_ID=your_firebase_project_id
```

**Linux/Mac:**
```bash
export GEMINI_API_KEY=your_gemini_api_key_here
export FIREBASE_PROJECT_ID=your_firebase_project_id
```

### Step 4: Download Firebase Credentials

1. Go to Firebase Console → Project Settings → Service Accounts
2. Click "Generate New Private Key"
3. Save as `firebase-credentials.json` in the data folder

### Step 5: Test Backend Components

```bash
# Test Gemini API
python gemini_api.py

# Test Knowledge Base
python knowledge_base.py

# Test Fallback System
python fallback_system.py

# Test Warning Light Detector
python warning_light_detector.py

# Test Full Chatbot
python chatbot_core.py
```

### Step 6: Run Backend API Server

```bash
python api_server.py
```

Server will start at: `http://localhost:8000`

API Documentation: `http://localhost:8000/docs`

---

## 3. Firebase Configuration

### Step 1: Create Firebase Project

1. Go to https://console.firebase.google.com
2. Click "Add Project"
3. Name: "vehicle-chatbot-sl"
4. Enable Google Analytics (optional)

### Step 2: Enable Firestore Database

1. In Firebase Console, go to "Firestore Database"
2. Click "Create Database"
3. Start in **production mode**
4. Choose location: `asia-south1` (Singapore - closest to Sri Lanka)

### Step 3: Create Firestore Collections

The API will auto-create collections, but you can manually create:

```
- users
- conversations
  - [session_id]
    - messages (subcollection)
- warning_light_scans
- feedback
- usage_analytics
```

### Step 4: Set Security Rules

Go to Firestore → Rules, paste:

```javascript
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }

    match /conversations/{sessionId} {
      allow read, write: if request.auth != null;

      match /messages/{messageId} {
        allow read, write: if request.auth != null;
      }
    }

    match /warning_light_scans/{scanId} {
      allow read, write: if request.auth != null;
    }

    match /feedback/{feedbackId} {
      allow create: if request.auth != null;
      allow read: if request.auth != null;
    }
  }
}
```

### Step 5: Enable Firebase Storage

1. Go to "Storage" in Firebase Console
2. Click "Get Started"
3. Use default security rules
4. Create folders:
   - `dashboard_images/`
   - `voice_recordings/`

### Step 6: Set Storage Rules

```javascript
service firebase.storage {
  match /b/{bucket}/o {
    match /dashboard_images/{allPaths=**} {
      allow read, write: if request.auth != null;
      allow write: if request.resource.size < 5 * 1024 * 1024;
    }

    match /voice_recordings/{allPaths=**} {
      allow read, write: if request.auth != null;
      allow write: if request.resource.size < 10 * 1024 * 1024;
    }
  }
}
```

### Step 7: Enable Authentication (Anonymous)

1. Go to "Authentication" → "Sign-in method"
2. Enable "Anonymous" authentication
3. Save

---

## 4. Flutter App Setup

### Step 1: Create Flutter Project

```bash
flutter create vehicle_chatbot_app
cd vehicle_chatbot_app
```

### Step 2: Add Dependencies to `pubspec.yaml`

```yaml
dependencies:
  flutter:
    sdk: flutter

  # Firebase
  firebase_core: ^2.24.2
  cloud_firestore: ^4.13.6
  firebase_storage: ^11.5.6
  firebase_auth: ^4.15.3

  # HTTP & State Management
  http: ^1.1.2
  provider: ^6.1.1

  # UI Components
  flutter_chat_ui: ^1.6.10
  image_picker: ^1.0.5
  cached_network_image: ^3.3.0

  # Voice
  speech_to_text: ^6.5.1
  flutter_tts: ^3.8.3

  # Utilities
  intl: ^0.18.1
  shared_preferences: ^2.2.2
  flutter_markdown: ^0.6.18
```

### Step 3: Flutter Project Structure

```
vehicle_chatbot_app/
├── lib/
│   ├── main.dart
│   ├── models/
│   │   ├── message.dart
│   │   ├── conversation.dart
│   │   └── warning_light.dart
│   ├── services/
│   │   ├── api_service.dart
│   │   ├── firebase_service.dart
│   │   ├── voice_service.dart
│   │   └── storage_service.dart
│   ├── providers/
│   │   ├── chat_provider.dart
│   │   └── language_provider.dart
│   ├── screens/
│   │   ├── home_screen.dart
│   │   ├── chat_screen.dart
│   │   ├── warning_light_scan_screen.dart
│   │   └── history_screen.dart
│   ├── widgets/
│   │   ├── chat_message.dart
│   │   ├── voice_button.dart
│   │   ├── image_upload_button.dart
│   │   └── severity_indicator.dart
│   └── utils/
│       ├── constants.dart
│       └── helpers.dart
├── android/
├── ios/
└── pubspec.yaml
```

### Step 4: Configure Firebase in Flutter

**Android (android/app/build.gradle):**
```gradle
android {
    compileSdkVersion 33

    defaultConfig {
        minSdkVersion 21
        targetSdkVersion 33
    }
}

dependencies {
    implementation platform('com.google.firebase:firebase-bom:32.7.0')
}
```

**Add google-services.json:**
1. Download from Firebase Console → Project Settings → Your apps → Android
2. Place in `android/app/google-services.json`

**iOS (ios/Runner/Info.plist):**
Add permissions:
```xml
<key>NSCameraUsageDescription</key>
<string>Need camera access to scan dashboard warning lights</string>
<key>NSMicrophoneUsageDescription</key>
<string>Need microphone access for voice input</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Need photo library access to upload images</string>
<key>NSSpeechRecognitionUsageDescription</key>
<string>Need speech recognition for voice commands</string>
```

### Step 5: Main Flutter Files

**lib/main.dart:**
```dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'screens/home_screen.dart';
import 'providers/chat_provider.dart';
import 'providers/language_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
      ],
      child: VehicleChatbotApp(),
    ),
  );
}

class VehicleChatbotApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vehicle Troubleshooting Assistant',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
      ),
      home: HomeScreen(),
    );
  }
}
```

**lib/services/api_service.dart:**
```dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String BASE_URL = 'http://YOUR_SERVER_IP:8000/api';

  Future<Map<String, dynamic>> startConversation(String userId, String language) async {
    final response = await http.post(
      Uri.parse('$BASE_URL/conversation/start'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_id': userId,
        'language': language,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to start conversation');
    }
  }

  Future<Map<String, dynamic>> sendMessage(
    String sessionId,
    String message, {
    String? imageBase64,
  }) async {
    final response = await http.post(
      Uri.parse('$BASE_URL/conversation/message'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'session_id': sessionId,
        'message': message,
        'image_base64': imageBase64,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to send message');
    }
  }

  Future<Map<String, dynamic>> endConversation(String sessionId) async {
    final response = await http.post(
      Uri.parse('$BASE_URL/conversation/end'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'session_id': sessionId}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to end conversation');
    }
  }
}
```

**lib/screens/chat_screen.dart:**
```dart
import 'package:flutter/material.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import '../widgets/voice_button.dart';
import '../widgets/image_upload_button.dart';

class ChatScreen extends StatefulWidget {
  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  @override
  void initState() {
    super.initState();
    // Initialize conversation
    Provider.of<ChatProvider>(context, listen: false).startConversation();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Vehicle Assistant'),
        actions: [
          IconButton(
            icon: Icon(Icons.history),
            onPressed: () {
              // Navigate to history
            },
          ),
        ],
      ),
      body: Consumer<ChatProvider>(
        builder: (context, chatProvider, child) {
          return Chat(
            messages: chatProvider.messages,
            onSendPressed: (message) {
              chatProvider.sendMessage(message.text);
            },
            user: chatProvider.user,
            customBottomWidget: _buildCustomInput(chatProvider),
          );
        },
      ),
    );
  }

  Widget _buildCustomInput(ChatProvider chatProvider) {
    return Container(
      padding: EdgeInsets.all(8),
      child: Row(
        children: [
          VoiceButton(
            onVoiceInput: (text) {
              chatProvider.sendMessage(text);
            },
          ),
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Describe your vehicle issue...',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (text) {
                if (text.isNotEmpty) {
                  chatProvider.sendMessage(text);
                }
              },
            ),
          ),
          ImageUploadButton(
            onImageSelected: (imageBytes) {
              chatProvider.sendImageMessage(imageBytes);
            },
          ),
        ],
      ),
    );
  }
}
```

### Step 6: Run Flutter App

```bash
# Check devices
flutter devices

# Run on Android
flutter run -d android

# Run on iOS
flutter run -d ios

# Build APK
flutter build apk --release
```

---

## 5. Deployment

### Backend Deployment Options

#### Option 1: Google Cloud Run (Recommended)

```bash
# Install Google Cloud SDK
gcloud init

# Build and deploy
gcloud builds submit --tag gcr.io/PROJECT_ID/vehicle-chatbot
gcloud run deploy vehicle-chatbot \
  --image gcr.io/PROJECT_ID/vehicle-chatbot \
  --platform managed \
  --region asia-south1 \
  --allow-unauthenticated \
  --set-env-vars GEMINI_API_KEY=your_key
```

#### Option 2: AWS EC2

```bash
# SSH to EC2 instance
ssh -i your-key.pem ubuntu@your-ec2-ip

# Install dependencies
sudo apt update
sudo apt install python3.11 python3-pip

# Clone repo and setup
git clone your-repo
cd vehicle-chatbot
pip3 install -r requirements.txt

# Run with supervisor or systemd
uvicorn api_server:app --host 0.0.0.0 --port 8000
```

#### Option 3: Heroku

```bash
# Create Procfile
echo "web: uvicorn api_server:app --host 0.0.0.0 --port \$PORT" > Procfile

# Deploy
heroku create vehicle-chatbot-sl
git push heroku main
heroku config:set GEMINI_API_KEY=your_key
```

### Flutter App Deployment

#### Android (Google Play Store)

```bash
# Build release APK
flutter build apk --release

# Or build App Bundle
flutter build appbundle --release

# Sign with your keystore
jarsigner -verbose -sigalg SHA1withRSA -digestalg SHA1 \
  -keystore your-keystore.jks \
  app-release.apk your-key-alias
```

#### iOS (App Store)

```bash
# Build iOS app
flutter build ios --release

# Open in Xcode for signing and submission
open ios/Runner.xcworkspace
```

---

## 6. Testing

### Backend API Testing

```bash
# Test health endpoint
curl http://localhost:8000/

# Test start conversation
curl -X POST http://localhost:8000/api/conversation/start \
  -H "Content-Type: application/json" \
  -d '{"user_id": "test123", "language": "english"}'

# Test send message
curl -X POST http://localhost:8000/api/conversation/message \
  -H "Content-Type: application/json" \
  -d '{
    "session_id": "SESSION_ID",
    "message": "My car won'\''t start"
  }'
```

### Flutter App Testing

```bash
# Run tests
flutter test

# Integration tests
flutter drive --target=test_driver/app.dart
```

---

## 7. Project Structure

```
e:\research\gamage new\data\
├── Python Backend:
│   ├── gemini_api.py                      # Gemini API integration
│   ├── knowledge_base.py                  # Semantic search engine
│   ├── fallback_system.py                 # Diagnostic questions
│   ├── warning_light_detector.py          # Image recognition
│   ├── chatbot_core.py                    # Main orchestrator
│   ├── text_preprocessor.py               # NLP preprocessing
│   ├── api_server.py                      # FastAPI server
│   │
│   ├── Data Files:
│   ├── sri_lanka_vehicle_dataset_5models_englishonly.xlsx
│   ├── fallback_dataset.xlsx
│   ├── warning_light_data.json
│   ├── requirements.txt
│   ├── firebase_config.json
│   ├── firebase-credentials.json          # (You need to create)
│   │
│   └── Notebooks:
│       └── nlp_preprocessing.ipynb
│
└── Flutter App:
    └── vehicle_chatbot_app/
        ├── lib/
        ├── android/
        ├── ios/
        └── pubspec.yaml
```

---

## 🚀 Quick Start Summary

```bash
# 1. Backend Setup
cd "e:\research\gamage new\data"
pip install -r requirements.txt
pip install fastapi uvicorn firebase-admin python-multipart

# 2. Set API Key
set GEMINI_API_KEY=your_key_here

# 3. Download firebase-credentials.json from Firebase Console

# 4. Run Backend
python api_server.py

# 5. Create Flutter App
flutter create vehicle_chatbot_app
cd vehicle_chatbot_app

# 6. Add dependencies to pubspec.yaml

# 7. Configure Firebase

# 8. Run Flutter App
flutter run
```

---

## 📱 App Features Checklist

- ✅ Text chat with vehicle assistant
- ✅ Voice input (Sinhala & English)
- ✅ Dashboard warning light scanning
- ✅ Severity indicators (🟢🟡🟠🔴)
- ✅ Conversation history
- ✅ Offline mode (cached responses)
- ✅ Push notifications
- ✅ User feedback system
- ✅ Multi-language support

---

## 📞 Support

For issues or questions:
- Check API documentation: `http://localhost:8000/docs`
- Review Firebase Console logs
- Check Flutter debug logs: `flutter logs`

---

**Version:** 1.0.0
**Last Updated:** December 2025
**Supported Vehicles:** Toyota Aqua, Prius, Corolla, Vitz | Suzuki Alto
