# AISSMS - Voice-based Farmer Scheme Access App

[![Django](https://img.shields.io/badge/Django-4.2+-green.svg)](https://www.djangoproject.com/)
[![Python](https://img.shields.io/badge/Python-3.8+-blue.svg)](https://www.python.org/)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

AIISMS (Artificial Intelligence Integrated Scheme Management System) is a voice-powered backend API that enables farmers to access government schemes through natural language voice commands. The system supports multiple Indian languages (Hindi, Marathi, English) and provides a seamless experience for farmers to check eligibility, apply for schemes, and track their applications.

## 🌟 Key Features

### Voice-Powered Interactions
- **Multilingual Support**: Process voice commands in Hindi, Marathi, and English
- **Intent Recognition**: Advanced NLP for understanding farmer queries
- **Natural Conversations**: Human-like responses with localized content

### Core Functionality
- **OTP Authentication**: Secure phone-based authentication system
- **Farmer Profiles**: Comprehensive farmer information management
- **Document Management**: Upload and verify farmer documents
- **Scheme Eligibility**: Intelligent eligibility checking engine
- **Application Processing**: Automated application submission with auto-fill
- **Status Tracking**: Real-time application status monitoring

### Technical Features
- **RESTful API**: Well-documented endpoints with JWT authentication
- **Real-time Updates**: Live status notifications
- **Scalable Architecture**: Modular Django apps design
- **Cloud Integration**: Supabase for database and storage
- **Cross-platform**: CORS-enabled for web and mobile integration

## 🛠 Technology Stack

### Backend Framework
- **Django 4.2+**: High-level Python web framework
- **Django REST Framework**: Powerful API toolkit
- **JWT Authentication**: Secure token-based authentication

### Database & Storage
- **Supabase PostgreSQL**: Cloud database with real-time capabilities
- **Supabase Storage**: File upload and management

### Additional Libraries
- **python-decouple**: Environment variable management
- **django-cors-headers**: Cross-origin resource sharing
- **whitenoise**: Static file serving
- **psycopg2-binary**: PostgreSQL adapter

## 📋 Prerequisites

Before running this application, make sure you have the following installed:

- **Python 3.8 or higher**
- **pip** (Python package installer)
- **Git** (version control)
- **Supabase Account** (for database and storage)

## 🚀 Installation

### 1. Clone the Repository
```bash
git clone https://github.com/your-username/aiisms.git
cd aiisms
```

### 2. Create Virtual Environment
```bash
# Windows
python -m venv .venv
.venv\Scripts\activate

# Linux/Mac
python -m venv .venv
source .venv/bin/activate
```

### 3. Install Dependencies
```bash
pip install -r requirements.txt
```

### 4. Environment Configuration
```bash
# Copy environment template
cp .env.example .env

# Edit .env with your configuration
nano .env  # or use your preferred editor
```

### 5. Database Setup
```bash
# Run migrations (if using local SQLite for development)
python manage.py migrate

# For production with Supabase, ensure your DATABASE_URL is set
```

### 6. Run the Application
```bash
# Development server
python manage.py runserver

# Production with Gunicorn
gunicorn core.wsgi:application --bind 0.0.0.0:8000
```

The API will be available at `http://127.0.0.1:8000` for development.

## ⚙️ Configuration

### Environment Variables

Create a `.env` file in the project root with the following variables:

```env
# Django Settings
SECRET_KEY=your-secret-key-here
DEBUG=True
ALLOWED_HOSTS=localhost,127.0.0.1

# Database
DATABASE_URL=postgresql://user:password@host:port/database

# Supabase (Optional)
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_KEY=your-supabase-anon-key
SUPABASE_SERVICE_KEY=your-supabase-service-key

# CORS
CORS_ALLOWED_ORIGINS=http://localhost:3000,https://your-frontend-domain.com
```

### Supabase Setup

1. Create a new Supabase project
2. Set up the following tables (managed=False in Django):
   - `farmers`
   - `otp_codes`
   - `schemes`
   - `documents`
   - `applications`
3. Configure storage buckets for document uploads
4. Update your `.env` with Supabase credentials

## 📚 API Documentation

### Authentication Endpoints

#### Send OTP
```http
POST /api/auth/send-otp/
Content-Type: application/json

{
    "phone": "+91xxxxxxxxxx"
}
```

#### Verify OTP
```http
POST /api/auth/verify-otp/
Content-Type: application/json

{
    "phone": "+91xxxxxxxxxx",
    "otp": "123456"
}
```

### Farmer Management

#### Get/Update Farmer Profile
```http
GET /api/farmers/profile/
PUT /api/farmers/profile/
Authorization: Bearer <token>
```

#### Update Farmer Profile
```http
PUT /api/farmers/profile/
Authorization: Bearer <token>
Content-Type: application/json

{
    "name": "राम कुमार",
    "state": "महाराष्ट्र",
    "district": "पुणे",
    "village": "वाघोली",
    "land_size": 2.5,
    "crop_type": "धान",
    "language": "hindi"
}
```

### Document Management

#### Upload Documents
```http
POST /api/documents/
Authorization: Bearer <token>
Content-Type: multipart/form-data

aadhaar: <aadhaar_file>
pan_card: <pan_card_file>
land_certificate: <land_certificate_file>
seven_twelve: <seven_twelve_file>
eight_a: <eight_a_file>
bank_passbook: <bank_passbook_file>
other: <optional_other_file>
```

**Note:** All compulsory documents (aadhaar, pan_card, land_certificate, seven_twelve, eight_a, bank_passbook) must be uploaded in a single request. Files are automatically renamed to {document_type}.{extension} and stored in farmer-specific Supabase storage buckets. The URL is generated and stored in the database. Optional 'other' document can be included.

#### Get Farmer Documents
```http
GET /api/documents/
Authorization: Bearer <token>
```

### Scheme Management

#### Get All Schemes
```http
GET /api/schemes/
Authorization: Bearer <token>
```

#### Get Eligible Schemes
```http
GET /api/schemes/eligible/
Authorization: Bearer <token>
```

### Application Management

#### Submit Application
```http
POST /api/applications/
Authorization: Bearer <token>
Content-Type: application/json

{
    "scheme_id": "uuid-here",
    "documents_submitted": ["aadhaar", "land_certificate"]
}
```

#### Get Application Status
```http
GET /api/applications/
Authorization: Bearer <token>
```

### Voice Processing (Hero Feature)

#### Process Voice Command
```http
POST /api/voice/process/
Authorization: Bearer <token>
Content-Type: application/json

{
    "text": "मेरी पात्र योजनाएं दिखाओ"
}
```

#### Confirm Voice Action
```http
POST /api/voice/confirm/
Authorization: Bearer <token>
Content-Type: application/json

{
    "action": "confirm_apply",
    "scheme_id": "uuid-here",
    "confirmed": true
}
```

## 🎯 Usage Examples

### Voice Commands (Hindi)
- "मेरी पात्र योजनाएं दिखाओ" (Show my eligible schemes)
- "पीएम किसान योजना के लिए आवेदन करो" (Apply for PM Kisan scheme)
- "मेरे आवेदन की स्थिति बताओ" (Tell me my application status)
- "मेरी प्रोफाइल दिखाओ" (Show my profile)

### API Integration
```python
import requests

# Authenticate farmer
response = requests.post('http://localhost:8000/api/auth/send-otp/', json={
    'phone': '+919876543210'
})

# Verify OTP and get token
response = requests.post('http://localhost:8000/api/auth/verify-otp/', json={
    'phone': '+919876543210',
    'otp': '123456'
})
token = response.json()['access']

# Use token for authenticated requests
headers = {'Authorization': f'Bearer {token}'}
response = requests.get('http://localhost:8000/api/farmers/profile/', headers=headers)
```

## 🧪 Testing

### Run Tests
```bash
python manage.py test
```

### Test Voice Processing
```bash
# Test with sample voice inputs
python manage.py shell
from voice.services.intent_parser import IntentParser
result = IntentParser.parse("मेरी योजनाएं दिखाओ", "hindi")
print(result.intent, result.confidence)
```

## 🔧 Development

### Project Structure
```
aiisms/
├── core/                    # Django project settings
├── auth_app/               # OTP authentication
├── farmers/                # Farmer management
├── documents/              # Document upload/verification
├── schemes/                # Government schemes
├── applications/           # Application processing
├── voice/                  # Voice intent processing
├── requirements.txt        # Python dependencies
├── manage.py              # Django management script
└── README.md              # This file
```

### Adding New Features
1. Create new Django app: `python manage.py startapp new_feature`
2. Add to INSTALLED_APPS in settings.py
3. Create models, views, serializers, URLs
4. Update main URLs configuration
5. Add tests and documentation

### Voice Intent Extension
To add new voice intents:
1. Update `Intent` enum in `voice/services/intent_parser.py`
2. Add patterns in `INTENT_PATTERNS`
3. Add responses in `ResponseGenerator.RESPONSES`
4. Implement handler in `VoiceProcessView`

## 🤝 Contributing

We welcome contributions! Please follow these steps:

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/amazing-feature`
3. Commit your changes: `git commit -m 'Add amazing feature'`
4. Push to the branch: `git push origin feature/amazing-feature`
5. Open a Pull Request

### Guidelines
- Follow PEP 8 style guidelines
- Write tests for new features
- Update documentation
- Ensure all tests pass
- Use meaningful commit messages

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **Django Community** for the excellent web framework
- **Supabase** for providing amazing backend-as-a-service
- **Indian Government** for the various farmer welfare schemes
- **Open Source Contributors** for making development possible

## 📞 Support

For support, email support@aiisms.com or join our Discord community.

---

**Made with ❤️ for Indian farmers**
