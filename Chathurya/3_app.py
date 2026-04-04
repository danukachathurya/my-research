"""
Vehicle Damage Assessment API
FastAPI application with damage detection, price estimation, and Gemini AI
Integrated with Firebase for user authentication and assessment history
"""

import os
import io
import re
import csv
import json
import hashlib
import firebase_admin
import torch
import joblib
import numpy as np
import uuid
from pathlib import Path
from datetime import datetime, timedelta
from typing import Optional, List, Dict
from PIL import Image

from fastapi import FastAPI, File, UploadFile, Form, HTTPException, Body
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from dotenv import load_dotenv
from firebase_admin import credentials, firestore
from google.api_core.exceptions import DeadlineExceeded as FirestoreDeadlineExceeded
from google.api_core.exceptions import ServiceUnavailable as FirestoreServiceUnavailable

import torch.nn as nn
from torchvision import transforms, models

# Authentication removed - running without Firebase

# Gemini AI (optional)
try:
    import google.generativeai as genai
    GEMINI_AVAILABLE = True
except ImportError:
    GEMINI_AVAILABLE = False
    print("⚠️  Gemini AI not available. Install: pip install google-generativeai")

# ============================================
# CONFIGURATION
# ============================================
load_dotenv()

class Config:
    # Paths
    MODELS_DIR = Path("models")
    DAMAGE_MODEL_PATH = MODELS_DIR / "damage_model.pth"
    DAMAGE_LABELS_PATH = MODELS_DIR / "damage_labels.json"
    PRICE_MODEL_PATH = MODELS_DIR / "price_model.pkl"
    PRICE_SCALER_PATH = MODELS_DIR / "price_scaler.pkl"
    GEMINI_PRICE_CACHE_PATH = MODELS_DIR / "gemini_price_cache.json"
    SPARE_PARTS_CSV_PATH = Path("spare_parts_prices/toyota_sri_lanka_spare_parts_prices.csv")

    # Model settings
    IMG_SIZE = (224, 224)
    DAMAGE_THRESHOLD = 0.5
    
    # Gemini API
    GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
    
    # Device
    DEVICE = torch.device("cuda" if torch.cuda.is_available() else "cpu")

config = Config()

# Spare-parts CSV data was collected ~2022. Sri Lanka has experienced significant currency
# depreciation and import-cost inflation since then. This factor adjusts reference prices
# to approximate current (2026) market rates. Revisit annually.
PARTS_PRICE_INFLATION_FACTOR = 1.45

FIREBASE_CRED_PATH = os.getenv("FIREBASE_CRED_PATH", "firebase_service_account.json")

def get_db():
    if not firebase_admin._apps:
        cred_path = Path(FIREBASE_CRED_PATH)
        if not cred_path.exists():
            raise RuntimeError(
                f"Firebase credential file not found: {cred_path}. "
                "Set FIREBASE_CRED_PATH in .env to a Firebase Admin SDK service-account JSON file."
            )

        try:
            with open(cred_path, "r", encoding="utf-8") as f:
                raw = json.load(f)
        except Exception as e:
            raise RuntimeError(
                f"Failed to read Firebase credential JSON: {cred_path}. Error: {e}"
            ) from e

        if raw.get("type") != "service_account":
            raise RuntimeError(
                "Invalid Firebase credential JSON. Expected a service-account key with "
                "\"type\": \"service_account\". "
                f"Current file: {cred_path}. "
                "This looks like a Flutter config file, not Admin SDK credentials. "
                "Download from Firebase Console -> Project Settings -> Service Accounts -> "
                "\"Generate new private key\", then set FIREBASE_CRED_PATH to that file."
            )

        cred = credentials.Certificate(str(cred_path))
        firebase_admin.initialize_app(cred)
    return firestore.client()

db = get_db()

# ============================================
# HELPERS
# ============================================

def compute_image_hash(image_bytes: bytes) -> str:
    return hashlib.sha256(image_bytes).hexdigest()

# ============================================
# DAMAGE DETECTION MODEL
# ============================================

class DamageDetectionModel(nn.Module):
    def __init__(self, num_classes, pretrained=False):
        super().__init__()
        weights = 'DEFAULT' if pretrained else None
        self.backbone = models.resnet18(weights=weights)
        num_features = self.backbone.fc.in_features
        self.backbone.fc = nn.Sequential(
            nn.Linear(num_features, 256),
            nn.ReLU(),
            nn.Dropout(0.5),
            nn.Linear(256, num_classes)
        )
    
    def forward(self, x):
        return self.backbone(x)

# ============================================
# PART MAPPING
# ============================================

def map_damage_to_part(detected_damages: List[str]) -> str:
    """Map detected damages to vehicle parts"""
    part_mapping = {
        'dent': 'body_panel',
        'scratch': 'body_panel',
        'crack': 'bumper',
        'glass_shatter': 'windshield',
        'glass shatter': 'windshield',
        'lamp_broken': 'headlight',
        'lamp broken': 'headlight',
        'tire_flat': 'tire',
        'tire flat': 'tire',
    }
    
    parts = set()
    for damage in detected_damages:
        damage_lower = damage.lower().replace('_', ' ')
        part = part_mapping.get(damage_lower, 'body_panel')
        parts.add(part)
    
    return list(parts)[0] if parts else 'body_panel'

# ============================================
# SPARE PARTS PRICE LOOKUP
# ============================================

# Maps each damage type to the spare parts likely needed for repair/replacement
DAMAGE_TO_PARTS = {
    'dent': ['Fender (LH)', 'Fender (RH)', 'Front Door (LH)', 'Front Door (RH)',
             'Rear Door (LH)', 'Rear Door (RH)', 'Hood/Bonnet'],
    'scratch': ['Fender (LH)', 'Fender (RH)', 'Front Bumper', 'Front Door (LH)',
                'Front Door (RH)', 'Hood/Bonnet'],
    'crack': ['Front Bumper', 'Front Windshield'],
    'glass shatter': ['Front Windshield'],
    'lamp broken': ['Headlight (LH)', 'Headlight (RH)', 'Tail Light (LH)', 'Tail Light (RH)'],
    'tire flat': ['Alloy Wheel (Single)'],
}


class SparePartsLookup:
    """Loads the spare parts CSV and provides price lookups by brand/model/year."""

    def __init__(self):
        self.data: List[Dict] = []  # raw rows
        self.models: set = set()     # known (brand, model) pairs

    def load(self, csv_path: Path):
        if not csv_path.exists():
            print(f"⚠️  Spare parts CSV not found: {csv_path}")
            return
        with open(csv_path, newline='', encoding='utf-8') as f:
            reader = csv.DictReader(f)
            for row in reader:
                price_str = row.get('Price_LKR (Indicative)', '').strip()
                if not price_str:
                    continue
                try:
                    price = float(price_str)
                except ValueError:
                    continue
                brand = row['Brand'].strip().lower()
                model = row['Model'].strip().lower()
                year = int(row['Year'])
                part = row['Part_Name'].strip()
                self.data.append({
                    'brand': brand, 'model': model, 'year': year,
                    'part': part, 'price': price,
                })
                self.models.add((brand, model))
        print(f"✅ Loaded {len(self.data)} spare parts prices ({len(self.models)} model variants)")

    def is_supported_brand(self, brand: str) -> bool:
        return any(b == brand.strip().lower() for b, _ in self.models)

    def lookup(self, brand: str, model: str, year: int, damages: List[str]) -> List[Dict]:
        """Return relevant parts with real prices for the given vehicle + damages."""
        brand_l = brand.strip().lower()
        model_l = model.strip().lower()

        # Collect part names relevant to the detected damages
        relevant_part_names = set()
        for dmg in damages:
            for part_name in DAMAGE_TO_PARTS.get(dmg.lower(), []):
                relevant_part_names.add(part_name)

        if not relevant_part_names:
            return []

        # Find rows matching brand + model
        candidates = [r for r in self.data
                      if r['brand'] == brand_l and r['model'] == model_l]

        if not candidates:
            # Try brand-only match (any model) as rough reference
            candidates = [r for r in self.data if r['brand'] == brand_l]

        if not candidates:
            return []

        # Pick the closest year for each relevant part
        results = []
        for part_name in relevant_part_names:
            part_rows = [r for r in candidates if r['part'] == part_name]
            if not part_rows:
                continue
            # Closest year
            best = min(part_rows, key=lambda r: abs(r['year'] - year))
            results.append({
                'part': best['part'],
                'price_lkr': best['price'],
                'reference_year': best['year'],
            })

        return results


spare_parts = SparePartsLookup()

# ============================================
# GEMINI AI CLASSES
# ============================================

class DamageValidationAI:
    """Gemini Vision for damage validation"""
    def __init__(self, api_key: str):
        if GEMINI_AVAILABLE and api_key:
            genai.configure(api_key=api_key)
            self.model = genai.GenerativeModel('gemini-2.5-flash')
        else:
            self.model = None
    
    def check_is_vehicle(self, image: Image.Image) -> dict:
        """Check if the image contains a vehicle before running the full pipeline."""
        if not self.model:
            return {"is_vehicle": True}  # Graceful fallback if AI unavailable

        try:
            prompt = """Look at this image carefully.
Does it show a vehicle (car, bus, truck, van, motorcycle, tuk-tuk, or similar)?

Respond with ONLY valid JSON, no extra text:
{"is_vehicle": true}
OR
{"is_vehicle": false, "detected_object": "<what you see in 2-4 words>"}"""

            response = self.model.generate_content(
                [prompt, image],
                generation_config={"temperature": 0, "top_p": 1, "top_k": 1}
            )

            try:
                text = response.text
            except Exception:
                if hasattr(response, 'parts') and response.parts:
                    text = ''.join([p.text for p in response.parts if hasattr(p, 'text')])
                else:
                    return {"is_vehicle": True}  # Fallback on parse error

            json_match = re.search(r'\{.*\}', text, re.DOTALL)
            if json_match:
                return json.loads(json_match.group())

            return {"is_vehicle": True}  # Fallback if JSON not found

        except Exception:
            return {"is_vehicle": True}  # Never block assessment if check itself errors

    def validate_damage(self, image: Image.Image, detected_damages: List[str]) -> dict:
        """Get AI validation of detected damages"""
        if not self.model:
            return {'analysis': 'AI not available', 'confidence_score': 'N/A'}
        
        try:
            prompt = f"""
            Analyze this vehicle image for damage.
            Our ML model detected: {', '.join(detected_damages)}
            
            Please:
            1. Confirm if you see these damages
            2. Describe what you observe in 2-3 sentences
            3. Rate confidence (Low/Medium/High)
            
            Keep response brief and professional.
            """
            
            response = self.model.generate_content(
                [prompt, image],
                generation_config={"temperature": 0, "top_p": 1, "top_k": 1}
            )

            # Handle Gemini response parts properly
            try:
                analysis_text = response.text
            except Exception as e:
                # Sometimes response.text fails, try getting parts directly
                if hasattr(response, 'parts') and response.parts:
                    analysis_text = ''.join([part.text for part in response.parts if hasattr(part, 'text')])
                else:
                    analysis_text = f'Error extracting response: {str(e)}'

            return {
                'analysis': analysis_text,
                'confidence_score': 'AI-validated'
            }
        except Exception as e:
            return {'analysis': f'Error: {str(e)}', 'confidence_score': 'N/A'}

class PriceExplanationAI:
    """Gemini Text for price estimation and explanation"""
    def __init__(self, api_key: str):
        if GEMINI_AVAILABLE and api_key:
            genai.configure(api_key=api_key)
            self.model = genai.GenerativeModel('gemini-2.5-pro')
        else:
            self.model = None

    def estimate_price(
        self,
        damages: List[str],
        vehicle_brand: str,
        vehicle_model: str,
        vehicle_year: int,
        affected_part: str,
        image: Optional[Image.Image] = None,
        reference_prices: Optional[List[Dict]] = None,
    ) -> dict:
        """Estimate price using Gemini AI, grounded by real spare parts prices."""
        if not self.model:
            return {'estimated_price': None, 'explanation': 'AI not available', 'method': 'fallback'}

        # Build reference price block for the prompt
        if reference_prices:
            price_lines = []
            for rp in reference_prices:
                adjusted = round(rp['price_lkr'] * PARTS_PRICE_INFLATION_FACTOR)
                price_lines.append(
                    f"  - {rp['part']}: LKR {adjusted:,} "
                    f"(2026-adjusted from LKR {rp['price_lkr']:,.0f} in {rp['reference_year']})"
                )
            price_ref_block = "\n".join(price_lines)
        else:
            price_ref_block = "  No reference data available."

        try:
            prompt = f"""
                You are a senior vehicle damage assessor and Sri Lankan automotive repair cost estimator.
                Your goal is to estimate a realistic repair cost in Sri Lankan Rupees (LKR) from 1 or more vehicle damage images.

                You MUST base your assessment primarily on what is visible in the provided image(s).
                Do NOT invent damage that cannot be seen. If visibility is poor or an area is hidden, mark it as uncertain and lower confidence.

                Vehicle Information:
                - Brand: {vehicle_brand}
                - Model: {vehicle_model}
                - Year: {vehicle_year}
                - Age: {2026 - vehicle_year} years
                - Market: Sri Lanka
                - Currency: LKR

                Detected Damages (from upstream model; may be incomplete):
                {', '.join(damages) if damages else 'No damages detected'}

                Primary Affected Part (from upstream model):
                {affected_part}

                ### REAL SRI LANKAN MARKET SPARE PARTS PRICES (MANDATORY REFERENCE):
                The following are actual spare parts prices from the Sri Lankan market
                (sources: ikman.lk, daraz.lk, newpgenterprises.com).
                You MUST use these prices as the baseline for the "parts" portion of your estimate.
                If a part needs replacement, use the price below. If it only needs repair, the
                parts cost should be significantly lower (materials/filler only).

{price_ref_block}

                TASK:
                Return a realistic repair cost estimate (LKR) with a clear breakdown: parts, labor, paint.
                You must decide whether each visible damaged item is most likely to be:
                - repair (panel beating / plastic welding / polishing)
                - replace (new / recondition / aftermarket)
                - inspect (if structural or hidden damage is suspected)

                ### CORE PRINCIPLES (VERY IMPORTANT):
                1) Sri Lanka repair reality:
                - These are Toyota vehicles common in Sri Lanka.
                - Recondition/aftermarket parts are commonly used when appropriate.
                - Older vehicles often use recondition parts (apply 30-50% discount to reference prices).
                - Newer vehicles may use OEM parts (reference prices or slightly higher).

                2) Parts cost rules:
                - If REPLACING a part: use the reference price above as baseline.
                - If REPAIRING a part (panel beating, polishing): parts cost = materials only (LKR 5,000-15,000 typically).
                - Do NOT guess parts prices. Use the reference data provided.

                3) You must not underestimate paint and finishing:
                - If repaint is required, include prep + paint + clearcoat + polish.
                - If multiple panels are adjacent and paint mismatch is likely, include blending.
                - If only minor scuff and clearcoat damage is visible, polishing may be enough instead of repaint.

                4) You must not overestimate:
                - If damage appears cosmetic only, avoid replacement and avoid structural costs.
                - Do not include airbags/suspension/frame repairs unless clearly visible or strongly implied by misalignment/impact signs.

                5) Be consistent:
                - estimated_price MUST equal parts + labor + paint
                - Values must be integers (no decimals)

                ### IMAGE-BASED DAMAGE ANALYSIS REQUIREMENTS:
                For each affected area visible in the image(s), you MUST produce:
                - part name (e.g., front bumper, left fender, bonnet, headlight, grille, mirror)
                - severity score:
                1 = light scuff/scratch (no deformation)
                2 = paint damage + minor dent (repairable)
                3 = moderate dent/crease (repairable with shaping/filler)
                4 = major deformation or crack/broken part (replacement likely)
                5 = potential structural/safety concern (inspection required)
                - damage types detected (scratch/scuff/dent/crease/crack/broken/misalignment)
                - recommended action: repair / replace / inspect

                ### COST ESTIMATION STRATEGY:
                - Parts: Use the REAL reference prices above. Do not invent prices.
                - Labor:
                  - Panel beating labor: LKR 10,000-28,000 per panel depending on severity.
                  - Replacement labor: LKR 7,000-15,000 per part (fitment + alignment).
                  - Multi-panel work increases labor.
                - Paint:
                  - Single panel repaint: LKR 15,000-28,000.
                  - Multiple panels: LKR 28,000-55,000+.
                  - Polish only: LKR 5,000-10,000.

                ### CONFIDENCE SCORING:
                Return confidence_score (0–100) based on:
                - image clarity and lighting
                - whether the entire damaged area is visible
                - whether multiple angles exist
                - whether internal/hidden damage might exist but cannot be seen

                If confidence_score < 70, include recommended_photos such as:
                - front wide shot
                - side wide shot
                - close-up of damage
                - angle showing panel gaps and alignment
                - inside view behind bumper/fender if possible

                ### OUTPUT FORMAT (STRICT):
                Respond ONLY with valid JSON and nothing else.

                JSON Schema:
                {{
                "estimated_price": <integer>,
                "breakdown": {{
                    "parts": <integer>,
                    "labor": <integer>,
                    "paint": <integer>
                }},
                "severity_summary": [
                    {{
                    "part": "<part name>",
                    "severity": <1-5>,
                    "damage_type": ["...", "..."],
                    "repair_action": "<repair|replace|inspect>",
                    "reference_price_used": <integer or null>
                    }}
                ],
                "confidence_score": <0-100>,
                "assumptions": ["...", "..."],
                "recommended_photos": ["...", "..."],
                "explanation": "<2-3 sentences describing the major cost drivers and why repair/replace was chosen>"
                }}

                Return ONLY JSON. Ensure parts + labor + paint = estimated_price.
                """

            generation_config = {
                "temperature": 0,
                "top_p": 1,
                "top_k": 1,
            }
            content = [prompt, image] if image is not None else prompt
            response = self.model.generate_content(
                content,
                generation_config=generation_config
            )

            # Handle Gemini response parts properly
            try:
                response_text = response.text.strip()
            except Exception as e:
                # Sometimes response.text fails, try getting parts directly
                if hasattr(response, 'parts') and response.parts:
                    response_text = ''.join([part.text for part in response.parts if hasattr(part, 'text')])
                else:
                    raise e

            # Try to extract JSON from response
            import re
            json_match = re.search(r'\{.*\}', response_text, re.DOTALL)
            if json_match:
                result = json.loads(json_match.group())
                estimated_price = float(result.get('estimated_price', 0))
                # Ensure price is reasonable (not 0 or None)
                if estimated_price > 0:
                    return {
                        'estimated_price': estimated_price,
                        'breakdown': result.get('breakdown', {}),
                        'explanation': result.get('explanation', ''),
                        'method': 'gemini_ai'
                    }
                else:
                    print(f"⚠️  Gemini returned invalid price: {estimated_price}")
                    return {'estimated_price': None, 'explanation': 'Gemini returned invalid price', 'method': 'fallback'}
            else:
                # Fallback if JSON parsing fails
                print(f"⚠️  Failed to parse Gemini response: {response_text[:200]}")
                return {'estimated_price': None, 'explanation': 'Failed to parse AI response', 'method': 'fallback'}

        except Exception as e:
            print(f"⚠️  Gemini API error: {str(e)}")
            return {'estimated_price': None, 'explanation': f'Error: {str(e)}', 'method': 'fallback'}

    def explain_price(self, damages: List[str], estimated_price: float) -> dict:
        """Explain existing price estimate (legacy method)"""
        if not self.model:
            return {'explanation': 'AI not available'}

        try:
            prompt = f"""
            Explain this vehicle repair cost estimate:
            - Damages: {', '.join(damages)}
            - Estimated cost: LKR {estimated_price:,.2f}

            Provide brief explanation (3-4 sentences):
            1. Main cost factors
            2. Why this price range
            3. What affects the cost

            Keep it concise and professional.
            """

            response = self.model.generate_content(
                prompt,
                generation_config={"temperature": 0, "top_p": 1, "top_k": 1}
            )
            return {'explanation': response.text}
        except Exception as e:
            return {'explanation': f'Error: {str(e)}'}

# ============================================
# LOAD MODELS ON STARTUP
# ============================================

class ModelLoader:
    def __init__(self):
        self.damage_model = None
        self.price_model = None
        self.price_scaler = None
        self.idx_to_class = None
        self.num_classes = None
        self.damage_ai = None
        self.price_ai = None
        self.transform = None
        self.price_cache = {}

    def load_price_cache(self):
        """Load cached Gemini price responses"""
        try:
            if config.GEMINI_PRICE_CACHE_PATH.exists():
                with open(config.GEMINI_PRICE_CACHE_PATH, "r") as f:
                    self.price_cache = json.load(f)
                print(f"✅ Loaded {len(self.price_cache)} Gemini cache entries")
            else:
                self.price_cache = {}
        except Exception as e:
            print(f"⚠️  Failed to load Gemini price cache: {e}")
            self.price_cache = {}

    def save_price_cache(self):
        """Persist Gemini cache to disk"""
        try:
            config.MODELS_DIR.mkdir(exist_ok=True)
            with open(config.GEMINI_PRICE_CACHE_PATH, "w") as f:
                json.dump(self.price_cache, f)
        except Exception as e:
            print(f"⚠️  Failed to save Gemini price cache: {e}")
        
    def load_all(self):
        """Load all models"""
        print("\n" + "="*80)
        print("🔄 LOADING MODELS")
        print("="*80)
        
        # Load damage labels
        print("\n📋 Loading damage labels...")
        try:
            with open(config.DAMAGE_LABELS_PATH, 'r') as f:
                labels_data = json.load(f)
            self.idx_to_class = {int(k): v for k, v in labels_data['idx_to_class'].items()}
            self.num_classes = labels_data['num_classes']
            print(f"✅ Loaded {self.num_classes} damage classes")
        except Exception as e:
            raise RuntimeError(f"Failed to load damage labels: {e}")
        
        # Load damage detection model
        print("\n🧠 Loading damage detection model...")
        try:
            self.damage_model = DamageDetectionModel(self.num_classes, pretrained=False)
            self.damage_model.load_state_dict(
                torch.load(config.DAMAGE_MODEL_PATH, map_location=config.DEVICE)
            )
            self.damage_model.to(config.DEVICE)
            self.damage_model.eval()
            print(f"✅ Damage model loaded on {config.DEVICE}")
        except Exception as e:
            raise RuntimeError(f"Failed to load damage model: {e}")
        
        # Load price model
        print("\n💰 Loading price estimation model...")
        try:
            self.price_model = joblib.load(config.PRICE_MODEL_PATH)
            self.price_scaler = joblib.load(config.PRICE_SCALER_PATH)
            print("✅ Price model loaded")
        except Exception as e:
            print(f"⚠️  Price model failed to load: {e}")
            print("⚠️  Will use Gemini AI or fallback pricing")
            self.price_model = None
            self.price_scaler = None
        
        # Setup image transformation
        self.transform = transforms.Compose([
            transforms.Resize(config.IMG_SIZE),
            transforms.ToTensor(),
            transforms.Normalize(mean=[0.485, 0.456, 0.406],
                               std=[0.229, 0.224, 0.225])
        ])
        
        # Initialize Gemini AI
        if GEMINI_AVAILABLE and config.GEMINI_API_KEY:
            print("\n🤖 Initializing Gemini AI...")
            try:
                self.damage_ai = DamageValidationAI(config.GEMINI_API_KEY)
                self.price_ai = PriceExplanationAI(config.GEMINI_API_KEY)
                print("✅ Gemini AI initialized")
            except Exception as e:
                print(f"⚠️  Gemini AI initialization failed: {e}")
                self.damage_ai = None
                self.price_ai = None
        else:
            print("\n⚠️  Gemini AI not configured")
            self.damage_ai = None
            self.price_ai = None

        # Load spare parts reference prices
        print("\n📊 Loading spare parts prices...")
        spare_parts.load(config.SPARE_PARTS_CSV_PATH)

        # Load persistent Gemini price cache
        self.load_price_cache()

        print("\n" + "="*80)
        print("✅ ALL MODELS LOADED SUCCESSFULLY")
        print("="*80)

# Initialize model loader
model_loader = ModelLoader()

# ============================================
# FASTAPI APP
# ============================================

app = FastAPI(
    title="Vehicle Damage Assessment API",
    description="API for vehicle damage detection and price estimation",
    version="1.0.0"
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ============================================
# PYDANTIC MODELS
# ============================================

class AssessmentResponse(BaseModel):
    claim_id: Optional[str] = None
    assessment_id: Optional[str] = None
    image_hash: Optional[str] = None
    timestamp: str
    vehicle: dict
    damage_detection: dict
    part_mapping: dict
    price_estimation: dict
    ai_validation: Optional[dict] = None
    processing_time_seconds: float

class HealthResponse(BaseModel):
    status: str
    models_loaded: bool
    gemini_available: bool
    device: str


# ============================================
# STARTUP EVENT
# ============================================

@app.on_event("startup")
async def startup_event():
    """Load models on startup"""
    try:
        model_loader.load_all()
    except Exception as e:
        print(f"\n❌ ERROR: {e}")
        print("⚠️  API will not work properly without models!")

# ============================================
# API ENDPOINTS
# ============================================

@app.get("/", response_model=dict)
async def root():
    """Root endpoint"""
    return {
        "message": "Vehicle Damage Assessment API",
        "version": "2.0.0",
        "features": ["damage detection", "price estimation", "gemini AI"],
        "endpoints": {
            "assessment": {
                "assess": "/assess (POST)"
            },
            "info": {
                "health": "/health",
                "models": "/models/info"
            },
            "docs": "/docs"
        }
    }

@app.get("/health", response_model=HealthResponse)
async def health_check():
    """Health check endpoint"""
    return HealthResponse(
        status="healthy" if model_loader.damage_model is not None else "unhealthy",
        models_loaded=model_loader.damage_model is not None,
        gemini_available=model_loader.damage_ai is not None,
        device=str(config.DEVICE)
    )

@app.post("/assess", response_model=AssessmentResponse)
async def assess_damage(
    image: UploadFile = File(..., description="Vehicle image"),
    vehicle_brand: str = Form(..., description="Vehicle brand (e.g., Toyota)"),
    vehicle_model: str = Form(..., description="Vehicle model (e.g., Corolla)"),
    vehicle_year: int = Form(..., description="Vehicle year (e.g., 2016)"),
    use_ai: bool = Form(True, description="Use Gemini AI for validation")
):
    """
    Assess vehicle damage from image
    
    Returns:
    - Detected damages with confidence scores
    - Affected vehicle part
    - Estimated repair cost
    - AI validation (if enabled)
    """
    start_time = datetime.now()
    
    try:
        # Validate models are loaded
        if model_loader.damage_model is None:
            raise HTTPException(status_code=503, detail="Models not loaded")

        # Validate supported brand
        if not spare_parts.is_supported_brand(vehicle_brand):
            raise HTTPException(
                status_code=400,
                detail=f"Brand '{vehicle_brand}' is not supported yet. Currently supported: Toyota."
            )

        # Validate vehicle year
        current_year = datetime.now().year
        if not (1980 <= vehicle_year <= current_year):
            raise HTTPException(
                status_code=400,
                detail=f"Vehicle year must be between 1980 and {current_year}. Got: {vehicle_year}."
            )

        # Read and process image
        image_bytes = await image.read()
        img_hash = compute_image_hash(image_bytes)
        pil_image = Image.open(io.BytesIO(image_bytes)).convert('RGB')

        # Vehicle presence check — reject non-vehicle images early
        if model_loader.damage_ai is not None:
            vehicle_check = model_loader.damage_ai.check_is_vehicle(pil_image)
            if not vehicle_check.get("is_vehicle", True):
                detected_obj = vehicle_check.get("detected_object", "a non-vehicle object")
                raise HTTPException(
                    status_code=400,
                    detail=f"This image appears to show {detected_obj}, not a vehicle. "
                           f"Please upload a photo of a damaged vehicle."
                )

        # Prepare image for model
        img_tensor = model_loader.transform(pil_image).unsqueeze(0).to(config.DEVICE)
        
        # Damage detection
        with torch.no_grad():
            outputs = model_loader.damage_model(img_tensor)
            probs = torch.sigmoid(outputs).cpu().numpy()[0]
        
        # Get detected damages
        detected_damages = []
        confidences = {}
        
        for i, prob in enumerate(probs):
            if prob > config.DAMAGE_THRESHOLD:
                damage_name = model_loader.idx_to_class[i]
                detected_damages.append(damage_name)
                confidences[damage_name] = float(prob)
        
        # Part mapping
        affected_part = map_damage_to_part(detected_damages)

        # Deterministic cache key: image content + vehicle identity only.
        # Damages and affected_part are deliberately excluded — they are derived
        # from the image, so including them would cause cache misses if ResNet18
        # ever produces a slightly different result for the same image.
        # Same image + same vehicle => same price, always.
        request_fingerprint = {
            "image_sha256": img_hash,
            "vehicle_brand": vehicle_brand.strip().lower(),
            "vehicle_model": vehicle_model.strip().lower(),
            "vehicle_year": vehicle_year,
        }
        cache_key = hashlib.sha256(
            json.dumps(request_fingerprint, sort_keys=True).encode("utf-8")
        ).hexdigest()

        # Gemini-only price estimation
        if not use_ai:
            raise HTTPException(
                status_code=400,
                detail="Gemini AI pricing is required. Set use_ai=true."
            )
        if model_loader.price_ai is None:
            raise HTTPException(
                status_code=503,
                detail="Gemini AI price model is not available."
            )

        estimated_price = None
        price_method = 'gemini_ai'
        price_breakdown = None
        price_explanation_text = None

        # Look up real spare parts prices for this vehicle + damages
        reference_prices = spare_parts.lookup(
            vehicle_brand, vehicle_model, vehicle_year, detected_damages
        )

        cached_price_result = model_loader.price_cache.get(cache_key)
        if cached_price_result is not None:
            price_result = cached_price_result
            price_method = 'gemini_ai_cached'
        else:
            price_result = model_loader.price_ai.estimate_price(
                detected_damages,
                vehicle_brand,
                vehicle_model,
                vehicle_year,
                affected_part,
                pil_image,
                reference_prices=reference_prices,
            )
            if price_result.get('estimated_price') is not None:
                model_loader.price_cache[cache_key] = price_result
                model_loader.save_price_cache()

        estimated_price = price_result.get('estimated_price')
        price_breakdown = price_result.get('breakdown')
        price_explanation_text = price_result.get('explanation')
        if price_method != 'gemini_ai_cached':
            price_method = price_result.get('method', 'gemini_ai')

        if estimated_price is None:
            raise HTTPException(
                status_code=502,
                detail=f"Gemini price estimation failed: {price_result.get('explanation', 'No price returned')}"
            )
        
        # Build response
        response = {
            "timestamp": datetime.now().isoformat(),
            "vehicle": {
                "brand": vehicle_brand,
                "model": vehicle_model,
                "year": vehicle_year
            },
            "damage_detection": {
                "detected_damages": detected_damages,
                "confidences": confidences,
                "num_damages": len(detected_damages),
                "threshold": config.DAMAGE_THRESHOLD
            },
            "part_mapping": {
                "affected_part": affected_part,
                "mapped_from": detected_damages
            },
            "price_estimation": {
                "estimated_price": estimated_price,
                "currency": "LKR",
                "method": price_method,
                "breakdown": price_breakdown if price_breakdown else {},
                "reference_prices": reference_prices,
            }
        }

        # AI validation (optional)
        if use_ai and model_loader.damage_ai is not None:
            damage_validation = model_loader.damage_ai.validate_damage(
                pil_image, detected_damages
            )

            # Use the price explanation from Gemini estimation if available
            if price_explanation_text:
                price_explanation = {'explanation': price_explanation_text}
            else:
                # Otherwise generate a separate explanation
                price_explanation = model_loader.price_ai.explain_price(
                    detected_damages, estimated_price
                )

            response["ai_validation"] = {
                "damage_validation": damage_validation,
                "price_explanation": price_explanation
            }
        
        # Calculate processing time
        processing_time = (datetime.now() - start_time).total_seconds()
        response["processing_time_seconds"] = processing_time

        # Generate assessment ID for reference
        assessment_id = str(uuid.uuid4())
        response["assessment_id"] = assessment_id
        response["image_hash"] = img_hash

        ai_response_dict = response
        claim_payload = {
            "vehicle": {
                "brand": vehicle_brand,
                "model": vehicle_model,
                "year": vehicle_year,
            },
            "image_hash": img_hash,
            "status": "ai_generated",
            "ai_result": ai_response_dict,
            "created_at": datetime.utcnow().isoformat(),
        }

        # Save assessment to Firestore
        claim_ref = db.collection("claims").document()  # Auto-ID
        claim_id = claim_ref.id
        try:
            claim_ref.set(claim_payload)
        except (FirestoreDeadlineExceeded, FirestoreServiceUnavailable) as e:
            raise HTTPException(
                status_code=503,
                detail=(
                    "Firestore write timed out. Check internet/firewall and Firebase project connectivity. "
                    f"Details: {e}"
                ),
            )

        result_dict = ai_response_dict
        result_dict["claim_id"] = claim_id
        return result_dict

    except HTTPException:
        raise
    except Exception as e:
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Assessment failed: {str(e)}")


@app.get("/models/info")
async def models_info():
    """Get information about loaded models"""
    if model_loader.damage_model is None:
        raise HTTPException(status_code=503, detail="Models not loaded")

    return {
        "damage_model": {
            "type": "ResNet18",
            "num_classes": model_loader.num_classes,
            "classes": list(model_loader.idx_to_class.values()),
            "device": str(config.DEVICE)
        },
        "price_model": {
            "type": "RandomForest",
            "loaded": model_loader.price_model is not None
        },
        "gemini_ai": {
            "available": model_loader.damage_ai is not None,
            "vision": model_loader.damage_ai is not None,
            "text": model_loader.price_ai is not None
        }
    }

class NotifyInsurerRequest(BaseModel):
    insurer_id: str
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    location_address: Optional[str] = None


@app.post("/claims/{claim_id}/notify")
def notify_insurer(claim_id: str, body: NotifyInsurerRequest):
    claim_ref = db.collection("claims").document(claim_id)
    doc = claim_ref.get()
    if not doc.exists:
        raise HTTPException(status_code=404, detail="Claim not found")

    update_payload: Dict = {
        "insurer_id": body.insurer_id,
        "status": "sent_to_insurer",
        "sent_at": datetime.utcnow().isoformat(),
    }

    if body.latitude is not None and body.longitude is not None:
        update_payload["location"] = {
            "latitude": body.latitude,
            "longitude": body.longitude,
            "address": body.location_address or "",
            "maps_url": (
                f"https://www.google.com/maps/search/?api=1"
                f"&query={body.latitude},{body.longitude}"
            ),
        }

    try:
        claim_ref.update(update_payload)
    except (FirestoreDeadlineExceeded, FirestoreServiceUnavailable) as e:
        raise HTTPException(
            status_code=503,
            detail=(
                "Firestore update timed out while notifying insurer. "
                f"Details: {e}"
            ),
        )

    response_payload = {
        "ok": True,
        "claim_id": claim_id,
        "status": "sent_to_insurer",
        "insurer_id": body.insurer_id,
    }
    if "location" in update_payload:
        response_payload["location"] = update_payload["location"]

    return response_payload

@app.get("/insurers")
def list_insurers():
    docs = db.collection("insurers").stream()
    return [{"id": d.id, **d.to_dict()} for d in docs]

@app.get("/insurers/{insurer_id}/claims")
def insurer_claims(insurer_id: str):
    q = db.collection("claims").where("insurer_id", "==", insurer_id).stream()
    claims = [{"id": d.id, **d.to_dict()} for d in q]
    claims.sort(key=lambda c: c.get("sent_at", ""), reverse=True)
    return claims

@app.get("/claims")
def list_claims():
    """Return all claims sorted by created_at descending, limited to 50."""
    docs = (
        db.collection("claims")
        .order_by("created_at", direction=firestore.Query.DESCENDING)
        .limit(50)
        .stream()
    )
    return [{"id": d.id, **d.to_dict()} for d in docs]

@app.patch("/claims/{claim_id}/decision")
def submit_decision(
    claim_id: str,
    final_cost: float = Body(...),
    decision: str = Body(...),
    notes: str = Body(default=""),
):
    """Insurer confirms or adjusts the AI-estimated repair cost."""
    if decision not in ("confirmed", "adjusted"):
        raise HTTPException(status_code=422, detail="decision must be 'confirmed' or 'adjusted'")
    claim_ref = db.collection("claims").document(claim_id)
    if not claim_ref.get().exists:
        raise HTTPException(status_code=404, detail="Claim not found")
    try:
        claim_ref.update({
            "final_cost": final_cost,
            "decision": decision,
            "notes": notes,
            "status": "decision_submitted",
            "decided_at": datetime.utcnow().isoformat(),
        })
    except (FirestoreDeadlineExceeded, FirestoreServiceUnavailable) as e:
        raise HTTPException(
            status_code=503,
            detail=(
                "Firestore update timed out while saving insurer decision. "
                f"Details: {e}"
            ),
        )
    return {"ok": True, "claim_id": claim_id, "decision": decision, "final_cost": final_cost}

# ============================================
# MAIN
# ============================================

if __name__ == "__main__":
    import uvicorn

    port = int(os.getenv("SERVICE_1_PORT", "8000"))

    print("\n" + "="*80)
    print("🚗 VEHICLE DAMAGE ASSESSMENT API (SERVICE 1)")
    print("="*80)
    print("\nStarting server...")
    print(f"API will be available at: http://localhost:{port}")
    print(f"Documentation: http://localhost:{port}/docs")
    print("\nPress Ctrl+C to stop")
    print("="*80 + "\n")

    uvicorn.run(app, host="0.0.0.0", port=port, reload=False)
