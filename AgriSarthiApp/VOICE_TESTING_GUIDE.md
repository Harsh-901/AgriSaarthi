# 🧪 Voice Assistant Testing Guide

## Quick Test Checklist

### ✅ Pre-requisites
- [ ] App is installed and running
- [ ] User is logged in (phone number + OTP)
- [ ] Backend is connected (green cloud icon in top-right)
- [ ] Microphone permission is granted

### 🎯 Test 1: Basic Voice Input
**Objective:** Verify voice recording and processing works

1. Open the Farmer Home Screen
2. Look for the **green circular mic button** at the bottom center
3. **Long press** the mic button
4. Button should turn **RED** and show "Listening..." overlay
5. **Speak clearly:** "मुझे योजनाएं दिखाओ" (Show me schemes)
6. **Release** the button
7. Button should turn **YELLOW** with "Processing..." text
8. Wait for response (5-15 seconds)
9. Button should turn **GREEN** with speaker icon
10. **Listen** to the audio response
11. Overlay should show the text response

**Expected Result:**
- ✅ Audio plays with response in Hindi
- ✅ Text appears in overlay: "आपके लिए X योजनाएं उपलब्ध हैं..." 
- ✅ App stays on home screen showing schemes

---

### 🎯 Test 2: Profile Navigation
**Objective:** Verify voice-driven navigation

1. Long press mic button
2. Say: "मेरी प्रोफाइल दिखाओ" (Show my profile)
3. Release button
4. Wait for audio response
5. After audio finishes, app should **auto-navigate** to Profile screen

**Expected Result:**
- ✅ Audio response: "आपका नाम [Name] है..."
- ✅ Auto-navigates to Profile screen after audio
- ✅ Profile data is displayed

---

### 🎯 Test 3: Application Status
**Objective:** Verify data fetching and navigation

1. Long press mic button
2. Say: "मेरे आवेदन की स्थिति क्या है?" (What is my application status?)
3. Release button
4. Wait for response

**Expected Result:**
- ✅ Audio response with application count and status
- ✅ Auto-navigates to Applications screen
- ✅ Shows list of applications

---

### 🎯 Test 4: Multi-Language Support
**Objective:** Verify language detection

**Test 4a: English**
1. Long press mic button
2. Say: "Show my profile"
3. Release button

**Expected:** Response in English

**Test 4b: Marathi**
1. Long press mic button
2. Say: "माझे प्रोफाइल दाखवा"
3. Release button

**Expected:** Response in Marathi

---

### 🎯 Test 5: Error Handling
**Objective:** Verify error states and recovery

**Test 5a: Short Recording**
1. Long press mic button
2. Immediately release (< 1 second)

**Expected:**
- ❌ Error message: "Recording too short"
- 🔄 Auto-recovers to idle after 3 seconds

**Test 5b: No Internet**
1. Turn off WiFi/Mobile data
2. Long press mic button
3. Say something and release

**Expected:**
- ❌ Error message: "Cannot connect to server"
- 🔄 Auto-recovers to idle

**Test 5c: Force Reset**
1. Start recording
2. If stuck in "Processing" state
3. **Tap** the mic button (don't long press)

**Expected:**
- 🔄 Shows "Reset complete" snackbar
- 🔄 Returns to idle state

---

### 🎯 Test 6: Apply for Scheme
**Objective:** Verify confirmation flow

1. Long press mic button
2. Say: "मैं योजना के लिए आवेदन करना चाहता हूं" (I want to apply for scheme)
3. Release button
4. Wait for response

**Expected Result:**
- ✅ Audio asks: "क्या आप [Scheme Name] के लिए आवेदन करना चाहते हैं?"
- ✅ Overlay shows "Confirm Apply" button
- ✅ Tap "Confirm Apply" to submit application
- ✅ Success message with tracking ID

---

## 🐛 Common Issues & Solutions

### Issue 1: Mic Button is Gray
**Cause:** Backend not connected

**Solution:**
1. Check internet connection
2. Tap the cloud icon in top-right to retry sync
3. Wait for green cloud icon
4. Try voice command again

---

### Issue 2: "Microphone permission denied"
**Cause:** App doesn't have mic access

**Solution:**
1. Go to phone Settings → Apps → AgriSarthi
2. Enable Microphone permission
3. Restart the app
4. Try again

---

### Issue 3: No Audio Response
**Cause:** TTS failed or audio player issue

**Solution:**
1. Check phone volume is not muted
2. Response text should still appear in overlay
3. Try again - backend will retry TTS

---

### Issue 4: "Request timed out"
**Cause:** Slow internet or backend overload

**Solution:**
1. Check internet speed
2. Try again with shorter command
3. Wait a few seconds and retry

---

### Issue 5: Wrong Language Response
**Cause:** Language detection mismatch

**Solution:**
1. Speak more clearly
2. Use longer sentences
3. Update farmer profile language setting
4. Backend will use profile language as fallback

---

## 📊 Test Results Template

Copy this template to track your testing:

```
Date: ___________
Tester: ___________
Device: ___________
OS Version: ___________

Test 1 - Basic Voice Input: ☐ PASS ☐ FAIL
Notes: _________________________________

Test 2 - Profile Navigation: ☐ PASS ☐ FAIL
Notes: _________________________________

Test 3 - Application Status: ☐ PASS ☐ FAIL
Notes: _________________________________

Test 4 - Multi-Language: ☐ PASS ☐ FAIL
Notes: _________________________________

Test 5 - Error Handling: ☐ PASS ☐ FAIL
Notes: _________________________________

Test 6 - Apply for Scheme: ☐ PASS ☐ FAIL
Notes: _________________________________

Overall Status: ☐ ALL PASS ☐ SOME ISSUES ☐ MAJOR ISSUES
```

---

## 🎬 Demo Script

Use this script for demonstrations:

**Intro:**
"Welcome to AgriSarthi! Let me show you our voice assistant feature that helps farmers interact with the app in their native language."

**Demo Steps:**

1. **Show the mic button**
   "You can see this green microphone button at the bottom. This is your voice assistant."

2. **Demonstrate recording**
   "Just long press and speak..." [Long press]
   "मुझे योजनाएं दिखाओ" [Release]
   "And release when done."

3. **Show processing**
   "The app is now processing your voice, recognizing what you said, and preparing a response."

4. **Show audio response**
   "Listen to the response in Hindi..." [Audio plays]
   "And here are your eligible schemes!"

5. **Demonstrate navigation**
   [Long press] "मेरी प्रोफाइल दिखाओ" [Release]
   "The app automatically navigates to your profile after the response."

6. **Show multi-language**
   [Long press] "Show my applications" [Release]
   "It works in English, Hindi, and Marathi!"

**Closing:**
"This makes it easy for farmers to use the app without typing, especially for those who prefer voice interaction or have difficulty reading."

---

## 📱 Video Recording Tips

If recording a demo video:

1. **Enable screen recording** with audio
2. **Use a quiet environment** for clear voice input
3. **Speak clearly and slowly** for demonstration
4. **Show the visual states** (button color changes)
5. **Highlight the overlay** showing responses
6. **Demonstrate auto-navigation** feature
7. **Show error recovery** (optional)
8. **Keep video under 2 minutes** for best impact

---

## ✅ Acceptance Criteria

The voice feature is working correctly if:

- ✅ Mic button responds to long press
- ✅ Recording state is visible (red button)
- ✅ Processing state is visible (yellow button)
- ✅ Audio response plays clearly
- ✅ Text response appears in overlay
- ✅ Auto-navigation works for supported actions
- ✅ Multi-language support works (Hindi, Marathi, English)
- ✅ Error states auto-recover
- ✅ Confirmation flow works for scheme applications
- ✅ Backend connection status is visible

---

**Happy Testing! 🎉**

If you encounter any issues not covered here, check the debug logs in the console or contact the development team.
