# Flutter App Features

Complete overview of all features implemented in the Vehicle Troubleshooting Chatbot Flutter app.

## 1. Home Screen Features

### Server Status Indicator
- **Real-time connection check** to backend API
- **Visual status display**:
  - Green checkmark: Server online
  - Red error icon: Server offline
- **Refresh button** to manually check connection
- **Error messages** with backend setup instructions

### Vehicle Selection
- **5 Supported Vehicles**:
  1. Toyota Aqua
  2. Toyota Prius
  3. Toyota Corolla
  4. Toyota Vitz
  5. Suzuki Alto
- **One-tap selection** to start conversation
- **Disabled when offline** to prevent errors
- **Beautiful card-based UI** with icons

### Visual Design
- **Gradient background** (blue theme)
- **Large car icon** for brand identity
- **Clear typography** and spacing
- **Material Design 3** components

## 2. Chat Screen Features

### Real-time Messaging
- **Live chat interface** with scrolling
- **Auto-scroll** to latest message
- **Message timestamps** (HH:MM format)
- **Distinct message styles**:
  - User messages: Blue bubbles, right-aligned
  - Bot messages: Grey bubbles, left-aligned
- **Rounded corners** with modern design

### Message Input
- **Multi-line text input** with auto-resize
- **Send button** with icon
- **Enter key** to send (on mobile keyboards)
- **Disabled during loading** to prevent spam
- **Placeholder text** for guidance

### Image Upload
- **Two options**:
  1. Take photo with camera
  2. Choose from gallery
- **Bottom sheet selector** for user choice
- **Image preview** in message bubble
- **Automatic upload** to backend
- **Warning light detection** via Gemini Vision API

### Loading States
- **Loading indicator** with "Thinking..." text
- **Disabled input** during processing
- **Smooth animations** for better UX

### Error Handling
- **Error banner** at top of screen
- **Clear error messages** for users
- **Dismiss button** to hide errors
- **Automatic retry** suggestions

### Additional Actions
- **Feedback system**:
  - Star rating (1-5 stars)
  - Optional text comment
  - Submit to backend
  - Success confirmation
- **End conversation**:
  - Confirmation dialog
  - Clean up session
  - Return to home screen

### App Bar
- **Vehicle model display** as subtitle
- **Feedback button** (star icon)
- **Menu with options**:
  - End conversation

## 3. Technical Features

### State Management (Provider)
- **ChatProvider** for global state
- **Real-time updates** across screens
- **Efficient rebuilds** only when needed
- **Clean separation** of business logic

### API Integration
- **RESTful API calls** to FastAPI backend
- **Proper error handling** with try-catch
- **Timeout management** (30 seconds)
- **JSON serialization** for all requests

### Data Models
- **ChatMessage**: User and bot messages
- **ConversationResponse**: API responses
- **Vehicle**: Vehicle information

### Local Storage (Ready)
- **SharedPreferences** package included
- Ready for:
  - Session persistence
  - Conversation history
  - User preferences
  - Offline support (future)

### Image Handling
- **Image picker** plugin
- **File management** for uploads
- **Image compression** (by plugin)
- **Multiple sources** (camera/gallery)

### Networking
- **HTTP client** for API calls
- **Multipart upload** for images
- **Connection timeouts** configured
- **Error response** handling

## 4. User Experience Features

### Smooth Animations
- **Auto-scroll** to new messages
- **Fade-in** for message bubbles
- **Ripple effects** on buttons
- **Smooth transitions** between screens

### Responsive Design
- **Works on all screen sizes**:
  - Phones (iOS & Android)
  - Tablets
  - Web browsers
  - Desktop (via Flutter)
- **Adaptive layouts** with constraints
- **Safe areas** for notched devices

### Accessibility
- **Semantic labels** on all buttons
- **High contrast** text colors
- **Touch targets** meet minimum size
- **Screen reader** compatible

### Performance
- **Efficient list rendering** with ListView.builder
- **Image caching** by Flutter
- **Minimal rebuilds** with Provider
- **Fast startup** time

## 5. Safety & Validation

### Input Validation
- **Empty message** prevention
- **Session check** before sending
- **Server status** verification

### Error Recovery
- **Graceful failures** with user messages
- **Retry mechanisms** suggested
- **No app crashes** on API errors

### Data Privacy
- **No local storage** of messages (by default)
- **Session-based** conversations
- **No tracking** or analytics

## 6. Backend Integration

### API Endpoints Used
1. **POST /api/conversation/start**
   - Initialize conversation
   - Get session ID
   - Receive welcome message

2. **POST /api/conversation/message**
   - Send text messages
   - Upload images
   - Get AI responses

3. **POST /api/conversation/end**
   - Clean up session
   - Store analytics (if Firebase enabled)

4. **GET /api/vehicles**
   - Fetch supported vehicles
   - Fallback to hardcoded list

5. **POST /api/feedback**
   - Submit ratings
   - Store user feedback

6. **GET /** (Health check)
   - Check server status
   - Display connection state

### Request/Response Flow
```
User Action → Flutter Widget → Provider → API Service → Backend
                                                           ↓
User sees UI ← Flutter Widget ← Provider ← API Response ←┘
```

## 7. Configuration

### Easy Customization
All settings in [lib/constants/app_constants.dart](lib/constants/app_constants.dart):
- API base URL
- Timeouts
- Vehicle list
- Language options
- Endpoint paths

### Environment Support
- Development (localhost)
- Staging (can be configured)
- Production (can be configured)

## 8. Developer Features

### Code Organization
- **Clean architecture** with folders:
  - `constants/` - Configuration
  - `models/` - Data structures
  - `services/` - API communication
  - `providers/` - State management
  - `screens/` - Full-page views
  - `widgets/` - Reusable components

### Code Quality
- **Type safety** with Dart
- **Null safety** enabled
- **Descriptive names** for variables
- **Comments** for complex logic
- **Consistent style** throughout

### Hot Reload Support
- **Instant updates** during development
- **State preservation** on reload
- **Fast iteration** cycle

### Debugging
- **Console logs** for tracking
- **Error messages** with context
- **Flutter DevTools** compatible

## 9. Planned Features (Future)

- [ ] **Dark mode** support
- [ ] **Multi-language** (Sinhala, Tamil)
- [ ] **Voice input** for messages
- [ ] **Conversation history** persistence
- [ ] **Offline mode** with cached responses
- [ ] **Push notifications** for updates
- [ ] **Share** conversation feature
- [ ] **Export** chat as PDF/text
- [ ] **In-app browser** for external links
- [ ] **Animations** for message send/receive

## 10. Platform Support

### Currently Tested
- ✅ iOS Simulator
- ✅ Android Emulator
- ✅ Web Browser (Chrome)

### Compatible Platforms
- ✅ iOS devices (iPhone/iPad)
- ✅ Android devices (phones/tablets)
- ✅ macOS desktop
- ✅ Windows desktop
- ✅ Linux desktop
- ✅ Web browsers (Chrome, Safari, Firefox, Edge)

---

## Summary

This Flutter app provides a **complete, production-ready** mobile interface for your vehicle troubleshooting chatbot with:

- ✅ **11 Dart files** with clean architecture
- ✅ **2 main screens** (Home, Chat)
- ✅ **7 dependencies** for core functionality
- ✅ **6 API endpoints** integrated
- ✅ **Real-time chat** with AI responses
- ✅ **Image upload** for warning lights
- ✅ **State management** with Provider
- ✅ **Error handling** throughout
- ✅ **Beautiful UI** with Material Design 3
- ✅ **Full documentation** (README, QUICKSTART, FEATURES)

**Ready to use right now!** Just start the backend and run `flutter run`.
