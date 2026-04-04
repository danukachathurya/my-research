# 🚗 Vehicle Troubleshooting Chatbot - Project Summary

## Executive Summary

A complete AI-powered vehicle troubleshooting chatbot system designed specifically for Sri Lankan drivers. The system helps users diagnose and fix common car issues for popular vehicles (Toyota Aqua, Prius, Corolla, Vitz, and Suzuki Alto) using natural language conversation, image recognition, and voice input in both English and Sinhala.

---

## 🎯 Project Objectives

### ✅ Completed Features

1. **Natural Language Understanding**
   - Bilingual support (English & Sinhala)
   - Intent classification
   - Entity extraction (vehicle model, issue type)

2. **Knowledge Base System**
   - 250+ documented vehicle issues
   - Semantic search using TF-IDF and Gemini embeddings
   - Confidence scoring for match accuracy

3. **Intelligent Fallback System**
   - 7-question diagnostic flow
   - Context-aware general advice generation
   - Urgency assessment (low/medium/high/critical)

4. **Warning Light Recognition**
   - Dashboard image analysis using Gemini Vision API
   - 10+ common warning lights database
   - Blinking/steady status differentiation
   - Severity assessment with safety recommendations

5. **Voice Capabilities**
   - Speech-to-text input (English & Sinhala)
   - Text-to-speech output
   - Automatic language detection

6. **Backend Infrastructure**
   - FastAPI REST API server
   - Firebase Firestore database
   - Firebase Storage for images
   - Real-time conversation management

7. **Flutter Mobile App**
   - Native Android/iOS app
   - Chat interface
   - Image upload
   - Voice input
   - Conversation history

---

## 📁 Deliverables

### Python Backend Modules

| File | Description | Lines of Code |
|------|-------------|---------------|
| `gemini_api.py` | Gemini API integration for text & vision | ~400 |
| `knowledge_base.py` | Semantic search engine | ~450 |
| `fallback_system.py` | Diagnostic question system | ~500 |
| `warning_light_detector.py` | Image recognition for warning lights | ~400 |
| `chatbot_core.py` | Main chatbot orchestrator | ~550 |
| `text_preprocessor.py` | NLP preprocessing utilities | ~350 |
| `api_server.py` | FastAPI REST API server | ~450 |

**Total Backend Code:** ~3,100 lines

### Data Files

| File | Description | Records |
|------|-------------|---------|
| `sri_lanka_vehicle_dataset_5models_englishonly.xlsx` | Main issues database | 250 |
| `fallback_dataset.xlsx` | Fallback scenarios | 250 |
| `warning_light_data.json` | Warning lights database | 10 |

**Total Data Records:** 510+

### Documentation

| File | Description |
|------|-------------|
| `COMPLETE_SETUP_GUIDE.md` | Full setup and deployment guide |
| `README_NLP.md` | NLP preprocessing documentation |
| `chatbot_architecture.md` | System architecture and flow diagrams |
| `PROJECT_SUMMARY.md` | This file |

### Configuration Files

- `requirements.txt` - Python dependencies
- `firebase_config.json` - Firebase structure definition
- `nlp_preprocessing.ipynb` - Data preprocessing notebook

---

## 🏗️ System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     FLUTTER MOBILE APP                          │
│              (Android & iOS - User Interface)                   │
└────────────────────────┬────────────────────────────────────────┘
                         │ HTTP/REST API
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│                    FASTAPI BACKEND SERVER                       │
│  • REST API Endpoints                                           │
│  • Request/Response Handling                                    │
│  • Session Management                                           │
└────────────────────────┬────────────────────────────────────────┘
                         │
           ┌─────────────┼─────────────┐
           ▼             ▼             ▼
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│  CHATBOT     │  │   FIREBASE   │  │ GEMINI API   │
│  CORE        │  │   DATABASE   │  │              │
│              │  │              │  │ • Text Gen   │
│ • Intent     │  │ • Firestore  │  │ • Vision     │
│ • Router     │  │ • Storage    │  │ • Embeddings │
│ • Context    │  │ • Auth       │  │ • Translation│
└──────┬───────┘  └──────────────┘  └──────────────┘
       │
       ├──────────┬──────────────┬────────────────┐
       ▼          ▼              ▼                ▼
┌──────────┐ ┌──────────┐ ┌──────────────┐ ┌──────────────┐
│KNOWLEDGE │ │ FALLBACK │ │  WARNING     │ │    VOICE     │
│  BASE    │ │  SYSTEM  │ │   LIGHT      │ │   HANDLER    │
│          │ │          │ │  DETECTOR    │ │              │
│• TF-IDF  │ │• Q&A Flow│ │ • Vision API │ │ • STT        │
│• Semantic│ │• Context │ │ • Severity   │ │ • TTS        │
│  Search  │ │• Advice  │ │ • Database   │ │ • Lang Det   │
└──────────┘ └──────────┘ └──────────────┘ └──────────────┘
```

---

## 🔄 Conversation Flow Examples

### Scenario 1: Known Issue (Main Dataset)

```
User: "My Aqua won't start and making clicking noise"
  ↓
[Intent Classification] → vehicle_issue
[Entity Extraction] → Vehicle: Aqua, Issue: starting problem
  ↓
[Semantic Search] → Match Found (confidence: 0.89)
  ↓
Bot: "I found a match in my database. This sounds like a battery issue.

🔍 QUICK CHECKS:
1. Check battery terminals for corrosion
2. Test battery voltage
3. Try jump start

🔧 DIAGNOSTIC STEPS:
[Detailed steps from database...]

⚠️ SAFETY NOTE:
Do not open radiator cap when hot."
```

### Scenario 2: Unknown Issue (Fallback System)

```
User: "My Vitz has weird smell from AC"
  ↓
[Semantic Search] → No good match (confidence: 0.42)
  ↓
[Activate Fallback System]
  ↓
Bot: "What is your car model?"
User: "Toyota Vitz"
  ↓
Bot: "When does the smell occur?"
User: "When AC is on"
  ↓
Bot: "What type of smell?"
User: "Musty smell"
  ↓
[Generate Advice with Gemini]
  ↓
Bot: "Based on your answers, this is likely mold in the AC system.

POSSIBLE CAUSES:
• Mold/mildew in evaporator
• Dirty cabin air filter
• Moisture accumulation

QUICK CHECKS:
1. Check cabin air filter
2. Clean AC vents
3. Run AC on max heat to dry system

RECOMMENDATION:
If smell persists, have AC system professionally cleaned."
```

### Scenario 3: Warning Light Detection

```
User: [Uploads dashboard photo]
  ↓
[Gemini Vision API] → "Check Engine Light detected (Yellow)"
  ↓
Bot: "I detected a Check Engine Light. Is it steady or blinking?"
  ↓
User: "Blinking"
  ↓
[Severity Assessment] → HIGH (Red)
  ↓
Bot: "🔴 HIGH SEVERITY WARNING

⚡ Warning Light: Check Engine Light
📊 Status: BLINKING

🚫 SAFE TO DRIVE: NO
⏰ Urgency: Stop immediately

⚠️ WARNING: Severe engine misfire - catalytic converter damage risk

TROUBLESHOOTING STEPS:
1. Pull over safely immediately
2. Turn off engine
3. Do not continue driving
4. Check coolant level (when cool)
5. Check oil level
6. Call for tow truck

📌 RECOMMENDATION:
⚠️ This is a serious issue. Get professional help immediately."
```

---

## 🛠️ Technology Stack

### Backend
- **Language:** Python 3.11+
- **AI/ML:** Google Gemini API (Pro & Vision)
- **NLP:** NLTK, scikit-learn
- **Web Framework:** FastAPI
- **Database:** Firebase Firestore
- **Storage:** Firebase Storage
- **Auth:** Firebase Authentication

### Frontend
- **Framework:** Flutter 3.16+
- **Language:** Dart
- **State Management:** Provider
- **UI Components:** flutter_chat_ui
- **Voice:** speech_to_text, flutter_tts

### Deployment
- **Backend:** Google Cloud Run / AWS EC2 / Heroku
- **App:** Google Play Store, Apple App Store
- **Database:** Firebase (cloud-hosted)

---

## 📊 Database Schema

### Firestore Collections

**1. conversations**
```javascript
{
  session_id: string,
  user_id: string,
  language: string,
  state: string,
  context: {
    vehicle_model: string,
    issue_type: string,
    intent: string
  },
  created_at: timestamp,
  last_updated: timestamp,
  is_active: boolean
}
```

**2. messages** (subcollection)
```javascript
{
  role: "user" | "bot",
  content: string,
  timestamp: timestamp,
  message_type: "text" | "image" | "audio",
  metadata: {...}
}
```

**3. warning_light_scans**
```javascript
{
  user_id: string,
  session_id: string,
  detected_lights: array,
  blinking_status: string,
  severity: {level, color, safe_to_drive},
  timestamp: timestamp
}
```

---

## 🎨 Key Features

### 1. Multilingual Support
- **Languages:** English & Sinhala
- **Auto-detection:** Automatically detects input language
- **Translation:** Gemini API for accurate translation

### 2. Intelligent Routing
```python
if confidence >= 0.65:
    → Use Main Dataset
elif user_uploads_image:
    → Warning Light Detection
else:
    → Fallback Diagnostic System
```

### 3. Severity Assessment
- 🟢 **LOW:** Safe to drive, schedule maintenance
- 🟡 **MEDIUM:** Limit driving, service soon
- 🟠 **HIGH:** Drive only if necessary, immediate service
- 🔴 **CRITICAL:** Do not drive, get immediate help

### 4. Context-Aware Responses
- Maintains conversation history
- Remembers vehicle model and previous answers
- Provides relevant follow-up questions

---

## 📈 Usage Analytics

The system tracks:
- Total conversations
- Successful matches vs fallback activations
- Warning light scans
- User ratings and feedback
- Popular vehicle models
- Common issues

---

## 🚀 Deployment Steps

### Quick Start (5 minutes)

```bash
# 1. Install dependencies
pip install -r requirements.txt

# 2. Set Gemini API key
set GEMINI_API_KEY=your_key_here

# 3. Run backend server
python api_server.py

# 4. Backend runs at http://localhost:8000
```

### Production Deployment (30 minutes)

1. **Setup Firebase Project** (10 min)
2. **Deploy Backend to Cloud** (10 min)
3. **Configure Flutter App** (5 min)
4. **Build and Release** (5 min)

See `COMPLETE_SETUP_GUIDE.md` for detailed instructions.

---

## 📱 Mobile App Features

### Screens
1. **Home Screen** - Welcome and language selection
2. **Chat Screen** - Main conversation interface
3. **Warning Light Scan** - Image upload and analysis
4. **History Screen** - Previous conversations
5. **Settings** - Language, notifications, preferences

### Capabilities
- ✅ Text messaging
- ✅ Voice input (tap to speak)
- ✅ Image upload (camera or gallery)
- ✅ Voice output (text-to-speech)
- ✅ Offline mode (cached responses)
- ✅ Push notifications
- ✅ Conversation history
- ✅ Feedback submission

---

## 🎓 Training Data

### Main Dataset Coverage
- **Vehicle Models:** 5 (Aqua, Prius, Corolla, Alto, Vitz)
- **Issue Categories:**
  - Starting problems
  - Engine issues
  - Brake problems
  - Electrical issues
  - Cooling system
  - Hybrid system (for Aqua/Prius)
  - AC problems
  - Transmission

### Warning Lights Supported
1. Check Engine Light
2. Battery/Charging Warning
3. Oil Pressure Warning
4. Brake Warning Light
5. Engine Temperature Warning
6. ABS Warning Light
7. Hybrid System Warning
8. Tire Pressure Warning (TPMS)
9. Power Steering Warning
10. Airbag Warning Light

---

## 🔒 Security Features

- Firebase Authentication (Anonymous)
- User-specific data access (Firestore rules)
- Image upload restrictions (size, type)
- API rate limiting
- Secure API keys (environment variables)
- HTTPS/TLS encryption

---

## 💡 Future Enhancements

### Phase 2 Features
- [ ] Service center locator (Google Maps integration)
- [ ] Maintenance reminders
- [ ] Parts price estimation
- [ ] Video tutorials for common fixes
- [ ] Community forum
- [ ] Expert mechanic chat (live support)

### Phase 3 Features
- [ ] OBD-II device integration
- [ ] Predictive maintenance using ML
- [ ] AR-guided repairs
- [ ] Multi-vehicle support per user
- [ ] Insurance claim assistance

---

## 📊 Performance Metrics

### Response Times (Target)
- Text query: < 2 seconds
- Voice query: < 4 seconds
- Image analysis: < 5 seconds
- Fallback advice: < 3 seconds

### Accuracy Goals
- Intent classification: 90%+
- Vehicle model detection: 85%+
- Warning light recognition: 95%+
- User satisfaction: 4.5+ stars

---

## 📞 Support & Maintenance

### Monitoring
- Backend API health checks
- Firebase usage monitoring
- Gemini API quota tracking
- Error logging and alerts

### Updates
- Regular database updates with new issues
- Gemini model upgrades
- Security patches
- Feature releases (quarterly)

---

## 👥 Project Team Roles

- **Backend Developer:** Python, FastAPI, Firebase
- **Mobile Developer:** Flutter, Dart
- **AI/ML Engineer:** Gemini API, NLP
- **Data Analyst:** Dataset curation, analytics
- **UI/UX Designer:** Mobile app design
- **DevOps:** Deployment, monitoring

---

## 📄 License

This project is proprietary software developed for vehicle troubleshooting in Sri Lanka.

---

## 🏆 Success Criteria

✅ **Functional Requirements Met:**
- Natural language understanding
- Knowledge base search
- Fallback diagnostic system
- Warning light recognition
- Multilingual support
- Voice input/output
- Mobile app deployment

✅ **Technical Requirements Met:**
- FastAPI backend
- Firebase integration
- Flutter app (Android & iOS)
- Gemini API integration
- Comprehensive documentation

✅ **User Experience:**
- Easy to use interface
- Quick response times
- Accurate diagnoses
- Safety-focused recommendations

---

**Project Status:** ✅ COMPLETED
**Version:** 1.0.0
**Date:** December 2025
**Total Development Time:** ~40 hours
**Total Lines of Code:** ~3,500 (Backend) + ~2,000 (Flutter) = **5,500+ lines**
