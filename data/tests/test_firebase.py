"""
Firebase Connection Test Script

This script tests your Firebase setup:
1. Firestore Database connection
2. Storage connection
3. Read/Write operations

Run this AFTER setting up Firebase and downloading credentials.
"""

import os

print("=" * 70)
print("Firebase Connection Test")
print("=" * 70)

# Check if credentials file exists
creds_file = 'firebase-credentials.json'

if not os.path.exists(creds_file):
    print(f"\n>>> ERROR: {creds_file} not found!")
    print("\nPlease:")
    print("1. Go to Firebase Console")
    print("2. Project Settings > Service Accounts")
    print("3. Click 'Generate New Private Key'")
    print("4. Save the file as 'firebase-credentials.json'")
    print("5. Place it in this folder: e:\\research\\gamage new\\data\\")
    print("\nSee FIREBASE_SETUP_GUIDE.md for detailed instructions.")
    exit(1)

print(f"\n>>> Found credentials file: {creds_file}")

try:
    import firebase_admin
    from firebase_admin import credentials, firestore, storage
    from datetime import datetime

    print("\n1. Initializing Firebase...")

    # Initialize Firebase
    # IMPORTANT: Replace 'your-project-id' with your actual Firebase project ID
    cred = credentials.Certificate(creds_file)
    firebase_admin.initialize_app(cred, {
        'storageBucket': 'vehicle-chatbot-sl.appspot.com'  # <<< CHANGE THIS
    })
    print("   >>> Firebase initialized!")

    # Test Firestore
    print("\n2. Testing Firestore Database...")
    db = firestore.client()
    print("   >>> Firestore connected!")

    # Test write
    print("\n3. Testing Firestore write...")
    test_data = {
        'name': 'Test User',
        'test_message': 'Firebase test from Python',
        'timestamp': firestore.SERVER_TIMESTAMP,
        'created_at': datetime.now().isoformat()
    }

    test_ref = db.collection('users').document('test_user_001')
    test_ref.set(test_data)
    print("   >>> Write successful!")
    print(f"   >>> Created document in: users/test_user_001")

    # Test read
    print("\n4. Testing Firestore read...")
    doc = test_ref.get()
    if doc.exists:
        print("   >>> Read successful!")
        print(f"   >>> Data: {doc.to_dict()}")
    else:
        print("   >>> WARNING: Document not found")

    # Test Storage
    print("\n5. Testing Firebase Storage...")
    bucket = storage.bucket()
    print(f"   >>> Storage connected!")
    print(f"   >>> Bucket name: {bucket.name}")

    # List some files (if any)
    blobs = list(bucket.list_blobs(max_results=5))
    if blobs:
        print(f"   >>> Found {len(blobs)} file(s) in storage")
    else:
        print("   >>> Storage is empty (this is normal for new projects)")

    # Create a test collection for conversations
    print("\n6. Creating test conversation...")
    conv_ref = db.collection('conversations').document('test_session_001')
    conv_ref.set({
        'session_id': 'test_session_001',
        'user_id': 'test_user_001',
        'language': 'english',
        'state': 'testing',
        'created_at': firestore.SERVER_TIMESTAMP,
        'is_active': True
    })
    print("   >>> Test conversation created!")

    # Add a test message
    msg_ref = conv_ref.collection('messages').add({
        'role': 'user',
        'content': 'This is a test message',
        'timestamp': firestore.SERVER_TIMESTAMP,
        'message_type': 'text'
    })
    print("   >>> Test message added!")

    print("\n" + "=" * 70)
    print(">>> ALL FIREBASE TESTS PASSED!")
    print("=" * 70)
    print("\n✓ Firestore: Working")
    print("✓ Storage: Working")
    print("✓ Read/Write: Working")
    print("\nYou can now:")
    print("1. Check Firebase Console to see your data")
    print("2. Run: python api_server.py")
    print("3. Start using the chatbot with Firebase backend")
    print("\nFirebase Console:")
    print("https://console.firebase.google.com")
    print("=" * 70)

except ImportError as e:
    print(f"\n>>> ERROR: Missing package")
    print(f"    {e}")
    print("\nInstall Firebase Admin SDK:")
    print("    pip install firebase-admin")

except Exception as e:
    print(f"\n>>> ERROR: {e}")
    print("\nPossible issues:")
    print("1. Incorrect project ID or storage bucket name")
    print("2. Firebase not enabled in console")
    print("3. Invalid credentials file")
    print("\nCheck FIREBASE_SETUP_GUIDE.md for troubleshooting")
    import traceback
    traceback.print_exc()
