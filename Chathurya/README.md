# Chathurya — Vehicle Damage Assessment System

AI-powered vehicle damage detection and repair cost estimation for Sri Lankan insurance claims.

---

## Architecture

```
Flutter App  →  POST /assess  →  FastAPI (3_app.py)
                                    ├── ResNet18        — detect damage type (6 classes)
                                    ├── SparePartsLookup — reference prices from CSV
                                    ├── Gemini 2.5 Flash — validate detected damages
                                    ├── Gemini 2.5 Pro   — estimate repair cost
                                    └── Firebase Firestore — store claim
```

**ML Models**
| Model | Purpose | Performance |
|---|---|---|
| ResNet18 (PyTorch) | Multi-label damage detection | 86.71% Hamming accuracy |
| Random Forest (sklearn) | Price estimation (fallback) | R² 0.912, MAE LKR 5,833 |
| Gemini 2.5 Pro | Primary pricing engine | — |
| Gemini 2.5 Flash | Damage validation + vehicle check | — |

**6 damage classes:** Dent · Scratch · Crack · Glass Shatter · Lamp Broken · Tire Flat

---

## Project Structure

```
Chathurya/
├── 3_app.py                          # FastAPI backend (main app)
├── requirements.txt                  # Python dependencies
├── .env                              # Backend env vars (GEMINI_API_KEY)
├── firebase_service_account.json     # Firebase credentials
├── models/
│   ├── damage_model.pth              # ResNet18 weights (43 MB)
│   ├── damage_labels.json            # 6 damage class labels
│   ├── price_model.pkl               # Random Forest model
│   ├── price_scaler.pkl              # Feature scaler
│   └── gemini_price_cache.json       # Cached Gemini responses
├── spare_parts_prices/
│   └── toyota_sri_lanka_spare_parts_prices.csv   # 819 Toyota parts (LKR)
├── vehicle_damage_app/               # Flutter frontend
│   ├── lib/
│   │   ├── main.dart                 # Main app UI
│   │   └── utils/image_processor.dart  # Background isolate processing
│   ├── .env                          # Flutter env vars (API_URL)
│   └── .env.example                  # Env template
├── 1_damage_detection_training.ipynb # ResNet18 training notebook
└── 2_price_estimation_training.ipynb # Random Forest training notebook
```

---

## Setup

### Backend

```bash
# Activate virtual environment
source venv/bin/activate          # macOS/Linux
venv\Scripts\activate             # Windows

# Install dependencies
pip install -r requirements.txt

# Configure environment
# Edit .env and set:
#   GEMINI_API_KEY=your_gemini_api_key

# Start the server
uvicorn 3_app:app --reload
# API available at http://localhost:8000
```

### Flutter Frontend

```bash
cd vehicle_damage_app

# Set environment variables
cp .env.example .env
# Edit .env:
#   API_URL=http://192.168.8.162:8000/assess   ← Android emulator
#   API_URL=http://localhost:8000/assess   ← iOS simulator
#   API_URL=http://192.168.1.X:8000/assess ← Physical device

# Install dependencies
flutter pub get

# Run
flutter run
```

**Platform API URLs**
| Platform | API_URL |
|---|---|
| Android Emulator | `http://192.168.8.162:8000/assess` |
| iOS Simulator | `http://localhost:8000/assess` |
| Physical Device | `http://<your-machine-ip>:8000/assess` |

Find your machine IP: `ifconfig` (macOS/Linux) · `ipconfig` (Windows)

---

## API Endpoints

| Method | Endpoint | Description |
|---|---|---|
| `POST` | `/assess` | Main: image + vehicle info → damage + cost |
| `GET` | `/health` | Health check |
| `GET` | `/models/info` | Loaded model info |
| `GET` | `/insurers` | List available insurers |
| `POST` | `/claims/{id}/notify` | Notify insurer of claim |

**`POST /assess` form fields**
- `image` — vehicle photo (multipart)
- `vehicle_brand` — e.g. `Toyota`
- `vehicle_model` — e.g. `Corolla`
- `vehicle_year` — e.g. `2020`
- `use_ai` — `true` (required)

> Only **Toyota** is currently supported (pricing data limited to Toyota Sri Lanka).

---

## Pricing System

Repair cost is estimated in a 3-tier system:

1. **Gemini 2.5 Pro** (primary) — context-aware estimate grounded by CSV reference prices
2. **Random Forest** (fallback 1) — ML model trained on 819 Sri Lankan spare parts records
3. **Simple formula** (fallback 2) — `num_damages × 15,000 LKR`

**Cost breakdown returned:** Parts & Materials · Labor · Paint & Finishing

**Sri Lankan market reference ranges (LKR)**
| Category | Range |
|---|---|
| Body panels / doors / fenders | 15,000 – 50,000 |
| Bumpers | 8,000 – 25,000 |
| Headlights / taillights | 5,000 – 30,000 |
| Windshield | 15,000 – 40,000 |
| Dent removal (per panel) | 5,000 – 15,000 |
| Single panel repaint | 10,000 – 25,000 |

---

## How It Works (Flow)

1. User uploads vehicle photo + enters brand/model/year
2. Gemini Flash checks the image is actually a vehicle (rejects non-vehicles with a descriptive error)
3. ResNet18 detects damage types (multi-label, threshold 0.5)
4. Damaged parts are mapped (e.g. Dent → Fender LH/RH)
5. Reference prices are looked up from the CSV
6. Gemini Pro estimates cost (parts + labor + paint), with SHA-256 cache to avoid duplicate API calls
7. Gemini Flash validates detected damages
8. Result saved to Firebase Firestore, `claim_id` returned

---

## Performance Notes

- Heavy processing (API calls, image encoding) runs in a **Flutter background isolate** via `compute()` — keeps UI at 60 FPS
- Gemini responses are **deterministically cached** (SHA-256 key: image + vehicle + damages) — same input never calls the API twice
- Multi-image support: damages merged across images, price only added if new damage types found

---

## Troubleshooting

| Problem | Fix |
|---|---|
| `Connection refused` | Ensure backend is running on port 8000; use `192.168.8.162` not `localhost` for Android emulator |
| `Brand not supported` | Only Toyota is supported currently |
| `Could not load .env` | Copy `.env.example` to `.env` and fill in values |
| Image picker not working | Grant camera/storage permissions on device |
| Build errors | Run `flutter clean && flutter pub get && flutter run` |
| Backend import errors | Run `pip install -r requirements.txt` inside `venv` |
