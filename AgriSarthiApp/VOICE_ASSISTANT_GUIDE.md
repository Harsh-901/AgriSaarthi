# 🎤 Voice Assistant Feature Guide

## Overview
Your AgriSarthi app already has a **fully functional voice assistant** feature! Users can interact with the app by speaking commands in **Hindi, Marathi, or English**.

## 🎯 How It Works

### Frontend (Flutter)
The voice assistant is already integrated into your app with the following components:

1. **Voice Button** - A floating action button (microphone icon) at the bottom center of the home screen
2. **Voice Overlay** - Shows real-time feedback during voice interaction
3. **Voice Provider** - Manages the recording, processing, and playback states

### Backend (Django)
The backend API is deployed at: `https://agrisarthi.onrender.com`

**API Endpoints:**
- `POST /api/voice/process/` - Main voice processing endpoint (STT + Intent Recognition + TTS)
- `POST /api/voice/confirm/` - Confirm actions like scheme applications
- `POST /api/voice/tts/` - Text-to-speech conversion

## 📱 User Experience

### How to Use the Voice Assistant

1. **Open the App** - Navigate to the Farmer Home Screen
2. **Long Press the Mic Button** - Hold down the circular microphone button at the bottom center
3. **Speak Your Command** - While holding, speak clearly in Hindi, Marathi, or English
4. **Release to Process** - Release the button when done speaking
5. **Listen to Response** - The app will process your voice and respond with audio + visual feedback
6. **Auto-Navigation** - The app automatically navigates to relevant screens based on your command

### Visual States

| State | Button Color | Icon | Description |
|-------|-------------|------|-------------|
| **Idle** | Green | 🎤 | Ready to listen |
| **Recording** | Red | 🎤 | Listening to your voice |
| **Processing** | Yellow | ⏳ | Processing your command |
| **Speaking** | Green | 🔊 | Playing audio response |
| **Error** | Red | ⚠️ | Something went wrong |
| **Not Connected** | Gray | 🎤🚫 | Backend not connected |

## 🗣️ Supported Voice Commands

### 1. Show Eligible Schemes
**Commands:**
- "मुझे योजनाएं दिखाओ" (Hindi)
- "मला योजना दाखवा" (Marathi)
- "Show me schemes" (English)
- "Which schemes am I eligible for?"

**Response:** Lists your eligible schemes and stays on the home screen

### 2. Apply for Scheme
**Commands:**
- "मैं योजना के लिए आवेदन करना चाहता हूं" (Hindi)
- "मी योजनेसाठी अर्ज करू इच्छितो" (Marathi)
- "I want to apply for a scheme" (English)
- "Apply for PM Kisan"

**Response:** Shows confirmation dialog for the scheme application

### 3. Check Application Status
**Commands:**
- "मेरे आवेदन की स्थिति क्या है?" (Hindi)
- "माझ्या अर्जाची स्थिती काय आहे?" (Marathi)
- "What is my application status?" (English)
- "Show my applications"

**Response:** Navigates to Applications screen with status summary

### 4. View Profile
**Commands:**
- "मेरी प्रोफाइल दिखाओ" (Hindi)
- "माझे प्रोफाइल दाखवा" (Marathi)
- "Show my profile" (English)

**Response:** Navigates to Profile screen

### 5. View Documents
**Commands:**
- "मेरे दस्तावेज़ दिखाओ" (Hindi)
- "माझे कागदपत्रे दाखवा" (Marathi)
- "Show my documents" (English)

**Response:** Navigates to Document Upload screen

### 6. Help
**Commands:**
- "मदद" (Hindi)
- "मदत" (Marathi)
- "Help" (English)
- "How do I use this app?"

**Response:** Provides help information

## 🔧 Technical Architecture

### Frontend Flow
```
User Long Press → Start Recording → Stop Recording → 
Upload Audio to Backend → Receive Response (Audio + Metadata) → 
Play Audio → Auto-Navigate to Relevant Screen
```

### Backend Processing
```
Receive Audio → Speech-to-Text (STT) → 
Intent Recognition (AI/Groq) → 
Fetch Data from Database → 
Generate Response Text → 
Text-to-Speech (TTS) → 
Return Audio + Metadata
```

### Key Files

**Frontend:**
- `lib/features/voice/providers/voice_provider.dart` - State management
- `lib/features/voice/widgets/voice_assistant_button.dart` - Mic button UI
- `lib/features/voice/widgets/voice_assistant_overlay.dart` - Feedback overlay
- `lib/core/services/voice_assistant_service.dart` - API communication

**Backend:**
- `voice/views.py` - API endpoints
- `voice/services/voice_service.py` - STT/TTS processing
- `voice/services/intent_parser.py` - AI intent recognition

## 🎨 UI Components

### Voice Assistant Button
- **Location:** Bottom center (floating action button)
- **Interaction:** Long press to record, release to process
- **States:** Idle, Recording, Processing, Speaking, Error
- **Visual Feedback:** Color changes, icons, shadows

### Voice Assistant Overlay
- **Location:** Above the voice button
- **Shows:** 
  - Current state (Listening, Processing, Speaking)
  - Response text
  - Action buttons (Confirm, Dismiss)
  - Navigation hints

## 🔐 Authentication & Permissions

### Required Permissions
- **Microphone Permission** - Required for voice recording
- **Internet Permission** - Required for API communication

### Authentication Flow
1. User logs in with phone number (OTP)
2. App syncs with Django backend
3. JWT token is stored for API calls
4. Voice commands require active authentication

## 🌐 Multi-Language Support

The voice assistant automatically detects the language from:
1. **User's profile language setting** (stored in database)
2. **Speech-to-Text detection** (auto-detects from audio)

Supported languages:
- **Hindi** (हिंदी)
- **Marathi** (मराठी)
- **English**

## 🚨 Error Handling

### Common Errors & Solutions

| Error | Cause | Solution |
|-------|-------|----------|
| "Microphone permission denied" | No mic access | Enable mic permission in app settings |
| "Not authenticated" | Backend not synced | Wait for automatic sync or tap cloud icon |
| "Audio too short" | Recording < 1 second | Hold button longer and speak clearly |
| "Request timed out" | Network issue | Check internet connection |
| "Cannot connect to server" | Backend offline | Check if backend is running |

### Auto-Recovery
- **Error State:** Automatically clears after 3 seconds
- **Stuck State:** Tap the button to force reset
- **Processing Timeout:** 60 seconds maximum, then auto-reset

## 📊 Voice Navigation Mapping

| Voice Action | Navigation Target | Screen |
|--------------|------------------|---------|
| `show_schemes` | Stay on home | Farmer Home Screen |
| `show_applications` | `/applications` | Applications List |
| `show_profile` | `/profile` | Farmer Profile |
| `complete_profile` | `/profile` | Farmer Profile |
| `show_documents` | `/documents` | Document Upload |
| `show_help` | Show snackbar | Help message |
| `confirm_apply` | Show dialog | Confirmation dialog |

## 🎯 Intent Recognition

The backend uses **AI-powered intent recognition** with:
- **Primary:** Groq AI API (fast, accurate)
- **Fallback:** Regex pattern matching

**Supported Intents:**
1. `SHOW_ELIGIBLE_SCHEMES`
2. `APPLY_SCHEME`
3. `CHECK_STATUS`
4. `VIEW_PROFILE`
5. `LIST_APPLICATIONS`
6. `VIEW_DOCUMENTS`
7. `HELP`
8. `UNKNOWN` (fallback)

## 🔊 Audio Processing

### Speech-to-Text (STT)
- **Provider:** Google Cloud Speech-to-Text API
- **Format:** M4A, WAV, MP3
- **Max Size:** 10MB
- **Sample Rate:** 44.1kHz

### Text-to-Speech (TTS)
- **Provider:** Google Cloud Text-to-Speech API
- **Output Format:** WAV
- **Quality:** High-quality neural voices
- **Languages:** Hindi, Marathi, English

## 📱 Testing the Voice Feature

### Quick Test Steps
1. **Open the app** and log in
2. **Wait for green cloud icon** (backend connected)
3. **Long press the mic button**
4. **Say:** "मुझे योजनाएं दिखाओ" (Show me schemes)
5. **Release the button**
6. **Listen** to the audio response
7. **Observe** the app stays on home screen showing schemes

### Test Commands
```
Hindi: "मेरी प्रोफाइल दिखाओ"
Marathi: "माझे प्रोफाइल दाखवा"
English: "Show my profile"
```

## 🛠️ Development Notes

### Adding New Voice Commands

1. **Update Backend Intent Parser** (`voice/services/intent_parser.py`)
   - Add new intent to `Intent` enum
   - Add patterns to `IntentParser`
   - Add response templates to `ResponseGenerator`

2. **Update Backend View** (`voice/views.py`)
   - Add handler method in `VoiceProcessView`
   - Implement business logic

3. **Update Frontend Navigation** (`lib/features/home/screens/farmer_home_screen.dart`)
   - Add case to `_handleVoiceNavigation` switch statement
   - Implement navigation logic

### Configuration

**Backend API URL:**
```dart
// lib/core/config/api_config.dart
static const String baseUrl = 'https://agrisarthi.onrender.com';
```

**Voice Endpoints:**
```dart
'/api/voice/process/'   // Main processing
'/api/voice/confirm/'   // Confirm actions
'/api/voice/tts/'       // Text-to-speech only
```

## 🎉 Summary

Your AgriSarthi app has a **production-ready voice assistant** that:
- ✅ Records user voice input
- ✅ Converts speech to text (multi-language)
- ✅ Recognizes user intent with AI
- ✅ Fetches relevant data from backend
- ✅ Generates natural language responses
- ✅ Converts response to speech
- ✅ Plays audio feedback
- ✅ Auto-navigates to relevant screens
- ✅ Handles errors gracefully
- ✅ Works in Hindi, Marathi, and English

**No additional implementation needed!** The feature is already fully functional and integrated into your app.

## 📞 Support

For issues or questions:
- Check backend logs at Render dashboard
- Review frontend debug logs in console
- Verify microphone permissions
- Ensure backend is deployed and accessible
- Test with simple commands first

---

**Made with ❤️ for Indian Farmers** 🌾
