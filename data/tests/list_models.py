import os
import google.generativeai as genai

os.environ['GEMINI_API_KEY'] = 'AIzaSyDYCz9POfhc6pBuEd-wX1IYOu4sBW3H8Yo'
genai.configure(api_key=os.environ['GEMINI_API_KEY'])

print("Available Gemini models:")
print("=" * 70)
for model in genai.list_models():
    if 'generateContent' in model.supported_generation_methods:
        print(f"  - {model.name}")
print("=" * 70)
