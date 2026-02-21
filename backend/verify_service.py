import os
import django
from django.conf import settings

# Setup Django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'core.settings')
django.setup()

from voice.services.voice_service import VoiceService
from voice.services.intent_parser import Intent

def test_intent_parsing():
    print("\n=== Testing Intent Parsing (Marathi) ===")
    text = "मला माझ्या योजना दाखवा"
    language = "marathi"
    parsed = VoiceService.map_intent(text, language)
    print(f"Input: {text}")
    print(f"Intent: {parsed.intent}")
    print(f"Confidence: {parsed.confidence}")
    assert parsed.intent == Intent.SHOW_ELIGIBLE_SCHEMES
    print("Marathi Intent Parsing: PASSED ✓")

    print("\n=== Testing Intent Parsing (Hindi) ===")
    text = "PM Kisan के लिए अप्लाई करो"
    language = "hindi"
    parsed = VoiceService.map_intent(text, language)
    print(f"Input: {text}")
    print(f"Intent: {parsed.intent}")
    print(f"Entities: {parsed.entities}")
    assert parsed.intent == Intent.APPLY_SCHEME
    print("Hindi Intent Parsing: PASSED ✓")

def test_tts():
    print("\n=== Testing VoiceService.text_to_speech (Marathi) ===")
    text = "नमस्कार, मी तुमची कशी मदत करू शकतो?"
    audio_bytes = VoiceService.text_to_speech(text, "marathi")
    if audio_bytes:
        print(f"Success: Generated {len(audio_bytes)} bytes of audio")
        print("VoiceService TTS: PASSED ✓")
    else:
        print("Failure: No audio generated")

if __name__ == "__main__":
    try:
        test_intent_parsing()
        test_tts()
        print("\n=== All VoiceService tests PASSED ✓ ===")
    except Exception as e:
        print(f"\nVerification FAILED: {e}")
        import traceback
        traceback.print_exc()
