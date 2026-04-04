# RoadResQ Flutter App - Quick Start Guide

## 🚀 Get Started in 5 Minutes

### Step 1: Start the Backend API (Terminal 1)

```bash
cd "/Users/kusalanithennakoon/Documents/research projects/gallage"
python main.py
```

You should see:
```
✅ Damage detection model loaded
✅ Gemini AI analyzer initialized
✅ Google Maps service initialized
Server running on http://0.0.0.0:8000
```

### Step 2: Install Flutter Dependencies (Terminal 2)

```bash
cd "/Users/kusalanithennakoon/Documents/research projects/gallage/flutter_app"
flutter pub get
```

### Step 3: Configure API Endpoint

**Before running, update the API URL:**

Edit: `lib/services/damage_detection_service.dart` (line 11)

```dart
// Choose based on your device:

// iOS Simulator (default - no change needed):
static const String baseUrl = 'http://localhost:8000';

// Android Emulator:
static const String baseUrl = 'http://192.168.8.162:8000';

// Physical Device (find your IP with: ifconfig | grep "inet "):
static const String baseUrl = 'http://YOUR_IP_HERE:8000';
// Example: static const String baseUrl = 'http://192.168.1.100:8000';
```

### Step 4: Run the App

```bash
flutter run
```

Flutter will automatically detect available devices. Choose one if prompted.

### Step 5: Test the App

1. ✅ Check green indicator in top-right (server connected)
2. 📸 Tap "Select Image" → Choose "Camera" or "Gallery"
3. 🖼️ Select a vehicle damage photo
4. 🔍 Tap "Analyze Damage"
5. ⏳ Wait 3-5 seconds for analysis
6. 📊 View detailed results!

---

## 📱 Device-Specific Instructions

### iOS Simulator (Easiest)

```bash
# No special configuration needed - just run:
flutter run -d "iPhone 15 Pro"
```

API URL: `http://localhost:8000` (default)

### Android Emulator

1. Start Android emulator from Android Studio
2. Update API URL to: `http://192.168.8.162:8000`
3. Run: `flutter run`

### Physical Device (iPhone/Android)

1. **Find your computer's IP address:**
   ```bash
   ifconfig | grep "inet " | grep -v 127.0.0.1
   ```
   Look for something like: `192.168.1.100`

2. **Update API URL:**
   ```dart
   static const String baseUrl = 'http://192.168.1.100:8000';
   ```

3. **Ensure same WiFi network:**
   - Computer and phone must be on same network
   - Check firewall allows connections on port 8000

4. **Connect device and run:**
   ```bash
   flutter devices
   flutter run -d <device-id>
   ```

---

## 🐛 Common Issues & Fixes

### ❌ Red Indicator (Server Not Connected)

**Fix:**
1. Check API is running: `curl http://localhost:8000/`
2. Verify `baseUrl` in `damage_detection_service.dart`
3. For physical device: use computer's IP, not localhost

### ❌ "Failed to pick image"

**Fix:**
- **iOS**: Check camera permissions in Settings > RoadResQ
- **Android**: Grant permissions when prompted

### ❌ Build Errors

**Fix:**
```bash
flutter clean
flutter pub get
flutter run
```

### ❌ "Connection refused" or "Network error"

**Fix:**
1. Verify API server is running
2. Check you're using correct IP/port
3. For physical device: ensure same WiFi network
4. Check firewall settings

---

## 🎯 Test with Sample Damage

Don't have a damage photo? Test with these:

1. **Search online for**: "car dent", "car scratch", "flat tire"
2. **Download image to phone**
3. **Use "Gallery" option** in app
4. **Analyze!**

---

## 📂 Project Structure (For Reference)

```
flutter_app/
├── lib/
│   ├── main.dart                        # ← App starts here
│   ├── models/
│   │   └── damage_detection_result.dart # Data models
│   ├── screens/
│   │   ├── home_screen.dart             # Image selection
│   │   └── result_screen.dart           # Results display
│   └── services/
│       └── damage_detection_service.dart # ← UPDATE API URL HERE
└── pubspec.yaml
```

---

## 🔍 What Gets Detected?

- **Dent** - Body panel indentations
- **Scratch** - Paint surface damage
- **Crack** - Structural breaks
- **Glass Shatter** - Broken glass/windows
- **Lamp Broken** - Light damage
- **Tire Flat** - Tire issues

---

## 📊 Results Include:

✅ Damage type & confidence score
✅ Severity level (0-5)
✅ What happened (explanation)
✅ Immediate actions to take
✅ Repair options available
✅ Estimated repair time
✅ Urgency level
✅ Prevention tips

---

## 🎨 Screenshots Preview

**Home Screen:**
- Clean interface
- Camera/Gallery options
- Server status indicator
- How it works guide

**Results Screen:**
- Damage image preview
- Confidence & severity badges
- Color-coded urgency banner
- Expandable sections for details
- Additional damages (if any)

---

## ⚡ Performance Tips

- Use good lighting when taking photos
- Frame damage clearly in center
- Use landscape orientation for wide damage
- Avoid blurry photos
- Keep image size reasonable (< 10MB)

---

## 🚀 Next Steps

1. ✅ Test with different damage types
2. ✅ Try camera vs gallery
3. ✅ Check results accuracy
4. ✅ Review repair recommendations
5. 📝 Provide feedback for improvements

---

## 💡 Pro Tips

- **Multiple damages?** The app detects all visible damage types
- **Severity score** is based on number of detected damages
- **Urgency colors**: Red (critical) → Orange (high) → Yellow (medium) → Green (low)
- **Prevention tips** help avoid future damage

---

## 📞 Need Help?

1. Check the full [README.md](README.md) for detailed docs
2. Review backend logs if analysis fails
3. Run `flutter doctor -v` to check Flutter setup
4. Verify API is responding: `curl http://localhost:8000/`

---

## 🎉 You're All Set!

Your Flutter app is ready to detect vehicle damage with AI-powered analysis.

**Happy Testing!** 🚗📸🤖
