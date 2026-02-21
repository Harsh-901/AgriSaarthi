"""
Voice Service - Sarvam.ai STT/TTS + Groq Intent Mapping

Handles all voice-related AI operations:
1. Speech to Text (Sarvam.ai saaras:v3)
2. Intent Mapping (Groq LLM)
3. Text to Speech (Sarvam.ai bulbul:v3)
"""

import os
import json
import base64
import logging
import requests
from groq import Groq
from django.conf import settings
from .intent_parser import Intent, IntentParser, ParsedIntent


logger = logging.getLogger(__name__)

# Sarvam.ai language code mappings
LANGUAGE_TO_SARVAM = {
    'hindi': 'hi-IN',
    'marathi': 'mr-IN',
    'english': 'en-IN',
    'bengali': 'bn-IN',
    'gujarati': 'gu-IN',
    'kannada': 'kn-IN',
    'malayalam': 'ml-IN',
    'odia': 'od-IN',
    'punjabi': 'pa-IN',
    'tamil': 'ta-IN',
    'telugu': 'te-IN',
}

SARVAM_TO_LANGUAGE = {v: k for k, v in LANGUAGE_TO_SARVAM.items()}


class VoiceService:
    """
    Service for handling all voice-related AI operations using:
    - Sarvam.ai for STT and TTS (native Hindi/Marathi support)
    - Groq LLM for intent classification
    """

    SARVAM_STT_URL = "https://api.sarvam.ai/speech-to-text"
    SARVAM_TTS_URL = "https://api.sarvam.ai/text-to-speech"

    @staticmethod
    def _get_sarvam_key():
        """Get and validate Sarvam API key."""
        key = getattr(settings, 'SARVAM_API_KEY', '') or ''
        if not key.strip():
            logger.error("SARVAM_API_KEY is not set in environment/settings")
            return None
        return key.strip()

    @staticmethod
    def _get_groq_key():
        """Get and validate Groq API key."""
        key = getattr(settings, 'GROQ_API_KEY', '') or ''
        if not key.strip():
            logger.error("GROQ_API_KEY is not set in environment/settings")
            return None
        return key.strip()

    @staticmethod
    def speech_to_text(audio_file_path):
        """
        Convert speech to text using Sarvam.ai STT (saaras:v3).
        
        Args:
            audio_file_path: Path to the audio file
            
        Returns:
            tuple: (transcribed_text, detected_language) or (None, None) on error
        """
        api_key = VoiceService._get_sarvam_key()
        if not api_key:
            logger.error("STT failed: Missing SARVAM_API_KEY")
            return None, None

        # Validate file exists
        if not os.path.exists(audio_file_path):
            logger.error(f"STT failed: Audio file not found: {audio_file_path}")
            return None, None

        file_size = os.path.getsize(audio_file_path)
        if file_size < 100:
            logger.warning(f"STT: Audio file very small ({file_size} bytes), may fail")

        try:
            headers = {
                "api-subscription-key": api_key,
            }

            with open(audio_file_path, "rb") as audio_file:
                # Determine MIME type explicitly to avoid "Invalid file type: None" error
                if audio_file_path.endswith('.wav'):
                    mime_type = 'audio/wav'
                elif audio_file_path.endswith('.mp3'):
                    mime_type = 'audio/mpeg'
                else:
                    # Default to x-m4a for m4a/aac files (Sarvam supports this)
                    mime_type = 'audio/x-m4a'

                files = {
                    "file": (os.path.basename(audio_file_path), audio_file, mime_type),
                }
                data = {
                    "model": "saaras:v3",
                    "language_code": "unknown",  # Auto-detect language
                    "mode": "transcribe",
                }

                logger.info(f"STT: Sending {file_size} bytes to Sarvam.ai...")
                response = requests.post(
                    VoiceService.SARVAM_STT_URL,
                    headers=headers,
                    files=files,
                    data=data,
                    timeout=30,
                )


            if response.status_code != 200:
                logger.error(f"STT Error: HTTP {response.status_code} - {response.text[:500]}")
                return None, None

            result = response.json()
            text = result.get("transcript", "").strip()
            lang_code = result.get("language_code")  # e.g., "hi-IN", "mr-IN"

            # Map Sarvam BCP-47 code to internal language name
            language = SARVAM_TO_LANGUAGE.get(lang_code, "hindi")

            logger.info(f"STT: lang={lang_code} -> {language}, text='{text[:100]}'")

            if not text:
                logger.warning("STT: Empty transcript returned")
                return None, None

            return text, language

        except requests.exceptions.Timeout:
            logger.error("STT Error: Request timed out (30s)")
            return None, None
        except requests.exceptions.ConnectionError as e:
            logger.error(f"STT Error: Connection failed - {e}")
            return None, None
        except Exception as e:
            logger.error(f"STT Error: {type(e).__name__}: {e}")
            return None, None

    @staticmethod
    def map_intent(text, language):
        """Map text to system intent using Groq LLM"""
        groq_key = VoiceService._get_groq_key()
        if not groq_key:
            logger.warning("Intent mapping: GROQ_API_KEY missing, falling back to regex parser")
            return IntentParser.parse(text, language)

        try:
            client = Groq(api_key=groq_key)

            # Categorize the input into one of our predefined intents
            intents_list = [i.value for i in Intent if i != Intent.UNKNOWN]

            prompt = f"""
            You are an AI assistant for a Farmer Welfare App called AgriSarthi.
            Your task is to map a farmer's voice input to a specific system intent.
            The farmer may speak in Hindi, Marathi, or English (or a mix).
            
            User Input: "{text}"
            User Language: {language}
            
            Available Intents:
            - show_eligible_schemes: When user wants to see schemes they can apply for.
              Examples: "मला माझ्या योजना दाखवा" (Marathi), "मेरी योजनाएं दिखाओ" (Hindi), "show my schemes"
            - apply_scheme: When user wants to apply for a specific scheme or start application.
              Examples: "या योजनेसाठी अर्ज करा" (Marathi), "इस योजना के लिए आवेदन करो" (Hindi), "apply for this scheme"
            - check_status: When user wants to check the status of their submitted applications.
              Examples: "माझ्या अर्जाची स्थिती" (Marathi), "आवेदन की स्थिति बताओ" (Hindi), "check my application status"
            - view_profile: When user wants to see their own profile or personal details.
              Examples: "माझी माहिती दाखवा" (Marathi), "मेरी प्रोफाइल दिखाओ" (Hindi), "show my profile"
            - list_applications: When user wants to see a list of all their applications.
              Examples: "माझे सर्व अर्ज" (Marathi), "मेरे सारे आवेदन" (Hindi), "list my applications"
            - view_documents: When user wants to view or manage their uploaded documents.
              Examples: "माझी कागदपत्रे दाखवा" (Marathi), "मेरे दस्तावेज दिखाओ" (Hindi), "show my documents"
            - help: When user is confused or asks what they can do.
              Examples: "मदत करा" (Marathi), "मदद करो" (Hindi), "help"
            
            Rules:
            1. Respond ONLY with a JSON object containing 'intent' and 'confidence'.
            2. 'intent' must be one of {intents_list} or 'unknown'.
            3. 'confidence' should be between 0 and 1.
            4. If a specific scheme is mentioned, include it in 'entities' as 'scheme_mention'.
            
            Example:
            Input: "मला माझ्या योजना दाखवा" (Marathi)
            Output: {{"intent": "show_eligible_schemes", "confidence": 0.95, "entities": {{}}}}
            
            Input: "PM Kisan के लिए अप्लाई करो" (Hindi)
            Output: {{"intent": "apply_scheme", "confidence": 0.98, "entities": {{"scheme_mention": "PM Kisan"}}}}
            """

            chat_completion = client.chat.completions.create(
                messages=[
                    {"role": "system", "content": "You are a specialized intent mapping agent for an Indian farmer welfare app. You understand Hindi, Marathi, and English."},
                    {"role": "user", "content": prompt}
                ],
                model="llama-3.3-70b-versatile",
                response_format={"type": "json_object"},
                timeout=15,
            )

            result = json.loads(chat_completion.choices[0].message.content)
            
            intent_str = result.get('intent', 'unknown')
            # Safely parse the intent enum
            try:
                intent = Intent(intent_str)
            except ValueError:
                logger.warning(f"Intent mapping: Unknown intent '{intent_str}', defaulting to UNKNOWN")
                intent = Intent.UNKNOWN

            parsed = ParsedIntent(
                intent=intent,
                confidence=result.get('confidence', 0.0),
                entities=result.get('entities', {}),
                original_text=text
            )
            logger.info(f"Intent mapping: '{text[:50]}' -> {parsed.intent.value} (confidence={parsed.confidence})")
            return parsed

        except Exception as e:
            logger.error(f"Intent mapping error: {type(e).__name__}: {e}")
            # Fallback to regex parser
            logger.info("Intent mapping: Falling back to regex parser")
            return IntentParser.parse(text, language)

    @staticmethod
    def text_to_speech(text, language):
        """
        Convert text to speech using Sarvam.ai TTS (bulbul:v3).
        
        Args:
            text: Text to convert to speech
            language: Internal language name (hindi, marathi, english)
            
        Returns:
            bytes: Raw audio bytes (WAV format) or None on error
        """
        api_key = VoiceService._get_sarvam_key()
        if not api_key:
            logger.error("TTS failed: Missing SARVAM_API_KEY")
            return None

        if not text or not text.strip():
            logger.warning("TTS: Empty text provided, skipping")
            return None

        try:
            # Map internal language to Sarvam BCP-47 code
            target_lang = LANGUAGE_TO_SARVAM.get(language, 'hi-IN')

            # Pick voice based on language for more natural output
            speaker_map = {
                'hindi': 'shubh',
                'marathi': 'shubh',
                'english': 'amelia',
            }
            speaker = speaker_map.get(language, 'shubh')

            headers = {
                "api-subscription-key": api_key,
                "Content-Type": "application/json",
            }

            # Truncate to bulbul:v3 max limit
            truncated_text = text[:2500]

            payload = {
                "text": truncated_text,
                "target_language_code": target_lang,
                "model": "bulbul:v3",
                "speaker": speaker,
                "pace": 1.0,
                "speech_sample_rate": "22050",
                "output_audio_codec": "wav",
            }

            logger.info(f"TTS: Generating audio for '{truncated_text[:60]}...' lang={target_lang}")
            response = requests.post(
                VoiceService.SARVAM_TTS_URL,
                headers=headers,
                json=payload,
                timeout=30,
            )

            if response.status_code != 200:
                logger.error(f"TTS Error: HTTP {response.status_code} - {response.text[:500]}")
                return None

            result = response.json()
            audios = result.get("audios", [])

            if not audios:
                logger.error("TTS Error: No audio in response")
                return None

            # Decode the first base64 audio string to raw bytes
            audio_bytes = base64.b64decode(audios[0])
            logger.info(f"TTS: Generated {len(audio_bytes)} bytes for lang={target_lang}")
            return audio_bytes

        except requests.exceptions.Timeout:
            logger.error("TTS Error: Request timed out (30s)")
            return None
        except requests.exceptions.ConnectionError as e:
            logger.error(f"TTS Error: Connection failed - {e}")
            return None
        except Exception as e:
            logger.error(f"TTS Error: {type(e).__name__}: {e}")
            return None
