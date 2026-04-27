"""
Quick test script for Gemini API
"""
import os

# Set API key
os.environ['GEMINI_API_KEY'] = 'AIzaSyDYCz9POfhc6pBuEd-wX1IYOu4sBW3H8Yo'

print("=" * 70)
print("Testing Gemini API Connection")
print("=" * 70)

try:
    from gemini_api import GeminiAPI

    # Initialize API
    print("\n1. Initializing Gemini API...")
    api = GeminiAPI()
    print("   >>> Gemini API initialized successfully!")

    # Test simple response
    print("\n2. Testing text generation...")
    response = api.generate_response("My Toyota Aqua won't start")
    print(f"   >>> Response received ({len(response)} characters)")
    print(f"\n   Response preview:\n   {response[:300]}...")

    # Test intent classification
    print("\n3. Testing intent classification...")
    intent = api.classify_intent("My Aqua has engine problem")
    print(f"   >>> Intent: {intent.get('intent')}")
    print(f"   Vehicle: {intent.get('vehicle_model')}")
    print(f"   Issue: {intent.get('issue_type')}")

    print("\n" + "=" * 70)
    print(">>> ALL TESTS PASSED - Gemini API is working!")
    print("=" * 70)

except Exception as e:
    print(f"\n>>> Error: {e}")
    import traceback
    traceback.print_exc()
