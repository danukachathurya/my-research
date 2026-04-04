# 📮 Postman Testing Guide - Vehicle Chatbot API

## Complete guide to test your Vehicle Troubleshooting Chatbot API using Postman

---

## 🚀 Quick Setup

### Step 1: Install Postman
Download from: https://www.postman.com/downloads/

### Step 2: Start Your Server
```cmd
cd "e:\research\gamage new\data"
start_server_simple.bat
```

Wait for: `Uvicorn running on http://0.0.0.0:8000`

### Step 3: Verify Server is Running
Open browser: http://localhost:8000

You should see:
```json
{
  "status": "online",
  "service": "Vehicle Troubleshooting Chatbot API",
  "version": "1.0.0"
}
```

---

## 📋 Postman Collection Setup

### Create New Collection

1. Open Postman
2. Click **"New"** → **"Collection"**
3. Name: `Vehicle Chatbot API`
4. Click **"Create"**

### Set Collection Variables

1. Click on your collection
2. Go to **"Variables"** tab
3. Add these variables:

| Variable | Initial Value | Current Value |
|----------|--------------|---------------|
| `base_url` | `http://localhost:8000` | `http://localhost:8000` |
| `session_id` | (leave empty) | (leave empty) |

4. Click **"Save"**

---

## 🧪 Test Endpoints (Step by Step)

### Test 1: Health Check ✅

**Purpose:** Verify server is running

**Request:**
- **Method:** `GET`
- **URL:** `{{base_url}}/`
- **Headers:** None needed

**Steps in Postman:**
1. Click **"Add request"** in your collection
2. Name: `1. Health Check`
3. Method: `GET`
4. URL: `{{base_url}}/`
5. Click **"Send"**

**Expected Response (200 OK):**
```json
{
  "status": "online",
  "service": "Vehicle Troubleshooting Chatbot API",
  "version": "1.0.0",
  "firebase": "disconnected",
  "chatbot": "ready"
}
```

✅ If you see this, your server is working!

---

### Test 2: Start Conversation 💬

**Purpose:** Create a new chat session

**Request:**
- **Method:** `POST`
- **URL:** `{{base_url}}/api/conversation/start`
- **Headers:**
  - `Content-Type: application/json`
- **Body (raw JSON):**

```json
{
  "user_id": "test_user_123",
  "language": "english"
}
```

**Steps in Postman:**
1. Add new request: `2. Start Conversation`
2. Method: `POST`
3. URL: `{{base_url}}/api/conversation/start`
4. Go to **"Headers"** tab
   - Key: `Content-Type`
   - Value: `application/json`
5. Go to **"Body"** tab
   - Select **"raw"**
   - Select **"JSON"** from dropdown
   - Paste the JSON above
6. Click **"Send"**

**Expected Response (200 OK):**
```json
{
  "success": true,
  "session_id": "abc-123-xyz-456",
  "message": "Hello! I'm your vehicle troubleshooting assistant. I can help you diagnose issues with Toyota Aqua, Prius, Corolla, Vitz, and Suzuki Alto...",
  "language": "english"
}
```

**Important:** Copy the `session_id` value!

**Auto-Save Session ID (Optional):**
1. Go to **"Tests"** tab in this request
2. Add this script:
```javascript
var response = pm.response.json();
if (response.session_id) {
    pm.collectionVariables.set("session_id", response.session_id);
    console.log("Session ID saved: " + response.session_id);
}
```
3. Click **"Send"** again
4. Now `{{session_id}}` variable is automatically set!

---

### Test 3: Send Message (Known Issue) 🚗

**Purpose:** Test chatbot with a vehicle issue from database

**Request:**
- **Method:** `POST`
- **URL:** `{{base_url}}/api/conversation/message`
- **Headers:**
  - `Content-Type: application/json`
- **Body (raw JSON):**

```json
{
  "session_id": "{{session_id}}",
  "message": "My Toyota Aqua won't start and I hear clicking noise"
}
```

**Steps in Postman:**
1. Add new request: `3. Send Message - Known Issue`
2. Method: `POST`
3. URL: `{{base_url}}/api/conversation/message`
4. Headers: `Content-Type: application/json`
5. Body (raw JSON): Paste above
6. Click **"Send"**

**Expected Response (200 OK):**
```json
{
  "success": true,
  "status": "success",
  "source": "knowledge_base",
  "confidence": 0.89,
  "message": "I found a match in my database...\n\n🔍 QUICK CHECKS:\n• Check battery terminals\n• Test battery voltage\n...",
  "vehicle": "Aqua",
  "severity": {
    "level": "medium",
    "color": "yellow"
  }
}
```

✅ **Success:** Bot found the issue in database and provided solution!

---

### Test 4: Send Message (Unknown Issue - Fallback) ❓

**Purpose:** Trigger fallback diagnostic system

**Request:**
- **Method:** `POST`
- **URL:** `{{base_url}}/api/conversation/message`
- **Body (raw JSON):**

```json
{
  "session_id": "{{session_id}}",
  "message": "My car has a weird smell"
}
```

**Expected Response:**
```json
{
  "success": true,
  "status": "fallback_mode",
  "message": "I don't have a specific match for your issue...",
  "question": {
    "status": "asking",
    "question_id": "q1_vehicle",
    "question_text": "What is your car model?",
    "question_type": "selection",
    "options": ["Toyota Aqua", "Toyota Prius", "Toyota Corolla", "Suzuki Alto", "Toyota Vitz", "Other"],
    "progress": {
      "current": 1,
      "total": 7
    }
  },
  "source": "fallback_system"
}
```

✅ **Success:** Bot activated fallback system and asking diagnostic questions!

---

### Test 5: Answer Fallback Question 💡

**Purpose:** Answer diagnostic question

**Request:**
```json
{
  "session_id": "{{session_id}}",
  "message": "Toyota Vitz"
}
```

**Expected Response:**
```json
{
  "success": true,
  "status": "fallback_mode",
  "question": {
    "status": "asking",
    "question_id": "q2_occurrence",
    "question_text": "When does the problem occur?",
    "options": ["When starting the car", "While driving", "When braking", ...],
    "progress": {
      "current": 2,
      "total": 7
    }
  }
}
```

**Continue answering until all questions done!**

---

### Test 6: Get Supported Vehicles 🚙

**Purpose:** Check which vehicles are supported

**Request:**
- **Method:** `GET`
- **URL:** `{{base_url}}/api/vehicles`

**Expected Response:**
```json
{
  "success": true,
  "vehicles": [
    "Toyota Aqua",
    "Toyota Prius",
    "Toyota Corolla",
    "Suzuki Alto",
    "Toyota Vitz"
  ]
}
```

---

### Test 7: Get Warning Lights ⚠️

**Purpose:** List all supported warning lights

**Request:**
- **Method:** `GET`
- **URL:** `{{base_url}}/api/warning-lights`

**Expected Response:**
```json
{
  "success": true,
  "warning_lights": [
    {
      "id": "wl_001",
      "name": "Check Engine Light",
      "symbol": "Engine outline or word 'ENGINE'",
      "colors": ["yellow", "amber", "orange"]
    },
    {
      "id": "wl_002",
      "name": "Battery/Charging Warning Light",
      "symbol": "Battery symbol or 'BAT'",
      "colors": ["red"]
    },
    ...
  ]
}
```

---

### Test 8: Translate Text 🌐

**Purpose:** Test translation feature

**Request:**
- **Method:** `POST`
- **URL:** `{{base_url}}/api/translate`
- **Body (raw JSON):**

```json
{
  "text": "My car won't start",
  "source_lang": "english",
  "target_lang": "sinhala"
}
```

**Expected Response:**
```json
{
  "success": true,
  "translated_text": "මගේ කාරය ස්ටාර්ට් වෙන්නේ නැහැ",
  "source_lang": "english",
  "target_lang": "sinhala"
}
```

---

### Test 9: Submit Feedback ⭐

**Purpose:** Submit user feedback

**Request:**
- **Method:** `POST`
- **URL:** `{{base_url}}/api/feedback`
- **Body (raw JSON):**

```json
{
  "session_id": "{{session_id}}",
  "user_id": "test_user_123",
  "rating": 5,
  "comment": "Very helpful! Solved my problem.",
  "was_helpful": true
}
```

**Expected Response:**
```json
{
  "success": true,
  "message": "Thank you for your feedback!"
}
```

---

### Test 10: End Conversation 👋

**Purpose:** Close the chat session

**Request:**
- **Method:** `POST`
- **URL:** `{{base_url}}/api/conversation/end`
- **Body (raw JSON):**

```json
{
  "session_id": "{{session_id}}"
}
```

**Expected Response:**
```json
{
  "success": true,
  "status": "ended",
  "message": "Thank you for using the vehicle troubleshooting assistant. Stay safe!",
  "conversation_summary": {
    "duration": "2024-12-19T10:30:00Z",
    "messages_count": 5
  }
}
```

---

## 📸 Test with Image Upload

### Test 11: Upload Dashboard Image 🖼️

**Purpose:** Upload warning light image

**Request:**
- **Method:** `POST`
- **URL:** `{{base_url}}/api/upload-image`
- **Body:** `form-data`
  - Key: `file` (change type to **"File"**)
  - Value: Select an image file

**Steps:**
1. Add new request: `11. Upload Image`
2. Method: `POST`
3. URL: `{{base_url}}/api/upload-image`
4. Go to **"Body"** tab
5. Select **"form-data"**
6. Add key: `file`
7. Change type dropdown to **"File"**
8. Click **"Select Files"** and choose an image
9. Click **"Send"**

**Expected Response:**
```json
{
  "success": true,
  "url": "https://storage.googleapis.com/.../image.jpg",
  "filename": "dashboard_images/20241219_103000_warning.jpg"
}
```

---

### Test 12: Send Message with Image (Base64) 📷

**Purpose:** Send message with embedded image

**Request:**
- **Method:** `POST`
- **URL:** `{{base_url}}/api/conversation/message`
- **Body:**

```json
{
  "session_id": "{{session_id}}",
  "message": "What is this warning light?",
  "image_base64": "data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAA..."
}
```

**How to get Base64:**
1. Use online tool: https://base64.guru/converter/encode/image
2. Upload your dashboard image
3. Copy the base64 string
4. Paste in `image_base64` field

**Expected Response:**
```json
{
  "success": true,
  "status": "lights_detected",
  "message": "I detected the following warning light(s): Check Engine Light.\n\nIs it steady or blinking?",
  "detected_lights": [
    {
      "id": "wl_001",
      "name_en": "Check Engine Light",
      "detected_color": "yellow",
      "match_confidence": 0.95
    }
  ],
  "question": {
    "question": "Is the warning light steady or blinking?",
    "options": ["Steady (stays on continuously)", "Blinking (flashing on and off)"]
  },
  "requires_input": true
}
```

---

## 🔄 Complete Conversation Flow Example

### Scenario: User reports starting problem

**1. Start Conversation**
```
POST /api/conversation/start
Body: {"user_id": "user123", "language": "english"}
→ Get session_id
```

**2. Send Initial Query**
```
POST /api/conversation/message
Body: {
  "session_id": "SESSION_ID",
  "message": "My Aqua won't start"
}
→ Bot provides diagnostic steps
```

**3. Follow-up Question**
```
POST /api/conversation/message
Body: {
  "session_id": "SESSION_ID",
  "message": "I checked the battery, it looks fine"
}
→ Bot suggests next steps
```

**4. Submit Feedback**
```
POST /api/feedback
Body: {
  "session_id": "SESSION_ID",
  "user_id": "user123",
  "rating": 5,
  "was_helpful": true
}
```

**5. End Conversation**
```
POST /api/conversation/end
Body: {"session_id": "SESSION_ID"}
```

---

## 🎯 Postman Tests (Automated)

### Add Tests to Validate Responses

In each request's **"Tests"** tab, add:

**For Health Check:**
```javascript
pm.test("Status is 200 OK", function () {
    pm.response.to.have.status(200);
});

pm.test("Response has status field", function () {
    var jsonData = pm.response.json();
    pm.expect(jsonData.status).to.eql("online");
});
```

**For Start Conversation:**
```javascript
pm.test("Status is 200 OK", function () {
    pm.response.to.have.status(200);
});

pm.test("Response has session_id", function () {
    var jsonData = pm.response.json();
    pm.expect(jsonData).to.have.property("session_id");

    // Save session_id for next requests
    pm.collectionVariables.set("session_id", jsonData.session_id);
});

pm.test("Success is true", function () {
    var jsonData = pm.response.json();
    pm.expect(jsonData.success).to.eql(true);
});
```

**For Send Message:**
```javascript
pm.test("Status is 200 OK", function () {
    pm.response.to.have.status(200);
});

pm.test("Response has message", function () {
    var jsonData = pm.response.json();
    pm.expect(jsonData).to.have.property("message");
});

pm.test("Response has status field", function () {
    var jsonData = pm.response.json();
    pm.expect(jsonData).to.have.property("status");
});
```

---

## 📊 Environment Setup (Optional)

### Create Environments for Different Servers

**Development:**
- `base_url`: `http://localhost:8000`

**Production:**
- `base_url`: `https://your-production-url.com`

**To switch:**
1. Top-right dropdown in Postman
2. Select environment
3. All requests use that base_url

---

## 🎨 Organize Your Collection

### Folder Structure:

```
Vehicle Chatbot API/
├── 📁 Setup
│   ├── 1. Health Check
│   └── 2. Get Supported Vehicles
│
├── 📁 Conversations
│   ├── 3. Start Conversation
│   ├── 4. Send Message - Known Issue
│   ├── 5. Send Message - Unknown Issue
│   ├── 6. Answer Diagnostic Question
│   └── 7. End Conversation
│
├── 📁 Warning Lights
│   ├── 8. Upload Image
│   ├── 9. Send Message with Image
│   └── 10. Get Warning Lights
│
└── 📁 Utilities
    ├── 11. Translate Text
    └── 12. Submit Feedback
```

---

## 🔍 Debugging Tips

### Enable Postman Console
1. Click **"Console"** button (bottom-left)
2. See all requests/responses
3. View request details
4. Check response times

### Common Response Codes

| Code | Meaning | Likely Cause |
|------|---------|--------------|
| 200 | Success | Everything worked! |
| 404 | Not Found | Wrong URL or endpoint |
| 422 | Validation Error | Missing required field |
| 500 | Server Error | Backend error - check server logs |
| 503 | Service Unavailable | Server not running |

### Check Server Logs

When testing, watch your server console:
```
INFO: 127.0.0.1:54321 - "POST /api/conversation/start HTTP/1.1" 200 OK
```

---

## 📥 Import Postman Collection

### Save & Export Collection

1. Right-click collection
2. **"Export"**
3. Choose **"Collection v2.1"**
4. Save as: `Vehicle_Chatbot_API.postman_collection.json`

### Share with Team

Send the exported JSON file
Others can import: **File → Import**

---

## ✅ Quick Test Checklist

Test in this order:

- [ ] Health Check (GET /)
- [ ] Start Conversation
- [ ] Send Known Issue Message
- [ ] Send Unknown Issue Message
- [ ] Answer Diagnostic Questions
- [ ] Get Supported Vehicles
- [ ] Get Warning Lights
- [ ] Translate Text
- [ ] Submit Feedback
- [ ] End Conversation

---

## 🎓 Advanced Testing

### Test Concurrent Conversations

Create multiple session IDs and switch between them:

```javascript
// In Collection Variables
session_1: "abc-123"
session_2: "def-456"
session_3: "ghi-789"
```

Use `{{session_1}}`, `{{session_2}}`, etc.

### Load Testing

Use Postman's **Collection Runner**:
1. Click collection → **"Run"**
2. Set iterations: 100
3. Set delay: 1000ms
4. Click **"Run Vehicle Chatbot API"**

---

## 🎉 You're Ready!

**Start Testing:**
1. Make sure server is running
2. Create collection in Postman
3. Follow tests 1-12 above
4. Watch your chatbot respond!

**Need Help?**
- Server logs show request details
- Postman console shows full HTTP traffic
- Check [QUICK_START.md](QUICK_START.md) for server troubleshooting

---

**Happy Testing! 📮✨**
