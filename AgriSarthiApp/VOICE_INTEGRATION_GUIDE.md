# 🔌 Voice Assistant Integration Guide for Developers

## Overview

This guide shows how to add the voice assistant feature to **other screens** in your app. Currently, the voice button is only on the **Farmer Home Screen**. You can easily add it to other screens like Applications, Profile, Documents, etc.

---

## ✅ Current Integration

### Where Voice Button Exists Now

**Screen:** Farmer Home Screen  
**File:** `lib/features/home/screens/farmer_home_screen.dart`

```dart
@override
Widget build(BuildContext context) {
  return Scaffold(
    body: SafeArea(
      child: Stack(
        children: [
          // Main content
          Column(children: [...]),
          
          // Voice Assistant Overlay
          const VoiceAssistantOverlay(),
        ],
      ),
    ),
    floatingActionButton: const VoiceAssistantButton(),
    floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    bottomNavigationBar: _buildBottomNav(),
  );
}
```

---

## 🚀 How to Add Voice to Other Screens

### Step 1: Import Required Components

Add these imports to your screen file:

```dart
import 'package:provider/provider.dart';
import '../../voice/providers/voice_provider.dart';
import '../../voice/widgets/voice_assistant_button.dart';
import '../../voice/widgets/voice_assistant_overlay.dart';
```

### Step 2: Add Voice Button to Scaffold

```dart
@override
Widget build(BuildContext context) {
  return Scaffold(
    // ... your existing body
    
    // Add the voice button
    floatingActionButton: const VoiceAssistantButton(),
    floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
  );
}
```

### Step 3: Add Voice Overlay (Optional but Recommended)

Wrap your body content in a Stack and add the overlay:

```dart
body: SafeArea(
  child: Stack(
    children: [
      // Your existing content
      Column(
        children: [
          // ... your widgets
        ],
      ),
      
      // Voice feedback overlay
      const VoiceAssistantOverlay(),
    ],
  ),
),
```

### Step 4: Setup Voice Navigation (Optional)

If you want custom navigation behavior for voice commands on this screen:

```dart
class _YourScreenState extends State<YourScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupVoiceNavigation();
    });
  }

  void _setupVoiceNavigation() {
    if (!mounted) return;
    final voiceProvider = Provider.of<VoiceProvider>(context, listen: false);
    voiceProvider.onNavigate = _handleVoiceNavigation;
  }

  void _handleVoiceNavigation(String action, Map<String, dynamic>? data) {
    if (!mounted) return;
    
    switch (action) {
      case 'show_schemes':
        context.push(AppRouter.home);
        break;
      case 'show_profile':
        context.push(AppRouter.farmerProfile);
        break;
      // Add more cases as needed
      default:
        debugPrint('Unknown voice action: $action');
    }
  }
}
```

---

## 📝 Complete Example: Adding Voice to Applications Screen

### Before (No Voice)

```dart
class ApplicationsScreen extends StatelessWidget {
  const ApplicationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Applications')),
      body: ListView(
        children: [
          // Application cards
        ],
      ),
    );
  }
}
```

### After (With Voice)

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../voice/providers/voice_provider.dart';
import '../../voice/widgets/voice_assistant_button.dart';
import '../../voice/widgets/voice_assistant_overlay.dart';

class ApplicationsScreen extends StatefulWidget {
  const ApplicationsScreen({super.key});

  @override
  State<ApplicationsScreen> createState() => _ApplicationsScreenState();
}

class _ApplicationsScreenState extends State<ApplicationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupVoiceNavigation();
    });
  }

  void _setupVoiceNavigation() {
    if (!mounted) return;
    final voiceProvider = Provider.of<VoiceProvider>(context, listen: false);
    voiceProvider.onNavigate = _handleVoiceNavigation;
  }

  void _handleVoiceNavigation(String action, Map<String, dynamic>? data) {
    if (!mounted) return;
    
    switch (action) {
      case 'show_schemes':
        context.push(AppRouter.home);
        break;
      case 'show_profile':
        context.push(AppRouter.farmerProfile);
        break;
      case 'show_documents':
        context.push(AppRouter.documentUpload);
        break;
      // Already on applications screen
      case 'show_applications':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Already viewing applications')),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Applications')),
      body: SafeArea(
        child: Stack(
          children: [
            // Main content
            ListView(
              children: [
                // Application cards
              ],
            ),
            
            // Voice overlay
            const VoiceAssistantOverlay(),
          ],
        ),
      ),
      
      // Voice button
      floatingActionButton: const VoiceAssistantButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      
      // Bottom nav (if you have one)
      bottomNavigationBar: _buildBottomNav(),
    );
  }
  
  Widget _buildBottomNav() {
    // Your bottom navigation bar
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8.0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // Nav items
        ],
      ),
    );
  }
}
```

---

## 🎯 Integration Checklist

When adding voice to a new screen:

- [ ] Import voice components
- [ ] Add `VoiceAssistantButton` as `floatingActionButton`
- [ ] Add `VoiceAssistantOverlay` in a Stack (optional)
- [ ] Setup voice navigation callback (optional)
- [ ] Handle screen-specific voice actions (optional)
- [ ] Test voice commands on the screen
- [ ] Verify auto-navigation works correctly

---

## 🎨 UI Considerations

### With Bottom Navigation Bar

If your screen has a bottom nav bar, use `centerDocked` location:

```dart
floatingActionButton: const VoiceAssistantButton(),
floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
bottomNavigationBar: BottomAppBar(
  shape: const CircularNotchedRectangle(),
  notchMargin: 8.0,
  // ... nav items
),
```

### Without Bottom Navigation Bar

Use `endFloat` or `centerFloat` location:

```dart
floatingActionButton: const VoiceAssistantButton(),
floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
```

### Custom Positioning

For custom positioning, wrap in Positioned widget:

```dart
body: Stack(
  children: [
    // Main content
    
    // Custom positioned voice button
    Positioned(
      bottom: 20,
      right: 20,
      child: const VoiceAssistantButton(),
    ),
  ],
),
```

---

## 🔧 Advanced Customization

### Custom Voice Actions for Specific Screens

You can add screen-specific voice commands:

```dart
void _handleVoiceNavigation(String action, Map<String, dynamic>? data) {
  if (!mounted) return;
  
  // Screen-specific actions
  if (action == 'filter_applications') {
    _showFilterDialog();
    return;
  }
  
  if (action == 'sort_by_date') {
    _sortApplicationsByDate();
    return;
  }
  
  // Default navigation actions
  switch (action) {
    case 'show_schemes':
      context.push(AppRouter.home);
      break;
    // ... other cases
  }
}
```

### Conditional Voice Button Display

Show/hide voice button based on conditions:

```dart
floatingActionButton: authProvider.isDjangoAuthenticated 
    ? const VoiceAssistantButton()
    : null,
```

### Custom Voice Button Styling

Create a custom wrapper:

```dart
floatingActionButton: Container(
  decoration: BoxDecoration(
    boxShadow: [
      BoxShadow(
        color: AppColors.primary.withOpacity(0.3),
        blurRadius: 20,
        spreadRadius: 5,
      ),
    ],
  ),
  child: const VoiceAssistantButton(),
),
```

---

## 📋 Screens to Add Voice To

### Recommended Screens

1. **Applications Screen** ✅ High priority
   - Users often check application status
   - Voice command: "मेरे आवेदन की स्थिति?"

2. **Profile Screen** ✅ High priority
   - Users view/edit profile
   - Voice command: "मेरी प्रोफाइल दिखाओ"

3. **Document Upload Screen** ✅ Medium priority
   - Users upload documents
   - Voice command: "मेरे दस्तावेज़ दिखाओ"

4. **Scheme Details Screen** ⚠️ Low priority
   - Users view scheme details
   - Voice command: "योजना के बारे में बताओ"

5. **Notifications Screen** ⚠️ Low priority
   - Users check notifications
   - Voice command: "मेरी सूचनाएं दिखाओ"

### Screens to Avoid

❌ **Login/OTP Screens** - Users not authenticated yet  
❌ **Splash Screen** - Too early in app flow  
❌ **Language Selection** - Voice not needed here  
❌ **Admin Screens** - Different user type  

---

## 🧪 Testing After Integration

After adding voice to a screen:

1. **Navigate to the screen**
2. **Verify button appears** at bottom center
3. **Long press button** - should turn red
4. **Speak a command** - e.g., "मुझे योजनाएं दिखाओ"
5. **Release button** - should turn yellow (processing)
6. **Wait for response** - should play audio
7. **Verify navigation** - should go to correct screen
8. **Test overlay** - should show response text

---

## 🐛 Common Issues

### Issue 1: Voice button not showing

**Cause:** Missing import or wrong FAB location

**Solution:**
```dart
import '../../voice/widgets/voice_assistant_button.dart';

floatingActionButton: const VoiceAssistantButton(),
```

### Issue 2: Overlay not visible

**Cause:** Not wrapped in Stack

**Solution:**
```dart
body: Stack(
  children: [
    // Your content
    const VoiceAssistantOverlay(),
  ],
),
```

### Issue 3: Navigation not working

**Cause:** Navigation callback not set

**Solution:**
```dart
@override
void initState() {
  super.initState();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final voiceProvider = Provider.of<VoiceProvider>(context, listen: false);
    voiceProvider.onNavigate = _handleVoiceNavigation;
  });
}
```

### Issue 4: Button overlaps content

**Cause:** No padding at bottom

**Solution:**
```dart
ListView(
  padding: const EdgeInsets.only(bottom: 80), // Space for FAB
  children: [...],
)
```

---

## 📊 Integration Examples

### Example 1: Simple Screen (No Bottom Nav)

```dart
class SimpleScreen extends StatelessWidget {
  const SimpleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Simple Screen')),
      body: Stack(
        children: [
          // Content
          Center(child: Text('Content')),
          
          // Voice overlay
          const VoiceAssistantOverlay(),
        ],
      ),
      floatingActionButton: const VoiceAssistantButton(),
    );
  }
}
```

### Example 2: Screen with Bottom Nav

```dart
class ScreenWithNav extends StatelessWidget {
  const ScreenWithNav({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Content
          ListView(children: [...]),
          
          // Voice overlay
          const VoiceAssistantOverlay(),
        ],
      ),
      floatingActionButton: const VoiceAssistantButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        child: Row(children: [...]),
      ),
    );
  }
}
```

### Example 3: Screen with Custom Navigation

```dart
class CustomNavScreen extends StatefulWidget {
  const CustomNavScreen({super.key});

  @override
  State<CustomNavScreen> createState() => _CustomNavScreenState();
}

class _CustomNavScreenState extends State<CustomNavScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final voiceProvider = Provider.of<VoiceProvider>(context, listen: false);
      voiceProvider.onNavigate = (action, data) {
        // Custom navigation logic
        if (action == 'custom_action') {
          _handleCustomAction(data);
        }
      };
    });
  }

  void _handleCustomAction(Map<String, dynamic>? data) {
    // Your custom logic
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Content
          const VoiceAssistantOverlay(),
        ],
      ),
      floatingActionButton: const VoiceAssistantButton(),
    );
  }
}
```

---

## 🎯 Best Practices

### DO ✅

- **Add voice to frequently used screens**
- **Setup navigation callbacks for better UX**
- **Test voice commands after integration**
- **Add padding at bottom for FAB**
- **Use Stack for overlay**
- **Keep navigation logic simple**

### DON'T ❌

- **Don't add to login/splash screens**
- **Don't override global navigation**
- **Don't forget to test**
- **Don't add without overlay**
- **Don't use custom voice button (use provided component)**

---

## 📚 Reference

### Required Imports
```dart
import 'package:provider/provider.dart';
import '../../voice/providers/voice_provider.dart';
import '../../voice/widgets/voice_assistant_button.dart';
import '../../voice/widgets/voice_assistant_overlay.dart';
```

### Minimal Integration
```dart
Scaffold(
  body: Stack(
    children: [
      YourContent(),
      const VoiceAssistantOverlay(),
    ],
  ),
  floatingActionButton: const VoiceAssistantButton(),
)
```

### Full Integration
```dart
class YourScreen extends StatefulWidget {
  @override
  State<YourScreen> createState() => _YourScreenState();
}

class _YourScreenState extends State<YourScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final voiceProvider = Provider.of<VoiceProvider>(context, listen: false);
      voiceProvider.onNavigate = _handleVoiceNavigation;
    });
  }

  void _handleVoiceNavigation(String action, Map<String, dynamic>? data) {
    // Handle navigation
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          YourContent(),
          const VoiceAssistantOverlay(),
        ],
      ),
      floatingActionButton: const VoiceAssistantButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}
```

---

## 🎉 Summary

Adding voice to a new screen requires:

1. **3 imports** (Provider, VoiceProvider, Button, Overlay)
2. **1 widget** (VoiceAssistantButton as FAB)
3. **1 optional widget** (VoiceAssistantOverlay in Stack)
4. **1 optional callback** (Navigation handler)

**Time to integrate:** ~5 minutes per screen

**Difficulty:** ⭐ Easy

---

**Happy Coding! 🚀**

For questions or issues, refer to:
- `VOICE_ASSISTANT_GUIDE.md` - Technical details
- `VOICE_TESTING_GUIDE.md` - Testing procedures
- `VOICE_COMMANDS_REFERENCE.md` - Supported commands
