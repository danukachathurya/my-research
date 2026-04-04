"""
Vehicle Troubleshooting Chatbot - Main Orchestrator

This is the main chatbot brain that coordinates all components:
- Intent classification
- Knowledge base search
- Fallback system activation
- Warning light detection
- Response generation

Author: Vehicle Chatbot Team
Date: 2025
"""

import uuid
import sys
from typing import Dict, List, Optional, Any
from datetime import datetime
from enum import Enum
from pathlib import Path

# Add project root to path
sys.path.insert(0, str(Path(__file__).parent.parent.parent))

from src.api.gemini_api import GeminiAPI, VehicleExpertSystem
from src.core.knowledge_base import KnowledgeBase
from src.core.fallback_system import FallbackSystem, FallbackState
from src.core.warning_light_detector import WarningLightDetector
from src.utils.text_preprocessor import detect_language


class ConversationState(Enum):
    """States of conversation"""
    INITIAL = "initial"
    SEARCHING_KNOWLEDGE = "searching_knowledge"
    FALLBACK_MODE = "fallback_mode"
    WARNING_LIGHT_MODE = "warning_light_mode"
    AWAITING_BLINKING_STATUS = "awaiting_blinking_status"
    PROVIDING_SOLUTION = "providing_solution"


class VehicleChatbot:
    """
    Main chatbot orchestrator
    """

    def __init__(self,
                 gemini_api_key: str,
                 main_dataset_path: str,
                 fallback_dataset_path: str,
                 warning_lights_db_path: str = 'warning_light_data.json'):
        """
        Initialize chatbot

        Args:
            gemini_api_key: Gemini API key
            main_dataset_path: Path to main vehicle issues dataset
            fallback_dataset_path: Path to fallback dataset
            warning_lights_db_path: Path to warning lights database
        """
        print("Initializing Vehicle Troubleshooting Chatbot...")

        # Initialize Gemini API
        self.gemini_api = GeminiAPI(api_key=gemini_api_key)
        self.expert_system = VehicleExpertSystem(self.gemini_api)

        # Initialize Knowledge Base
        self.knowledge_base = KnowledgeBase(
            main_dataset_path,
            fallback_dataset_path,
            gemini_api=self.gemini_api
        )

        # Initialize Fallback System
        self.fallback_system = FallbackSystem(self.gemini_api)

        # Initialize Warning Light Detector
        self.warning_light_detector = WarningLightDetector(
            self.gemini_api,
            warning_lights_db_path
        )

        # Conversation sessions
        self.sessions = {}

        print("✅ Vehicle Troubleshooting Chatbot ready!")

    def start_conversation(self, user_id: str, language: str = 'english') -> Dict:
        """
        Start a new conversation session

        Args:
            user_id: User identifier
            language: Conversation language

        Returns:
            Dict: Session information and greeting
        """
        session_id = str(uuid.uuid4())

        # Create session
        self.sessions[session_id] = {
            'session_id': session_id,
            'user_id': user_id,
            'language': language,
            'state': ConversationState.INITIAL,
            'context': {},
            'conversation_history': [],
            'created_at': datetime.now().isoformat(),
            'last_updated': datetime.now().isoformat()
        }

        # Generate greeting
        greeting = self._generate_greeting(language)

        self._add_to_history(session_id, 'bot', greeting)

        return {
            'session_id': session_id,
            'message': greeting,
            'language': language
        }

    def process_message(self,
                       session_id: str,
                       message: str,
                       image: Optional[Any] = None) -> Dict:
        """
        Process user message (main entry point)

        Args:
            session_id: Session identifier
            message: User's message
            image: Optional image (for warning lights)

        Returns:
            Dict: Bot response
        """
        if session_id not in self.sessions:
            return {
                'error': 'Invalid session ID. Please start a new conversation.',
                'action': 'restart'
            }

        session = self.sessions[session_id]
        language = session['language']

        # Add user message to history
        self._add_to_history(session_id, 'user', message)

        # Detect language if not set
        if not language or language == 'auto':
            language = detect_language(message)
            session['language'] = language

        # Process based on current state
        current_state = session['state']

        if current_state == ConversationState.INITIAL or current_state == ConversationState.SEARCHING_KNOWLEDGE:
            return self._handle_initial_query(session_id, message, image)

        elif current_state == ConversationState.FALLBACK_MODE:
            return self._handle_fallback_answer(session_id, message)

        elif current_state == ConversationState.WARNING_LIGHT_MODE or current_state == ConversationState.AWAITING_BLINKING_STATUS:
            return self._handle_warning_light_interaction(session_id, message, image)

        else:
            # Default: treat as new query
            return self._handle_initial_query(session_id, message, image)

    def _handle_initial_query(self, session_id: str, message: str, image: Optional[Any]) -> Dict:
        """
        Handle initial user query - search knowledge base or route to warning light detection

        Args:
            session_id: Session ID
            message: User message
            image: Optional image

        Returns:
            Dict: Response
        """
        session = self.sessions[session_id]
        language = session['language']

        # Check if image provided (warning light scan)
        if image:
            session['state'] = ConversationState.WARNING_LIGHT_MODE
            return self._handle_warning_light_detection(session_id, image)

        # Classify intent
        intent_result = self.gemini_api.classify_intent(message)
        intent = intent_result.get('intent', 'vehicle_issue')

        # Store context
        session['context'].update({
            'intent': intent,
            'vehicle_model': intent_result.get('vehicle_model'),
            'issue_type': intent_result.get('issue_type'),
            'urgency': intent_result.get('urgency')
        })

        # Handle warning light intent
        if intent == 'warning_light':
            return self._prompt_for_warning_light_image(session_id)

        # Use Gemini for conversational responses
        # Build context from conversation history
        conversation_context = "\n".join([
            f"{msg['role']}: {msg['content']}"
            for msg in session['conversation_history'][-6:]  # Last 6 messages for context
        ])

        # Generate conversational response using Gemini
        gemini_response = self.expert_system.generate_conversational_response(
            user_message=message,
            conversation_history=conversation_context,
            vehicle_context=session['context']
        )

        self._add_to_history(session_id, 'bot', gemini_response)

        return {
            'status': 'success',
            'source': 'gemini_conversation',
            'message': gemini_response
        }

        # OLD CODE - Knowledge base search (now commented out for conversational mode)
        # Uncomment below to enable knowledge base search first
        # session['state'] = ConversationState.SEARCHING_KNOWLEDGE
        # vehicle_model = session['context'].get('vehicle_model')
        # search_results = self.knowledge_base.search_issue(message, vehicle_model=vehicle_model, top_n=3)
        # if search_results and search_results[0]['confidence'] >= 0.65:
        #     best_match = search_results[0]
        #     session['context']['matched_issue'] = best_match
        #     session['state'] = ConversationState.PROVIDING_SOLUTION
        #     solution = self.knowledge_base.format_solution(best_match, language)
        #     self._add_to_history(session_id, 'bot', solution)
        #     return {
        #         'status': 'success',
        #         'source': 'knowledge_base',
        #         'confidence': best_match['confidence'],
        #         'message': solution,
        #         'vehicle': best_match.get('vehicle_model'),
        #         'severity': self._determine_severity(best_match)
        #     }
        # else:
        #     session['state'] = ConversationState.FALLBACK_MODE
        #     return self._activate_fallback_system(session_id)

    def _activate_fallback_system(self, session_id: str) -> Dict:
        """
        Activate fallback diagnostic system

        Args:
            session_id: Session ID

        Returns:
            Dict: First diagnostic question
        """
        session = self.sessions[session_id]
        language = session['language']

        # Initialize fallback system for this session
        if 'fallback_instance' not in session:
            session['fallback_instance'] = FallbackSystem(self.gemini_api, language)

        fallback = session['fallback_instance']

        # Start diagnostic flow
        first_question = fallback.start_diagnostic_flow(language)

        self._add_to_history(session_id, 'bot', first_question['question_text'])

        return {
            'status': 'fallback_mode',
            'message': "I don't have a specific match for your issue in my database. Let me ask you some diagnostic questions to help better.",
            'question': first_question,
            'source': 'fallback_system'
        }

    def _handle_fallback_answer(self, session_id: str, answer: str) -> Dict:
        """
        Handle user's answer in fallback mode

        Args:
            session_id: Session ID
            answer: User's answer

        Returns:
            Dict: Next question or generated advice
        """
        session = self.sessions[session_id]
        fallback = session.get('fallback_instance')

        if not fallback:
            return {'error': 'Fallback system not initialized'}

        # Process answer
        result = fallback.process_answer(answer)

        if result['status'] == 'completed':
            # Generate advice
            advice_result = fallback.generate_advice()

            self._add_to_history(session_id, 'bot', advice_result['advice'])

            session['state'] = ConversationState.PROVIDING_SOLUTION

            return {
                'status': 'success',
                'source': 'fallback_advice',
                'message': advice_result['advice'],
                'quick_checks': advice_result['quick_checks'],
                'urgency': advice_result['urgency'],
                'recommendation': advice_result['recommendation']
            }
        else:
            # Ask next question
            self._add_to_history(session_id, 'bot', result['question_text'])

            return {
                'status': 'fallback_mode',
                'question': result,
                'source': 'fallback_system'
            }

    def _handle_warning_light_detection(self, session_id: str, image: Any) -> Dict:
        """
        Handle warning light image detection

        Args:
            session_id: Session ID
            image: Dashboard image

        Returns:
            Dict: Detection results
        """
        session = self.sessions[session_id]
        language = session['language']

        # Analyze image
        detection_result = self.warning_light_detector.analyze_dashboard_image(image)

        if detection_result['status'] == 'no_lights_detected':
            msg = "I couldn't detect any warning lights in the image. Please try taking a clearer photo of your dashboard."
            self._add_to_history(session_id, 'bot', msg)

            return {
                'status': 'no_detection',
                'message': msg
            }

        # Lights detected - ask about blinking status
        detected_lights = detection_result['warning_lights']
        session['context']['detected_warning_lights'] = detected_lights
        session['state'] = ConversationState.AWAITING_BLINKING_STATUS

        # Ask blinking status question
        blinking_question = self.warning_light_detector.ask_blinking_status(language)

        light_names = [light['name_en'] for light in detected_lights]
        msg = f"I detected the following warning light(s): {', '.join(light_names)}.\n\n{blinking_question['question']}"

        self._add_to_history(session_id, 'bot', msg)

        return {
            'status': 'lights_detected',
            'message': msg,
            'detected_lights': detected_lights,
            'question': blinking_question,
            'requires_input': True
        }

    def _handle_warning_light_interaction(self, session_id: str, message: str, image: Optional[Any]) -> Dict:
        """
        Handle warning light blinking status answer

        Args:
            session_id: Session ID
            message: User's answer about blinking
            image: Optional new image

        Returns:
            Dict: Troubleshooting information
        """
        session = self.sessions[session_id]
        language = session['language']

        # If new image provided
        if image:
            return self._handle_warning_light_detection(session_id, image)

        # Determine blinking status from answer
        blinking_status = 'steady'
        if 'blink' in message.lower() or 'flash' in message.lower():
            blinking_status = 'blinking'

        # Get detected lights
        detected_lights = session['context'].get('detected_warning_lights', [])

        if not detected_lights:
            return {'error': 'No warning lights detected'}

        # Get troubleshooting for first detected light
        light = detected_lights[0]
        troubleshooting = self.warning_light_detector.get_troubleshooting_info(
            light['id'],
            blinking_status,
            language
        )

        session['state'] = ConversationState.PROVIDING_SOLUTION

        self._add_to_history(session_id, 'bot', troubleshooting['formatted_response'])

        return {
            'status': 'success',
            'source': 'warning_light',
            'message': troubleshooting['formatted_response'],
            'severity': troubleshooting['severity'],
            'warning_light': troubleshooting['warning_light']
        }

    def _prompt_for_warning_light_image(self, session_id: str) -> Dict:
        """
        Prompt user to upload warning light image

        Args:
            session_id: Session ID

        Returns:
            Dict: Prompt message
        """
        session = self.sessions[session_id]
        session['state'] = ConversationState.WARNING_LIGHT_MODE

        msg = "Please upload a clear photo of your dashboard showing the warning light(s)."

        self._add_to_history(session_id, 'bot', msg)

        return {
            'status': 'awaiting_image',
            'message': msg,
            'requires_image': True
        }

    def _generate_greeting(self, language: str) -> str:
        """Generate greeting message"""
        greetings = {
            'english': "Hello! I'm your vehicle troubleshooting assistant. I can help you diagnose issues with Toyota Aqua, Prius, Corolla, Vitz, and Suzuki Alto. You can:\n\n1. Describe your vehicle problem\n2. Upload a photo of dashboard warning lights\n3. Ask questions about vehicle maintenance\n\nHow can I help you today?",
            'sinhala': "ආයුබෝවන්! මම ඔබේ වාහන ගැටලු විසඳීමේ සහායකයා. මට ටොයොටා ඇක්වා, ප්‍රියස්, කොරොල්ලා, විට්ස් සහ සුසුකී ඇල්ටෝ යන වාහන පිළිබඳ ගැටලු හඳුනාගැනීමට උදව් කළ හැක.\n\n1. ඔබේ වාහන ගැටලුව විස්තර කරන්න\n2. ඩෑෂ්බෝඩ් අනතුරු ඇඟවීම් ඡායාරූපයක් උඩුගත කරන්න\n3. වාහන නඩත්තුව පිළිබඳ ප්‍රශ්න අසන්න\n\nඅද මට ඔබට උදව් කළ හැක්කේ කෙසේද?"
        }

        return greetings.get(language, greetings['english'])

    def _add_to_history(self, session_id: str, role: str, content: str):
        """Add message to conversation history"""
        if session_id in self.sessions:
            self.sessions[session_id]['conversation_history'].append({
                'role': role,
                'content': content,
                'timestamp': datetime.now().isoformat()
            })
            self.sessions[session_id]['last_updated'] = datetime.now().isoformat()

    def _determine_severity(self, issue_data: Dict) -> Dict:
        """Determine severity from issue data"""
        safety_note = str(issue_data.get('safety_note', '')).lower()

        if any(word in safety_note for word in ['do not drive', 'stop immediately', 'dangerous']):
            return {'level': 'high', 'color': 'red'}
        elif any(word in safety_note for word in ['caution', 'limit', 'monitor']):
            return {'level': 'medium', 'color': 'orange'}
        else:
            return {'level': 'low', 'color': 'yellow'}

    def get_session_info(self, session_id: str) -> Optional[Dict]:
        """Get session information"""
        return self.sessions.get(session_id)

    def end_conversation(self, session_id: str) -> Dict:
        """End conversation and cleanup"""
        if session_id in self.sessions:
            session = self.sessions.pop(session_id)
            return {
                'status': 'ended',
                'message': 'Thank you for using the vehicle troubleshooting assistant. Stay safe!',
                'conversation_summary': {
                    'duration': session['last_updated'],
                    'messages_count': len(session['conversation_history'])
                }
            }
        return {'error': 'Session not found'}


# Example usage
if __name__ == "__main__":
    print("=" * 70)
    print("Testing Vehicle Chatbot")
    print("=" * 70)

    try:
        import os

        # Initialize chatbot
        chatbot = VehicleChatbot(
            gemini_api_key=os.getenv('GEMINI_API_KEY'),
            main_dataset_path='sri_lanka_vehicle_dataset_5models_englishonly.xlsx',
            fallback_dataset_path='fallback_dataset.xlsx'
        )

        # Start conversation
        print("\n1. Starting conversation...")
        session = chatbot.start_conversation('user123', language='english')
        print(f"Session ID: {session['session_id']}")
        print(f"Bot: {session['message'][:100]}...")

        # Test query
        print("\n2. Testing user query...")
        response = chatbot.process_message(
            session['session_id'],
            "My Toyota Aqua won't start and I hear clicking noises"
        )
        print(f"Status: {response['status']}")
        print(f"Source: {response.get('source')}")
        if 'message' in response:
            print(f"Response: {response['message'][:200]}...")

        print("\n" + "=" * 70)
        print("✅ Chatbot test completed!")
        print("=" * 70)

    except Exception as e:
        print(f"\n❌ Error: {e}")
        import traceback
        traceback.print_exc()
