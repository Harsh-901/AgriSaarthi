# AgriSarthi Mobile App (Flutter)

[![Flutter](https://img.shields.io/badge/Flutter-3.0+-blue.svg)](https://flutter.dev/)
[![Supabase](https://img.shields.io/badge/Supabase-Auth-green)](https://supabase.com/)

AgriSarthi ("Agricultural Companion") is a state-of-the-art Flutter application empowering farmers to access government welfare schemes using just their voice. Designed with a focus on accessibility, language localization, and ease of use.

## 🌟 Key Features

### 🗣️ Smart Voice Assistant
- **Voice Navigation**: Navigate the entire app using voice commands in Hindi, Marathi, or English.
- **Conversational Apply**: "Apply for PM Kisan" triggers a guided application flow.
- **Status Enquiry**: "Check my application status" fetches real-time updates.

### 📱 User-Centric Design
- **One-Tap Login**: Simple OTP-based authentication via mobile number.
- **Document Locker**: Securely upload and manage documents (Aadhaar, Pan, Land Records) once and reuse them for multiple schemes.
- **Eligibility Check**: Automatically filters schemes based on the farmer's profile data.
- **Application Dashboard**: Track the progress of all submitted applications in one place.

### 👨‍💼 Admin Features
- **Scheme Management**: Add, update, or remove government schemes.
- **Application Review**: Review farmer applications and documents.
- **User Management**: Oversee farmer registrations.

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (3.10+)
- Dart SDK
- Android Studio / VS Code with Flutter extensions
- Android Device/Emulator

### Installation

1. **Navigate to Frontend Directory**
   ```bash
   cd FrontEnd2.0
   ```

2. **Install Dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure Environment**
   Ensure `lib/core/config/supabase_config.dart` (or similar config file) contains your Supabase credentials.

4. **Run the App**
   ```bash
   flutter run
   ```

## 🏗️ Project Structure

```
lib/
├── main.dart                  # App Entry Point
├── core/                      # Core configs (Theme, Router, API clients)
├── features/
│   ├── auth/                  # Login & OTP Logic
│   ├── home/                  # Dashboard Screens
│   ├── profile/               # Farmer Profile Management
│   ├── documents/             # Document Upload & Gallery
│   ├── schemes/               # Scheme Listing & Details
│   ├── applications/          # Tracking & Status
│   └── voice/                 # Voice Assistant Implementation
└── shared/                    # Reusable Widgets
```

## 🎤 Voice Commands Guide

| Command (English) | Hindi Example | Action |
|-------------------|---------------|--------|
| "Show Schemes" | "योजनाएं दिखाओ" | Lists eligible schemes |
| "Apply for [Scheme]" | "[Scheme] के लिए आवेदन करें" | Starts application process |
| "Check Status" | "स्थिति चेक करें" | Shows application status |
| "View Profile" | "प्रोफाइल दिखाओ" | Opens profile page |

## 🛠 Tech Stack
- **Frontend**: Flutter (Dart)
- **State Management**: Provider
- **Backend Service**: Supabase (Auth, Storage, Database)
- **Voice/Audio**: `speech_to_text`, `flutter_tts` (or custom integration)

## 🤝 Contributing
1. Fork the repo
2. Create feature branch (`git checkout -b feature/NewFeature`)
3. Commit changes
4. Push to branch
5. Create Pull Request

## 📄 License
MIT License.
