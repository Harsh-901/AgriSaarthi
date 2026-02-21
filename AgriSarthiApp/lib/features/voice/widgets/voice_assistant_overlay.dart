import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/voice_provider.dart';
import '../../../core/theme/app_theme.dart';

class VoiceAssistantOverlay extends StatelessWidget {
  const VoiceAssistantOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<VoiceProvider>(
      builder: (context, provider, child) {
        if (provider.state == VoiceState.idle &&
            provider.lastResponse.isEmpty) {
          return const SizedBox.shrink();
        }

        return Positioned(
          bottom: 100,
          left: 20,
          right: 20,
          child: AnimatedOpacity(
            opacity: provider.state != VoiceState.idle ||
                    provider.lastResponse.isNotEmpty
                ? 1.0
                : 0.0,
            duration: const Duration(milliseconds: 300),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Recording state
                  if (provider.isRecording)
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.mic, color: AppColors.error, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Listening... Tap again to stop',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.error),
                        ),
                      ],
                    ),

                  // Processing state
                  if (provider.isProcessing)
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.primary),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Processing...',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary),
                        ),
                      ],
                    ),

                  // Speaking state
                  if (provider.isSpeaking)
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.volume_up,
                            color: AppColors.primary, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Speaking...',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary),
                        ),
                      ],
                    ),

                  // Response text
                  if (provider.lastResponse.isNotEmpty) ...[
                    if (provider.isRecording ||
                        provider.isProcessing ||
                        provider.isSpeaking)
                      const SizedBox(height: 8),
                    Text(
                      provider.lastResponse,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16),
                    ),

                    // Action buttons — only show for confirm_apply (needs user confirmation)
                    if (provider.lastAction != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12.0),
                        child: Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: [
                            // Confirm apply requires user action — no auto-navigate
                            if (provider.lastAction == 'confirm_apply')
                              ElevatedButton(
                                onPressed: () async {
                                  // Show loading
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Row(
                                        children: [
                                          SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          ),
                                          SizedBox(width: 12),
                                          Text('Submitting application...'),
                                        ],
                                      ),
                                      duration: Duration(seconds: 10),
                                      backgroundColor: AppColors.primary,
                                    ),
                                  );

                                  final result = await provider.confirmAction();

                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context)
                                        .hideCurrentSnackBar();
                                    if (result['success'] == true) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content:
                                              Text('Application Submitted! 🎉'),
                                          backgroundColor: AppColors.success,
                                        ),
                                      );
                                    } else {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            result['message'] ??
                                                'Failed to submit application',
                                          ),
                                          backgroundColor: AppColors.error,
                                        ),
                                      );
                                    }
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.success,
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('✅ Confirm Apply'),
                              ),

                            // Navigating indicator for auto-navigate actions
                            if (_isNavigableAction(provider.lastAction) &&
                                provider.isSpeaking)
                              const Text(
                                'Navigating after audio...',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),

                            // Dismiss button
                            TextButton(
                              onPressed: () => provider.clearResponse(),
                              child: const Text(
                                'Dismiss',
                                style:
                                    TextStyle(color: AppColors.textSecondary),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Clear button when no action
                    if (provider.lastAction == null &&
                        provider.lastResponse.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: TextButton(
                          onPressed: () => provider.clearResponse(),
                          child: const Text('Clear'),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  bool _isNavigableAction(String? action) {
    return const {
      'show_schemes',
      'show_applications',
      'show_profile',
      'complete_profile',
      'show_documents',
      'show_help',
    }.contains(action);
  }
}
