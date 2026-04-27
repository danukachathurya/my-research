"""
Vehicle Troubleshooting Chatbot - FastAPI Backend Server with Firebase

This is the REST API server that connects Flutter app with the chatbot backend.

Author: Vehicle Chatbot Team
Date: 2025
"""

from fastapi import FastAPI, File, UploadFile, HTTPException, Depends, Form, Request
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional, List, Dict, Any
import os
import sys
from datetime import datetime
from pathlib import Path
from PIL import Image
import io
import base64
import json as json_module

# Add project root to path
project_root = Path(__file__).parent.parent.parent
sys.path.insert(0, str(project_root))

from src.core.chatbot_core import VehicleChatbot
from src.api.gemini_api import GeminiAPI

# Optional Firebase imports - only needed if ENABLE_FIREBASE=1
try:
    import firebase_admin
    from firebase_admin import credentials, firestore, storage
    FIREBASE_AVAILABLE = True
except ImportError:
    FIREBASE_AVAILABLE = False
    print(">>> Firebase module not installed - running in NO-DATABASE mode")


# Initialize FastAPI app
app = FastAPI(
    title="Vehicle Troubleshooting Chatbot API",
    description="API for Sri Lankan vehicle troubleshooting chatbot",
    version="1.0.0"
)

# CORS middleware for Flutter app
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, specify Flutter app domain
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Initialize Firebase (OPTIONAL - disabled by default for testing)
# Set ENABLE_FIREBASE=1 environment variable to enable Firebase
db = None
bucket = None

if os.getenv('ENABLE_FIREBASE') == '1' and FIREBASE_AVAILABLE:
    try:
        cred = credentials.Certificate(project_root / 'config' / 'firebase-credentials.json')
        firebase_admin.initialize_app(cred, {
            'storageBucket': 'vehicle-project-97147.appspot.com'
        })
        db = firestore.client()
        bucket = storage.bucket()
        print(">>> Firebase enabled and initialized")
    except Exception as e:
        print(f">>> WARNING: Firebase initialization error: {e}")
        print("   Continuing in NO-DATABASE mode")
        db = None
        bucket = None
else:
    print("\n" + "="*70)
    print(">>> Running in NO-DATABASE MODE (Firebase disabled)")
    print("="*70)
    print("\n>>> WHAT WORKS:")
    print("   - AI chatbot responses (Gemini API)")
    print("   - Knowledge base search (250+ vehicle issues)")
    print("   - Fallback diagnostic questions")
    print("   - Warning light detection")
    print("   - Text translation")
    print("\n>>> WHAT DOES NOT WORK:")
    print("   - Saving conversation history")
    print("   - Storing uploaded images permanently")
    print("\n>>> This is PERFECT for testing the chatbot!")
    print("   To enable Firebase: set ENABLE_FIREBASE=1")
    print("="*70 + "\n")

# Initialize Chatbot
chatbot = None
try:
    # Set API key if not already set
    if not os.getenv('GEMINI_API_KEY'):
        os.environ['GEMINI_API_KEY'] = 'AIzaSyDYCz9POfhc6pBuEd-wX1IYOu4sBW3H8Yo'

    chatbot = VehicleChatbot(
        gemini_api_key=os.getenv('GEMINI_API_KEY'),
        main_dataset_path=str(project_root / 'data' / 'sri_lanka_vehicle_dataset_5models_englishonly.xlsx'),
        fallback_dataset_path=str(project_root / 'data' / 'fallback_dataset.xlsx')
    )
    print(">>> Chatbot initialized successfully")
except Exception as e:
    print(f">>> ERROR: Chatbot initialization failed: {e}")


# Pydantic models for request/response
class StartConversationRequest(BaseModel):
    user_id: str
    language: str = 'english'


class SendMessageRequest(BaseModel):
    session_id: str
    message: str
    image_base64: Optional[str] = None


class EndConversationRequest(BaseModel):
    session_id: str


class FeedbackRequest(BaseModel):
    session_id: str
    user_id: str
    rating: int
    comment: Optional[str] = None
    was_helpful: bool


class TranslateRequest(BaseModel):
    text: str
    source_lang: str
    target_lang: str


# API Endpoints

@app.get("/")
async def root():
    """API health check"""
    return {
        "status": "online",
        "service": "Vehicle Troubleshooting Chatbot API",
        "version": "1.0.0",
        "firebase": "connected" if db else "disconnected",
        "chatbot": "ready" if chatbot else "not initialized"
    }


@app.post("/api/conversation/start")
async def start_conversation(request: StartConversationRequest):
    """
    Start a new conversation session

    Returns:
        session_id, greeting message
    """
    if not chatbot:
        raise HTTPException(status_code=503, detail="Chatbot not initialized")

    try:
        # Start chatbot conversation
        result = chatbot.start_conversation(request.user_id, request.language)

        # Save to Firebase
        if db:
            conversation_ref = db.collection('conversations').document(result['session_id'])
            conversation_ref.set({
                'session_id': result['session_id'],
                'user_id': request.user_id,
                'language': request.language,
                'state': 'initial',
                'context': {},
                'created_at': firestore.SERVER_TIMESTAMP,
                'last_updated': firestore.SERVER_TIMESTAMP,
                'is_active': True
            })

            # Add greeting message
            conversation_ref.collection('messages').add({
                'role': 'bot',
                'content': result['message'],
                'timestamp': firestore.SERVER_TIMESTAMP,
                'message_type': 'text'
            })

        return {
            "success": True,
            "session_id": result['session_id'],
            "message": result['message'],
            "language": request.language
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/api/conversation/message")
async def send_message(request: Request):
    """
    Send message to chatbot

    Handles:
    - Text messages (JSON or form-data)
    - Image uploads (base64 in JSON or multipart file upload)
    """
    if not chatbot:
        raise HTTPException(status_code=503, detail="Chatbot not initialized")

    try:
        session_id = None
        message = None
        image_base64_data = None
        image_obj = None

        # Determine content type and parse accordingly
        content_type = request.headers.get('content-type', '')

        if 'application/json' in content_type:
            # Handle JSON request
            body = await request.json()
            session_id = body.get('session_id')
            message = body.get('message')
            image_base64_data = body.get('image_base64')

            # Handle base64 image from JSON
            if image_base64_data:
                image_data = base64.b64decode(image_base64_data)
                image_obj = Image.open(io.BytesIO(image_data))

        elif 'multipart/form-data' in content_type:
            # Handle multipart form data
            form = await request.form()
            session_id = form.get('session_id')
            message = form.get('message')
            image_base64_data = form.get('image_base64')

            # Handle base64 image from form
            if image_base64_data:
                image_data = base64.b64decode(image_base64_data)
                image_obj = Image.open(io.BytesIO(image_data))

            # Handle file upload from form
            if 'image' in form:
                image_file = form['image']
                if hasattr(image_file, 'read'):
                    image_data = await image_file.read()
                    image_obj = Image.open(io.BytesIO(image_data))

        else:
            raise HTTPException(status_code=400, detail="Unsupported content type")

        # Validate required fields
        if not session_id:
            raise HTTPException(status_code=400, detail="session_id is required")

        # Default message
        if not message:
            message = "Image uploaded for analysis" if image_obj else ""

        # Process message
        response = chatbot.process_message(
            session_id,
            message,
            image=image_obj
        )

        # Save to Firebase
        if db:
            conversation_ref = db.collection('conversations').document(session_id)
            messages_ref = conversation_ref.collection('messages')

            # Save user message
            messages_ref.add({
                'role': 'user',
                'content': message,
                'timestamp': firestore.SERVER_TIMESTAMP,
                'message_type': 'image' if image_obj else 'text'
            })

            # Save bot response
            messages_ref.add({
                'role': 'bot',
                'content': response.get('message', ''),
                'timestamp': firestore.SERVER_TIMESTAMP,
                'message_type': 'text',
                'metadata': {
                    'status': response.get('status'),
                    'source': response.get('source'),
                    'confidence': response.get('confidence')
                }
            })

            # Update conversation
            conversation_ref.update({
                'last_updated': firestore.SERVER_TIMESTAMP,
                'state': response.get('status', 'unknown')
            })

            # Save warning light scan if applicable
            if response.get('source') == 'warning_light' and image_obj:
                db.collection('warning_light_scans').add({
                    'session_id': session_id,
                    'detected_lights': response.get('detected_lights', []),
                    'severity': response.get('severity', {}),
                    'timestamp': firestore.SERVER_TIMESTAMP
                })

        return {
            "success": True,
            "session_id": session_id,
            **response
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/api/conversation/end")
async def end_conversation(request: EndConversationRequest):
    """End conversation session"""
    if not chatbot:
        raise HTTPException(status_code=503, detail="Chatbot not initialized")

    try:
        result = chatbot.end_conversation(request.session_id)

        # Update Firebase
        if db:
            db.collection('conversations').document(request.session_id).update({
                'is_active': False,
                'ended_at': firestore.SERVER_TIMESTAMP
            })

        return {
            "success": True,
            **result
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/api/conversation/{session_id}")
async def get_conversation(session_id: str):
    """Get conversation history"""
    if not chatbot:
        raise HTTPException(status_code=503, detail="Chatbot not initialized")

    try:
        # Get from chatbot memory
        session_info = chatbot.get_session_info(session_id)

        if not session_info:
            # Try Firebase
            if db:
                doc = db.collection('conversations').document(session_id).get()
                if doc.exists:
                    conversation_data = doc.to_dict()

                    # Get messages
                    messages = []
                    messages_ref = db.collection('conversations').document(session_id).collection('messages')
                    for msg in messages_ref.order_by('timestamp').stream():
                        messages.append(msg.to_dict())

                    return {
                        "success": True,
                        "conversation": conversation_data,
                        "messages": messages
                    }

            raise HTTPException(status_code=404, detail="Conversation not found")

        return {
            "success": True,
            "conversation": session_info
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/api/feedback")
async def submit_feedback(request: FeedbackRequest):
    """Submit user feedback"""
    try:
        if db:
            db.collection('feedback').add({
                'session_id': request.session_id,
                'user_id': request.user_id,
                'rating': request.rating,
                'comment': request.comment,
                'was_helpful': request.was_helpful,
                'timestamp': firestore.SERVER_TIMESTAMP
            })

        return {
            "success": True,
            "message": "Thank you for your feedback!"
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/api/translate")
async def translate_text(request: TranslateRequest):
    """Translate text between English and Sinhala"""
    try:
        if not chatbot or not chatbot.gemini_api:
            raise HTTPException(status_code=503, detail="Translation service not available")

        translated = chatbot.gemini_api.translate_text(
            request.text,
            request.source_lang,
            request.target_lang
        )

        return {
            "success": True,
            "translated_text": translated,
            "source_lang": request.source_lang,
            "target_lang": request.target_lang
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/api/vehicles")
async def get_supported_vehicles():
    """Get list of supported vehicles"""
    try:
        if chatbot and chatbot.knowledge_base:
            stats = chatbot.knowledge_base.get_statistics()
            return {
                "success": True,
                "vehicles": stats['main_dataset']['vehicles'],
                "powertrains": stats['main_dataset']['powertrains']
            }

        return {
            "success": True,
            "vehicles": ["Toyota Aqua", "Toyota Prius", "Toyota Corolla", "Suzuki Alto", "Toyota Vitz"]
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/api/warning-lights")
async def get_warning_lights():
    """Get list of all warning lights"""
    try:
        if chatbot and chatbot.warning_light_detector:
            lights = chatbot.warning_light_detector.get_all_warning_lights('english')
            return {
                "success": True,
                "warning_lights": lights
            }

        raise HTTPException(status_code=503, detail="Warning light detector not available")

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/api/upload-image")
async def upload_image(file: UploadFile = File(...)):
    """Upload image to Firebase Storage"""
    try:
        if not bucket:
            raise HTTPException(status_code=503, detail="Storage not configured")

        # Read file
        contents = await file.read()

        # Generate unique filename
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        filename = f"dashboard_images/{timestamp}_{file.filename}"

        # Upload to Firebase Storage
        blob = bucket.blob(filename)
        blob.upload_from_string(contents, content_type=file.content_type)
        blob.make_public()

        return {
            "success": True,
            "url": blob.public_url,
            "filename": filename
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/api/analytics/daily")
async def get_daily_analytics():
    """Get daily usage analytics (admin endpoint)"""
    try:
        if not db:
            raise HTTPException(status_code=503, detail="Database not available")

        today = datetime.now().strftime('%Y-%m-%d')
        doc = db.collection('usage_analytics').document(today).get()

        if doc.exists:
            return {
                "success": True,
                "analytics": doc.to_dict()
            }

        return {
            "success": True,
            "analytics": {
                "date": today,
                "total_conversations": 0,
                "successful_matches": 0,
                "fallback_activations": 0,
                "warning_light_scans": 0
            }
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# Run server
if __name__ == "__main__":
    import uvicorn

    print("=" * 70)
    print("Starting Vehicle Troubleshooting Chatbot API Server")
    print("=" * 70)

    uvicorn.run(
        app,
        host="0.0.0.0",
        port=8000,
        log_level="info"
    )
