# RoadResQ - Vehicle Damage Detection Flutter App

A simple Flutter mobile application for detecting vehicle damage and getting repair recommendations using AI-powered image analysis.

## Features

- 📸 **Image Capture**: Take photos or select from gallery
- 🤖 **AI Detection**: Real-time damage detection using ResNet-18 model
- 📊 **Detailed Analysis**: Get comprehensive damage descriptions and severity scores
- ⚠️ **Safety Recommendations**: Immediate actions to take based on damage type
- 🔧 **Repair Guidance**: Multiple repair options with time estimates
- 💡 **Prevention Tips**: Learn how to avoid similar damage in the future

## Supported Damage Types

1. **Dent** - Physical indentations in body panels
2. **Scratch** - Surface paint/coating damage
3. **Crack** - Structural breaks in panels
4. **Glass Shatter** - Broken glass/windows
5. **Lamp Broken** - Damaged lights
6. **Tire Flat** - Tire puncture/damage

## Prerequisites

- **Flutter SDK** (3.0.0 or higher)
- **Dart SDK** (included with Flutter)
- **iOS** (for iOS development):
  - macOS
  - Xcode 14.0 or higher
  - CocoaPods
- **Android** (for Android development):
  - Android Studio
  - Android SDK (API 21 or higher)

## Setup Instructions

### 1. Install Flutter

If you don't have Flutter installed:

```bash
# macOS (using Homebrew)
brew install flutter

# Or download from: https://flutter.dev/docs/get-started/install
```

Verify installation:

```bash
flutter doctor
```

### 2. Clone/Navigate to Project

```bash
cd "/Users/kusalanithennakoon/Documents/research projects/gallage/flutter_app"
```

### 3. Install Dependencies

```bash
flutter pub get
```

### 4. Start the Backend API Server

The app needs the FastAPI backend running. In a separate terminal:

```bash
cd "/Users/kusalanithennakoon/Documents/research projects/gallage"
python main.py
```

The API should be running on `http://localhost:8000`

### 5. Configure API Endpoint

**Important**: Update the API endpoint based on your testing device:

Edit `lib/services/damage_detection_service.dart`:

```dart
// For iOS Simulator
static const String baseUrl = 'http://localhost:8000';

// For Android Emulator
static const String baseUrl = 'http://192.168.8.162:8000';

// For Physical Device (replace with your computer's IP)
static const String baseUrl = 'http://192.168.1.XXX:8000';
```

To find your computer's IP address:

```bash
# macOS/Linux
ifconfig | grep "inet "

# Windows
ipconfig
```

### 6. Run the App

#### For iOS Simulator:

```bash
flutter run -d "iPhone 15 Pro"
```

Or open iOS Simulator first, then:

```bash
flutter run
```

#### For Android Emulator:

Start an Android emulator from Android Studio, then:

```bash
flutter run
```

#### For Physical Device:

Connect your device via USB, enable developer mode, then:

```bash
flutter devices  # List available devices
flutter run -d <device-id>
```

## Project Structure

```
flutter_app/
├── lib/
│   ├── main.dart                          # App entry point
│   ├── models/
│   │   └── damage_detection_result.dart   # Data models
│   ├── screens/
│   │   ├── home_screen.dart               # Home screen with image picker
│   │   └── result_screen.dart             # Results display screen
│   └── services/
│       └── damage_detection_service.dart  # API integration
├── android/                               # Android-specific files
├── ios/                                   # iOS-specific files
├── pubspec.yaml                           # Dependencies
└── README.md                              # This file
```

## Usage Guide

### 1. Launch the App

- Make sure the backend API is running
- Launch the app on your device/simulator

### 2. Check Server Connection

- Look for the green/red indicator in the top-right corner
- Green = Connected to API server
- Red = Not connected (check API is running and endpoint is correct)

### 3. Select or Capture Image

- Tap "Select Image" button
- Choose "Camera" to take a new photo
- Choose "Gallery" to select existing photo

### 4. Analyze Damage

- Once image is selected, tap "Analyze Damage"
- Wait for AI processing (usually 2-5 seconds)

### 5. View Results

The results screen shows:
- **Damage Type**: Primary detected damage
- **Confidence Score**: Detection accuracy
- **Severity Level**: 0-5 scale
- **Urgency**: How quickly repair is needed
- **Description**: What the damage is
- **What Happened**: Explanation of cause
- **Immediate Actions**: Steps to take now
- **Repair Options**: Available fix methods
- **Estimated Time**: Repair duration
- **Prevention Tips**: Avoid future damage

## Troubleshooting

### Server Connection Failed

**Problem**: Red indicator showing, cannot connect to API

**Solutions**:
1. Verify API server is running:
   ```bash
   curl http://localhost:8000/
   ```

2. Check the `baseUrl` in `damage_detection_service.dart` matches your setup

3. For physical devices, ensure phone and computer are on same WiFi network

4. For Android, try using `192.168.8.162` instead of `localhost`

5. Check firewall isn't blocking port 8000

### Camera/Gallery Not Working

**Problem**: Cannot access camera or photos

**Solutions**:

**iOS**:
- Check permissions in `ios/Runner/Info.plist`
- Grant permissions in iOS Settings > RoadResQ

**Android**:
- Check permissions in `android/app/src/main/AndroidManifest.xml`
- Grant permissions when app requests them

### Build Errors

**Problem**: Flutter build fails

**Solutions**:

```bash
# Clean build files
flutter clean

# Get dependencies again
flutter pub get

# Run doctor to check setup
flutter doctor -v

# For iOS specific issues
cd ios && pod install && cd ..
```

### Image Upload Fails

**Problem**: Image selected but analysis fails

**Solutions**:
1. Check image file size (< 10MB recommended)
2. Verify API server logs for errors
3. Ensure image is in supported format (JPG/PNG)
4. Check network connectivity

## Development

### Adding New Features

The app follows a simple architecture:

1. **Models** (`lib/models/`) - Data structures
2. **Services** (`lib/services/`) - API communication
3. **Screens** (`lib/screens/`) - UI components

### Testing

```bash
# Run unit tests
flutter test

# Run integration tests
flutter drive --target=test_driver/app.dart
```

### Building for Production

#### Android APK:

```bash
flutter build apk --release
```

Output: `build/app/outputs/flutter-apk/app-release.apk`

#### iOS IPA:

```bash
flutter build ios --release
```

Then archive in Xcode for App Store submission.

## API Endpoints Used

- `GET /` - Health check
- `POST /detect-damage` - Main damage detection endpoint
  - Input: Image file (multipart/form-data)
  - Output: DamageDetectionResult JSON

## Dependencies

Key packages used:

- `http: ^1.1.0` - HTTP requests
- `image_picker: ^1.0.4` - Camera/gallery access
- `provider: ^6.0.5` - State management
- `flutter_spinkit: ^5.2.0` - Loading indicators
- `geolocator: ^10.1.0` - Location services
- `permission_handler: ^11.0.1` - Permission management

## Performance

- **Image Upload**: ~500ms - 2s (depends on image size and network)
- **AI Detection**: ~2-5s (depends on server hardware)
- **Total Process**: ~3-7s from upload to results

## Future Enhancements

Potential features to add:

- [ ] Garage recommendation integration
- [ ] Offline mode with local model
- [ ] Multiple image support
- [ ] Damage history tracking
- [ ] Cost estimation (if needed)
- [ ] Share results via social media
- [ ] Multi-language support

## Support

For issues or questions:
- Check the troubleshooting section above
- Review backend API logs: `/Users/kusalanithennakoon/Documents/research projects/gallage/main.py`
- Check Flutter issues: `flutter doctor -v`

## License

Part of the RoadResQ vehicle damage assessment system.

## Version

- **App Version**: 1.0.0
- **Flutter Version**: >=3.0.0
- **Backend API**: v1.0
