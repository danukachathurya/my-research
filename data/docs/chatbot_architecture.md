# Vehicle Troubleshooting Chatbot - Complete Architecture

## System Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                          USER INTERFACE LAYER                            │
│  ┌────────────────┐  ┌──────────────────┐  ┌────────────────────────┐  │
│  │  Voice Input   │  │  Text Chat       │  │  Image Upload          │  │
│  │  (Si/En)       │  │  Interface       │  │  (Warning Lights)      │  │
│  └────────────────┘  └──────────────────┘  └────────────────────────┘  │
└──────────────────────────────┬──────────────────────────────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────────────────┐
│                     INPUT PROCESSING LAYER                               │
│  ┌────────────────────┐  ┌──────────────────┐  ┌───────────────────┐   │
│  │ Speech-to-Text     │  │ Language         │  │ Image Analysis    │   │
│  │ (Google/Whisper)   │  │ Detection        │  │ (Gemini Vision)   │   │
│  └────────────────────┘  └──────────────────┘  └───────────────────┘   │
└──────────────────────────────┬──────────────────────────────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────────────────┐
│                    CHATBOT ORCHESTRATOR (MAIN BRAIN)                     │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │  • Intent Classification (Gemini API)                              │ │
│  │  • Entity Extraction (vehicle model, issue type, etc.)            │ │
│  │  • Conversation State Management                                   │ │
│  │  • Decision Router: Main Dataset vs Fallback vs Warning Light     │ │
│  └────────────────────────────────────────────────────────────────────┘ │
└────────┬────────────────────┬─────────────────────┬─────────────────────┘
         │                    │                     │
         ▼                    ▼                     ▼
┌────────────────┐   ┌───────────────────┐   ┌──────────────────────────┐
│ MAIN DATASET   │   │ FALLBACK SYSTEM   │   │ WARNING LIGHT SYSTEM     │
│ SEARCH ENGINE  │   │ (Diagnostic Qs)   │   │ (Vision + Severity)      │
│                │   │                   │   │                          │
│ • Semantic     │   │ • Question Flow   │   │ • Image Recognition      │
│   Search       │   │ • Context         │   │ • Blinking Detection     │
│ • TF-IDF       │   │   Building        │   │ • Severity Assessment    │
│ • Gemini       │   │ • General Advice  │   │ • Safety Determination   │
│   Embeddings   │   │   Generation      │   │                          │
└────────┬───────┘   └─────────┬─────────┘   └──────────┬───────────────┘
         │                     │                         │
         └─────────────────────┴─────────────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────────────────┐
│                    RESPONSE GENERATION LAYER                             │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │  • Natural Language Generation (Gemini API)                        │ │
│  │  • Translation (English ↔ Sinhala)                                 │ │
│  │  • Response Formatting                                             │ │
│  └────────────────────────────────────────────────────────────────────┘ │
└──────────────────────────────┬──────────────────────────────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────────────────┐
│                         OUTPUT LAYER                                     │
│  ┌────────────────┐  ┌──────────────────┐  ┌────────────────────────┐  │
│  │  Text Response │  │  Voice Output    │  │  Diagnostic Steps      │  │
│  │                │  │  (TTS Si/En)     │  │  + Severity Indicators │  │
│  └────────────────┘  └──────────────────┘  └────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────┘
```

## Conversation Flow

### Flow 1: Known Issue (Main Dataset)
```
User: "My Aqua won't start" (Voice/Text, Sinhala or English)
  ↓
[Language Detection] → English
  ↓
[Speech-to-Text] → "my aqua won't start"
  ↓
[Intent Classification] → vehicle_issue
[Entity Extraction] → vehicle: "Aqua", issue: "won't start"
  ↓
[Semantic Search in Main Dataset] → MATCH FOUND (Confidence > 0.7)
  ↓
[Retrieve Solution] → Quick checks, diagnostic steps, recommended actions
  ↓
[Generate Response with Gemini] → Natural language response
  ↓
[Translate if needed] → Same language as input
  ↓
[Output] → Text + Voice: "Let me help you with your Aqua starting issue..."
```

### Flow 2: Unknown Issue (Fallback System)
```
User: "There's a weird smell from my Vitz"
  ↓
[Semantic Search] → NO GOOD MATCH (Confidence < 0.7)
  ↓
[Trigger Fallback System]
  ↓
Bot: "What is your car model?"
  ↓
User: "Toyota Vitz"
  ↓
Bot: "When does the smell occur?"
  ↓
User: "When I turn on the AC"
  ↓
Bot: "Are there any warning lights on the dashboard?"
  ↓
User: "No"
  ↓
Bot: "What type of smell is it?"
  ↓
User: "Musty smell"
  ↓
[Context: Vitz, AC, musty smell, no warnings]
  ↓
[Gemini Generates Advice] →
"A musty smell from the AC typically indicates mold/mildew in the system.
Quick checks:
1. Check cabin air filter
2. Clean AC vents
3. Run AC on high heat to dry system
If problem persists, have the AC system professionally cleaned."
  ↓
[Output Response in Same Language]
```

### Flow 3: Warning Light Detection
```
User: Uploads image of dashboard with warning light
  ↓
[Gemini Vision API] → Analyze image
  ↓
[Detection] → "Check Engine Light" (Yellow/Amber)
  ↓
Bot: "I detected a Check Engine Light. Is it steady or blinking?"
  ↓
User: "Blinking"
  ↓
[Warning Light Database] → Check Engine + Blinking
  ↓
[Severity Assessment] → HIGH
[Safe to Drive] → NO
  ↓
Bot: "⚠️ HIGH SEVERITY WARNING
The blinking Check Engine Light indicates a serious issue.
🚫 NOT SAFE TO DRIVE

Immediate Actions:
1. Pull over safely as soon as possible
2. Turn off the engine
3. Check coolant level (when cool)
4. Check oil level
5. Do not continue driving

This could indicate:
- Severe engine misfire
- Catalytic converter damage risk
- Overheating

Recommendation: Have your vehicle towed to a mechanic immediately."
  ↓
[Display with Red Warning UI + Voice Alert]
```

## Core Components

### 1. Chatbot Orchestrator (`chatbot_core.py`)
```python
class VehicleChatbot:
    - __init__(gemini_api_key, datasets)
    - process_message(text, language, image=None)
    - classify_intent(text)
    - route_to_handler(intent, context)
    - manage_conversation_state()
```

### 2. Knowledge Base Manager (`knowledge_base.py`)
```python
class KnowledgeBase:
    - load_datasets()
    - semantic_search(query, threshold=0.7)
    - get_solution(issue_id)
    - combine_main_fallback()
```

### 3. Fallback System (`fallback_system.py`)
```python
class FallbackSystem:
    - start_diagnostic_flow()
    - ask_next_question(context)
    - collect_responses()
    - generate_general_advice(context)
    - determine_next_step()
```

### 4. Warning Light Detector (`warning_light_detector.py`)
```python
class WarningLightDetector:
    - analyze_image(image)
    - detect_warning_symbols()
    - classify_severity(symbol, blinking_status)
    - get_troubleshooting_steps()
    - assess_safety()
```

### 5. Voice Handler (`voice_handler.py`)
```python
class VoiceHandler:
    - speech_to_text(audio, language)
    - text_to_speech(text, language)
    - detect_language(audio/text)
```

### 6. Gemini Integration (`gemini_api.py`)
```python
class GeminiAPI:
    - generate_response(prompt, context)
    - analyze_image(image, prompt)
    - get_embeddings(text)
    - translate(text, target_language)
```

## Database Schema

### Conversation State
```json
{
  "session_id": "uuid",
  "user_id": "user123",
  "language": "english",
  "current_state": "awaiting_response",
  "conversation_history": [],
  "context": {
    "vehicle_model": "Toyota Aqua",
    "issue_type": "starting_problem",
    "answers_collected": {}
  },
  "timestamp": "2025-12-17T10:30:00Z"
}
```

### Warning Light Database
```json
{
  "warning_lights": [
    {
      "id": "wl_001",
      "name_en": "Check Engine Light",
      "name_si": "එන්ජින් පරීක්ෂා කරන්න",
      "symbol_description": "Engine outline",
      "colors": ["yellow", "amber", "orange"],
      "severity": {
        "steady": {
          "level": "medium",
          "safe_to_drive": "short_distance",
          "max_distance_km": 50,
          "urgency": "Schedule service within 1-2 days"
        },
        "blinking": {
          "level": "high",
          "safe_to_drive": "no",
          "urgency": "Stop immediately",
          "potential_issues": [
            "Severe engine misfire",
            "Catalytic converter damage",
            "Overheating"
          ]
        }
      },
      "common_causes": [
        "Oxygen sensor failure",
        "Loose gas cap",
        "Catalytic converter issues",
        "Mass airflow sensor problems"
      ],
      "quick_checks": [
        "Check gas cap tightness",
        "Check for unusual engine sounds",
        "Note any performance changes"
      ],
      "troubleshooting_steps": {
        "steady": [...],
        "blinking": [...]
      }
    }
  ]
}
```

## API Endpoints (FastAPI)

### REST API Structure
```
POST /api/chat
- Input: { text, language, session_id, image? }
- Output: { response, language, severity?, next_action? }

POST /api/voice
- Input: audio file + language
- Output: { transcription, response, audio_response }

POST /api/warning-light
- Input: image file + session_id
- Output: { detected_lights[], severity, safety_status, steps[] }

GET /api/conversation/{session_id}
- Output: { conversation_history, context }

POST /api/translate
- Input: { text, source_lang, target_lang }
- Output: { translated_text }
```

## Technology Stack

### Backend
- **Framework**: FastAPI (Python 3.11+)
- **AI/ML**:
  - Google Gemini API (Pro & Vision)
  - scikit-learn (TF-IDF)
  - NLTK (preprocessing)
- **Database**:
  - PostgreSQL (conversation history)
  - Redis (session management)
  - ChromaDB (vector embeddings)
- **Voice**:
  - Google Speech-to-Text API
  - gTTS / Google Text-to-Speech

### Frontend
- **Framework**: React.js or Flutter (mobile)
- **UI Components**:
  - Chat interface
  - Voice recorder
  - Image uploader
  - Severity indicators

### Deployment
- **Container**: Docker
- **Cloud**: Google Cloud Platform (for Gemini API optimization)
- **CI/CD**: GitHub Actions

## Diagnostic Question Flow

### Fallback System Questions (Sequential)
```python
DIAGNOSTIC_QUESTIONS = [
    {
        "id": "q1_vehicle",
        "text_en": "What is your car model?",
        "text_si": "ඔබේ මෝටර් රථ මාදිලිය කුමක්ද?",
        "type": "selection",
        "options": ["Toyota Aqua", "Toyota Prius", "Toyota Corolla", "Suzuki Alto", "Toyota Vitz", "Other"],
        "required": True
    },
    {
        "id": "q2_occurrence",
        "text_en": "When does the problem occur?",
        "text_si": "ගැටලුව ඇතිවන්නේ කවදාද?",
        "type": "selection",
        "options": ["Starting the car", "While driving", "When braking", "When accelerating", "When idling", "All the time"],
        "required": True
    },
    {
        "id": "q3_warning_lights",
        "text_en": "Are there any warning lights on the dashboard?",
        "text_si": "ඩෑෂ්බෝඩ් එකේ අනතුරු ඇඟවීමේ විදුලි පහන් තිබේද?",
        "type": "yes_no_image",
        "trigger_image_upload": True,
        "required": True
    },
    {
        "id": "q4_sounds",
        "text_en": "Do you hear any strange sounds?",
        "text_si": "අමුතු ශබ්දයක් ඇහෙනවාද?",
        "type": "selection",
        "options": ["Clicking", "Grinding", "Squealing", "Knocking", "Hissing", "No sounds"],
        "required": False
    },
    {
        "id": "q5_smells",
        "text_en": "Do you notice any strange smells?",
        "text_si": "අමුතු සුවඳක් දැනෙනවාද?",
        "type": "selection",
        "options": ["Burning smell", "Rotten egg smell", "Sweet smell", "Gasoline smell", "Musty smell", "No smell"],
        "required": False
    },
    {
        "id": "q6_visual",
        "text_en": "Do you see any leaks or smoke?",
        "text_si": "කාන්දු හෝ දුමක් පෙනෙනවාද?",
        "type": "selection",
        "options": ["Smoke from engine", "Smoke from exhaust", "Fluid leak under car", "Steam from hood", "Nothing visible"],
        "required": False
    }
]
```

## Severity Levels

### Color-Coded System
- 🟢 **GREEN (Low)**: Minor issue, safe to drive, schedule maintenance
- 🟡 **YELLOW (Medium)**: Moderate issue, limit driving, service soon
- 🟠 **ORANGE (High)**: Serious issue, drive only if necessary, service immediately
- 🔴 **RED (Critical)**: Dangerous, do not drive, get immediate help

## Multilingual Support

### Translation Strategy
1. **Input**: Detect language (English or Sinhala)
2. **Processing**: Internal processing in English
3. **Output**: Translate response back to input language

### Key Phrases Dictionary
```python
TRANSLATIONS = {
    "greetings": {
        "en": "Hello! I'm your vehicle troubleshooting assistant.",
        "si": "ආයුබෝවන්! මම ඔබේ වාහන ගැටලු විසඳීමේ සහායකයා."
    },
    "ask_vehicle": {
        "en": "What is your car model?",
        "si": "ඔබේ මෝටර් රථ මාදිලිය කුමක්ද?"
    },
    # ... more translations
}
```

## Error Handling

### Fallback Scenarios
1. **Gemini API Failure**: Use TF-IDF search + template responses
2. **Voice Recognition Failure**: Fallback to text input
3. **Image Analysis Failure**: Manual selection of warning light
4. **No Match Found**: Always route to fallback diagnostic system

## Performance Optimization

### Caching Strategy
- Cache Gemini embeddings for common queries
- Cache TF-IDF vectors for datasets
- Cache warning light recognition results
- Session state in Redis (fast access)

### Response Time Targets
- Text query: < 2 seconds
- Voice query: < 4 seconds
- Image analysis: < 5 seconds
- Fallback advice generation: < 3 seconds

---

**Next Steps**: Implement each component systematically
