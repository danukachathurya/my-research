"""
Vehicle Troubleshooting Chatbot - Warning Light Detection System

This module handles dashboard warning light detection and analysis using Gemini Vision API.

Author: Vehicle Chatbot Team
Date: 2025
"""

import json
import sys
from typing import Dict, List, Optional, Union
from pathlib import Path
from PIL import Image

# Add project root to path
sys.path.insert(0, str(Path(__file__).parent.parent.parent))

from src.api.gemini_api import GeminiAPI


class WarningLightDetector:
    """
    Warning light detection and analysis system
    """

    def __init__(self, gemini_api: GeminiAPI, warning_lights_db_path: str = None):
        """
        Initialize warning light detector

        Args:
            gemini_api: GeminiAPI instance
            warning_lights_db_path: Path to warning lights database
        """
        self.gemini_api = gemini_api

        # Set default path if not provided
        if warning_lights_db_path is None:
            project_root = Path(__file__).parent.parent.parent
            self.warning_lights_db_path = str(project_root / 'data' / 'warning_light_data.json')
        else:
            self.warning_lights_db_path = warning_lights_db_path

        # Load warning lights database
        self.warning_lights_db = self._load_warning_lights_db()

        print(f">>> Warning Light Detector initialized with {len(self.warning_lights_db)} warning lights")

    def _load_warning_lights_db(self) -> List[Dict]:
        """
        Load warning lights database

        Returns:
            List[Dict]: Warning lights data
        """
        try:
            with open(self.warning_lights_db_path, 'r', encoding='utf-8') as f:
                data = json.load(f)
                return data.get('warning_lights', [])
        except Exception as e:
            print(f"Error loading warning lights database: {e}")
            return []

    def analyze_dashboard_image(self, image: Union[str, bytes, Image.Image]) -> Dict:
        """
        Analyze dashboard image for warning lights

        Args:
            image: Dashboard image

        Returns:
            Dict: Analysis results
        """
        print("Analyzing dashboard image...")

        # Use Gemini Vision to detect warning lights
        vision_result = self.gemini_api.analyze_warning_light_image(image)

        # Process detected lights
        processed_lights = []
        for detected_light in vision_result.get('detected_lights', []):
            # Match with database
            matched_light = self._match_warning_light(detected_light)
            if matched_light:
                processed_lights.append(matched_light)

        result = {
            "status": "success" if processed_lights else "no_lights_detected",
            "detected_count": len(processed_lights),
            "warning_lights": processed_lights,
            "image_quality": vision_result.get('image_quality', 'unknown'),
            "requires_blinking_check": len(processed_lights) > 0,
            "raw_detection": vision_result
        }

        return result

    def _match_warning_light(self, detected_light: Dict) -> Optional[Dict]:
        """
        Match detected light with database entry

        Args:
            detected_light: Detected light information

        Returns:
            Dict or None: Matched warning light data
        """
        light_name = detected_light.get('name', '').lower()
        light_color = detected_light.get('color', '').lower()

        # Search database for match
        best_match = None
        best_score = 0

        for db_light in self.warning_lights_db:
            # Calculate match score
            score = 0

            # Name matching
            db_name = db_light['name_en'].lower()
            if light_name in db_name or db_name in light_name:
                score += 3

            # Check for keyword matches
            keywords = ['engine', 'battery', 'oil', 'brake', 'temperature', 'abs', 'airbag', 'tire', 'hybrid']
            for keyword in keywords:
                if keyword in light_name and keyword in db_name:
                    score += 2

            # Color matching
            if light_color in db_light['colors']:
                score += 1

            if score > best_score:
                best_score = score
                best_match = db_light

        if best_match and best_score >= 2:
            return {
                "id": best_match['id'],
                "name_en": best_match['name_en'],
                "name_si": best_match['name_si'],
                "detected_color": light_color,
                "symbol_description": best_match['symbol_description'],
                "match_confidence": min(best_score / 5.0, 1.0),
                "awaiting_blinking_status": True
            }

        return None

    def get_troubleshooting_info(self,
                                 warning_light_id: str,
                                 blinking_status: str,
                                 language: str = 'english') -> Dict:
        """
        Get troubleshooting information for a warning light

        Args:
            warning_light_id: Warning light ID
            blinking_status: 'steady' or 'blinking'
            language: Response language

        Returns:
            Dict: Troubleshooting information
        """
        # Find warning light in database
        warning_light = None
        for light in self.warning_lights_db:
            if light['id'] == warning_light_id:
                warning_light = light
                break

        if not warning_light:
            return {
                "status": "error",
                "message": "Warning light not found in database"
            }

        # Get severity information
        severity_info = self._get_severity_info(warning_light, blinking_status)

        # Get troubleshooting steps
        troubleshooting_steps = warning_light['troubleshooting'].get(blinking_status, [])

        # Build response
        lang_suffix = '_si' if language == 'sinhala' else '_en'

        result = {
            "status": "success",
            "warning_light": {
                "id": warning_light['id'],
                "name": warning_light[f'name{lang_suffix}'],
                "symbol": warning_light['symbol_description'],
                "blinking_status": blinking_status
            },
            "severity": severity_info,
            "common_causes": warning_light['common_causes'],
            "quick_checks": warning_light['quick_checks'],
            "troubleshooting_steps": troubleshooting_steps,
            "formatted_response": self._format_response(
                warning_light,
                blinking_status,
                severity_info,
                troubleshooting_steps,
                language
            )
        }

        # Translate if Sinhala
        if language == 'sinhala':
            result['formatted_response'] = self.gemini_api.translate_text(
                result['formatted_response'],
                'english',
                'sinhala'
            )

        return result

    def _get_severity_info(self, warning_light: Dict, blinking_status: str) -> Dict:
        """
        Get severity information for warning light

        Args:
            warning_light: Warning light data
            blinking_status: Blinking status

        Returns:
            Dict: Severity information
        """
        severity_data = warning_light.get('severity', {})

        # Handle different severity structures
        if blinking_status in severity_data:
            severity = severity_data[blinking_status]
        elif 'steady' in severity_data:
            severity = severity_data['steady']
        else:
            # Default severity
            severity = {
                "level": "medium",
                "color": "yellow",
                "safe_to_drive": "limited",
                "urgency": "Schedule service soon"
            }

        return severity

    def _format_response(self,
                        warning_light: Dict,
                        blinking_status: str,
                        severity_info: Dict,
                        troubleshooting_steps: List[str],
                        language: str) -> str:
        """
        Format complete response for user

        Args:
            warning_light: Warning light data
            blinking_status: Blinking status
            severity_info: Severity information
            troubleshooting_steps: List of steps
            language: Language

        Returns:
            str: Formatted response
        """
        response = []

        # Header with severity
        level = severity_info['level'].upper()
        emoji = {
            'low': '🟢',
            'medium': '🟡',
            'high': '🟠',
            'critical': '🔴'
        }.get(severity_info['level'], '⚠️')

        response.append(f"{emoji} {level} SEVERITY WARNING")
        response.append("=" * 50)
        response.append("")

        # Warning light name
        response.append(f"⚡ Warning Light: {warning_light['name_en']}")
        response.append(f"📊 Status: {blinking_status.upper()}")
        response.append("")

        # Safety status
        safe_drive = severity_info.get('safe_to_drive', 'unknown')
        if safe_drive == 'no':
            response.append("🚫 SAFE TO DRIVE: NO")
        elif safe_drive == 'limited' or safe_drive == 'short_distance':
            response.append("⚠️ SAFE TO DRIVE: LIMITED/SHORT DISTANCE ONLY")
        else:
            response.append("✓ SAFE TO DRIVE: YES (with caution)")

        response.append(f"⏰ Urgency: {severity_info.get('urgency', 'Check soon')}")

        if severity_info.get('warning'):
            response.append(f"⚠️ Warning: {severity_info['warning']}")

        response.append("")

        # Common causes
        response.append("🔍 POSSIBLE CAUSES:")
        for i, cause in enumerate(warning_light['common_causes'][:5], 1):
            response.append(f"  {i}. {cause}")
        response.append("")

        # Quick checks
        response.append("✅ QUICK CHECKS YOU CAN DO:")
        for i, check in enumerate(warning_light['quick_checks'], 1):
            response.append(f"  {i}. {check}")
        response.append("")

        # Troubleshooting steps
        response.append("🔧 TROUBLESHOOTING STEPS:")
        for i, step in enumerate(troubleshooting_steps, 1):
            response.append(f"  {i}. {step}")
        response.append("")

        # Final recommendation
        response.append("📌 RECOMMENDATION:")
        if severity_info['level'] in ['critical', 'high']:
            response.append("  ⚠️ This is a serious issue. Do not ignore this warning.")
            response.append("  Get professional help immediately.")
        elif severity_info['level'] == 'medium':
            response.append("  Schedule a diagnostic check within the next few days.")
            response.append("  Monitor the situation and avoid long trips.")
        else:
            response.append("  Address when convenient, but don't delay too long.")
            response.append("  Monitor for any changes.")

        return '\n'.join(response)

    def ask_blinking_status(self, language: str = 'english') -> Dict:
        """
        Generate question about blinking status

        Args:
            language: Question language

        Returns:
            Dict: Question data
        """
        questions = {
            'english': {
                'question': 'Is the warning light steady or blinking?',
                'options': ['Steady (stays on continuously)', 'Blinking (flashing on and off)'],
                'help_text': 'Blinking lights usually indicate more urgent issues.'
            },
            'sinhala': {
                'question': 'අනතුරු ඇඟවීමේ විදුලි පහන ස්ථාවරද නැතහොත් දැල්වෙනවාද?',
                'options': ['ස්ථාවර (අඛණ්ඩව දැල්වෙනවා)', 'දැල්වෙනවා (ඔන් ඕෆ් වෙනවා)'],
                'help_text': 'දැල්වෙන ලයිට් සාමාන්‍යයෙන් වඩා හදිසි ගැටළු පෙන්නුම් කරයි.'
            }
        }

        return questions.get(language, questions['english'])

    def get_all_warning_lights(self, language: str = 'english') -> List[Dict]:
        """
        Get list of all warning lights in database

        Args:
            language: Language for names

        Returns:
            List[Dict]: Warning lights list
        """
        lang_suffix = '_si' if language == 'sinhala' else '_en'

        lights = []
        for light in self.warning_lights_db:
            lights.append({
                'id': light['id'],
                'name': light[f'name{lang_suffix}'],
                'symbol': light['symbol_description'],
                'colors': light['colors']
            })

        return lights


# Example usage and testing
if __name__ == "__main__":
    print("=" * 70)
    print("Testing Warning Light Detector")
    print("=" * 70)

    try:
        from gemini_api import GeminiAPI

        # Initialize
        api = GeminiAPI()
        detector = WarningLightDetector(api)

        # Test 1: List all warning lights
        print("\n1. Available Warning Lights:")
        lights = detector.get_all_warning_lights()
        for light in lights[:5]:
            print(f"  - {light['name']} ({', '.join(light['colors'])})")

        # Test 2: Simulate detection result
        print("\n2. Simulating warning light detection...")
        simulated_detection = {
            "detected_lights": [
                {
                    "name": "Check Engine Light",
                    "color": "yellow",
                    "symbol": "engine outline",
                    "confidence": "high"
                }
            ],
            "image_quality": "good"
        }

        # Process detection
        matched = detector._match_warning_light(simulated_detection['detected_lights'][0])
        if matched:
            print(f"  Matched: {matched['name_en']}")
            print(f"  Confidence: {matched['match_confidence']:.2f}")

            # Test 3: Get troubleshooting info
            print("\n3. Getting troubleshooting info for BLINKING status...")
            info = detector.get_troubleshooting_info(
                matched['id'],
                'blinking',
                'english'
            )

            print("\n" + info['formatted_response'][:500] + "...")

        # Test 4: Get blinking status question
        print("\n4. Blinking status question:")
        question = detector.ask_blinking_status('english')
        print(f"  Q: {question['question']}")
        print(f"  Options: {question['options']}")

        print("\n" + "=" * 70)
        print("✅ All tests completed successfully!")
        print("=" * 70)

    except Exception as e:
        print(f"\n❌ Error: {e}")
        print("\nMake sure to set GEMINI_API_KEY environment variable!")
        import traceback
        traceback.print_exc()
