"""

API Endpoints:
- POST /detect-damage: Upload image and get damage analysis
- POST /recommend-garages: Get garage recommendations
- POST /complete-assessment: Full end-to-end pipeline
- GET /health: Health check
"""

from fastapi import FastAPI, File, UploadFile, HTTPException, Form, Request
from fastapi.responses import JSONResponse, FileResponse
from starlette.exceptions import HTTPException as StarletteHTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from typing import List, Optional, Dict
import uvicorn
import os
import io
import shutil
from datetime import datetime
import tempfile
from PIL import Image

# Import our integration system
from complete_integration import (
    VehicleDamageAssessmentSystem,
    Config,
    DamageDetector,
    GeminiAnalyzer,
    GoogleMapsService,
    GarageRecommender,
    ReportGenerator,
    TowingServiceFinder,
    SparePartsBidder,
)

# Initialize FastAPI app
app = FastAPI(
    title="RoadResQ API",
    description="Vehicle Damage Assessment & Garage Recommendation System",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc"
)

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, specify actual origins
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Global system instance
system = None
config = Config()


# Pydantic models for request/response
class LocationModel(BaseModel):
    latitude: float = Field(..., ge=-90, le=90, description="Latitude")
    longitude: float = Field(..., ge=-180, le=180, description="Longitude")


class DamageDetails(BaseModel):
    description: str
    what_happened: str
    immediate_actions: List[str]
    repair_options: List[str]
    urgency: str
    estimated_time: str
    prevention_tips: str


class DamageDetectionResponse(BaseModel):
    damage_type: str
    severity_score: int
    confidence: float
    probabilities: Dict[str, float]
    detected_damages: List[str]
    damage_details: DamageDetails


class GarageRecommendation(BaseModel):
    name: str
    address: str
    rating: float
    total_ratings: int
    latitude: float
    longitude: float
    distance_km: Optional[float]
    distance_text: Optional[str]
    duration_text: Optional[str]
    ml_satisfaction_score: float
    final_score: float
    google_maps_link: str
    place_id: str


class CompletionAssessmentResponse(BaseModel):
    damage_info: DamageDetectionResponse
    gemini_analysis: str
    recommendations: List[GarageRecommendation]
    report_path: str
    timestamp: str


# ── Towing Models ──────────────────────────────────────────────────────────────

class TowingRequest(BaseModel):
    latitude: float = Field(..., ge=-90, le=90)
    longitude: float = Field(..., ge=-180, le=180)
    max_results: int = Field(5, ge=1, le=10)


class TowingOptionResponse(BaseModel):
    towing_id: str
    name: str
    phone: str
    city: str
    distance_km: float
    base_fee_lkr: float
    rate_per_km_lkr: float
    estimated_cost_lkr: float
    avg_eta_minutes: int
    rating: float
    num_reviews: int
    available_24h: bool
    flatbed_available: bool
    vehicle_types: List[str]


class TowingBookingRequest(BaseModel):
    towing_id: str
    latitude: float = Field(..., ge=-90, le=90)
    longitude: float = Field(..., ge=-180, le=180)
    destination: Optional[str] = None


class TowingBookingResponse(BaseModel):
    booking_ref: str
    towing_service: str
    status: str
    estimated_arrival_minutes: int
    message: str


# ── Spare Parts Bidding Models ─────────────────────────────────────────────────

class SparePartsRequest(BaseModel):
    damage_type: str
    vehicle_make: str = "Toyota"
    vehicle_model: Optional[str] = None
    vehicle_year: Optional[int] = None
    user_latitude: Optional[float] = None   # user's location for proximity sorting
    user_longitude: Optional[float] = None


class SparePartBidResponse(BaseModel):
    vendor_id: str
    vendor_name: str
    phone: str
    city: str
    price_lkr: float
    lead_time_days: int
    warranty_months: int
    rating: float


class PartWithBidsResponse(BaseModel):
    part_name: str
    bids: List[SparePartBidResponse]
    lowest_bid_lkr: float
    highest_bid_lkr: float


class SparePartsBidsResponse(BaseModel):
    damage_type: str
    vehicle_info: str
    parts_needed: List[PartWithBidsResponse]
    total_min_cost_lkr: float
    total_max_cost_lkr: float


# Startup event
@app.on_event("startup")
async def startup_event():
    """Initialize the system on startup"""
    global system
    
    print("\n" + "="*80)
    print("🚀 STARTING ROADRESQ API SERVER")
    print("="*80 + "\n")
    
    # Initialize system
    system = VehicleDamageAssessmentSystem(config)
    
    # Load models
    if not system.load_models():
        print("❌ Failed to load models!")
    else:
        print("✅ All models loaded successfully!")
    
    print("\n" + "="*80)
    print("✅ API SERVER READY")
    print("="*80 + "\n")


# Shutdown event
@app.on_event("shutdown")
async def shutdown_event():
    """Cleanup on shutdown"""
    print("\n🛑 Shutting down API server...")


@app.get("/", tags=["Root"])
async def root():
    """Root endpoint"""
    return {
        "message": "Welcome to RoadResQ API",
        "version": "1.0.0",
        "status": "active",
        "endpoints": {
            "health": "/health",
            "docs": "/docs",
            "detect_damage": "POST /detect-damage",
            "recommend_garages": "POST /recommend-garages",
            "complete_assessment": "POST /complete-assessment"
        }
    }


@app.get("/health", tags=["Health"])
async def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "timestamp": datetime.now().isoformat(),
        "models_loaded": system is not None,
        "version": "1.0.0"
    }


@app.post("/detect-damage", tags=["Damage Detection"], response_model=DamageDetectionResponse)
async def detect_damage(
    image: UploadFile = File(..., description="Vehicle damage image")
):
    """
    Detect vehicle damage from uploaded image
    
    - **image**: Upload an image file (JPG, PNG)
    
    Returns damage type, severity, and confidence scores
    """
    if system is None:
        raise HTTPException(status_code=503, detail="System not initialized")

    # Validate file type
    if not image.content_type.startswith('image/'):
        raise HTTPException(status_code=400, detail="File must be an image")

    tmp_path = None
    try:
        # Read bytes upfront so we can (a) run vehicle check and (b) write tempfile
        image_bytes = await image.read()
        pil_image = Image.open(io.BytesIO(image_bytes)).convert('RGB')

        # Vehicle presence check — reject non-vehicle images before damage detection
        vehicle_check = system.gemini_analyzer.check_is_vehicle(pil_image)
        if not vehicle_check.get("is_vehicle", True):
            detected_obj = vehicle_check.get("detected_object", "a non-vehicle object")
            raise HTTPException(
                status_code=400,
                detail=f"This image appears to show {detected_obj}, not a vehicle. "
                       f"Please upload a photo of a damaged vehicle."
            )

        # Save to tempfile for damage model
        with tempfile.NamedTemporaryFile(delete=False, suffix='.jpg') as tmp_file:
            tmp_file.write(image_bytes)
            tmp_path = tmp_file.name

        # Detect damage
        damage_info = system.damage_detector.predict(tmp_path)

        if damage_info is None:
            raise HTTPException(status_code=500, detail="Damage detection failed")

        return DamageDetectionResponse(**damage_info)

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error processing image: {str(e)}")
    finally:
        if tmp_path and os.path.exists(tmp_path):
            os.unlink(tmp_path)


@app.post("/recommend-garages", tags=["Recommendations"], response_model=List[GarageRecommendation])
@app.post("/recommend-garages/", tags=["Recommendations"], response_model=List[GarageRecommendation], include_in_schema=False)
@app.post("/recommend_garages", tags=["Recommendations"], response_model=List[GarageRecommendation], include_in_schema=False)
@app.post("/recommend_garages/", tags=["Recommendations"], response_model=List[GarageRecommendation], include_in_schema=False)
async def recommend_garages(
    latitude: float = Form(..., ge=-90, le=90),
    longitude: float = Form(..., ge=-180, le=180),
    damage_type: str = Form(..., description="Damage type: minor, moderate, severe"),
    max_results: int = Form(5, ge=1, le=20)
):
    """
    Get garage recommendations based on location and damage type
    
    - **latitude**: User's latitude
    - **longitude**: User's longitude  
    - **damage_type**: Type of damage (minor/moderate/severe)
    - **max_results**: Number of recommendations (default: 5)
    
    Returns list of recommended garages with scores
    """
    if system is None:
        raise HTTPException(status_code=503, detail="System not initialized")
    
    try:
        user_location = (latitude, longitude)
        
        # Validate damage type
        if damage_type not in Config.DAMAGE_CLASSES:
            raise HTTPException(
                status_code=400, 
                detail=f"Invalid damage_type. Must be one of: {Config.DAMAGE_CLASSES}"
            )
        
        # Find nearby garages from Google Maps first.
        google_garages = system.google_maps.find_nearby_garages(user_location)
        used_local_fallback = False

        # Fallback to local garage dataset when Google Places returns no results.
        if not google_garages:
            garages_df = getattr(system.garage_recommender, "garages_df", None)
            if garages_df is None or garages_df.empty:
                raise HTTPException(status_code=404, detail="No garages found nearby")

            fallback_candidates = []
            for _, row in garages_df.iterrows():
                lat = float(row.get("latitude", 0.0))
                lon = float(row.get("longitude", 0.0))
                distance_km = system.garage_recommender.calculate_distance(
                    user_location[0], user_location[1], lat, lon
                )
                garage_id = str(row.get("garage_id", f"local_{len(fallback_candidates)}"))
                city = str(row.get("city", "Sri Lanka"))
                fallback_candidates.append({
                    "name": str(row.get("name", "Local Garage")),
                    "address": f"{city}, Sri Lanka",
                    "location": {"lat": lat, "lng": lon},
                    "latitude": lat,
                    "longitude": lon,
                    "rating": float(row.get("avg_rating", 4.0)),
                    "total_ratings": int(row.get("num_reviews", 0)),
                    "place_id": garage_id,
                    "open_now": None,
                    "distance_km": distance_km,
                    "distance_text": f"{distance_km:.1f} km",
                    "duration_text": None,
                    "is_local_fallback": True,
                })

            fallback_candidates.sort(key=lambda g: g["distance_km"])
            google_garages = fallback_candidates[:max(20, max_results * 4)]
            used_local_fallback = True

        # Calculate route-based distance/time only for Google results.
        if not used_local_fallback:
            garage_locations = [(g['latitude'], g['longitude']) for g in google_garages]
            distances = system.google_maps.get_distance_matrix(user_location, garage_locations)

            for i, garage in enumerate(google_garages):
                if i < len(distances):
                    garage['distance_km'] = distances[i]['distance_km']
                    garage['distance_text'] = distances[i]['distance_text']
                    garage['duration_text'] = distances[i]['duration_text']
        
        # Create damage info for ML model
        damage_info = {
            'damage_type': damage_type,
            'severity_score': Config.DAMAGE_CLASSES.index(damage_type),
            'confidence': 0.85  # Default
        }
        
        # Get recommendations
        recommendations = system.garage_recommender.recommend(
            user_location, damage_info, google_garages, top_k=max_results
        )
        
        # Format response
        response = []
        for rec in recommendations:
            garage = rec['garage']
            response.append(GarageRecommendation(
                name=garage['name'],
                address=garage['address'],
                rating=garage['rating'],
                total_ratings=garage['total_ratings'],
                latitude=garage['latitude'],
                longitude=garage['longitude'],
                distance_km=garage.get('distance_km'),
                distance_text=garage.get('distance_text'),
                duration_text=garage.get('duration_text'),
                ml_satisfaction_score=rec['ml_satisfaction_score'],
                final_score=rec['final_score'],
                google_maps_link=(
                    f"https://www.google.com/maps/search/?api=1&query={garage['latitude']},{garage['longitude']}"
                    if garage.get("is_local_fallback")
                    else f"https://www.google.com/maps/place/?q=place_id:{garage['place_id']}"
                ),
                place_id=garage['place_id']
            ))

        return response
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error generating recommendations: {str(e)}")


@app.post("/complete-assessment", tags=["Complete Pipeline"])
async def complete_assessment(
    image: UploadFile = File(..., description="Vehicle damage image"),
    latitude: float = Form(..., ge=-90, le=90),
    longitude: float = Form(..., ge=-180, le=180)
):
    """
    Complete end-to-end damage assessment pipeline
    
    - **image**: Vehicle damage image
    - **latitude**: User's latitude
    - **longitude**: User's longitude
    
    Returns complete assessment including:
    - Damage detection results
    - Gemini AI analysis
    - Top 5 garage recommendations
    - Downloadable report
    """
    if system is None:
        raise HTTPException(status_code=503, detail="System not initialized")

    # Validate file type
    if not image.content_type.startswith('image/'):
        raise HTTPException(status_code=400, detail="File must be an image")

    tmp_path = None
    try:
        # Read bytes upfront so we can (a) run vehicle check and (b) write tempfile
        image_bytes = await image.read()
        pil_image = Image.open(io.BytesIO(image_bytes)).convert('RGB')

        # Vehicle presence check — reject non-vehicle images before the full pipeline
        vehicle_check = system.gemini_analyzer.check_is_vehicle(pil_image)
        if not vehicle_check.get("is_vehicle", True):
            detected_obj = vehicle_check.get("detected_object", "a non-vehicle object")
            raise HTTPException(
                status_code=400,
                detail=f"This image appears to show {detected_obj}, not a vehicle. "
                       f"Please upload a photo of a damaged vehicle."
            )

        # Save to tempfile for the pipeline
        with tempfile.NamedTemporaryFile(delete=False, suffix='.jpg') as tmp_file:
            tmp_file.write(image_bytes)
            tmp_path = tmp_file.name

        user_location = (latitude, longitude)

        # Run complete assessment
        results = system.process_damage_image(tmp_path, user_location)

        if 'error' in results:
            raise HTTPException(status_code=500, detail=results['error'])
        
        # Format recommendations
        formatted_recs = []
        for rec in results['recommendations']:
            garage = rec['garage']
            formatted_recs.append({
                'name': garage['name'],
                'address': garage['address'],
                'rating': garage['rating'],
                'total_ratings': garage['total_ratings'],
                'distance_km': garage.get('distance_km'),
                'distance_text': garage.get('distance_text'),
                'duration_text': garage.get('duration_text'),
                'ml_satisfaction_score': rec['ml_satisfaction_score'],
                'final_score': rec['final_score'],
                'google_maps_link': f"https://www.google.com/maps/place/?q=place_id:{garage['place_id']}",
                'place_id': garage['place_id']
            })
        
        return {
            'damage_info': results['damage_info'],
            'gemini_analysis': results['gemini_analysis'],
            'recommendations': formatted_recs,
            'report_path': results['report_path'],
            'timestamp': datetime.now().isoformat()
        }
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error in complete assessment: {str(e)}")
    finally:
        if tmp_path and os.path.exists(tmp_path):
            os.unlink(tmp_path)


@app.get("/download-report/{report_filename}", tags=["Reports"])
async def download_report(report_filename: str):
    """
    Download a generated report
    
    - **report_filename**: Name of the report file
    """
    if not os.path.exists(report_filename):
        raise HTTPException(status_code=404, detail="Report not found")
    
    return FileResponse(
        report_filename,
        media_type='text/plain',
        filename=report_filename
    )


# Error handlers
@app.exception_handler(StarletteHTTPException)
async def http_exception_handler(request: Request, exc: StarletteHTTPException):
    if exc.status_code == 404 and exc.detail == "Not Found":
        # Only override generic routing 404s (route not found), not app-level ones
        return JSONResponse(
            status_code=404,
            content={
                "error": "Not Found",
                "message": "The requested resource was not found",
                "path": str(request.url)
            }
        )
    return JSONResponse(
        status_code=exc.status_code,
        content={"error": str(exc.status_code), "detail": exc.detail}
    )


@app.exception_handler(500)
async def internal_error_handler(request, exc):
    return JSONResponse(
        status_code=500,
        content={
            "error": "Internal Server Error",
            "message": "An internal error occurred. Please try again later."
        }
    )


# ── Towing Endpoints ───────────────────────────────────────────────────────────

@app.post("/find-towing", response_model=List[TowingOptionResponse], tags=["Towing"])
async def find_towing(request: TowingRequest):
    """
    Find nearby towing services and estimated costs.

    Returns a list of towing operators sorted by distance from the provided location.
    """
    if system is None:
        raise HTTPException(status_code=503, detail="System not initialized")
    try:
        results = system.towing_finder.find_nearby(
            request.latitude, request.longitude, request.max_results
        )
        if not results:
            raise HTTPException(
                status_code=404,
                detail="No towing services found within range of your location"
            )
        return results
    except HTTPException:
        raise
    except Exception as e:
        print(f"❌ Towing search error: {e}")
        raise HTTPException(status_code=500, detail=f"Towing search failed: {str(e)}")


@app.post("/book-towing", response_model=TowingBookingResponse, tags=["Towing"])
async def book_towing(request: TowingBookingRequest):
    """
    Simulate booking a towing service.

    Returns a booking reference number and estimated arrival time.
    """
    if system is None:
        raise HTTPException(status_code=503, detail="System not initialized")
    try:
        result = system.towing_finder.book_towing(
            request.towing_id, request.latitude, request.longitude, request.destination
        )
        return result
    except Exception as e:
        print(f"❌ Towing booking error: {e}")
        raise HTTPException(status_code=500, detail=f"Booking failed: {str(e)}")


# ── Spare Parts Bidding Endpoints ──────────────────────────────────────────────

@app.post("/get-spare-parts-bids", response_model=SparePartsBidsResponse, tags=["Spare Parts"])
async def get_spare_parts_bids(request: SparePartsRequest):
    """
    Get competitive vendor bids for spare parts required to repair the detected damage.

    Automatically identifies which parts are needed based on damage type,
    then generates competitive price bids from multiple vendors.
    """
    if system is None:
        raise HTTPException(status_code=503, detail="System not initialized")
    try:
        result = system.spare_parts_bidder.get_all_bids(
            damage_type=request.damage_type,
            vehicle_make=request.vehicle_make,
            vehicle_model=request.vehicle_model,
            vehicle_year=request.vehicle_year,
            user_lat=request.user_latitude,
            user_lon=request.user_longitude,
        )
        if not result or not result.get("parts_needed"):
            raise HTTPException(
                status_code=404,
                detail=f"No parts data found for damage type: {request.damage_type}"
            )
        return result
    except HTTPException:
        raise
    except Exception as e:
        print(f"❌ Spare parts bids error: {e}")
        raise HTTPException(status_code=500, detail=f"Spare parts query failed: {str(e)}")


# Run the application
if __name__ == "__main__":
    port = int(os.getenv("PORT", os.getenv("API_PORT", "8002")))

    print("\n" + "="*80)
    print("🚀 STARTING ROADRESQ FASTAPI SERVER")
    print("="*80 + "\n")
    print(f"📚 API Documentation: http://localhost:{port}/docs")
    print(f"📖 ReDoc: http://localhost:{port}/redoc")
    print(f"🏥 Health Check: http://localhost:{port}/health")
    print("\n" + "="*80 + "\n")

    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=port,
        reload=True,
        log_level="info"
    )
