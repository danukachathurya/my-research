"""
Download all required NLTK data for the vehicle chatbot project
Run this script BEFORE running the notebook if you get NLTK errors
"""

import nltk
import ssl

print("=" * 70)
print("NLTK Data Downloader for Vehicle Chatbot")
print("=" * 70)
print()

# Fix SSL certificate issues
try:
    _create_unverified_https_context = ssl._create_unverified_context
except AttributeError:
    print("SSL context already configured")
else:
    ssl._create_default_https_context = _create_unverified_https_context
    print("✓ SSL context configured")

print()

# List of required packages
required_packages = [
    ('punkt', 'Sentence tokenization (old version)'),
    ('punkt_tab', 'Sentence tokenization (NLTK 3.9+ new version)'),
    ('stopwords', 'Common stopwords for filtering'),
    ('wordnet', 'Word meanings for lemmatization'),
    ('omw-1.4', 'Open Multilingual Wordnet'),
    ('averaged_perceptron_tagger', 'POS tagging (old version)'),
    ('averaged_perceptron_tagger_eng', 'POS tagging (new version)')
]

print(f"Downloading {len(required_packages)} NLTK packages...")
print()

success_count = 0
failed_packages = []

for package, description in required_packages:
    print(f"[{success_count + 1}/{len(required_packages)}] {package:35s}", end=" ")
    try:
        nltk.download(package, quiet=True)
        print("✓ Success")
        success_count += 1
    except Exception as e:
        print(f"✗ Failed: {e}")
        failed_packages.append((package, str(e)))

print()
print("=" * 70)
print("DOWNLOAD SUMMARY")
print("=" * 70)
print(f"✓ Successfully downloaded: {success_count}/{len(required_packages)} packages")

if failed_packages:
    print(f"✗ Failed: {len(failed_packages)} packages")
    print()
    print("Failed packages:")
    for package, error in failed_packages:
        print(f"  - {package}: {error}")
    print()
    print("Try running this script again or download manually:")
    print("  python -m nltk.downloader all")
else:
    print()
    print("✓ All NLTK data downloaded successfully!")
    print()
    print("You can now run your Jupyter notebook without NLTK errors.")

print("=" * 70)
print()

# Verify installation
print("Verifying installation...")
print()

verified = 0
for package, description in required_packages:
    try:
        # Try to find the package
        if package in ['punkt', 'punkt_tab']:
            nltk.data.find(f'tokenizers/{package}')
        elif package == 'stopwords':
            nltk.data.find('corpora/stopwords')
        elif package in ['wordnet', 'omw-1.4']:
            nltk.data.find('corpora/wordnet')
        else:
            nltk.data.find(f'taggers/{package}')
        print(f"✓ {package:35s} - Verified")
        verified += 1
    except LookupError:
        print(f"✗ {package:35s} - Not found")

print()
if verified == len(required_packages):
    print("=" * 70)
    print("✓✓✓ ALL PACKAGES VERIFIED - READY TO USE! ✓✓✓")
    print("=" * 70)
else:
    print("=" * 70)
    print(f"⚠ Some packages not verified ({verified}/{len(required_packages)})")
    print("=" * 70)
    print("Try downloading all NLTK data:")
    print("  python -m nltk.downloader all")

print()
input("Press Enter to exit...")
