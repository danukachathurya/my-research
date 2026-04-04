# Quick Start Guide

Get your Flutter Vehicle Chatbot app running in 3 steps!

## Step 1: Start Backend Server

Open a terminal and navigate to the parent directory:

```bash
cd "/Users/kusalanithennakoon/Documents/research projects/data"
```

Start the server:
```bash
# Windows
run_server.bat

# macOS/Linux
python -m uvicorn src.api.api_server:app --reload --host 0.0.0.0 --port 8000
```

You should see:
```
INFO:     Uvicorn running on http://0.0.0.0:8000
```

## Step 2: Configure for Your Device

### iOS Simulator (Default - No Change Needed)
Already configured to use `http://localhost:8000`

### Android Emulator
Edit [lib/constants/app_constants.dart](lib/constants/app_constants.dart):
```dart
static const String baseUrl = 'http://192.168.8.162:8000';
```

### Physical Device
1. Find your computer's IP address:
   - macOS: `ifconfig | grep "inet " | grep -v 127.0.0.1`
   - Windows: `ipconfig`

2. Edit [lib/constants/app_constants.dart](lib/constants/app_constants.dart):
```dart
static const String baseUrl = 'http://YOUR_IP_ADDRESS:8000';
```

## Step 3: Run the App

```bash
cd flutter_vehicle_chatbot
flutter run
```

That's it! The app should launch and connect to your backend.

## Test It Out

1. The home screen should show "Server Online" (green)
2. Tap any vehicle (e.g., "Toyota Aqua")
3. Start chatting: "My car won't start"
4. Try uploading an image with the camera icon

## Troubleshooting

**"Server Offline" on home screen?**
- Make sure backend is running
- Check the terminal where you ran `run_server.bat`
- Tap the refresh icon on home screen

**Can't connect from physical device?**
- Make sure device and computer are on the same WiFi
- Check firewall settings
- Use your computer's IP address, not localhost

**Build errors?**
```bash
flutter clean
flutter pub get
flutter run
```

## Next Steps

- Read the full [README.md](README.md) for detailed documentation
- Explore the [project structure](README.md#project-structure)
- Check out the [backend API docs](http://localhost:8000/docs)

---

Need help? See [README.md](README.md) for full documentation.
