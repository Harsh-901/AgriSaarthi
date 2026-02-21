import os, requests, json, base64
from dotenv import load_dotenv
load_dotenv()
key = os.getenv("SARVAM_API_KEY")
url = "https://api.sarvam.ai/text-to-speech"
headers = {"api-subscription-key": key, "Content-Type": "application/json"}
payload = {
    "text": "नमस्कार",
    "target_language_code": "mr-IN",
    "model": "bulbul:v3",
    "speaker": "shubh",
    "output_audio_codec": "wav"
}
try:
    resp = requests.post(url, headers=headers, json=payload, timeout=30)
    print(f"Status: {resp.status_code}")
    if resp.status_code == 200:
        data = resp.json()
        print(f"Keys: {list(data.keys())}")
        if "audios" in data:
            print(f"Audios count: {len(data['audios'])}")
            if data["audios"]:
                print(f"First 20 chars of audio[0]: {data['audios'][0][:20]}")
        else:
            print("ERROR: 'audios' key missing in response")
    else:
        print(f"Error Body: {resp.text}")
except Exception as e:
    print(f"Exception: {type(e).__name__}: {e}")
