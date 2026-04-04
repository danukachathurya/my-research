"""
Vehicle Troubleshooting Chatbot - Gemini API Integration

This module handles all interactions with Google Gemini API:
- Text generation (conversational responses)
- Image analysis (warning light detection)
- Embeddings (semantic search)
- Translation (English ↔ Sinhala)

Author: Vehicle Chatbot Team
Date: 2025
"""

import os
import json
import base64
from typing import List, Dict, Optional, Union
from io import BytesIO
from PIL import Image

import google.generativeai as genai


class GeminiAPI:
    """
    Wrapper class for Google Gemini API interactions
    """

    def __init__(self, api_key: Optional[str] = None):
        """
        Initialize Gemini API client

        Args:
            api_key (str): Google Gemini API key
        """
        self.api_key = api_key or os.getenv('GEMINI_API_KEY')

        if not self.api_key:
            raise ValueError("Gemini API key not found. Set GEMINI_API_KEY environment variable.")

        # Configure Gemini API
        genai.configure(api_key=self.api_key)

        # Initialize models
        self.text_model = genai.GenerativeModel('gemini-2.5-flash')
        self.vision_model = genai.GenerativeModel('gemini-2.5-flash')

        # Safety settings
        self.safety_settings = [
            {
                "category": "HARM_CATEGORY_HARASSMENT",
                "threshold": "BLOCK_NONE"
            },
            {
                "category": "HARM_CATEGORY_HATE_SPEECH",
                "threshold": "BLOCK_NONE"
            },
            {
                "category": "HARM_CATEGORY_SEXUALLY_EXPLICIT",
                "threshold": "BLOCK_NONE"
            },
            {
                "category": "HARM_CATEGORY_DANGEROUS_CONTENT",
                "threshold": "BLOCK_NONE"
            }
        ]

        print(">>> Gemini API initialized successfully!")

    def generate_response(self,
                         prompt: str,
                         context: Optional[Dict] = None,
                         max_tokens: int = 500,
                         temperature: float = 0.7) -> str:
        """
        Generate conversational response using Gemini Pro

        Args:
            prompt (str): User query or prompt
            context (dict): Conversation context
            max_tokens (int): Maximum response length
            temperature (float): Creativity level (0.0-1.0)

        Returns:
            str: Generated response
        """
        try:
            # Build full prompt with context
            full_prompt = self._build_prompt_with_context(prompt, context)

            # Generate response
            response = self.text_model.generate_content(
                full_prompt,
                generation_config=genai.types.GenerationConfig(
                    max_output_tokens=max_tokens,
                    temperature=temperature,
                ),
                safety_settings=self.safety_settings
            )

            # Extract text from response (handle different response formats)
            # Try to access via candidates first (safer approach)
            if hasattr(response, 'candidates') and response.candidates:
                candidate = response.candidates[0]
                if hasattr(candidate, 'content') and hasattr(candidate.content, 'parts'):
                    parts_text = []
                    for part in candidate.content.parts:
                        if hasattr(part, 'text'):
                            parts_text.append(part.text)
                    if parts_text:
                        return ''.join(parts_text)

            # Try direct text access (may fail on some API versions)
            try:
                return response.text
            except:
                pass

            # Fallback to string representation
            return str(response)

        except Exception as e:
            print(f"Error generating response: {e}")
            import traceback
            traceback.print_exc()
            return "I apologize, but I'm having trouble generating a response. Please try again."

    def analyze_warning_light_image(self,
                                    image: Union[str, bytes, Image.Image],
                                    prompt: Optional[str] = None) -> Dict:
        """
        Analyze dashboard warning light image using Gemini Vision

        Args:
            image: Image file path, bytes, or PIL Image
            prompt: Optional custom prompt

        Returns:
            dict: Analysis results
        """
        try:
            # Convert image to PIL Image if needed
            pil_image = self._prepare_image(image)

            # Default prompt for warning light detection
            if not prompt:
                prompt = """
                Analyze this vehicle dashboard image and identify any warning lights.

                For each warning light detected, provide:
                1. Name of the warning light
                2. Color (red, yellow/amber, orange, blue, green)
                3. Symbol description
                4. Approximate location on dashboard

                Format your response as JSON:
                {
                    "detected_lights": [
                        {
                            "name": "Check Engine Light",
                            "color": "yellow",
                            "symbol": "engine outline",
                            "location": "center-left",
                            "confidence": "high"
                        }
                    ],
                    "image_quality": "good/moderate/poor",
                    "notes": "any additional observations"
                }

                If no warning lights are detected, return empty detected_lights array.
                """

            # Analyze image
            response = self.vision_model.generate_content(
                [prompt, pil_image],
                safety_settings=self.safety_settings
            )

            # Parse response
            result = self._parse_vision_response(response.text)
            return result

        except Exception as e:
            print(f"Error analyzing image: {e}")
            return {
                "detected_lights": [],
                "error": str(e),
                "image_quality": "unknown"
            }

    def generate_fallback_advice(self,
                                context: Dict,
                                language: str = 'english') -> str:
        """
        Generate general diagnostic advice based on collected context

        Args:
            context (dict): User's answers to diagnostic questions
            language (str): Response language

        Returns:
            str: Generated advice
        """
        vehicle = context.get('vehicle_model', 'your vehicle')
        occurrence = context.get('occurrence', 'unknown time')
        sounds = context.get('sounds', 'none')
        smells = context.get('smells', 'none')
        warning_lights = context.get('warning_lights', 'none')
        visual = context.get('visual', 'nothing visible')

        prompt = f"""
        You are an expert vehicle mechanic helping diagnose a problem. Generate practical troubleshooting advice.

        Vehicle Information:
        - Model: {vehicle}
        - Problem occurs: {occurrence}
        - Sounds heard: {sounds}
        - Smells noticed: {smells}
        - Warning lights: {warning_lights}
        - Visual observations: {visual}

        Provide:
        1. Most likely causes (2-3 possibilities)
        2. Quick checks the user can do themselves
        3. When to seek professional help
        4. Safety considerations

        Keep the advice practical and easy to understand. Use numbered lists.
        Language: {language}

        Format the response in a friendly, helpful tone.
        """

        try:
            response = self.generate_response(prompt, max_tokens=600)
            return response
        except Exception as e:
            print(f"Error generating fallback advice: {e}")
            return "Based on the information provided, I recommend having a professional mechanic inspect your vehicle to properly diagnose the issue."

    def translate_text(self,
                      text: str,
                      source_lang: str,
                      target_lang: str) -> str:
        """
        Translate text between English and Sinhala

        Args:
            text (str): Text to translate
            source_lang (str): Source language
            target_lang (str): Target language

        Returns:
            str: Translated text
        """
        if source_lang == target_lang:
            return text

        prompt = f"""
        Translate the following text from {source_lang} to {target_lang}.

        Maintain the tone and technical accuracy, especially for automotive terms.

        Text to translate:
        {text}

        Provide only the translation, no explanations.
        """

        try:
            response = self.generate_response(prompt, max_tokens=500, temperature=0.3)
            return response.strip()
        except Exception as e:
            print(f"Error translating text: {e}")
            return text  # Return original if translation fails

    def get_embeddings(self, text: str) -> List[float]:
        """
        Get text embeddings for semantic search

        Args:
            text (str): Input text

        Returns:
            List[float]: Embedding vector
        """
        try:
            result = genai.embed_content(
                model="models/embedding-001",
                content=text,
                task_type="retrieval_document"
            )
            return result['embedding']
        except Exception as e:
            print(f"Error getting embeddings: {e}")
            return []

    def classify_intent(self, user_message: str) -> Dict:
        """
        Classify user intent from message

        Args:
            user_message (str): User's message

        Returns:
            dict: Intent classification
        """
        prompt = f"""
        Classify the user's intent from this message about their vehicle.

        Message: "{user_message}"

        Possible intents:
        - vehicle_issue: User has a problem with their vehicle
        - warning_light: User is asking about a warning light
        - general_question: General question about vehicles
        - greeting: User is greeting or starting conversation
        - unclear: Intent is not clear

        Also extract:
        - vehicle_model: If mentioned (Aqua, Prius, Corolla, Alto, Vitz)
        - issue_type: Category of issue (starting, braking, engine, electrical, etc.)
        - urgency: low, medium, high

        Respond in JSON format:
        {{
            "intent": "vehicle_issue",
            "vehicle_model": "Aqua" or null,
            "issue_type": "starting" or null,
            "urgency": "medium",
            "confidence": 0.9
        }}
        """

        try:
            response = self.generate_response(prompt, temperature=0.3)
            # Parse JSON response
            result = json.loads(response.strip())
            return result
        except Exception as e:
            print(f"Error classifying intent: {e}")
            return {
                "intent": "unclear",
                "vehicle_model": None,
                "issue_type": None,
                "urgency": "medium",
                "confidence": 0.0
            }

    def _build_prompt_with_context(self, prompt: str, context: Optional[Dict]) -> str:
        """
        Build full prompt with conversation context

        Args:
            prompt (str): Base prompt
            context (dict): Context information

        Returns:
            str: Full prompt
        """
        if not context:
            return prompt

        context_str = "Context:\n"
        if context.get('vehicle_model'):
            context_str += f"- Vehicle: {context['vehicle_model']}\n"
        if context.get('conversation_history'):
            context_str += "- Previous conversation:\n"
            for msg in context['conversation_history'][-3:]:  # Last 3 messages
                context_str += f"  {msg['role']}: {msg['content']}\n"

        return f"{context_str}\nCurrent query: {prompt}"

    def _prepare_image(self, image: Union[str, bytes, Image.Image]) -> Image.Image:
        """
        Prepare image for Gemini Vision API

        Args:
            image: Image in various formats

        Returns:
            PIL.Image: Prepared image
        """
        if isinstance(image, Image.Image):
            return image
        elif isinstance(image, str):
            # File path
            return Image.open(image)
        elif isinstance(image, bytes):
            # Bytes
            return Image.open(BytesIO(image))
        else:
            raise ValueError("Unsupported image format")

    def _parse_vision_response(self, response_text: str) -> Dict:
        """
        Parse JSON response from vision model

        Args:
            response_text (str): Raw response

        Returns:
            dict: Parsed response
        """
        try:
            # Try to extract JSON from response
            start_idx = response_text.find('{')
            end_idx = response_text.rfind('}') + 1

            if start_idx != -1 and end_idx != 0:
                json_str = response_text[start_idx:end_idx]
                return json.loads(json_str)
            else:
                # If no JSON found, return structured response
                return {
                    "detected_lights": [],
                    "raw_response": response_text,
                    "image_quality": "unknown"
                }
        except Exception as e:
            print(f"Error parsing vision response: {e}")
            return {
                "detected_lights": [],
                "error": str(e),
                "raw_response": response_text
            }


class VehicleExpertSystem:
    """
    Specialized system for vehicle troubleshooting with Gemini
    """

    def __init__(self, gemini_api: GeminiAPI):
        """
        Initialize expert system

        Args:
            gemini_api: GeminiAPI instance
        """
        self.api = gemini_api

        # System prompt for vehicle expert
        self.system_prompt = """
        You are an expert vehicle mechanic with 20+ years of experience, specializing in
        Toyota (Aqua, Prius, Corolla, Vitz) and Suzuki (Alto) vehicles common in Sri Lanka.

        Your role:
        - Diagnose vehicle problems accurately
        - Provide clear, step-by-step troubleshooting advice
        - Consider local Sri Lankan conditions (hot climate, road conditions)
        - Prioritize safety
        - Use simple language that non-mechanics can understand

        Always:
        - Start with quick checks users can do themselves
        - Explain WHY each check is important
        - Indicate when professional help is needed
        - Mention safety warnings when relevant
        - Consider cost-effective solutions
        """

    def diagnose_issue(self,
                      issue_description: str,
                      vehicle_model: str,
                      additional_info: Optional[Dict] = None) -> Dict:
        """
        Provide expert diagnosis for vehicle issue

        Args:
            issue_description: User's description of the problem
            vehicle_model: Vehicle model
            additional_info: Additional context

        Returns:
            dict: Diagnosis with steps
        """
        prompt = f"""
        {self.system_prompt}

        Vehicle: {vehicle_model}
        Issue: {issue_description}

        {f"Additional information: {json.dumps(additional_info)}" if additional_info else ""}

        Provide a diagnosis in this format:

        1. MOST LIKELY CAUSE: [Main diagnosis]

        2. QUICK CHECKS:
           - [Check 1]
           - [Check 2]
           - [Check 3]

        3. DIAGNOSTIC STEPS:
           Step 1: [Detailed step]
           Step 2: [Detailed step]
           ...

        4. RECOMMENDED ACTIONS:
           - [Action 1]
           - [Action 2]

        5. WHEN TO SEEK HELP:
           [When to go to mechanic]

        6. SAFETY NOTE:
           [Any safety warnings]
        """

        response = self.api.generate_response(prompt, max_tokens=700)

        return {
            "diagnosis": response,
            "vehicle": vehicle_model,
            "issue": issue_description
        }

    def generate_conversational_response(self,
                                        user_message: str,
                                        conversation_history: str = "",
                                        vehicle_context: Optional[Dict] = None) -> str:
        """
        Generate natural conversational responses for chat-like interaction

        Args:
            user_message: Current user message
            conversation_history: Previous conversation context
            vehicle_context: Any vehicle/issue context

        Returns:
            str: Natural conversational response
        """
        vehicle_info = vehicle_context.get('vehicle_model', 'the vehicle') if vehicle_context else 'your vehicle'

        prompt = f"""
        You are a professional vehicle troubleshooting assistant specializing in Sri Lankan vehicles (Toyota Aqua, Prius, Corolla, Vitz, and Suzuki Alto).

        Your approach:
        - Give direct, clear answers without unnecessary small talk
        - Be professional but approachable
        - Ask clarifying questions only when essential for diagnosis
        - Provide concise, actionable advice (2-3 sentences unless explaining repair steps)
        - Focus on solving the problem efficiently
        - Use simple language but stay solution-focused

        Previous conversation:
        {conversation_history if conversation_history else "This is the start of the conversation"}

        Vehicle context: {vehicle_info}

        User message: "{user_message}"

        Provide a direct response. If diagnosing an issue, either:
        1. Ask one specific question needed for diagnosis
        2. Give clear advice if you have sufficient information
        3. Provide step-by-step instructions if appropriate

        Be concise and practical.
        """

        response = self.api.generate_response(
            prompt,
            max_tokens=500,
            temperature=0.7  # Balanced for direct but natural responses
        )

        return response


# Example usage and testing
if __name__ == "__main__":
    print("=" * 70)
    print("Testing Gemini API Integration")
    print("=" * 70)

    # Note: Set your API key as environment variable or pass directly
     #export GEMINI_API_KEY='your-api-key-here'

    try:
        # Initialize API
        api = GeminiAPI()

        # Test 1: Simple response generation
        print("\n1. Testing response generation...")
        response = api.generate_response("My Toyota Aqua won't start")
        print(f"Response: {response[:200]}...")

        # Test 2: Intent classification
        print("\n2. Testing intent classification...")
        intent = api.classify_intent("My Aqua has a strange noise when braking")
        print(f"Intent: {json.dumps(intent, indent=2)}")

        # Test 3: Fallback advice generation
        print("\n3. Testing fallback advice...")
        context = {
            "vehicle_model": "Toyota Vitz",
            "occurrence": "when accelerating",
            "sounds": "squealing",
            "smells": "none",
            "warning_lights": "none"
        }
        advice = api.generate_fallback_advice(context)
        print(f"Advice: {advice[:200]}...")

        # Test 4: Expert system
        print("\n4. Testing expert system...")
        expert = VehicleExpertSystem(api)
        diagnosis = expert.diagnose_issue(
            "Engine won't start, clicking sound",
            "Toyota Aqua"
        )
        print(f"Diagnosis: {diagnosis['diagnosis'][:200]}...")

        print("\n" + "=" * 70)
        print("✅ All tests completed successfully!")
        print("=" * 70)

    except Exception as e:
        print(f"\n❌ Error: {e}")
        print("\nMake sure to set GEMINI_API_KEY environment variable!")
