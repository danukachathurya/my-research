"""
Vehicle Damage Assessment & Garage Recommendation System

1. Damage Detection (ResNet-18)
2. Gemini AI Analysis
3. Google Maps APIs
4. ML-based Garage Recommendation
5. Report Generation
"""

import os
import sys
import time
import torch
import torch.nn as nn
import torchvision.transforms as transforms
from torchvision import models
from PIL import Image
import pandas as pd
import numpy as np
import joblib
from datetime import datetime
from math import radians, cos, sin, asin, sqrt
import warnings
warnings.filterwarnings('ignore')

# Environment variables
from dotenv import load_dotenv

# Google APIs
import googlemaps
import google.generativeai as genai

# Load environment variables from .env file
load_dotenv()


# Model Definition (matching training architecture)
class DamageDetectionModel(nn.Module):
    """Custom ResNet-18 based model for damage detection"""
    def __init__(self, num_classes, pretrained=False):
        super().__init__()
        self.backbone = models.resnet18(pretrained=pretrained)
        num_features = self.backbone.fc.in_features
        self.backbone.fc = nn.Sequential(
            nn.Linear(num_features, 256),
            nn.ReLU(),
            nn.Dropout(0.5),
            nn.Linear(256, num_classes)
        )

    def forward(self, x):
        return self.backbone(x)


# Configuration
class Config:
    """Configuration settings"""

    # API Keys - Load from environment variables
    GOOGLE_MAPS_API_KEY = os.getenv('GOOGLE_MAPS_API_KEY', '')
    GEMINI_API_KEY = os.getenv('GEMINI_API_KEY', '')

    # Model paths
    DAMAGE_MODEL_PATH = 'models/damage_model.pth'
    GARAGE_MODEL_PATH = 'models/complete_model_package.pkl'

    # Data paths
    GARAGES_DATA_PATH = 'data/processed/garages_clean.csv'
    TOWING_DATA_PATH = 'data/towing_services_sri_lanka.csv'
    SPARE_PARTS_PATH = 'data/toyota_sri_lanka_spare_parts_prices.csv'
    DAMAGE_REF_PATH = 'data/damage_reference_dataset.csv'
    SPARE_PARTS_VENDORS_PATH = 'data/spare_parts_vendors_sri_lanka.csv'

    # Damage classes (6 classes from training)
    DAMAGE_CLASSES = ['dent', 'scratch', 'crack', 'glass shatter', 'lamp broken', 'tire flat']
    NUM_DAMAGE_CLASSES = 6
    
    # Sri Lanka location bounds
    SRI_LANKA_BOUNDS = {
        'lat_min': 5.9,
        'lat_max': 9.9,
        'lon_min': 79.5,
        'lon_max': 82.0
    }


class DamageDetector:
    """Handles vehicle damage detection using ResNet-18"""

    # Damage type descriptions and recommendations
    DAMAGE_INFO = {
        'dent': {
            'description': 'A dent is a physical indentation in the vehicle body panel without breaking the paint surface. This type of damage typically occurs from impact with objects, hail, or minor collisions. Dents can range from small dings to large depressions affecting structural panels.',
            'what_happened': 'The vehicle body has been impacted, causing the metal to deform inward. The paint may still be intact, but the panel shape has been compromised.',
            'immediate_actions': [
                'Check if the dent affects any moving parts (doors, hood, trunk)',
                'Inspect for paint cracks that could lead to rust',
                'Take photos from multiple angles for insurance documentation',
                'Avoid trying to pop out the dent yourself if paint is cracked'
            ],
            'repair_options': [
                'Paintless Dent Repair (PDR) - if paint is intact and dent is accessible',
                'Traditional body work - for larger dents or if paint is damaged',
                'Panel replacement - for severe structural dents'
            ],
            'urgency': 'Medium - Should be repaired within 2-4 weeks to prevent rust',
            'estimated_time': '2-8 hours depending on size and location',
            'prevention_tips': 'Park away from high-traffic areas, use garage when possible, maintain safe following distance'
        },
        'scratch': {
            'description': 'A scratch is surface-level damage to the vehicle paint or clear coat. Scratches can be superficial (affecting only clear coat) or deep (penetrating to primer or metal). They typically result from contact with sharp objects, key marks, or brushing against surfaces.',
            'what_happened': 'The protective paint layers have been scraped away, exposing underlying layers. Deep scratches may expose bare metal, which can lead to corrosion.',
            'immediate_actions': [
                'Clean the area gently with car wash soap and water',
                'Determine scratch depth (fingernail test - if it catches, it\'s deep)',
                'Apply touch-up paint or clear coat protectant if metal is exposed',
                'Document with photos for insurance if extensive'
            ],
            'repair_options': [
                'Polishing/buffing - for light clear coat scratches',
                'Touch-up paint - for medium depth scratches',
                'Panel repainting - for deep or extensive scratches',
                'Vinyl wrap - to cover scratched areas cosmetically'
            ],
            'urgency': 'Low to Medium - Deep scratches (metal exposed) need attention within 1-2 weeks',
            'estimated_time': '1-4 hours for minor scratches, 1-2 days for repainting',
            'prevention_tips': 'Use protective film on high-contact areas, park away from tight spaces, apply ceramic coating'
        },
        'crack': {
            'description': 'A crack is a structural break in the vehicle body panel, bumper, or plastic components. Unlike dents, cracks involve actual splitting or fracturing of the material. This type of damage compromises both appearance and structural integrity.',
            'what_happened': 'The material has been stressed beyond its breaking point, causing a fracture line. This often occurs from high-impact collisions, stress concentration points, or material fatigue.',
            'immediate_actions': [
                'Avoid applying stress to the cracked area',
                'Cover with waterproof tape if crack allows water entry',
                'Check for sharp edges that could cause injury',
                'Inspect if crack is expanding or stable',
                'Document crack length and location with measurements'
            ],
            'repair_options': [
                'Plastic welding - for bumper and plastic panel cracks',
                'Fiberglass repair - for reinforcing cracked areas',
                'Panel replacement - recommended for structural cracks',
                'Epoxy bonding - for minor non-structural cracks'
            ],
            'urgency': 'High - Should be addressed within 1 week, immediately if structural',
            'estimated_time': '3-6 hours for repair, 1-2 days for replacement',
            'prevention_tips': 'Avoid overloading vehicle, inspect for stress cracks regularly, repair small cracks before they spread'
        },
        'glass shatter': {
            'description': 'Glass shatter involves broken or severely cracked windshield, windows, or mirrors. This can range from small chips to complete shattering. Shattered glass poses safety risks and compromises vehicle security and weather protection.',
            'what_happened': 'The glass has been impacted with sufficient force to crack or shatter. Windshield damage often starts as a small chip that spreads due to temperature changes and vehicle vibration.',
            'immediate_actions': [
                'DO NOT drive if windshield vision is obstructed',
                'Cover broken windows with plastic sheeting and tape',
                'Remove loose glass carefully using thick gloves',
                'Avoid slamming doors (vibration can spread cracks)',
                'Contact insurance immediately for glass coverage',
                'Schedule repair/replacement ASAP for safety'
            ],
            'repair_options': [
                'Chip repair - for small chips (coin-sized or smaller)',
                'Windshield replacement - for cracks longer than 3 inches',
                'Window replacement - for side/rear windows (cannot be repaired)',
                'Mirror replacement - for broken side mirrors'
            ],
            'urgency': 'Critical - Repair within 24-48 hours, immediate if driver visibility affected',
            'estimated_time': '30 minutes for chip repair, 1-2 hours for replacement',
            'prevention_tips': 'Maintain distance from trucks/gravel, replace worn wipers, park under cover, repair chips immediately'
        },
        'lamp broken': {
            'description': 'Broken lamps include damaged headlights, taillights, turn signals, or brake lights. This damage affects vehicle visibility and legal road compliance. Broken lamp housings can allow moisture entry, causing electrical issues.',
            'what_happened': 'The lamp assembly has been impacted, causing the lens to crack/break or internal components to fail. This compromises lighting function and may expose electrical components to moisture.',
            'immediate_actions': [
                'Check if light still functions despite broken lens',
                'Cover broken area with red/clear tape (matching lamp color) as temporary fix',
                'Test all lights (headlights, brake, turn signals)',
                'Avoid driving at night if headlights are affected',
                'Be aware this may result in traffic citation if not fixed'
            ],
            'repair_options': [
                'Lens replacement - if only outer lens is damaged',
                'Complete assembly replacement - most common and recommended',
                'Aftermarket vs OEM parts - cost vs quality consideration',
                'Bulb replacement - if only internal bulb is damaged'
            ],
            'urgency': 'High - Illegal to drive with broken lights, repair within 2-3 days',
            'estimated_time': '30 minutes to 2 hours depending on vehicle model',
            'prevention_tips': 'Install protective film on lenses, park away from traffic, consider brush guards for off-road vehicles'
        },
        'tire flat': {
            'description': 'A flat tire occurs when air pressure is lost due to puncture, valve damage, rim damage, or sidewall failure. This affects vehicle handling, fuel efficiency, and safety. Driving on a flat tire can cause permanent wheel damage.',
            'what_happened': 'The tire has lost air pressure, either rapidly (puncture) or slowly (leak). The tire can no longer support the vehicle weight properly, affecting performance and safety.',
            'immediate_actions': [
                'DO NOT continue driving - pull over safely immediately',
                'Turn on hazard lights and use warning triangle',
                'Inspect for visible puncture (nail, screw, etc.)',
                'Check if spare tire is available and properly inflated',
                'Call roadside assistance if unable to change tire safely',
                'If repairable puncture, mark location before removal'
            ],
            'repair_options': [
                'Tire patch/plug - for small punctures in tread area (up to 1/4 inch)',
                'Tire replacement - for sidewall damage, large punctures, or worn tires',
                'TPMS sensor check - ensure monitoring system works after repair',
                'Wheel alignment check - recommended after tire replacement'
            ],
            'urgency': 'Critical - Address immediately, do not drive on flat tire',
            'estimated_time': '15-30 minutes for patch, 30-60 minutes for replacement',
            'prevention_tips': 'Check tire pressure monthly, rotate tires regularly, avoid potholes/debris, inspect for embedded objects'
        }
    }

    def __init__(self, model_path):
        self.model_path = model_path
        self.device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
        self.model = None
        self.transform = transforms.Compose([
            transforms.Resize((224, 224)),
            transforms.ToTensor(),
            transforms.Normalize([0.485, 0.456, 0.406], [0.229, 0.224, 0.225])
        ])

        print(f"🔧 DamageDetector initialized (Device: {self.device})")
        
    def get_damage_info(self, damage_type):
        """
        Get detailed information about a specific damage type

        Args:
            damage_type: The damage type string

        Returns:
            dict: Detailed information about the damage type
        """
        return self.DAMAGE_INFO.get(damage_type, {
            'description': 'Unknown damage type',
            'what_happened': 'Unable to determine damage details',
            'immediate_actions': ['Contact a professional mechanic for assessment'],
            'repair_options': ['Professional inspection required'],
            'urgency': 'Unknown - Get professional assessment',
            'estimated_time': 'Varies',
            'prevention_tips': 'Regular vehicle maintenance and careful driving'
        })

    def load_model(self):
        """Load the trained damage detection model"""
        try:
            # Create the model with the correct architecture (6 damage classes)
            self.model = DamageDetectionModel(num_classes=6, pretrained=False)
            self.model.to(self.device)

            # Load the state_dict
            state_dict = torch.load(self.model_path, map_location=self.device)
            self.model.load_state_dict(state_dict)
            self.model.eval()

            print(f"✅ Damage detection model loaded from {self.model_path}")
            return True
        except Exception as e:
            print(f"❌ Error loading damage model: {e}")
            return False
    
    def predict(self, image_path, threshold=0.5):
        """
        Predict damage type(s) from image (multi-label) with detailed descriptions and recommendations

        Args:
            image_path: Path to the damage image
            threshold: Confidence threshold for multi-label classification (default 0.5)

        Returns:
            dict: {
                'damage_type': str (primary damage),
                'severity_score': int (0-5, based on number of damages),
                'confidence': float (max confidence among detected damages),
                'probabilities': dict (all class probabilities),
                'detected_damages': list (all damages above threshold),
                'damage_details': dict {
                    'description': str (what this damage type is),
                    'what_happened': str (explanation of the damage),
                    'immediate_actions': list (steps to take right away),
                    'repair_options': list (available repair methods),
                    'urgency': str (how urgently this needs repair),
                    'estimated_time': str (typical repair duration),
                    'prevention_tips': str (how to avoid this in future)
                }
            }
        """
        if self.model is None:
            raise ValueError("Model not loaded. Call load_model() first.")

        try:
            # Load and preprocess image
            image = Image.open(image_path).convert('RGB')
            image_tensor = self.transform(image).unsqueeze(0).to(self.device)

            # Predict
            with torch.no_grad():
                outputs = self.model(image_tensor)
                probabilities = torch.sigmoid(outputs)  # Multi-label sigmoid

            # Get probabilities
            probs_array = probabilities[0].cpu().numpy()
            probs_dict = {
                Config.DAMAGE_CLASSES[i]: float(probs_array[i])
                for i in range(len(Config.DAMAGE_CLASSES))
            }

            # Get detected damages (above threshold)
            detected_damages = [
                Config.DAMAGE_CLASSES[i]
                for i in range(len(Config.DAMAGE_CLASSES))
                if probs_array[i] > threshold
            ]

            # Primary damage (highest confidence)
            max_idx = np.argmax(probs_array)
            damage_type = Config.DAMAGE_CLASSES[max_idx]
            confidence_val = float(probs_array[max_idx])
            severity_score = min(5, len(detected_damages))  # Severity based on number of damages

            # Get detailed information about the primary damage
            damage_details = self.get_damage_info(damage_type)

            result = {
                'damage_type': damage_type,
                'severity_score': severity_score,
                'confidence': confidence_val,
                'probabilities': probs_dict,
                'detected_damages': detected_damages,
                'damage_details': {
                    'description': damage_details['description'],
                    'what_happened': damage_details['what_happened'],
                    'immediate_actions': damage_details['immediate_actions'],
                    'repair_options': damage_details['repair_options'],
                    'urgency': damage_details['urgency'],
                    'estimated_time': damage_details['estimated_time'],
                    'prevention_tips': damage_details['prevention_tips']
                }
            }

            damages_str = ', '.join(detected_damages) if detected_damages else damage_type
            print(f"✅ Damage detected: {damages_str} (primary: {damage_type}, confidence: {confidence_val:.2%})")
            print(f"ℹ️  What happened: {damage_details['what_happened']}")
            print(f"⚠️  Urgency: {damage_details['urgency']}")
            return result

        except Exception as e:
            print(f"❌ Error in damage detection: {e}")
            return None


class GeminiAnalyzer:
    """Handles enhanced damage analysis using Gemini AI"""
    
    def __init__(self, api_key):
        self.api_key = api_key
        genai.configure(api_key=api_key)
        self.model = genai.GenerativeModel('gemini-2.0-flash')
        print("🔧 GeminiAnalyzer initialized")
    
    def analyze_damage(self, image_path, detection_results):
        """
        Get detailed damage analysis from Gemini AI
        
        Args:
            image_path: Path to the damage image
            detection_results: Results from damage detector
            
        Returns:
            str: Detailed analysis text
        """
        try:
            # Convert to bytes — workaround for google-generativeai==0.3.1
            # PIL plugin bug (PIL.PngImagePlugin not auto-imported)
            import io as _io
            _raw = Image.open(image_path).convert('RGB')
            _buf = _io.BytesIO()
            _raw.save(_buf, format='JPEG')
            image = {"mime_type": "image/jpeg", "data": _buf.getvalue()}

            prompt = f"""
Vehicle Damage Analysis Request:

Initial AI Detection:
- Damage Type: {detection_results['damage_type']}
- Confidence: {detection_results['confidence']:.1%}
- Severity Score: {detection_results['severity_score']}/2

Please provide a detailed analysis in the following format:

**1. DAMAGE DESCRIPTION**
Describe what you see in the image (2-3 sentences).

**2. AFFECTED PARTS**
List all damaged vehicle components (e.g., bumper, headlight, door, etc.).

**3. REPAIR TYPE NEEDED**
Specify repair categories: body work, paint, mechanical, electrical, glass repair.

**4. URGENCY LEVEL**
Rate as: Immediate, Within a week, Can wait, Cosmetic only.

**5. REPAIR COMPLEXITY**
Rate as: Simple, Moderate, Complex, Very Complex.

**6. RECOMMENDED SPECIALIZATION**
What type of garage is best suited for this repair?

Be specific and practical for the Sri Lankan automotive repair market.
"""
            
            response = self.model.generate_content([prompt, image])
            analysis = response.text
            
            print("✅ Gemini AI analysis completed")
            return analysis
            
        except Exception as e:
            print(f"❌ Error in Gemini analysis: {e}")
            return None

    def check_is_vehicle(self, image) -> dict:
        """
        Check if the image contains a vehicle before running the full pipeline.
        Modelled on DamageValidationAI.check_is_vehicle() from the Chathurya project.

        Args:
            image: PIL Image object

        Returns:
            dict: {"is_vehicle": True} or {"is_vehicle": False, "detected_object": "..."}
        """
        import re as _re
        import json as _json
        import traceback

        print("🔍 Running vehicle image check...")

        try:
            prompt = """Look at this image carefully.
Does it show a vehicle (car, bus, truck, van, motorcycle, tuk-tuk, or similar)?

Respond with ONLY valid JSON, no extra text:
{"is_vehicle": true}
OR
{"is_vehicle": false, "detected_object": "<what you see in 2-4 words>"}"""

            # Convert PIL Image to bytes — workaround for google-generativeai==0.3.1
            # bug where PIL.PngImagePlugin is not imported, causing AttributeError
            # when passing PIL Image objects directly.
            import io as _io
            img_buf = _io.BytesIO()
            image.save(img_buf, format='JPEG')
            image_part = {"mime_type": "image/jpeg", "data": img_buf.getvalue()}

            response = self.model.generate_content([prompt, image_part])

            try:
                text = response.text
            except Exception:
                if hasattr(response, 'parts') and response.parts:
                    text = ''.join([p.text for p in response.parts if hasattr(p, 'text')])
                else:
                    print("⚠️  Vehicle check: could not read response text, failing open")
                    return {"is_vehicle": True}

            print(f"🤖 Gemini vehicle check raw response: {text[:300]}")

            json_match = _re.search(r'\{.*?\}', text, _re.DOTALL)
            if json_match:
                result = _json.loads(json_match.group())
                print(f"✅ Vehicle check result: {result}")
                return result

            print("⚠️  Vehicle check: no JSON in response, failing open")
            return {"is_vehicle": True}

        except Exception as e:
            print(f"⚠️  Vehicle check error (failing open): {e}")
            traceback.print_exc()
            return {"is_vehicle": True}  # Never block if check itself errors


class GoogleMapsService:
    """Handles Google Maps API interactions"""
    
    def __init__(self, api_key):
        self.api_key = api_key
        self.gmaps = googlemaps.Client(key=api_key)
        print("🔧 GoogleMapsService initialized")

    def _extract_garage(self, place):
        """Normalize Google Places record to garage shape used by the app."""
        return {
            'name': place.get('name', 'Unknown'),
            'address': place.get('vicinity') or place.get('formatted_address', 'N/A'),
            'location': place['geometry']['location'],
            'latitude': place['geometry']['location']['lat'],
            'longitude': place['geometry']['location']['lng'],
            'rating': place.get('rating', 0),
            'total_ratings': place.get('user_ratings_total', 0),
            'place_id': place['place_id'],
            'open_now': place.get('opening_hours', {}).get('open_now', None)
        }
    
    def find_nearby_garages(self, location, radius=5000, max_results=20):
        """
        Find nearby auto repair garages
        
        Args:
            location: tuple (latitude, longitude)
            radius: Search radius in meters
            max_results: Maximum number of results
            
        Returns:
            list: List of garage dictionaries
        """
        garages_by_place = {}
        search_radii = [radius, 10000, 20000]
        nearby_searches = [
            {'type': 'car_repair', 'keyword': 'auto repair'},
            {'type': 'car_repair', 'keyword': 'mechanic'},
            {'type': 'car_repair'},
        ]

        def add_results(places_result):
            for place in places_result.get('results', []):
                place_id = place.get('place_id')
                if not place_id or place_id in garages_by_place:
                    continue
                garages_by_place[place_id] = self._extract_garage(place)
                if len(garages_by_place) >= max_results:
                    return True
            return False

        try:
            # Try increasingly broader nearby searches first.
            for search_radius in search_radii:
                for query in nearby_searches:
                    places_result = self.gmaps.places_nearby(
                        location=location,
                        radius=search_radius,
                        **query
                    )

                    if add_results(places_result):
                        garages = list(garages_by_place.values())[:max_results]
                        print(f"✅ Found {len(garages)} nearby garages")
                        return garages

                    # Handle paginated nearby results.
                    next_page_token = places_result.get('next_page_token')
                    while next_page_token and len(garages_by_place) < max_results:
                        time.sleep(2)  # token activation delay required by Google Places API
                        places_result = self.gmaps.places_nearby(
                            location=location,
                            radius=search_radius,
                            page_token=next_page_token,
                            **query
                        )
                        if add_results(places_result):
                            break
                        next_page_token = places_result.get('next_page_token')

                if len(garages_by_place) >= max_results:
                    break

            # Fallback to text search if nearby search is sparse or empty.
            if len(garages_by_place) < max_results:
                lat, lon = location
                text_queries = [
                    "auto repair near me",
                    "mechanic garage near me",
                    "car repair shop"
                ]
                for text_query in text_queries:
                    places_result = self.gmaps.places(
                        query=text_query,
                        location=(lat, lon),
                        radius=20000
                    )
                    if add_results(places_result):
                        break

            garages = list(garages_by_place.values())[:max_results]
            print(f"✅ Found {len(garages)} nearby garages")
            return garages

        except Exception as e:
            print(f"❌ Error finding garages: {e}")
            return []
    
    def get_distance_matrix(self, origin, destinations):
        """
        Calculate distances and travel times
        
        Args:
            origin: tuple (lat, lon)
            destinations: list of tuples [(lat, lon), ...]
            
        Returns:
            list: Distance and duration information
        """
        try:
            distance_result = self.gmaps.distance_matrix(
                origins=[origin],
                destinations=destinations,
                mode="driving",
                units="metric"
            )
            
            results = []
            for i, element in enumerate(distance_result['rows'][0]['elements']):
                if element['status'] == 'OK':
                    results.append({
                        'destination_index': i,
                        'distance_km': element['distance']['value'] / 1000,
                        'distance_text': element['distance']['text'],
                        'duration_min': element['duration']['value'] / 60,
                        'duration_text': element['duration']['text']
                    })
                else:
                    results.append({
                        'destination_index': i,
                        'distance_km': None,
                        'distance_text': 'N/A',
                        'duration_min': None,
                        'duration_text': 'N/A'
                    })
            
            return results
            
        except Exception as e:
            print(f"❌ Error calculating distances: {e}")
            return []
    
    def get_garage_details(self, place_id):
        """Get detailed information about a garage"""
        try:
            place_details = self.gmaps.place(
                place_id=place_id,
                fields=['name', 'rating', 'formatted_phone_number', 
                        'formatted_address', 'opening_hours', 'website', 'reviews']
            )
            
            result = place_details.get('result', {})
            
            details = {
                'name': result.get('name'),
                'phone': result.get('formatted_phone_number'),
                'address': result.get('formatted_address'),
                'rating': result.get('rating'),
                'website': result.get('website'),
                'opening_hours': result.get('opening_hours', {}).get('weekday_text', []),
                'reviews': []
            }
            
            # Get top 3 reviews
            for review in result.get('reviews', [])[:3]:
                details['reviews'].append({
                    'author': review.get('author_name'),
                    'rating': review.get('rating'),
                    'text': review.get('text'),
                    'time': review.get('relative_time_description')
                })
            
            return details
            
        except Exception as e:
            print(f"❌ Error getting garage details: {e}")
            return None


class GarageRecommender:
    """ML-based garage recommendation system"""
    
    def __init__(self, model_path, garages_data_path):
        self.model_path = model_path
        self.garages_data_path = garages_data_path
        self.model = None
        self.scaler = None
        self.feature_columns = None
        self.garages_df = None
        
        print("🔧 GarageRecommender initialized")
    
    def load_model(self):
        """Load the trained ML model"""
        try:
            # Load model package
            model_package = joblib.load(self.model_path)
            self.model = model_package['model']
            self.scaler = model_package['scaler']
            self.feature_columns = model_package['feature_columns']
            
            print(f"✅ Garage recommendation model loaded")
            print(f"   Features: {len(self.feature_columns)}")
            
            return True
            
        except Exception as e:
            print(f"❌ Error loading garage model: {e}")
            return False
    
    def load_garage_data(self):
        """Load garage database"""
        try:
            self.garages_df = pd.read_csv(self.garages_data_path)
            print(f"✅ Loaded {len(self.garages_df)} garages from database")
            return True
        except Exception as e:
            print(f"❌ Error loading garage data: {e}")
            return False
    
    def calculate_distance(self, lat1, lon1, lat2, lon2):
        """Calculate distance using Haversine formula"""
        lon1, lat1, lon2, lat2 = map(radians, [lon1, lat1, lon2, lat2])
        dlon = lon2 - lon1
        dlat = lat2 - lat1
        a = sin(dlat/2)**2 + cos(lat1) * cos(lat2) * sin(dlon/2)**2
        c = 2 * asin(sqrt(a))
        km = 6371 * c
        return km
    
    def create_features(self, user_location, damage_info, google_garages):
        """
        Create features for garage recommendation
        
        Args:
            user_location: tuple (lat, lon)
            damage_info: Damage detection results
            google_garages: Garages from Google Maps
            
        Returns:
            pd.DataFrame: Feature matrix
        """
        features_list = []
        
        for garage in google_garages:
            # Calculate distance
            distance_km = self.calculate_distance(
                user_location[0], user_location[1],
                garage['latitude'], garage['longitude']
            )
            
            # Create feature dict (matching training features)
            features = {
                'calculated_distance_km': distance_km,
                'distance_score': 1 / (1 + distance_km),
                'is_nearby': 1 if distance_km <= 5 else 0,
                'is_very_close': 1 if distance_km <= 2 else 0,
                'specialization_match_score': 0.7,  # Default - can be improved with more data
                'historical_satisfaction_rate': 0.75,  # Default
                'total_repairs': 50,  # Default
                'avg_historical_cost': 50000,  # Default
                'avg_completion_time': 3.0,  # Default
                'cost_reliability': 0.8,  # Default
                'time_reliability': 0.8,  # Default
                'overall_preference_score': 0.7,  # Default
                'distance_preference_match': 1 if distance_km <= 10 else 0,
                'price_preference_match': 1,  # Default
                'rating_preference_match': 1 if garage['rating'] >= 3.5 else 0,
                'availability_score': 0.5,  # Default
                'current_utilization': 0.6,  # Default
                'avg_hourly_rate': 3000,  # Default
                'price_competitiveness': 1.0,  # Default
                'cost_accuracy': 0.85,  # Default
                'avg_rating': garage['rating'] if garage['rating'] > 0 else 3.5,
                'num_reviews': garage['total_ratings'],
                'years_in_business': 5,  # Default
                'certified': 1  # Default
            }
            
            features_list.append(features)
        
        return pd.DataFrame(features_list)
    
    def recommend(self, user_location, damage_info, google_garages, top_k=5):
        """
        Get top K garage recommendations
        
        Args:
            user_location: tuple (lat, lon)
            damage_info: Damage detection results
            google_garages: Garages from Google Maps
            top_k: Number of recommendations
            
        Returns:
            list: Top K recommended garages with scores
        """
        if self.model is None:
            raise ValueError("Model not loaded")
        
        # Create features
        X = self.create_features(user_location, damage_info, google_garages)
        
        # Scale features
        X_scaled = self.scaler.transform(X)
        
        # Predict satisfaction probabilities
        satisfaction_probs = self.model.predict_proba(X_scaled)[:, 1]
        
        # Combine with Google ratings + distance for final score
        final_scores = []
        for i, garage in enumerate(google_garages):
            ml_score = satisfaction_probs[i]
            google_score = garage['rating'] / 5.0 if garage['rating'] > 0 else 0.7

            # Proximity score: decays with distance.
            # score=1.0 at 0 km, ~0.67 at 10 km, ~0.50 at 20 km, ~0.25 at 60 km
            distance_km = garage.get('distance_km', 50.0) or 50.0
            proximity_score = 1.0 / (1.0 + distance_km / 20.0)

            # Weighted combination: 40% ML quality, 20% user rating, 40% proximity
            final_score = 0.4 * ml_score + 0.2 * google_score + 0.4 * proximity_score

            final_scores.append({
                'garage': garage,
                'ml_satisfaction_score': ml_score,
                'google_rating_score': google_score,
                'final_score': final_score
            })
        
        # Sort by final score
        final_scores.sort(key=lambda x: x['final_score'], reverse=True)
        
        # Get top K
        recommendations = final_scores[:top_k]
        
        print(f"✅ Generated top {len(recommendations)} recommendations")
        return recommendations


class TowingServiceFinder:
    """Finds nearby towing services and estimates costs"""

    def __init__(self, data_path='data/towing_services_sri_lanka.csv'):
        self.data_path = data_path
        self.towing_df = None
        print("🚛 TowingServiceFinder initialized")

    def load_data(self) -> bool:
        """Load towing services CSV"""
        try:
            self.towing_df = pd.read_csv(
                self.data_path,
                dtype={'phone': str, 'towing_id': str, 'vehicle_types': str, 'name': str, 'city': str}
            )
            print(f"✅ Loaded {len(self.towing_df)} towing services from database")
            return True
        except Exception as e:
            print(f"❌ Error loading towing data: {e}")
            return False

    def calculate_distance(self, lat1, lon1, lat2, lon2) -> float:
        """Calculate distance using Haversine formula"""
        lon1, lat1, lon2, lat2 = map(radians, [lon1, lat1, lon2, lat2])
        dlon = lon2 - lon1
        dlat = lat2 - lat1
        a = sin(dlat/2)**2 + cos(lat1) * cos(lat2) * sin(dlon/2)**2
        c = 2 * asin(sqrt(a))
        return 6371 * c

    def estimate_cost(self, distance_km: float, base_fee: float, rate_per_km: float) -> dict:
        """Estimate towing cost with ±10% variance for min/max"""
        estimated = base_fee + distance_km * rate_per_km
        return {
            'estimated_cost_lkr': round(estimated),
            'min_cost_lkr': round(estimated * 0.90),
            'max_cost_lkr': round(estimated * 1.10),
        }

    def find_nearby(self, user_lat: float, user_lon: float, max_results: int = 5) -> list:
        """Find nearby towing services sorted by distance"""
        if self.towing_df is None:
            self.load_data()
        if self.towing_df is None or self.towing_df.empty:
            print("⚠️  No towing data available, using fallback")
            return self._get_fallback_towing(user_lat, user_lon, max_results)

        results = []
        for _, row in self.towing_df.iterrows():
            dist = self.calculate_distance(user_lat, user_lon, row['latitude'], row['longitude'])
            if dist <= row['max_distance_km']:
                cost_info = self.estimate_cost(dist, row['base_fee_lkr'], row['rate_per_km_lkr'])
                results.append({
                    'towing_id': row['towing_id'],
                    'name': row['name'],
                    'phone': row['phone'],
                    'city': row['city'],
                    'distance_km': round(dist, 1),
                    'base_fee_lkr': float(row['base_fee_lkr']),
                    'rate_per_km_lkr': float(row['rate_per_km_lkr']),
                    'estimated_cost_lkr': float(cost_info['estimated_cost_lkr']),
                    'avg_eta_minutes': int(row['avg_eta_minutes']),
                    'rating': float(row['rating']),
                    'num_reviews': int(row['num_reviews']),
                    'available_24h': bool(row['available_24h']),
                    'flatbed_available': bool(row['flatbed_available']),
                    'vehicle_types': str(row['vehicle_types']).split(';'),
                })

        results.sort(key=lambda x: x['distance_km'])
        print(f"✅ Found {len(results[:max_results])} towing services nearby")
        return results[:max_results]

    def _get_fallback_towing(self, user_lat: float, user_lon: float, max_results: int) -> list:
        """Fallback towing data when CSV unavailable"""
        return [
            {
                'towing_id': 'TOW_FB1',
                'name': 'Lanka Road Rescue',
                'phone': '+94711234567',
                'city': 'Colombo',
                'distance_km': 3.5,
                'base_fee_lkr': 2500.0,
                'rate_per_km_lkr': 120.0,
                'estimated_cost_lkr': 2920.0,
                'avg_eta_minutes': 25,
                'rating': 4.2,
                'num_reviews': 65,
                'available_24h': True,
                'flatbed_available': True,
                'vehicle_types': ['car', 'suv', 'van'],
            }
        ]

    def book_towing(self, towing_id: str, user_lat: float, user_lon: float,
                    destination: str = None) -> dict:
        """Simulate a towing booking and return a reference number"""
        import random
        suffix = str(random.randint(1000, 9999))
        booking_ref = f"TOW-{datetime.now().strftime('%Y%m%d')}-{suffix}"

        # Find service info
        service_name = "Towing Service"
        eta = 25
        if self.towing_df is not None:
            row = self.towing_df[self.towing_df['towing_id'] == towing_id]
            if not row.empty:
                service_name = row.iloc[0]['name']
                eta = int(row.iloc[0]['avg_eta_minutes'])

        print(f"✅ Towing booking confirmed: {booking_ref}")
        return {
            'booking_ref': booking_ref,
            'towing_service': service_name,
            'status': 'CONFIRMED',
            'estimated_arrival_minutes': eta,
            'message': f'Your towing truck is on the way. Reference: {booking_ref}',
        }


class SparePartsBidder:
    """Matches damage types to required parts and generates competitive vendor bids"""

    # Maps our 6 damage classes to typical parts needed
    DAMAGE_TO_PARTS = {
        'dent': ['Door Panel', 'Bumper', 'Fender', 'Hood'],
        'scratch': ['Door Panel', 'Bumper', 'Fender', 'Side Mirror'],
        'crack': ['Windshield', 'Bumper', 'Headlight', 'Taillight'],
        'glass shatter': ['Windshield', 'Side Mirror', 'Rear Glass'],
        'lamp broken': ['Headlight', 'Taillight', 'Fog Light'],
        'tire flat': ['Tyre', 'Alloy Wheel', 'Rim'],
    }

    def __init__(
        self,
        parts_path='data/toyota_sri_lanka_spare_parts_prices.csv',
        damage_ref_path='data/damage_reference_dataset.csv',
        vendors_path='data/spare_parts_vendors_sri_lanka.csv',
    ):
        self.parts_path = parts_path
        self.damage_ref_path = damage_ref_path
        self.vendors_path = vendors_path
        self.parts_df = None
        self.damage_ref_df = None
        self.vendors_df = None
        print("🔩 SparePartsBidder initialized")

    def load_data(self) -> bool:
        """Load all CSVs"""
        success = True
        try:
            self.parts_df = pd.read_csv(self.parts_path)
            print(f"✅ Loaded {len(self.parts_df)} spare parts price records")
        except Exception as e:
            print(f"❌ Error loading spare parts data: {e}")
            success = False

        try:
            self.damage_ref_df = pd.read_csv(self.damage_ref_path)
            print(f"✅ Loaded {len(self.damage_ref_df)} damage reference records")
        except Exception as e:
            print(f"⚠️  Damage reference data unavailable: {e}")

        try:
            self.vendors_df = pd.read_csv(
                self.vendors_path,
                dtype={'phone': str, 'vendor_id': str, 'name': str, 'city': str, 'brands_stocked': str}
            )
            print(f"✅ Loaded {len(self.vendors_df)} spare parts vendors")
        except Exception as e:
            print(f"❌ Error loading vendors data: {e}")
            success = False

        return success

    def get_parts_for_damage(self, damage_type: str) -> list:
        """Return list of part names typically needed for this damage type"""
        damage_lower = damage_type.lower().strip()

        # First check our hardcoded mapping (most reliable)
        for key, parts in self.DAMAGE_TO_PARTS.items():
            if key in damage_lower or damage_lower in key:
                return parts

        # Fallback: check damage_reference_dataset if loaded
        if self.damage_ref_df is not None:
            try:
                match = self.damage_ref_df[
                    self.damage_ref_df['damage_type'].str.lower().str.contains(damage_lower, na=False)
                ]
                if not match.empty and 'typical_parts_needed' in match.columns:
                    parts_str = match.iloc[0]['typical_parts_needed']
                    if pd.notna(parts_str):
                        return [p.strip() for p in str(parts_str).split(',') if p.strip()]
            except Exception:
                pass

        return ['Door Panel', 'Bumper', 'Windshield']  # generic fallback

    def get_bids_for_part(self, part_name: str, vehicle_make: str = 'Toyota',
                           num_vendors: int = 5,
                           user_lat: float = None, user_lon: float = None) -> list:
        """Generate competitive vendor bids for a single part, sorted by proximity."""
        import random
        random.seed(hash(part_name) % 10000)

        base_price = None

        # Search parts CSV for matching part
        if self.parts_df is not None:
            try:
                part_lower = part_name.lower()
                # Try brand-filtered search first
                mask = self.parts_df['Part_Name'].str.lower().str.contains(part_lower, na=False)
                brand_mask = self.parts_df['Brand'].str.lower().str.contains(
                    vehicle_make.lower(), na=False)
                matches = self.parts_df[mask & brand_mask]
                if matches.empty:
                    matches = self.parts_df[mask]
                if not matches.empty:
                    price_col = 'Price_LKR'
                    if price_col not in matches.columns:
                        # Try flexible column name matching
                        price_col = [c for c in matches.columns if 'price' in c.lower() or 'lkr' in c.lower()]
                        price_col = price_col[0] if price_col else None
                    if price_col:
                        price_val = pd.to_numeric(
                            matches.iloc[0][price_col], errors='coerce')
                        if pd.notna(price_val) and price_val > 0:
                            base_price = float(price_val)
            except Exception as e:
                print(f"⚠️  Parts lookup error for '{part_name}': {e}")

        # Use generic fallback price if not found
        if base_price is None or base_price <= 0:
            fallback_prices = {
                'windshield': 95000, 'door panel': 75000, 'bumper': 45000,
                'headlight': 35000, 'taillight': 28000, 'fender': 40000,
                'hood': 85000, 'tyre': 22000, 'alloy wheel': 38000,
                'rim': 15000, 'side mirror': 12000, 'fog light': 18000,
                'rear glass': 65000,
            }
            part_lower = part_name.lower()
            base_price = next(
                (v for k, v in fallback_prices.items() if k in part_lower or part_lower in k),
                40000
            )

        # Generate bids from vendors — prefer nearest vendors when location is given
        bids = []
        if self.vendors_df is not None and not self.vendors_df.empty:
            vendors_pool = self.vendors_df.copy()

            if user_lat is not None and user_lon is not None:
                # Sort vendors by straight-line distance to user (fast approximate)
                try:
                    vendors_pool['_dist'] = (
                        (vendors_pool['latitude'] - user_lat) ** 2 +
                        (vendors_pool['longitude'] - user_lon) ** 2
                    ) ** 0.5
                    vendors_pool = vendors_pool.sort_values('_dist')
                except Exception:
                    pass  # fall through to random sample if columns missing

            vendor_sample = vendors_pool.head(min(num_vendors, len(vendors_pool)))
            for _, vendor in vendor_sample.iterrows():
                variation = random.uniform(0.88, 1.18)
                bid_price = round(base_price * variation, -2)  # round to nearest 100
                bids.append({
                    'vendor_id': vendor['vendor_id'],
                    'vendor_name': vendor['name'],
                    'phone': vendor['phone'],
                    'city': vendor['city'],
                    'price_lkr': float(bid_price),
                    'lead_time_days': int(vendor['lead_time_days']),
                    'warranty_months': int(vendor['warranty_months']),
                    'rating': float(vendor['rating']),
                })
        else:
            # Fallback vendors
            for i in range(min(num_vendors, 3)):
                variation = random.uniform(0.90, 1.15)
                bids.append({
                    'vendor_id': f'VND_FB{i+1}',
                    'vendor_name': f'Lanka Auto Parts {i+1}',
                    'phone': f'+9471{1000000+i}',
                    'city': 'Colombo',
                    'price_lkr': float(round(base_price * variation, -2)),
                    'lead_time_days': i + 1,
                    'warranty_months': 12,
                    'rating': round(3.8 + i * 0.2, 1),
                })

        bids.sort(key=lambda x: x['price_lkr'])
        return bids

    def get_all_bids(self, damage_type: str, vehicle_make: str = 'Toyota',
                      vehicle_model: str = None, vehicle_year: int = None,
                      user_lat: float = None, user_lon: float = None) -> dict:
        """Main method: get competitive bids for all parts needed to repair the damage.
        Pass user_lat/user_lon to prioritise vendors closest to the user."""
        if self.parts_df is None:
            self.load_data()

        parts_list = self.get_parts_for_damage(damage_type)

        vehicle_info = vehicle_make
        if vehicle_model:
            vehicle_info += f" {vehicle_model}"
        if vehicle_year:
            vehicle_info += f" {vehicle_year}"

        parts_with_bids = []
        total_min = 0.0
        total_max = 0.0

        for part_name in parts_list:
            bids = self.get_bids_for_part(part_name, vehicle_make,
                                          user_lat=user_lat, user_lon=user_lon)
            if not bids:
                continue
            lowest = bids[0]['price_lkr']
            highest = bids[-1]['price_lkr']
            total_min += lowest
            total_max += highest
            parts_with_bids.append({
                'part_name': part_name,
                'bids': bids,
                'lowest_bid_lkr': lowest,
                'highest_bid_lkr': highest,
            })

        print(f"✅ Generated bids for {len(parts_with_bids)} parts (total: LKR {total_min:,.0f}–{total_max:,.0f})")
        return {
            'damage_type': damage_type,
            'vehicle_info': vehicle_info,
            'parts_needed': parts_with_bids,
            'total_min_cost_lkr': total_min,
            'total_max_cost_lkr': total_max,
        }


class ReportGenerator:
    """Generates comprehensive damage assessment reports"""
    
    def __init__(self):
        print("🔧 ReportGenerator initialized")
    
    def generate_text_report(self, damage_info, gemini_analysis, recommendations, distances,
                              towing_options=None, spare_parts_bids=None):
        """
        Generate a comprehensive text report
        
        Args:
            damage_info: Damage detection results
            gemini_analysis: Gemini AI analysis
            recommendations: Top garage recommendations
            distances: Distance information
            
        Returns:
            str: Complete report text
        """
        report = f"""
{'='*80}
        VEHICLE DAMAGE ASSESSMENT REPORT
        Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}
{'='*80}

1. DAMAGE DETECTION (AI Model - ResNet-18)
{'-'*80}
Damage Type: {damage_info['damage_type'].upper()}
Severity Score: {damage_info['severity_score']}/2
Confidence: {damage_info['confidence']:.1%}

Probability Distribution:
"""
        for damage_type, prob in damage_info['probabilities'].items():
            report += f"  • {damage_type.capitalize()}: {prob:.1%}\n"
        
        report += f"""
2. DETAILED ANALYSIS (Gemini AI)
{'-'*80}
{gemini_analysis}

3. RECOMMENDED GARAGES
{'-'*80}
"""
        
        for i, rec in enumerate(recommendations, 1):
            garage = rec['garage']
            dist_info = distances[i-1] if i-1 < len(distances) else {}
            
            report += f"""
{i}. {garage['name']}
   {'─'*76}
   Address: {garage['address']}
   Google Rating: {garage['rating']}/5.0 ({garage['total_ratings']} reviews)
   
   Distance: {dist_info.get('distance_text', 'N/A')}
   Travel Time: {dist_info.get('duration_text', 'N/A')}
   
   ML Satisfaction Score: {rec['ml_satisfaction_score']:.1%}
   Final Recommendation Score: {rec['final_score']:.1%}
   
   Currently Open: {'Yes' if garage['open_now'] else 'No' if garage['open_now'] is not None else 'Unknown'}
   
   Google Maps: https://www.google.com/maps/place/?q=place_id:{garage['place_id']}
   
"""
        
        # Section 4: Towing Options
        if towing_options:
            report += f"""
4. TOWING OPTIONS
{'-'*80}
"""
            for i, t in enumerate(towing_options, 1):
                avail = "✅ Yes" if t.get('available_24h') else "❌ No"
                flatbed = "✅ Yes" if t.get('flatbed_available') else "❌ No"
                report += f"""
{i}. {t['name']} — {t['city']}
   Rating: ⭐ {t['rating']} ({t['num_reviews']} reviews)
   Distance: {t['distance_km']} km  |  ETA: ~{t['avg_eta_minutes']} minutes
   Estimated Cost: LKR {t['estimated_cost_lkr']:,.0f}  (Base: LKR {t['base_fee_lkr']:,.0f} + LKR {t['rate_per_km_lkr']}/km)
   24h Service: {avail}  |  Flatbed: {flatbed}
   Phone: {t['phone']}
"""

        # Section 5: Spare Parts Bids
        if spare_parts_bids and spare_parts_bids.get('parts_needed'):
            report += f"""
5. SPARE PARTS COST ESTIMATES (Bidding Platform)
{'-'*80}
Vehicle: {spare_parts_bids.get('vehicle_info', 'N/A')}
"""
            for part in spare_parts_bids['parts_needed']:
                best_vendor = part['bids'][0] if part['bids'] else {}
                report += f"""
Part: {part['part_name']}
   Best Price: LKR {part['lowest_bid_lkr']:,.0f} — {best_vendor.get('vendor_name', 'N/A')} (⭐ {best_vendor.get('rating', 'N/A')})
   Price Range: LKR {part['lowest_bid_lkr']:,.0f} – LKR {part['highest_bid_lkr']:,.0f}
   Top Bids:"""
                for bid in part['bids'][:3]:
                    report += f"\n     • {bid['vendor_name']} ({bid['city']}): LKR {bid['price_lkr']:,.0f} | {bid['lead_time_days']}d delivery | {bid['warranty_months']}m warranty"
                report += "\n"
            report += f"""
TOTAL ESTIMATED PARTS COST: LKR {spare_parts_bids['total_min_cost_lkr']:,.0f} – LKR {spare_parts_bids['total_max_cost_lkr']:,.0f}
"""

        report += f"""
{'='*80}
NEXT STEPS
{'='*80}
1. Review the recommended garages above
2. Contact your preferred garage for an appointment
3. Share this report with the garage for accurate cost estimation
4. Book a towing service if your vehicle is not driveable
5. Compare spare parts bids to minimize repair costs
6. Keep this report for insurance claim processing (if applicable)

DISCLAIMER: This is an AI-generated assessment. Towing costs and spare parts prices
are estimates. Final repair costs should be confirmed with the selected service provider.
{'='*80}
"""

        return report
    
    def save_report(self, report_text, output_path='damage_assessment_report.txt'):
        """Save report to file"""
        try:
            with open(output_path, 'w', encoding='utf-8') as f:
                f.write(report_text)
            print(f"✅ Report saved: {output_path}")
            return output_path
        except Exception as e:
            print(f"❌ Error saving report: {e}")
            return None


class VehicleDamageAssessmentSystem:
    """Main system integrating all components"""
    
    def __init__(self, config):
        self.config = config
        
        # Initialize components
        self.damage_detector = DamageDetector(config.DAMAGE_MODEL_PATH)
        self.gemini_analyzer = GeminiAnalyzer(config.GEMINI_API_KEY)
        self.google_maps = GoogleMapsService(config.GOOGLE_MAPS_API_KEY)
        self.garage_recommender = GarageRecommender(
            config.GARAGE_MODEL_PATH,
            config.GARAGES_DATA_PATH
        )
        self.report_generator = ReportGenerator()
        self.towing_finder = TowingServiceFinder(config.TOWING_DATA_PATH)
        self.spare_parts_bidder = SparePartsBidder(
            parts_path=config.SPARE_PARTS_PATH,
            damage_ref_path=config.DAMAGE_REF_PATH,
            vendors_path=config.SPARE_PARTS_VENDORS_PATH,
        )
        
        print("\n" + "="*80)
        print("🚗 VEHICLE DAMAGE ASSESSMENT SYSTEM INITIALIZED")
        print("="*80 + "\n")
    
    def load_models(self):
        """Load all required models"""
        print("📦 Loading models...\n")
        
        success = True
        success &= self.damage_detector.load_model()
        success &= self.garage_recommender.load_model()
        success &= self.garage_recommender.load_garage_data()
        self.towing_finder.load_data()
        self.spare_parts_bidder.load_data()
        
        if success:
            print("\n✅ All models loaded successfully!\n")
        else:
            print("\n❌ Some models failed to load!\n")
        
        return success
    
    def process_damage_image(self, image_path, user_location):
        """
        Complete end-to-end damage assessment pipeline
        
        Args:
            image_path: Path to damage image
            user_location: tuple (latitude, longitude)
            
        Returns:
            dict: Complete assessment results
        """
        print("\n" + "="*80)
        print("🔍 STARTING DAMAGE ASSESSMENT PIPELINE")
        print("="*80 + "\n")
        
        # Step 1: Damage Detection
        print("STEP 1: Detecting damage from image...")
        damage_info = self.damage_detector.predict(image_path)
        if damage_info is None:
            return {'error': 'Damage detection failed'}
        print()
        
        # Step 2: Gemini AI Analysis
        print("STEP 2: Analyzing damage with Gemini AI...")
        gemini_analysis = self.gemini_analyzer.analyze_damage(image_path, damage_info)
        if gemini_analysis is None:
            gemini_analysis = "Analysis unavailable"
        print()
        
        # Step 3: Find nearby garages
        print("STEP 3: Finding nearby garages...")
        google_garages = self.google_maps.find_nearby_garages(user_location)
        if not google_garages:
            return {'error': 'No garages found nearby'}
        print()
        
        # Step 4: Calculate distances
        print("STEP 4: Calculating distances and travel times...")
        garage_locations = [(g['latitude'], g['longitude']) for g in google_garages]
        distances = self.google_maps.get_distance_matrix(user_location, garage_locations)
        
        # Add distance info to garages
        for i, garage in enumerate(google_garages):
            if i < len(distances):
                garage['distance_km'] = distances[i]['distance_km']
                garage['distance_text'] = distances[i]['distance_text']
                garage['duration_text'] = distances[i]['duration_text']
        print()
        
        # Step 5: ML-based recommendations
        print("STEP 5: Generating ML-based garage recommendations...")
        recommendations = self.garage_recommender.recommend(
            user_location, damage_info, google_garages, top_k=5
        )
        print()
        
        # Step 6: Generate report
        print("STEP 6: Generating comprehensive report...")
        report_text = self.report_generator.generate_text_report(
            damage_info, gemini_analysis, recommendations, distances
        )
        
        # Save report
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        report_path = f'damage_report_{timestamp}.txt'
        self.report_generator.save_report(report_text, report_path)
        print()
        
        print("="*80)
        print("✅ DAMAGE ASSESSMENT COMPLETE!")
        print("="*80 + "\n")
        
        # Return results
        return {
            'damage_info': damage_info,
            'gemini_analysis': gemini_analysis,
            'recommendations': recommendations,
            'report_text': report_text,
            'report_path': report_path
        }


def main():
    """Main execution function"""
    
    print("\n" + "="*80)
    print("🚗 VEHICLE DAMAGE ASSESSMENT & GARAGE RECOMMENDATION SYSTEM")
    print("   RoadResQ - Smart Repair Locator")
    
    print("="*80 + "\n")
    
    # Configuration
    config = Config()
    
    # Check if API keys are set
    if config.GOOGLE_MAPS_API_KEY == 'AIzaSyA4WKCnwVoO_AddbRreuViqH1cNsNSZ1hs':
        print("⚠️  Warning: Please set your Google Maps API key in Config class")
    if config.GEMINI_API_KEY == 'AIzaSyDYCz9POfhc6pBuEd-wX1IYOu4sBW3H8Yo':
        print("⚠️  Warning: Please set your Gemini API key in Config class")
    
    # Initialize system
    system = VehicleDamageAssessmentSystem(config)
    
    # Load models
    if not system.load_models():
        print("❌ Failed to load models. Exiting...")
        return
    
    # Example usage
    print("="*80)
    print("EXAMPLE USAGE")
    print("="*80 + "\n")
    
    # Example: Process a damage image
    image_path = 'path/to/damage/image.jpg'  # Replace with actual path
    user_location = (6.9271, 79.8612)  # Colombo, Sri Lanka
    
    print(f"📸 Image: {image_path}")
    print(f"📍 Location: {user_location[0]}, {user_location[1]}\n")
    
    # Uncomment to run actual assessment
    # results = system.process_damage_image(image_path, user_location)
    # 
    # if 'error' not in results:
    #     print("\n" + "="*80)
    #     print("📊 RESULTS SUMMARY")
    #     print("="*80)
    #     print(f"\nDamage Type: {results['damage_info']['damage_type']}")
    #     print(f"Confidence: {results['damage_info']['confidence']:.1%}")
    #     print(f"\nTop Recommendation: {results['recommendations'][0]['garage']['name']}")
    #     print(f"Recommendation Score: {results['recommendations'][0]['final_score']:.1%}")
    #     print(f"\n📄 Full report saved: {results['report_path']}")
    
    print("\n✅ System ready for use!")
    print("\n💡 To use this system:")
    print("   1. Set your API keys in the Config class")
    print("   2. Provide a damage image path")
    print("   3. Provide user location (latitude, longitude)")
    print("   4. Call: system.process_damage_image(image_path, user_location)")


if __name__ == "__main__":
    main()
