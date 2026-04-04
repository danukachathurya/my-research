# Vehicle Troubleshooting Chatbot - Flutter App

A beautiful Flutter mobile application for the Vehicle Troubleshooting Chatbot powered by Google Gemini AI. This app connects to the FastAPI backend to provide AI-powered vehicle diagnostics and troubleshooting.

## Features

- **Vehicle Selection**: Choose from 5 supported Sri Lankan vehicle models
- **AI Chatbot**: Powered by Google Gemini 2.5 Flash
- **Real-time Chat**: Interactive conversation with the chatbot
- **Warning Light Detection**: Upload dashboard images for warning light analysis
- **Knowledge Base**: Access to 250+ documented vehicle issues
- **Feedback System**: Rate and provide feedback on chatbot responses
- **Server Status**: Real-time server connectivity check

## Supported Vehicles

1. Toyota Aqua
2. Toyota Prius
3. Toyota Corolla
4. Toyota Vitz
5. Suzuki Alto

## Prerequisites

- Flutter SDK 3.0.6 or higher
- Dart SDK
- Android Studio / Xcode (for emulators)
- Backend server running (see Backend Setup below)

## Installation

### 1. Install Flutter

If you haven't installed Flutter yet:

```bash
# macOS
brew install flutter

# Or download from https://flutter.dev/docs/get-started/install
```

Verify installation:
```bash
flutter doctor
```

### 2. Install Dependencies

```bash
flutter pub get
```

## Backend Setup

**IMPORTANT**: The Flutter app requires the backend server to be running.

### Start Backend Server

1. Navigate to the parent directory:
```bash
cd ..
```

2. Run the backend server:
```bash
# Windows
run_server.bat

# macOS/Linux
python -m uvicorn src.api.api_server:app --reload --host 0.0.0.0 --port 8000
```

3. Verify server is running at http://localhost:8000

### Configure API Endpoint

The app is configured to connect to `http://localhost:8000` by default.

**For Android Emulator**: Change in [lib/constants/app_constants.dart](lib/constants/app_constants.dart):
```dart
static const String baseUrl = 'http://192.168.8.162:8000';
```

**For Physical Device**: Use your computer's local IP address.

## Running the App

```bash
flutter run
```

Or press F5 in VS Code / Android Studio.

## Project Structure

```
flutter_vehicle_chatbot/
├── lib/
│   ├── constants/      # API endpoints & configuration
│   ├── models/         # Data models
│   ├── services/       # Backend API communication
│   ├── providers/      # State management
│   ├── screens/        # UI screens
│   ├── widgets/        # Reusable widgets
│   └── main.dart       # App entry point
└── pubspec.yaml        # Dependencies
```

## Key Features

### Home Screen
- Server connection status indicator
- Vehicle selection list
- One-tap to start conversation

### Chat Screen
- Real-time messaging interface
- Image upload for warning light detection
- Feedback system
- End conversation option

## Troubleshooting

### Server Connection Issues

1. Make sure backend is running: `run_server.bat`
2. Check API endpoint in [lib/constants/app_constants.dart](lib/constants/app_constants.dart)
3. For Android emulator, use `http://192.168.8.162:8000`
4. For physical device, use your computer's IP address

### Build Issues

```bash
flutter clean
flutter pub get
flutter run
```

## Development

Start backend server first, then run:
```bash
flutter run
```

## License

This project is for educational and research purposes.

---

**Ready to Use!** 🚀
