# 🚗 Vehicle Troubleshooting Chatbot

> AI-powered chatbot for Sri Lankan vehicle troubleshooting using Google Gemini API

## 🎯 Quick Start

```cmd
run_server.bat
```

Then open: **http://localhost:8000/docs**

---

## ✨ Features

- 🤖 **AI Conversations** - Powered by Google Gemini 2.5 Flash
- 📚 **Knowledge Base** - 250+ documented vehicle issues
- 🔍 **Semantic Search** - TF-IDF + cosine similarity matching
- 💬 **Fallback System** - 7-question diagnostic flow
- 🚨 **Warning Light Detection** - Dashboard image recognition
- 🌐 **Multilingual** - English and Sinhala support
- 🚫 **No Database Required** - Works without Firebase for testing

---

## 🚙 Supported Vehicles

1. Toyota Aqua
2. Toyota Prius
3. Toyota Corolla
4. Toyota Vitz
5. Suzuki Alto

---

## 📁 Project Structure

```
vehicle-chatbot/
├── src/              # Source code
│   ├── api/         # FastAPI + Gemini API
│   ├── core/        # Chatbot logic
│   └── utils/       # Utilities
├── data/            # Datasets
├── config/          # Configuration
├── tests/           # Test scripts
├── docs/            # Documentation
├── postman/         # API testing
└── run_server.bat   # Start server
```

📖 **Full Structure**: [CLEAN_STRUCTURE.md](CLEAN_STRUCTURE.md)

---

## 🛠️ Installation

### Prerequisites
- Python 3.11+
- pip package manager

### Install Dependencies
```cmd
pip install -r requirements.txt
```

### Required Packages
- FastAPI - REST API framework
- Uvicorn - ASGI server
- google-generativeai - Gemini API
- pandas - Data handling
- scikit-learn - Machine learning
- Pillow - Image processing

---

## 🚀 Usage

### 1. Start the Server
```cmd
run_server.bat
```

### 2. Access API Documentation
```
http://localhost:8000/docs
```

### 3. Test with Postman
Import collection from: `postman/Vehicle_Chatbot_API.postman_collection.json`

---

## 🔌 API Endpoints

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/` | GET | Health check |
| `/api/conversation/start` | POST | Start conversation |
| `/api/conversation/message` | POST | Send message |
| `/api/conversation/end` | POST | End conversation |
| `/api/vehicles` | GET | Get vehicles |
| `/api/warning-lights` | GET | Get warning lights |
| `/api/translate` | POST | Translate text |
| `/api/feedback` | POST | Submit feedback |

---

## 📖 Documentation

- **Getting Started**: [docs/START_HERE.md](docs/START_HERE.md)
- **No Database Mode**: [docs/NO_DATABASE_MODE.md](docs/NO_DATABASE_MODE.md)
- **Firebase Setup**: [docs/FIREBASE_SETUP_GUIDE.md](docs/FIREBASE_SETUP_GUIDE.md)
- **API Testing**: [docs/POSTMAN_TESTING_GUIDE.md](docs/POSTMAN_TESTING_GUIDE.md)
- **Project Structure**: [CLEAN_STRUCTURE.md](CLEAN_STRUCTURE.md)

---

## 🧪 Testing

### Test Gemini API
```cmd
python tests/test_api.py
```

### Test with Postman
1. Import `postman/Vehicle_Chatbot_API.postman_collection.json`
2. Set base_url: `http://localhost:8000`
3. Run collection

### Example Request
```bash
POST http://localhost:8000/api/conversation/message
{
  "session_id": "your-session-id",
  "message": "My Toyota Aqua won't start"
}
```

---

## 🔥 Features Breakdown

### ✅ Works WITHOUT Firebase

Perfect for testing and development:

- AI chatbot responses
- Knowledge base search (250+ issues)
- Fallback diagnostic questions
- Warning light detection
- Text translation
- All vehicle models

### 🔐 Optional Firebase Features

Only needed for production:

- Save conversation history
- Store uploaded images
- User analytics
- Cross-device sync

**Setup guide**: [docs/FIREBASE_SETUP_GUIDE.md](docs/FIREBASE_SETUP_GUIDE.md)

---

## 🏗️ Architecture

### Components

1. **API Layer** (`src/api/`)
   - FastAPI REST server
   - Gemini API wrapper

2. **Core Logic** (`src/core/`)
   - Chatbot orchestrator
   - Knowledge base (semantic search)
   - Fallback system (diagnostic questions)
   - Warning light detector (vision AI)

3. **Utilities** (`src/utils/`)
   - Text preprocessing
   - NLP functions

### Data Flow

```
User Message → API Server → Chatbot Core
                                ↓
                    ┌───────────┴───────────┐
                    ↓                       ↓
            Knowledge Base          Warning Light
            (TF-IDF Search)         (Vision AI)
                    ↓                       ↓
            Match Found?                Image?
                ↓       ↓                  ↓
              Yes      No             Gemini Vision
               ↓        ↓                  ↓
          Solution  Fallback           Detected Lights
                    Questions              ↓
                       ↓            Troubleshooting
                  Gemini AI
                       ↓
                   Response → User
```

---

## 🎓 How It Works

### 1. Known Issue Flow
```
User: "My Aqua won't start and makes clicking noise"
  ↓
Knowledge Base searches 250+ issues using TF-IDF
  ↓
Match found with 89% confidence
  ↓
Returns solution from database
```

### 2. Unknown Issue Flow
```
User: "My car has a weird smell"
  ↓
No match in knowledge base (confidence < 65%)
  ↓
Activate fallback system
  ↓
Ask 7 diagnostic questions:
  - What car model?
  - When does it occur?
  - Any warning lights?
  - What sounds?
  - What smells?
  - Visual observations?
  - Recent changes?
  ↓
Generate advice using Gemini AI
```

### 3. Warning Light Flow
```
User uploads dashboard image
  ↓
Gemini Vision API analyzes image
  ↓
Detects warning lights (color, blinking)
  ↓
Matches against 10 known lights
  ↓
Returns:
  - Light name
  - Severity level
  - Troubleshooting steps
```

---

## 💻 Development

### Project Setup
```cmd
# Clone/Download project
cd "e:\research\gamage new\data"

# Install dependencies
pip install -r requirements.txt

# Run server
run_server.bat
```

### Running Tests
```cmd
# Test Gemini API
python tests/test_api.py

# Test Firebase (optional)
python tests/test_firebase.py

# List available models
python tests/list_models.py
```

---

## 🌟 Technology Stack

- **Backend**: Python 3.11+
- **API Framework**: FastAPI
- **Server**: Uvicorn (ASGI)
- **AI Model**: Google Gemini 2.5 Flash
- **NLP**: NLTK, scikit-learn
- **Search**: TF-IDF + cosine similarity
- **Image Processing**: Pillow, Gemini Vision
- **Database** (Optional): Firebase Firestore
- **Storage** (Optional): Firebase Storage

---

## 📱 Frontend Integration

This backend is designed to work with:
- Flutter mobile app
- React web app
- Any HTTP client

### CORS Enabled
Configured for cross-origin requests from mobile/web apps.

---

## 🔧 Configuration

### Environment Variables
```bash
GEMINI_API_KEY=your-api-key-here
ENABLE_FIREBASE=0  # Set to 1 to enable Firebase
```

### API Key Setup
Already configured in `run_server.bat`:
```batch
set GEMINI_API_KEY=AIzaSyAo0pDg4lfNzVolA0LRhEIh4LSwymTJwC8
```

---

## 📊 Dataset

### Main Dataset
- **File**: `data/sri_lanka_vehicle_dataset_5models_englishonly.xlsx`
- **Issues**: 250+ documented problems
- **Columns**: Model, Issue, Symptoms, Solutions

### Fallback Dataset
- **File**: `data/fallback_dataset.xlsx`
- **Scenarios**: 250 fallback cases
- **Purpose**: Training fallback system

### Warning Lights
- **File**: `data/warning_light_data.json`
- **Lights**: 10 common warning lights
- **Data**: Name, severity, troubleshooting steps

---

## 🚀 Deployment

### Local Development
```cmd
run_server.bat
```

### Production Deployment

See [docs/COMPLETE_SETUP_GUIDE.md](docs/COMPLETE_SETUP_GUIDE.md) for:
- Google Cloud Run deployment
- AWS EC2 deployment
- Heroku deployment
- Firebase setup

---

## 📝 License

This project is for educational and research purposes.

---

## 🤝 Contributing

1. Fork the repository
2. Create feature branch
3. Make changes
4. Test thoroughly
5. Submit pull request

---

## 📞 Support

- **Documentation**: Check `docs/` folder
- **API Docs**: http://localhost:8000/docs (when running)
- **Structure Guide**: [CLEAN_STRUCTURE.md](CLEAN_STRUCTURE.md)

---

## ✅ Status

- ✅ Backend API: Ready
- ✅ Gemini Integration: Working
- ✅ Knowledge Base: Loaded (250+ issues)
- ✅ Fallback System: Operational
- ✅ Warning Light Detection: Active
- ✅ Translation: Enabled
- ⚠️ Firebase: Optional (disabled by default)

---

## 🎉 Ready to Use!

Start your chatbot now:
```cmd
run_server.bat
```

Access API documentation:
```
http://localhost:8000/docs
```

**Happy Coding! 🚀**
