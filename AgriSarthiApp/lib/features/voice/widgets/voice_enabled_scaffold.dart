import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/router/app_router.dart';
import '../providers/voice_provider.dart';
import 'voice_assistant_button.dart';
import 'voice_assistant_overlay.dart';

/// A thin wrapper around [Scaffold] that adds voice assistant support.
///
/// Reuses the existing [VoiceAssistantButton] (FAB) and [VoiceAssistantOverlay]
/// and sets up the [VoiceProvider.onNavigate] callback for voice-driven navigation.
///
/// Usage: Simply replace `Scaffold(...)` with `VoiceEnabledScaffold(...)` in any screen.
/// All standard Scaffold properties are passed through.
class VoiceEnabledScaffold extends StatefulWidget {
  final Widget? body;
  final PreferredSizeWidget? appBar;
  final Widget? bottomNavigationBar;
  final Color? backgroundColor;
  final Widget? drawer;
  final Widget? endDrawer;
  final bool? resizeToAvoidBottomInset;
  final bool extendBody;
  final bool extendBodyBehindAppBar;

  /// Optional callback for screen-specific voice action handling.
  /// If this returns `true`, the default navigation is skipped.
  final bool Function(String action, Map<String, dynamic>? data)?
      onVoiceAction;

  const VoiceEnabledScaffold({
    super.key,
    this.body,
    this.appBar,
    this.bottomNavigationBar,
    this.backgroundColor,
    this.drawer,
    this.endDrawer,
    this.resizeToAvoidBottomInset,
    this.extendBody = false,
    this.extendBodyBehindAppBar = false,
    this.onVoiceAction,
  });

  @override
  State<VoiceEnabledScaffold> createState() => _VoiceEnabledScaffoldState();
}

class _VoiceEnabledScaffoldState extends State<VoiceEnabledScaffold> {
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

    // Let the screen handle it first if it wants to
    if (widget.onVoiceAction != null) {
      final handled = widget.onVoiceAction!(action, data);
      if (handled) return;
    }

    debugPrint('VoiceEnabledScaffold: 🧭 Voice navigation → $action');

    switch (action) {
      case 'show_schemes':
        // Navigate to home where schemes are displayed
        context.go(AppRouter.farmerHome);
        break;
      case 'show_applications':
        context.push(AppRouter.applications);
        break;
      case 'show_profile':
      case 'complete_profile':
        context.push(AppRouter.farmerProfile);
        break;
      case 'show_documents':
        context.push(AppRouter.documentUpload);
        break;
      case 'show_help':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Help section coming soon!'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
        break;
      case 'file_claim':
        context.push(AppRouter.insuranceClaim);
        break;
      default:
        debugPrint(
            'VoiceEnabledScaffold: Unknown voice action: $action');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.backgroundColor,
      appBar: widget.appBar,
      drawer: widget.drawer,
      endDrawer: widget.endDrawer,
      resizeToAvoidBottomInset: widget.resizeToAvoidBottomInset,
      extendBody: widget.extendBody,
      extendBodyBehindAppBar: widget.extendBodyBehindAppBar,
      body: Stack(
        children: [
          if (widget.body != null) widget.body!,
          // Voice overlay — shows recording/processing/response UI
          const VoiceAssistantOverlay(),
        ],
      ),
      floatingActionButton: const VoiceAssistantButton(),
      floatingActionButtonLocation:
          FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: widget.bottomNavigationBar,
    );
  }
}
