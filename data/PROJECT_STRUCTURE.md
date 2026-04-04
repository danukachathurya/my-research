# Vehicle Troubleshooting Chatbot - Project Structure

## 📁 Folder Organization

```
vehicle-chatbot/
│
├── src/                          # Source code
│   ├── api/                      # API layer
│   │   ├── __init__.py
│   │   ├── api_server.py         # FastAPI REST API server
│   │   └── gemini_api.py         # Gemini API wrapper
│   │
│   ├── core/                     # Core chatbot logic
│   │   ├── __init__.py
│   │   ├── chatbot_core.py       # Main orchestrator
│   │   ├── knowledge_base.py     # Semantic search engine
│   │   ├── fallback_system.py    # Diagnostic questions
│   │   └── warning_light_detector.py  # Image recognition
│   │
│   └── utils/                    # Utilities
│       ├── __init__.py
│       └── text_preprocessor.py  # NLP preprocessing
│
├── data/                         # Data files
│   ├── sri_lanka_vehicle_dataset_5models_englishonly.xlsx
│   ├── fallback_dataset.xlsx
│   └── warning_light_data.json
│
├── config/                       # Configuration files
│   ├── firebase-credentials.json  # Firebase credentials (if using)
│   └── firebase_config.json       # Firebase structure definition
│
├── tests/                        # Test scripts
│   ├── test_api.py               # Test Gemini API
│   ├── test_firebase.py          # Test Firebase connection
│   └── list_models.py            # List available models
│
├── scripts/                      # Utility scripts
│   ├── start_server.bat          # Start with Firebase
│   └── start_server_simple.bat   # Start without Firebase
│
├── docs/                         # Documentation
│   ├── START_HERE.md
│   ├── NO_DATABASE_MODE.md
│   ├── FIREBASE_SETUP_GUIDE.md
│   ├── POSTMAN_TESTING_GUIDE.md
│   ├── QUICK_START.md
│   ├── YOUR_API_SETUP.md
│   └── ... (other docs)
│
├── postman/                      # API testing
│   └── Vehicle_Chatbot_API.postman_collection.json
│
├── run_server.bat                # Main server starter (new structure)
└── requirements.txt              # Python dependencies
```

---

## 🎯 File Purposes

### Source Code (`src/`)

#### API Layer (`src/api/`)
- **`api_server.py`**: FastAPI REST API server with all endpoints
- **`gemini_api.py`**: Wrapper for Google Gemini API interactions

#### Core Logic (`src/core/`)
- **`chatbot_core.py`**: Main chatbot orchestrator, routes messages
- **`knowledge_base.py`**: TF-IDF semantic search for 250+ vehicle issues
- **`fallback_system.py`**: Asks diagnostic questions when issue unknown
- **`warning_light_detector.py`**: Gemini Vision API for dashboard images

#### Utilities (`src/utils/`)
- **`text_preprocessor.py`**: NLP preprocessing for English/Sinhala

---

### Data Files (`data/`)
- **`sri_lanka_vehicle_dataset_5models_englishonly.xlsx`**: 250+ known vehicle issues with solutions
- **`fallback_dataset.xlsx`**: 250 fallback scenarios for diagnostic questions
- **`warning_light_data.json`**: 10 warning lights with severity levels and troubleshooting steps

---

### Configuration (`config/`)
- **`firebase-credentials.json`**: Firebase service account credentials (optional)
- **`firebase_config.json`**: Database structure definition

---

### Tests (`tests/`)
- **`test_api.py`**: Test Gemini API connection
- **`test_firebase.py`**: Test Firebase/Firestore (if using database)
- **`list_models.py`**: List available Gemini models

---

### Scripts (`scripts/`)
- **`start_server.bat`**: Start server WITH Firebase enabled
- **`start_server_simple.bat`**: Start server WITHOUT Firebase (testing)

---

### Documentation (`docs/`)
Complete guides for setup, testing, and deployment.

---

### Postman (`postman/`)
API testing collection with 13 pre-configured endpoints.

---

## 🚀 How to Run

### Quick Start (No Firebase)
```cmd
run_server.bat
```
Then open: http://localhost:8000/docs

### With Firebase
1. Setup Firebase (see `docs/FIREBASE_SETUP_GUIDE.md`)
2. Set `ENABLE_FIREBASE=1` in `run_server.bat`
3. Run `run_server.bat`

---

## 📦 Dependencies

Install all required packages:
```cmd
pip install -r requirements.txt
```

Main dependencies:
- `fastapi` - REST API framework
- `uvicorn` - ASGI server
- `google-generativeai` - Gemini API
- `pandas` - Data handling
- `scikit-learn` - TF-IDF search
- `pillow` - Image processing
- `firebase-admin` - Firebase (optional)

---

## 🔧 Import Structure

All modules use absolute imports from project root:

```python
from src.api.gemini_api import GeminiAPI
from src.core.chatbot_core import VehicleChatbot
from src.utils.text_preprocessor import TextPreprocessor
```

The project root is automatically added to `sys.path` in each module.

---

## 📝 Key Features

### ✅ Works WITHOUT Firebase:
- AI chatbot responses (Gemini API)
- Knowledge base search (250+ issues)
- Fallback diagnostic questions
- Warning light detection
- Text translation

### 🔐 Requires Firebase (Optional):
- Save conversation history
- Store uploaded images
- User analytics

---

## 🎓 Getting Started

1. **Read First**: [`docs/START_HERE.md`](docs/START_HERE.md)
2. **Quick Test**: Run `run_server.bat`
3. **Test API**: Import [`postman/Vehicle_Chatbot_API.postman_collection.json`](postman/Vehicle_Chatbot_API.postman_collection.json)
4. **Read Guides**: Check `docs/` folder for detailed guides

---

## 🌟 Next Steps

- **Test Chatbot**: Use Postman or browser docs at http://localhost:8000/docs
- **Add Firebase**: Follow `docs/FIREBASE_SETUP_GUIDE.md`
- **Build Flutter App**: See `docs/COMPLETE_SETUP_GUIDE.md`
- **Deploy Production**: Use Google Cloud Run or AWS

---

## 📞 Support

- **Documentation**: See `docs/` folder
- **API Docs**: http://localhost:8000/docs (when server running)
- **Postman Testing**: Import collection from `postman/` folder

---

**Organized and ready to use! 🚀**
