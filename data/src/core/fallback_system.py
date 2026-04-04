"""
Vehicle Troubleshooting Chatbot - Fallback Diagnostic System

This module implements the fallback system for handling unknown issues.
It asks diagnostic questions and generates general advice based on collected context.

Author: Vehicle Chatbot Team
Date: 2025
"""

import json
import sys
from typing import Dict, List, Optional, Any
from enum import Enum
from pathlib import Path

# Add project root to path
sys.path.insert(0, str(Path(__file__).parent.parent.parent))

from src.api.gemini_api import GeminiAPI


class QuestionType(Enum):
    """Types of diagnostic questions"""
    SELECTION = "selection"
    YES_NO = "yes_no"
    TEXT = "text"
    IMAGE = "image"
    YES_NO_IMAGE = "yes_no_image"


class FallbackState(Enum):
    """States of fallback conversation"""
    INITIAL = "initial"
    ASKING_QUESTIONS = "asking_questions"
    GENERATING_ADVICE = "generating_advice"
    COMPLETED = "completed"


class FallbackSystem:
    """
    Fallback diagnostic system for unknown issues
    """

    def __init__(self, gemini_api: GeminiAPI, language: str = 'english'):
        """
        Initialize fallback system

        Args:
            gemini_api: GeminiAPI instance for generating advice
            language: Default language
        """
        self.gemini_api = gemini_api
        self.language = language

        # Diagnostic questions flow
        self.diagnostic_questions = self._define_diagnostic_questions()

        # Current conversation state
        self.current_state = FallbackState.INITIAL
        self.current_question_index = 0
        self.collected_answers = {}

        print("✅ Fallback System initialized")

    def _define_diagnostic_questions(self) -> List[Dict]:
        """
        Define the diagnostic question flow

        Returns:
            List[Dict]: List of questions
        """
        questions = [
            {
                "id": "q1_vehicle",
                "text_en": "What is your car model?",
                "text_si": "ඔබේ මෝටර් රථ මාදිලිය කුමක්ද?",
                "type": QuestionType.SELECTION,
                "options_en": [
                    "Toyota Aqua",
                    "Toyota Prius",
                    "Toyota Corolla",
                    "Suzuki Alto",
                    "Toyota Vitz",
                    "Other"
                ],
                "options_si": [
                    "ටොයොටා ඇක්වා",
                    "ටොයොටා ප්‍රියස්",
                    "ටොයොටා කොරොල්ලා",
                    "සුසුකී ඇල්ටෝ",
                    "ටොයොටා විට්ස්",
                    "වෙනත්"
                ],
                "required": True,
                "key": "vehicle_model"
            },
            {
                "id": "q2_occurrence",
                "text_en": "When does the problem occur?",
                "text_si": "ගැටලුව ඇතිවන්නේ කවදාද?",
                "type": QuestionType.SELECTION,
                "options_en": [
                    "When starting the car",
                    "While driving",
                    "When braking",
                    "When accelerating",
                    "When idling",
                    "All the time"
                ],
                "options_si": [
                    "කාරය ස්ටාර්ට් කරන විට",
                    "ධාවනය කරන විට",
                    "තිරිංග ගන්නා විට",
                    "වේගවත් කරන විට",
                    "නිශ්චලව සිටින විට",
                    "සෑම විටම"
                ],
                "required": True,
                "key": "occurrence"
            },
            {
                "id": "q3_warning_lights",
                "text_en": "Are there any warning lights on your dashboard?",
                "text_si": "ඔබේ ඩෑෂ්බෝඩ් එකේ අනතුරු ඇඟවීමේ විදුලි පහන් තිබේද?",
                "type": QuestionType.YES_NO_IMAGE,
                "trigger_image_upload": True,
                "required": True,
                "key": "warning_lights",
                "follow_up": {
                    "yes": "Could you upload a photo of your dashboard?",
                    "yes_si": "ඔබේ ඩෑෂ්බෝඩ් එකේ ඡායාරූපයක් උඩුගත කළ හැකිද?"
                }
            },
            {
                "id": "q4_sounds",
                "text_en": "Do you hear any strange sounds?",
                "text_si": "අමුතු ශබ්දයක් ඇහෙනවාද?",
                "type": QuestionType.SELECTION,
                "options_en": [
                    "Clicking sound",
                    "Grinding noise",
                    "Squealing sound",
                    "Knocking sound",
                    "Hissing sound",
                    "Rattling noise",
                    "No strange sounds"
                ],
                "options_si": [
                    "ක්ලික් ශබ්දය",
                    "ඝර්ෂණ ශබ්දය",
                    "සීරීම් ශබ්දය",
                    "තට්ටු කිරීමේ ශබ්දය",
                    "හිස් ශබ්දය",
                    "ගැලපීමේ ශබ්දය",
                    "අමුතු ශබ්ද නැත"
                ],
                "required": False,
                "key": "sounds"
            },
            {
                "id": "q5_smells",
                "text_en": "Do you notice any strange smells?",
                "text_si": "අමුතු සුවඳක් දැනෙනවාද?",
                "type": QuestionType.SELECTION,
                "options_en": [
                    "Burning smell",
                    "Rotten egg smell",
                    "Sweet smell (coolant)",
                    "Gasoline/fuel smell",
                    "Musty/moldy smell",
                    "Rubber burning smell",
                    "No strange smells"
                ],
                "options_si": [
                    "පිළිස්සෙන සුවඳ",
                    "දුර්ගන්ධ බිත්තර සුවඳ",
                    "මිහිරි සුවඳ (සිසිලන)",
                    "ඉන්ධන සුවඳ",
                    "පිළිකුල් සුවඳ",
                    "රබර් දැවෙන සුවඳ",
                    "අමුතු සුවඳ නැත"
                ],
                "required": False,
                "key": "smells"
            },
            {
                "id": "q6_visual",
                "text_en": "Do you see any leaks or smoke?",
                "text_si": "කාන්දු හෝ දුමක් පෙනෙනවාද?",
                "type": QuestionType.SELECTION,
                "options_en": [
                    "Smoke from engine bay",
                    "Smoke from exhaust",
                    "Fluid leak under car",
                    "Steam from hood",
                    "Oil on ground",
                    "Nothing visible"
                ],
                "options_si": [
                    "එන්ජින් එකෙන් දුම",
                    "නිෂ්කාශන දුම",
                    "කාර් එක යට තරල කාන්දුවීම",
                    "හුඩ් එකෙන් වාෂ්ප",
                    "බිම තෙල්",
                    "දෘශ්‍ය කිසිවක් නැත"
                ],
                "required": False,
                "key": "visual"
            },
            {
                "id": "q7_recent_changes",
                "text_en": "Have you noticed any recent changes in your car's behavior?",
                "text_si": "ඔබේ කාර් එකේ හැසිරීමේ මෑත වෙනස්කම් දැක තිබේද?",
                "type": QuestionType.SELECTION,
                "options_en": [
                    "Loss of power",
                    "Rough idling",
                    "Difficulty starting",
                    "Vibrations",
                    "Poor fuel economy",
                    "No noticeable changes"
                ],
                "options_si": [
                    "බලය අඩුවීම",
                    "රළු අයිඩ්ලින්",
                    "ආරම්භ කිරීමේ දුෂ්කරතා",
                    "කම්පන",
                    "දුර්වල ඉන්ධන පිරිභෝජනය",
                    "කැපී පෙනෙන වෙනස්කම් නැත"
                ],
                "required": False,
                "key": "recent_changes"
            }
        ]

        return questions

    def start_diagnostic_flow(self, language: str = 'english') -> Dict:
        """
        Start the diagnostic question flow

        Args:
            language: Conversation language

        Returns:
            Dict: First question
        """
        self.language = language
        self.current_state = FallbackState.ASKING_QUESTIONS
        self.current_question_index = 0
        self.collected_answers = {}

        return self.get_current_question()

    def get_current_question(self) -> Dict:
        """
        Get current question in the flow

        Returns:
            Dict: Current question with options
        """
        if self.current_question_index >= len(self.diagnostic_questions):
            self.current_state = FallbackState.GENERATING_ADVICE
            return {
                "status": "completed",
                "message": "Thank you for providing the information. Let me analyze and provide advice..."
            }

        question = self.diagnostic_questions[self.current_question_index]
        lang_suffix = '_si' if self.language == 'sinhala' else '_en'

        return {
            "status": "asking",
            "question_id": question['id'],
            "question_text": question[f'text{lang_suffix}'],
            "question_type": question['type'].value,
            "options": question.get(f'options{lang_suffix}', []),
            "required": question.get('required', False),
            "trigger_image_upload": question.get('trigger_image_upload', False),
            "progress": {
                "current": self.current_question_index + 1,
                "total": len(self.diagnostic_questions)
            }
        }

    def process_answer(self, answer: Any, skip: bool = False) -> Dict:
        """
        Process user's answer and move to next question

        Args:
            answer: User's answer
            skip: Whether user wants to skip this question

        Returns:
            Dict: Next question or completion status
        """
        if not skip:
            current_q = self.diagnostic_questions[self.current_question_index]
            self.collected_answers[current_q['key']] = answer

        # Move to next question
        self.current_question_index += 1

        return self.get_current_question()

    def generate_advice(self) -> Dict:
        """
        Generate general diagnostic advice based on collected answers

        Returns:
            Dict: Generated advice
        """
        self.current_state = FallbackState.GENERATING_ADVICE

        # Use Gemini to generate contextual advice
        advice_text = self.gemini_api.generate_fallback_advice(
            self.collected_answers,
            language=self.language
        )

        # Add quick checks based on symptoms
        quick_checks = self._generate_quick_checks()

        # Determine urgency level
        urgency = self._assess_urgency()

        result = {
            "status": "completed",
            "advice": advice_text,
            "quick_checks": quick_checks,
            "urgency": urgency,
            "context": self.collected_answers,
            "recommendation": self._generate_recommendation()
        }

        self.current_state = FallbackState.COMPLETED
        return result

    def _generate_quick_checks(self) -> List[str]:
        """
        Generate quick checks based on symptoms

        Returns:
            List[str]: Quick check items
        """
        checks = []

        # Check based on sounds
        sounds = self.collected_answers.get('sounds', '')
        if 'clicking' in sounds.lower():
            checks.append("Check battery terminals for corrosion")
            checks.append("Test battery voltage (should be 12.4V+)")
        elif 'squealing' in sounds.lower():
            checks.append("Inspect serpentine belt condition")
            checks.append("Check brake pads thickness")
        elif 'grinding' in sounds.lower():
            checks.append("Check brake pads immediately")
            checks.append("Inspect wheel bearings")

        # Check based on smells
        smells = self.collected_answers.get('smells', '')
        if 'burning' in smells.lower():
            checks.append("Check engine oil level")
            checks.append("Look for oil leaks")
        elif 'sweet' in smells.lower():
            checks.append("Check coolant level")
            checks.append("Inspect radiator and hoses for leaks")
        elif 'gasoline' in smells.lower() or 'fuel' in smells.lower():
            checks.append("Check for fuel leaks immediately")
            checks.append("Inspect fuel cap seal")

        # Check based on visual observations
        visual = self.collected_answers.get('visual', '')
        if 'smoke' in visual.lower():
            checks.append("Do not continue driving")
            checks.append("Check coolant and oil levels (when cool)")
        elif 'leak' in visual.lower():
            checks.append("Identify fluid type (color and smell)")
            checks.append("Check fluid levels")

        # Generic checks if none specific
        if not checks:
            checks = [
                "Check all fluid levels (oil, coolant, brake fluid)",
                "Inspect for loose connections or damaged wires",
                "Look for any unusual wear or damage",
                "Try restarting the vehicle after 5 minutes"
            ]

        return checks

    def _assess_urgency(self) -> Dict:
        """
        Assess urgency level based on symptoms

        Returns:
            Dict: Urgency information
        """
        # High urgency indicators
        high_urgency_keywords = [
            'smoke', 'fire', 'burning smell', 'no brakes', 'steering problem',
            'engine overheating', 'fuel leak', 'brake failure'
        ]

        # Medium urgency indicators
        medium_urgency_keywords = [
            'warning light', 'grinding', 'vibration', 'loss of power',
            'difficulty starting', 'oil leak'
        ]

        # Check all answers for urgency indicators
        all_answers = ' '.join([str(v).lower() for v in self.collected_answers.values()])

        for keyword in high_urgency_keywords:
            if keyword in all_answers:
                return {
                    "level": "high",
                    "color": "red",
                    "message": "⚠️ HIGH PRIORITY - Address immediately",
                    "safe_to_drive": "no",
                    "action": "Do not drive. Get immediate professional help."
                }

        for keyword in medium_urgency_keywords:
            if keyword in all_answers:
                return {
                    "level": "medium",
                    "color": "orange",
                    "message": "⚡ MEDIUM PRIORITY - Address soon",
                    "safe_to_drive": "limited",
                    "action": "Limit driving and schedule service within 1-2 days."
                }

        # Default: low urgency
        return {
            "level": "low",
            "color": "yellow",
            "message": "✓ LOW PRIORITY - Monitor and schedule service",
            "safe_to_drive": "yes",
            "action": "Safe to drive, but schedule maintenance when convenient."
        }

    def _generate_recommendation(self) -> str:
        """
        Generate final recommendation

        Returns:
            str: Recommendation text
        """
        urgency = self._assess_urgency()

        if urgency['level'] == 'high':
            return "We strongly recommend having your vehicle inspected by a professional mechanic immediately. Do not attempt to drive the vehicle."
        elif urgency['level'] == 'medium':
            return "We recommend scheduling an appointment with a mechanic within the next 1-2 days to properly diagnose and fix the issue."
        else:
            return "Monitor the situation and schedule a maintenance appointment when convenient. If symptoms worsen, seek professional help sooner."

    def reset(self):
        """Reset fallback system to initial state"""
        self.current_state = FallbackState.INITIAL
        self.current_question_index = 0
        self.collected_answers = {}

    def get_state(self) -> Dict:
        """
        Get current state of fallback system

        Returns:
            Dict: Current state information
        """
        return {
            "state": self.current_state.value,
            "current_question": self.current_question_index,
            "total_questions": len(self.diagnostic_questions),
            "answers_collected": len(self.collected_answers),
            "language": self.language
        }


# Example usage and testing
if __name__ == "__main__":
    print("=" * 70)
    print("Testing Fallback System")
    print("=" * 70)

    try:
        from gemini_api import GeminiAPI

        # Initialize (requires GEMINI_API_KEY environment variable)
        api = GeminiAPI()
        fallback = FallbackSystem(api, language='english')

        # Start diagnostic flow
        print("\n1. Starting diagnostic flow...")
        question = fallback.start_diagnostic_flow()
        print(f"\nQ{question['progress']['current']}: {question['question_text']}")
        print(f"Options: {question['options']}")

        # Simulate answering questions
        print("\n2. Simulating answers...")
        answers = [
            "Toyota Aqua",
            "When starting the car",
            "Yes",
            "Clicking sound",
            "No strange smells",
            "Nothing visible",
            "Difficulty starting"
        ]

        for i, answer in enumerate(answers):
            print(f"\nAnswer {i+1}: {answer}")
            next_q = fallback.process_answer(answer)
            if next_q['status'] == 'completed':
                break
            print(f"Q{next_q['progress']['current']}: {next_q['question_text']}")

        # Generate advice
        print("\n3. Generating advice...")
        result = fallback.generate_advice()

        print(f"\n{'='*70}")
        print(f"DIAGNOSTIC RESULT")
        print(f"{'='*70}")
        print(f"\nUrgency: {result['urgency']['message']}")
        print(f"Safe to drive: {result['urgency']['safe_to_drive']}")
        print(f"\nQuick Checks:")
        for check in result['quick_checks']:
            print(f"  - {check}")
        print(f"\nAdvice:\n{result['advice'][:300]}...")
        print(f"\nRecommendation:\n{result['recommendation']}")

        print("\n" + "=" * 70)
        print("✅ All tests completed successfully!")
        print("=" * 70)

    except Exception as e:
        print(f"\n❌ Error: {e}")
        print("\nMake sure to set GEMINI_API_KEY environment variable!")
        import traceback
        traceback.print_exc()
