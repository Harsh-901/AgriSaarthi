# 🐛 Troubleshooting: "Could not understand audio"

## The Issue
You are seeing the error: **"Could not understand the audio. Please try speaking more clearly."**

This specific error is returned by the backend in two cases:
1. **Missing API Keys:** The backend cannot contact the Speech-to-Text service (Sarvam.ai) because the API key is missing or not yet loaded.
2. **Empty Transcript:** The Speech-to-Text service processed the audio but returned no text (silence, noise, or unsupported format).

Given you just updated the environment variables 5 minutes ago, **Case 1 is 99% likely the cause**.

---

## ⏳ Why It's Happening (Render Deployment)

When you add Environment Variables on Render:
- **They apply immediately to NEW deployments.**
- **They do NOT automatically restart running services** in all cases (depending on plan/settings).
- **Redeployment takes time:** Even if a deploy started, it takes **3-7 minutes** to build and go live.

If the old version is still running, it **does not have your new keys yet**.

---

## 🛠️ How to Fix (Backend)

### 1. Manual Restart (Recommended)
You need to force Render to pick up the new variables:
1. Go to your **Render Dashboard**
2. Click on your **Agrisarthi Web Service**
3. Click the **"Manual Deploy"** button (top right) -> **"Deploy latest commit"**
   * *OR* click **"Restart Service"** if available.
4. Watch the **Logs** tab.
5. Wait until you see: `[gunicorn] Listening on port 10000` (or similar success message).

### 2. Verify Variables
Ensure you added these exact variable names in Render > Environment:
- `SARVAM_API_KEY` (Required for Voice)
- `GROQ_API_KEY` (Required for Intent)

### 3. Check Logs for "Missing Key" Error
If you can view Render logs while trying the app:
- Look for: `ERROR: STT failed: Missing SARVAM_API_KEY`
- If you see this, the key is still not loaded.

---

## 📱 How to Verify Fix (Frontend)

Once Render shows "Live":

1. **Restart the App:**
   - Press `q` in terminal
   - Run `flutter run`

2. **Test Voice:**
   - Tap mic -> Speak "Hello" -> Tap mic.
   - If it works, you'll see the text response.

---

## ℹ️ Technical Detail
Your backend uses **Sarvam.ai** for speech recognition (not Google Cloud directly).
- Takes `.m4a` audio from your phone.
- Sends to Sarvam API.
- If Sarvam API Key is missing, it returns `None, None`.
- The view then returns the "Could not understand" error.

**Status:** The system is built correctly, it just needs the valid credentials to be active on the running server!
