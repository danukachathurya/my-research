# 🚀 Quick Start Guide - Vehicle Chatbot

## ⚡ 5-Minute Setup

### Prerequisites
```bash
# Check Python version (need 3.11+)
python --version

# Check if pip is installed
pip --version
```

### Step 1: Install Dependencies (2 minutes)

```bash
cd "e:\research\gamage new\data"
pip install -r requirements.txt
```

### Step 2: Get Gemini API Key (1 minute)

1. Go to: https://makersuite.google.com/app/apikey
2. Click "Create API Key"
3. Copy the key

### Step 3: Set Environment Variable (30 seconds)

**Windows:**
```cmd
set GEMINI_API_KEY=YOUR_API_KEY_HERE
```

**Linux/Mac:**
```bash
export GEMINI_API_KEY=YOUR_API_KEY_HERE
```

### Step 4: Test Individual Components (1 minute)

```bash
# Test Gemini API
python gemini_api.py

# Test Knowledge Base
python knowledge_base.py

# Test Chatbot Core
python chatbot_core.py
```

### Step 5: Run Backend Server (30 seconds)

```bash
python api_server.py
```

✅ **Server running at:** http://localhost:8000

✅ **API Docs:** http://localhost:8000/docs

---

## 🧪 Testing the API

### Test 1: Health Check

```bash
curl http://localhost:8000/
```

**Expected Response:**
```json
{
  "status": "online",
  "service": "Vehicle Troubleshooting Chatbot API",
  "version": "1.0.0",
  "chatbot": "ready"
}
```

### Test 2: Start Conversation

```bash
curl -X POST http://localhost:8000/api/conversation/start \
  -H "Content-Type: application/json" \
  -d "{\"user_id\": \"test123\", \"language\": \"english\"}"
```

**Expected Response:**
```json
{
  "success": true,
  "session_id": "abc-123-xyz",
  "message": "Hello! I'm your vehicle troubleshooting assistant...",
  "language": "english"
}
```

### Test 3: Send Message

```bash
curl -X POST http://localhost:8000/api/conversation/message \
  -H "Content-Type: application/json" \
  -d "{\"session_id\": \"SESSION_ID_FROM_STEP2\", \"message\": \"My Toyota Aqua won't start\"}"
```

**Expected Response:**
```json
{
  "success": true,
  "status": "success",
  "source": "knowledge_base",
  "confidence": 0.89,
  "message": "I found a match in my database..."
}
```

---

## 🔍 Testing Individual Modules

### Test Gemini API

```python
from gemini_api import GeminiAPI

api = GeminiAPI(api_key='YOUR_KEY')

# Test text generation
response = api.generate_response("My car won't start")
print(response)

# Test intent classification
intent = api.classify_intent("My Aqua has engine problem")
print(intent)
```

### Test Knowledge Base

```python
from knowledge_base import KnowledgeBase

kb = KnowledgeBase(
    'sri_lanka_vehicle_dataset_5models_englishonly.xlsx',
    'fallback_dataset.xlsx'
)

# Search for issue
results = kb.search_issue("car won't start", vehicle_model="Aqua", top_n=3)
print(f"Found {len(results)} results")
print(f"Best match confidence: {results[0]['confidence']}")
```

### Test Fallback System

```python
from fallback_system import FallbackSystem
from gemini_api import GeminiAPI

api = GeminiAPI(api_key='YOUR_KEY')
fallback = FallbackSystem(api, language='english')

# Start diagnostic flow
question = fallback.start_diagnostic_flow()
print(question['question_text'])
print(question['options'])

# Simulate answers
fallback.process_answer("Toyota Aqua")
fallback.process_answer("When starting the car")
# ... continue with more answers

# Generate advice
result = fallback.generate_advice()
print(result['advice'])
```

### Test Warning Light Detector

```python
from warning_light_detector import WarningLightDetector
from gemini_api import GeminiAPI

api = GeminiAPI(api_key='YOUR_KEY')
detector = WarningLightDetector(api)

# Simulate detection
simulated_light = {
    "name": "Check Engine Light",
    "color": "yellow",
    "symbol": "engine outline"
}

matched = detector._match_warning_light(simulated_light)
print(f"Matched: {matched['name_en']}")

# Get troubleshooting info
info = detector.get_troubleshooting_info(
    matched['id'],
    'blinking',
    'english'
)
print(info['formatted_response'])
```

---

## 📱 Testing with Flutter

### Create Flutter Project

```bash
flutter create vehicle_chatbot_app
cd vehicle_chatbot_app
```

### Update pubspec.yaml

```yaml
dependencies:
  flutter:
    sdk: flutter
  http: ^1.1.2
  firebase_core: ^2.24.2
  cloud_firestore: ^4.13.6
  firebase_storage: ^11.5.6
```

### Test API Connection

```dart
import 'package:http/http.dart' as http;
import 'dart:convert';

Future<void> testAPI() async {
  final response = await http.post(
    Uri.parse('http://YOUR_IP:8000/api/conversation/start'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'user_id': 'test123',
      'language': 'english',
    }),
  );

  if (response.statusCode == 200) {
    print('Success: ${response.body}');
  } else {
    print('Error: ${response.statusCode}');
  }
}
```

---

## 🐛 Troubleshooting

### Issue: "Module not found"

**Solution:**
```bash
pip install --upgrade -r requirements.txt
```

### Issue: "GEMINI_API_KEY not found"

**Solution:**
```bash
# Verify environment variable is set
echo %GEMINI_API_KEY%  # Windows
echo $GEMINI_API_KEY   # Linux/Mac

# If not set, set it again
set GEMINI_API_KEY=your_key  # Windows
export GEMINI_API_KEY=your_key  # Linux/Mac
```

### Issue: "Firebase credentials not found"

**Solution:**
1. Download `firebase-credentials.json` from Firebase Console
2. Place it in the same directory as `api_server.py`

### Issue: "Dataset file not found"

**Solution:**
```bash
# Verify files exist
dir *.xlsx  # Windows
ls *.xlsx   # Linux/Mac

# Should see:
# - sri_lanka_vehicle_dataset_5models_englishonly.xlsx
# - fallback_dataset.xlsx
```

### Issue: "Port 8000 already in use"

**Solution:**
```bash
# Find and kill process using port 8000
netstat -ano | findstr :8000  # Windows
lsof -ti:8000 | xargs kill -9  # Linux/Mac

# Or run on different port
python api_server.py --port 8001
```

---

## 📊 Test Data Examples

### Good Queries (Should match Main Dataset)

```
1. "My Toyota Aqua won't start"
2. "Brake pedal feels soft in my Prius"
3. "Engine overheating in Corolla"
4. "Battery warning light in Alto"
5. "Hybrid system error in Aqua"
```

### Queries for Fallback System

```
1. "Strange noise from my car"
2. "My vehicle smells weird"
3. "Something is wrong but I don't know what"
4. "Car is acting unusual"
```

### Warning Light Test

Upload images of dashboard with these lights:
- Check Engine Light (yellow/amber)
- Battery Light (red)
- Oil Pressure Light (red)
- Brake Warning (red)
- ABS Light (yellow)

---

## ✅ Verification Checklist

Before deploying, verify:

- [ ] All Python modules install without errors
- [ ] Gemini API key is valid and set
- [ ] Backend server starts successfully
- [ ] API health endpoint returns "online"
- [ ] Start conversation endpoint works
- [ ] Send message endpoint works
- [ ] Knowledge base searches return results
- [ ] Fallback system activates for unknown queries
- [ ] Warning light database loads
- [ ] Firebase credentials are configured (if using Firebase)

---

## 🎯 Performance Benchmarks

Expected response times on average hardware:

| Operation | Time | Notes |
|-----------|------|-------|
| Start conversation | < 1s | Initial session creation |
| Text query (matched) | < 2s | Knowledge base search |
| Text query (fallback) | < 3s | Gemini API call |
| Image analysis | < 5s | Gemini Vision API |
| Intent classification | < 1s | Gemini API |

---

## 📝 Common Commands

### Backend Development

```bash
# Install dependencies
pip install -r requirements.txt

# Run server
python api_server.py

# Run server with auto-reload (development)
uvicorn api_server:app --reload --host 0.0.0.0 --port 8000

# Test individual module
python -m pytest tests/  # If you have tests

# Check API endpoints
curl http://localhost:8000/docs
```

### Flutter Development

```bash
# Create project
flutter create vehicle_chatbot_app

# Get dependencies
flutter pub get

# Run on device
flutter run

# Build APK
flutter build apk --release

# Build iOS
flutter build ios --release
```

### Firebase Commands

```bash
# Login to Firebase
firebase login

# Initialize project
firebase init

# Deploy functions
firebase deploy --only functions

# Check Firestore rules
firebase firestore:rules
```

---

## 🔗 Useful URLs

- **Backend API:** http://localhost:8000
- **API Documentation:** http://localhost:8000/docs
- **Gemini API Console:** https://makersuite.google.com
- **Firebase Console:** https://console.firebase.google.com
- **Flutter Docs:** https://flutter.dev/docs

---

## 💬 Example Conversation Flow

```
User: Hi

Bot: Hello! I'm your vehicle troubleshooting assistant. I can help you
     diagnose issues with Toyota Aqua, Prius, Corolla, Vitz, and Suzuki Alto.
     How can I help you today?

User: My Aqua won't start

Bot: I found a match in my database. This sounds like a battery issue.

     🔍 QUICK CHECKS:
     1. Check battery terminals for corrosion
     2. Test battery voltage (should be 12.4V+)
     3. Try jump start

     🔧 DIAGNOSTIC STEPS:
     [Full diagnostic steps...]

User: The terminals look corroded

Bot: Corroded battery terminals are a common cause of starting problems.

     ✅ RECOMMENDED ACTIONS:
     1. Clean terminals with wire brush
     2. Apply battery terminal protector
     3. If problem persists, have battery tested

     Would you like me to help with anything else?

User: No, thank you!

Bot: You're welcome! Stay safe on the roads! 🚗
```

---

## 🎓 Next Steps

After successful testing:

1. **Review Documentation:**
   - Read `COMPLETE_SETUP_GUIDE.md`
   - Review `PROJECT_SUMMARY.md`

2. **Setup Firebase:**
   - Create Firebase project
   - Configure Firestore
   - Enable Storage

3. **Build Flutter App:**
   - Follow Flutter setup guide
   - Configure Firebase in app
   - Test on device

4. **Deploy:**
   - Deploy backend to cloud
   - Build production app
   - Submit to app stores

---

**Happy Building! 🚀**

If you encounter any issues, refer to the `COMPLETE_SETUP_GUIDE.md` for detailed troubleshooting.
