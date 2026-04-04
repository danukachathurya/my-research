# RoadResQ App Flow Diagram

## 📱 Application Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         RoadResQ Flutter App                     │
└─────────────────────────────────────────────────────────────────┘
                                 │
                                 ▼
                    ┌────────────────────────┐
                    │      main.dart         │
                    │  (App Entry Point)     │
                    └────────────────────────┘
                                 │
                                 ▼
                    ┌────────────────────────┐
                    │     MaterialApp        │
                    │  (Theme & Routing)     │
                    └────────────────────────┘
                                 │
                                 ▼
                    ┌────────────────────────┐
                    │     HomeScreen         │
                    │  (Image Selection)     │
                    └────────────────────────┘
```

---

## 🏠 Home Screen Flow

```
┌───────────────────────────────────────────────────────────────┐
│                         HOME SCREEN                            │
│                                                                │
│  ┌──────────────────────────────────────────────────────┐    │
│  │  App Bar: "RoadResQ"                    [🟢]         │    │
│  └──────────────────────────────────────────────────────┘    │
│                                                                │
│  ┌──────────────────────────────────────────────────────┐    │
│  │        "Vehicle Damage Detection"                     │    │
│  │   Upload a photo to get instant analysis...          │    │
│  └──────────────────────────────────────────────────────┘    │
│                                                                │
│  ┌──────────────────────────────────────────────────────┐    │
│  │                                                       │    │
│  │         [Image Preview Area - 300px]                 │    │
│  │                                                       │    │
│  │  📷 No image selected  OR  [Selected Image]          │    │
│  │                                                       │    │
│  └──────────────────────────────────────────────────────┘    │
│                                                                │
│  ┌──────────────────────────────────────────────────────┐    │
│  │         [🖼️  Select Image]                           │    │
│  └──────────────────────────────────────────────────────┘    │
│                                                                │
│  ┌──────────────────────────────────────────────────────┐    │
│  │         [🔍 Analyze Damage]  (enabled when image)    │    │
│  └──────────────────────────────────────────────────────┘    │
│                                                                │
│  ┌──────────────────────────────────────────────────────┐    │
│  │  ℹ️  How it works:                                    │    │
│  │   1. Take or select a photo                          │    │
│  │   2. Tap "Analyze Damage"                            │    │
│  │   3. Get instant AI assessment                       │    │
│  │   4. View recommendations                            │    │
│  └──────────────────────────────────────────────────────┘    │
└───────────────────────────────────────────────────────────────┘
```

---

## 📸 Image Selection Flow

```
User taps "Select Image"
         │
         ▼
┌────────────────────┐
│  Bottom Sheet      │
│  ┌──────────────┐  │
│  │ 📷 Camera    │  │──────► Open Camera ──► Take Photo ──┐
│  └──────────────┘  │                                      │
│  ┌──────────────┐  │                                      │
│  │ 🖼️  Gallery  │  │──────► Open Gallery ─► Select Photo ─┤
│  └──────────────┘  │                                      │
└────────────────────┘                                      │
                                                            │
                                                            ▼
                                              ┌──────────────────────┐
                                              │ Image Preview        │
                                              │ "Change Image" button│
                                              │ "Analyze" enabled    │
                                              └──────────────────────┘
```

---

## 🔄 Analysis Flow

```
User taps "Analyze Damage"
         │
         ▼
┌────────────────────────────────────────────────────────┐
│  Loading State                                         │
│  ┌──────────────────────────────────────────────────┐ │
│  │         🔄 CircularProgressIndicator             │ │
│  │         "Analyzing damage..."                    │ │
│  └──────────────────────────────────────────────────┘ │
└────────────────────────────────────────────────────────┘
         │
         ▼
┌────────────────────────────────────────────────────────┐
│  DamageDetectionService.detectDamage()                 │
│  • Convert image to bytes                              │
│  • Create multipart request                            │
│  • POST to /detect-damage                              │
│  • Parse JSON response                                 │
└────────────────────────────────────────────────────────┘
         │
         ├─────► Success ────────┐
         │                       │
         └─────► Error ──────────┤
                                 │
                                 ▼
                    ┌────────────────────────┐
                    │  Result or Error       │
                    └────────────────────────┘
```

---

## 📊 Results Screen Layout

```
┌───────────────────────────────────────────────────────────────┐
│                       RESULTS SCREEN                           │
│                                                                │
│  ┌──────────────────────────────────────────────────────┐    │
│  │  [← Back]  "Damage Analysis"                         │    │
│  └──────────────────────────────────────────────────────┘    │
│                                                                │
│  ┌──────────────────────────────────────────────────────┐    │
│  │                                                       │    │
│  │         [Damage Image - 250px height]                │    │
│  │                                                       │    │
│  └──────────────────────────────────────────────────────┘    │
│                                                                │
│  ┌──────────────────────────────────────────────────────┐    │
│  │            [Icon for damage type]                    │    │
│  │                  DENT                                │    │
│  │                                                       │    │
│  │   [Confidence: 87%]    [Severity: 2/5]               │    │
│  └──────────────────────────────────────────────────────┘    │
│                                                                │
│  ┌──────────────────────────────────────────────────────┐    │
│  │  ⚠️  Urgency Level                                    │    │
│  │  Medium - Should be repaired within 2-4 weeks        │    │
│  └──────────────────────────────────────────────────────┘    │
│                                                                │
│  ┌──────────────────────────────────────────────────────┐    │
│  │  📖 Description                                       │    │
│  │  A dent is a physical indentation...                 │    │
│  └──────────────────────────────────────────────────────┘    │
│                                                                │
│  ┌──────────────────────────────────────────────────────┐    │
│  │  🔍 What Happened                                     │    │
│  │  The vehicle body has been impacted...               │    │
│  └──────────────────────────────────────────────────────┘    │
│                                                                │
│  ┌──────────────────────────────────────────────────────┐    │
│  │  ⚡ Immediate Actions                                 │    │
│  │  1. Check if the dent affects moving parts           │    │
│  │  2. Inspect for paint cracks                         │    │
│  │  3. Take photos for insurance                        │    │
│  │  4. Avoid DIY if paint is cracked                    │    │
│  └──────────────────────────────────────────────────────┘    │
│                                                                │
│  ┌──────────────────────────────────────────────────────┐    │
│  │  🔧 Repair Options                                    │    │
│  │  1. Paintless Dent Repair (PDR)                      │    │
│  │  2. Traditional body work                            │    │
│  │  3. Panel replacement                                │    │
│  └──────────────────────────────────────────────────────┘    │
│                                                                │
│  ┌──────────────────────────────────────────────────────┐    │
│  │  ⏱️  Estimated Repair Time                            │    │
│  │  2-8 hours depending on size and location            │    │
│  └──────────────────────────────────────────────────────┘    │
│                                                                │
│  ┌──────────────────────────────────────────────────────┐    │
│  │  💡 Prevention Tips                                   │    │
│  │  Park away from high-traffic areas...                │    │
│  └──────────────────────────────────────────────────────┘    │
│                                                                │
│  ┌──────────────────────────────────────────────────────┐    │
│  │  [← Analyze Another Image]                           │    │
│  └──────────────────────────────────────────────────────┘    │
│                                                                │
└───────────────────────────────────────────────────────────────┘
```

---

## 🔄 Data Flow Architecture

```
┌──────────────┐       ┌──────────────────┐       ┌──────────────┐
│              │       │                  │       │              │
│  UI Layer    │◄──────│  Service Layer   │◄──────│  API Server  │
│  (Screens)   │       │  (HTTP Client)   │       │  (FastAPI)   │
│              │       │                  │       │              │
└──────────────┘       └──────────────────┘       └──────────────┘
       │                       │                         │
       │                       │                         │
   Widgets &              DamageDetection          ResNet-18 Model
   Navigation               Service                 + Gemini AI
       │                       │                         │
       ▼                       ▼                         ▼
  User Actions          HTTP Requests              AI Analysis
  (tap, select)         (multipart/json)          (image → result)
```

---

## 📦 Component Interaction

```
┌─────────────────────────────────────────────────────────────┐
│                     Component Diagram                        │
└─────────────────────────────────────────────────────────────┘

main.dart
   │
   └─► MaterialApp
         │
         └─► HomeScreen (StatefulWidget)
               │
               ├─► ImagePicker (package)
               │     └─► Camera / Gallery
               │
               ├─► DamageDetectionService
               │     └─► HTTP Client
               │           └─► FastAPI Server
               │
               └─► Navigator.push()
                     └─► ResultScreen (StatelessWidget)
                           │
                           ├─► DamageDetectionResult (model)
                           │
                           └─► Custom Widgets:
                                 ├─► _buildSection()
                                 ├─► _buildListSection()
                                 ├─► _buildInfoRow()
                                 └─► _buildInfoChip()
```

---

## 🎯 State Management Flow

```
┌────────────────────────────────────────────────────────────┐
│                   State Management                          │
└────────────────────────────────────────────────────────────┘

HomeScreen States:
   │
   ├─► _selectedImage: File?
   │     └─► null → no image
   │     └─► File → image selected
   │
   ├─► _isLoading: bool
   │     └─► false → idle
   │     └─► true → analyzing
   │
   └─► _serverConnected: bool
         └─► false → red indicator
         └─► true → green indicator

State Changes:
   │
   ├─► User picks image
   │     └─► setState() → _selectedImage = File
   │
   ├─► User taps analyze
   │     └─► setState() → _isLoading = true
   │     └─► API call → result
   │     └─► setState() → _isLoading = false
   │     └─► Navigate to ResultScreen
   │
   └─► App initializes
         └─► checkServerConnection()
         └─► setState() → _serverConnected = bool
```

---

## 🌐 Network Communication

```
┌────────────────────────────────────────────────────────────┐
│                 Network Request Flow                        │
└────────────────────────────────────────────────────────────┘

Flutter App                         FastAPI Server
    │                                      │
    │  1. Create MultipartRequest          │
    │     - file: image.jpg                │
    │     - method: POST                   │
    │     - url: /detect-damage            │
    │                                      │
    │  2. Send Request ──────────────────► │
    │                                      │
    │                                      │  3. Receive file
    │                                      │  4. Load into PIL
    │                                      │  5. Preprocess image
    │                                      │  6. ResNet-18 inference
    │                                      │  7. Get damage info
    │                                      │  8. Format JSON response
    │                                      │
    │  9. Receive Response ◄────────────── │
    │     {                                │
    │       "damage_type": "dent",         │
    │       "confidence": 0.87,            │
    │       "damage_details": {...}        │
    │     }                                │
    │                                      │
    │  10. Parse JSON                      │
    │  11. Create DamageDetectionResult    │
    │  12. Navigate to ResultScreen        │
    │                                      │
```

---

## 🎨 UI Component Hierarchy

```
MaterialApp
  └─► Theme (Material 3)
        │
        └─► HomeScreen
              ├─► AppBar
              │     ├─► Title: "RoadResQ"
              │     └─► Status Indicator (green/red dot)
              │
              ├─► Body (SingleChildScrollView)
              │     ├─► Column
              │           ├─► Header Text
              │           ├─► Description Text
              │           ├─► Image Container (300px)
              │           │     └─► Image.file() or Placeholder
              │           ├─► Select Button (ElevatedButton)
              │           ├─► Analyze Button (ElevatedButton)
              │           ├─► Server Status Warning (conditional)
              │           └─► Instructions Card
              │
              └─► Modal Bottom Sheet (image source)
                    ├─► Camera ListTile
                    └─► Gallery ListTile

ResultScreen
  └─► Scaffold
        ├─► AppBar
        │     └─► Title: "Damage Analysis"
        │
        └─► Body (SingleChildScrollView)
              └─► Column
                    ├─► Image Display (250px)
                    ├─► Damage Card
                    │     ├─► Icon
                    │     ├─► Damage Type
                    │     └─► Badges (confidence, severity)
                    ├─► Urgency Banner
                    ├─► Description Section
                    ├─► What Happened Section
                    ├─► Immediate Actions List
                    ├─► Repair Options List
                    ├─► Estimated Time Row
                    ├─► Prevention Tips Section
                    ├─► Additional Damages (conditional)
                    └─► Back Button
```

---

## 🔐 Permission Flow

```
iOS Permission Flow:
   App Launch
      │
      └─► Info.plist checked
            │
            ├─► Camera Usage Description
            ├─► Photo Library Description
            └─► Location Description
                  │
                  └─► User taps Camera/Gallery
                        │
                        └─► System shows permission dialog
                              │
                              ├─► Allow → Access granted
                              └─► Deny → Show error

Android Permission Flow:
   App Launch
      │
      └─► AndroidManifest.xml checked
            │
            ├─► CAMERA
            ├─► READ_EXTERNAL_STORAGE
            └─► ACCESS_FINE_LOCATION
                  │
                  └─► User taps Camera/Gallery
                        │
                        └─► Runtime permission requested
                              │
                              ├─► Grant → Access granted
                              └─► Deny → Show error
```

---

## 🚀 Build & Deployment Flow

```
Development
    │
    ├─► flutter run (debug mode)
    │     └─► Hot reload enabled
    │     └─► Debug tools available
    │
    ├─► flutter build apk --release (Android)
    │     └─► Optimized APK
    │     └─► Ready for distribution
    │
    └─► flutter build ios --release (iOS)
          └─► Archive in Xcode
          └─► Submit to App Store
```

This comprehensive flow diagram shows how all components of the RoadResQ Flutter app work together!
