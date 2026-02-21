import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../../../core/services/voice_assistant_service.dart';

enum VoiceState { idle, recording, processing, speaking, error }

class VoiceProvider with ChangeNotifier {
  final VoiceAssistantService _voiceService = VoiceAssistantService();
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();

  VoiceState _state = VoiceState.idle;
  String _lastResponse = '';
  String? _lastIntent;
  String? _lastAction;
  Map<String, dynamic>? _lastData;
  String? _errorMessage;

  // Navigation callback — set by the screen that hosts the voice button
  // Called after audio playback finishes (or immediately if no audio)
  void Function(String action, Map<String, dynamic>? data)? onNavigate;

  // Timeout management
  Timer? _processingTimeout;
  Timer? _errorAutoRecover;

  // Audio player listener subscription — initialized ONCE
  StreamSubscription<void>? _playerCompleteSubscription;

  VoiceProvider() {
    _initAudioPlayerListener();
  }

  // --- Getters ---
  VoiceState get state => _state;
  String get lastResponse => _lastResponse;
  String? get lastIntent => _lastIntent;
  String? get lastAction => _lastAction;
  Map<String, dynamic>? get lastData => _lastData;
  String? get errorMessage => _errorMessage;

  bool get isRecording => _state == VoiceState.recording;
  bool get isProcessing => _state == VoiceState.processing;
  bool get isSpeaking => _state == VoiceState.speaking;
  bool get isError => _state == VoiceState.error;

  /// Initialize audio player completion listener ONCE (fixes listener leak bug)
  void _initAudioPlayerListener() {
    _playerCompleteSubscription = _player.onPlayerComplete.listen((_) {
      debugPrint('VoiceProvider: Audio playback completed');
      if (_state == VoiceState.speaking) {
        _state = VoiceState.idle;
        notifyListeners();

        // Trigger navigation after audio finishes playing
        _triggerNavigation();
      }
    });
  }

  @override
  void dispose() {
    _processingTimeout?.cancel();
    _errorAutoRecover?.cancel();
    _playerCompleteSubscription?.cancel();
    _recorder.dispose();
    _player.dispose();
    super.dispose();
  }

  // --- State Management Helpers ---

  void _setState(VoiceState newState) {
    _state = newState;
    notifyListeners();
  }

  void _startProcessingTimeout() {
    _processingTimeout?.cancel();
    _processingTimeout = Timer(const Duration(seconds: 60), () {
      debugPrint('VoiceProvider: ⚠️ Processing timeout — resetting to idle');
      _lastResponse = 'Request timed out. Please try again.';
      _errorMessage = 'Timeout';
      _setErrorState('Processing timed out. Please try again.');
    });
  }

  void _cancelProcessingTimeout() {
    _processingTimeout?.cancel();
    _processingTimeout = null;
  }

  void _setErrorState(String message) {
    _errorMessage = message;
    _lastResponse = message;
    _state = VoiceState.error;
    notifyListeners();

    // Auto-recover from error after 3 seconds
    _errorAutoRecover?.cancel();
    _errorAutoRecover = Timer(const Duration(seconds: 3), () {
      if (_state == VoiceState.error) {
        debugPrint('VoiceProvider: Auto-recovering from error state');
        _state = VoiceState.idle;
        _errorMessage = null;
        notifyListeners();
      }
    });
  }

  // --- Navigation ---

  /// Trigger navigation callback if an action is pending
  void _triggerNavigation() {
    if (_lastAction != null && onNavigate != null) {
      // Actions that require navigation
      const navigableActions = {
        'show_schemes',
        'show_applications',
        'show_profile',
        'complete_profile',
        'show_documents',
        'show_help',
      };

      if (navigableActions.contains(_lastAction)) {
        debugPrint('VoiceProvider: 🧭 Triggering navigation → $_lastAction');
        final action = _lastAction!;
        final data = _lastData;

        // Small delay to let the user see the response text before navigating
        Future.delayed(const Duration(milliseconds: 500), () {
          onNavigate?.call(action, data);
          // Clear after navigation
          clearResponse();
        });
      }
    }
  }

  // --- Recording ---

  /// Start recording audio with proper permission handling
  Future<void> startRecording() async {
    // Guard: don't start if already recording or processing
    if (_state == VoiceState.recording || _state == VoiceState.processing) {
      debugPrint(
          'VoiceProvider: Ignoring startRecording — already ${_state.name}');
      return;
    }

    try {
      // Check AND request permission using permission_handler which is more robust
      var status = await Permission.microphone.status;
      if (status.isDenied) {
        debugPrint(
            'VoiceProvider: Mic permission denied — requesting with permission_handler...');
        status = await Permission.microphone.request();
      }

      if (status.isPermanentlyDenied) {
        debugPrint('VoiceProvider: Mic permission permanently denied');
        _setErrorState(
            'Microphone permission denied. Please enable in Settings.');
        await openAppSettings();
        return;
      }

      if (!status.isGranted) {
        debugPrint('VoiceProvider: Mic permission not granted');
        _setErrorState('Microphone permission required.');
        return;
      }

      final directory = await getApplicationDocumentsDirectory();

      const config = RecordConfig(
        encoder: AudioEncoder.aacLc,
        sampleRate: 44100,
        numChannels: 1,
      );

      final fileName =
          'voice_input_${DateTime.now().millisecondsSinceEpoch}.m4a';
      final path = '${directory.path}/$fileName';

      await _recorder.start(config, path: path);
      _errorMessage = null;
      _setState(VoiceState.recording);
      debugPrint('VoiceProvider: ✅ Recording started -> $path');
    } catch (e) {
      debugPrint('VoiceProvider: ❌ Start recording error: $e');
      _setErrorState(
          'Failed to start recording: ${e.toString().split('\n').first}');
    }
  }

  /// Stop recording and process with backend
  Future<void> stopRecording() async {
    if (_state != VoiceState.recording) {
      debugPrint(
          'VoiceProvider: Ignoring stopRecording — not recording (state=${_state.name})');
      return;
    }

    try {
      final path = await _recorder.stop();
      if (path == null) {
        debugPrint('VoiceProvider: ⚠️ Recorder returned null path');
        _setErrorState('Recording failed. Please try again.');
        return;
      }

      // Validate file exists and has content
      final file = File(path);
      if (!await file.exists()) {
        debugPrint('VoiceProvider: ⚠️ Audio file does not exist at $path');
        _setErrorState('Recording failed. Please try again.');
        return;
      }
      final fileSize = await file.length();
      if (fileSize < 100) {
        debugPrint('VoiceProvider: ⚠️ Audio file too small ($fileSize bytes)');
        _setErrorState('Recording too short. Hold the button and speak.');
        return;
      }

      debugPrint(
          'VoiceProvider: Recording stopped. File: $path ($fileSize bytes)');

      // Transition to processing
      _setState(VoiceState.processing);
      _startProcessingTimeout();

      // Send to backend
      final result = await _voiceService.processVoice(path);
      _cancelProcessingTimeout();

      // Clean up the temp audio file
      try {
        await file.delete();
      } catch (_) {}

      if (result.success) {
        _lastResponse = result.response ?? '';
        _lastIntent = result.intent;
        _lastAction = result.action;
        _lastData = result.data;
        _errorMessage = null;

        debugPrint(
            'VoiceProvider: ✅ Backend response — intent: ${result.intent}, action: $_lastAction');

        // Play audio response if available
        if (result.audioBytes != null && result.audioBytes!.isNotEmpty) {
          await _playAudioBytes(result.audioBytes!);
        } else {
          _setState(VoiceState.idle);
          // No audio — navigate immediately
          _triggerNavigation();
        }
      } else {
        debugPrint('VoiceProvider: ❌ Backend error — ${result.message}');
        _setErrorState(result.message ?? 'Voice processing failed');
      }
    } catch (e) {
      _cancelProcessingTimeout();
      debugPrint('VoiceProvider: ❌ Stop recording error: $e');
      _setErrorState('Processing failed. Please try again.');
    }
  }

  /// Play raw audio bytes (WAV) directly
  Future<void> _playAudioBytes(Uint8List audioBytes) async {
    try {
      _setState(VoiceState.speaking);
      debugPrint(
          'VoiceProvider: Playing ${audioBytes.length} bytes of audio...');

      final source = BytesSource(audioBytes);
      await _player.play(source);
      // Listener in _initAudioPlayerListener() handles completion → idle + navigation
    } catch (e) {
      debugPrint('VoiceProvider: ⚠️ Play audio error: $e');
      // Don't block on audio failure — just go to idle and navigate
      _setState(VoiceState.idle);
      _triggerNavigation();
    }
  }

  /// Confirm an action initiated by voice
  Future<Map<String, dynamic>> confirmAction() async {
    debugPrint('VoiceProvider: confirmAction called — action=$_lastAction, data=$_lastData');

    if (_lastAction == null || _lastData == null) {
      debugPrint('VoiceProvider: confirmAction — missing action or data');
      return {'success': false, 'message': 'No pending action to confirm'};
    }

    final schemeId = _lastData!['scheme_id'] ?? '';
    debugPrint('VoiceProvider: confirmAction — scheme_id=$schemeId');

    if (schemeId.isEmpty) {
      debugPrint('VoiceProvider: confirmAction — scheme_id is empty!');
      return {'success': false, 'message': 'Scheme ID missing from voice response'};
    }

    try {
      final result = await _voiceService.confirmIntent(
        action: _lastAction!,
        schemeId: schemeId,
      );

      debugPrint('VoiceProvider: confirmAction result=$result');

      if (result['success'] == true) {
        _lastAction = null;
        _lastData = null;
        notifyListeners();
      }

      return result;
    } catch (e) {
      debugPrint('VoiceProvider: Confirm action error: $e');
      return {'success': false, 'message': 'Confirmation failed: $e'};
    }
  }

  /// Clear the last response and action — reset to idle
  void clearResponse() {
    _cancelProcessingTimeout();
    _errorAutoRecover?.cancel();
    _lastResponse = '';
    _lastIntent = null;
    _lastAction = null;
    _lastData = null;
    _errorMessage = null;
    _state = VoiceState.idle;
    notifyListeners();
  }

  /// Force reset — emergency recovery from any stuck state
  void forceReset() {
    _cancelProcessingTimeout();
    _errorAutoRecover?.cancel();
    _lastResponse = '';
    _lastIntent = null;
    _lastAction = null;
    _lastData = null;
    _errorMessage = null;
    _state = VoiceState.idle;

    // Try to stop recorder if running
    try {
      _recorder.stop();
    } catch (_) {}

    // Try to stop player if running
    try {
      _player.stop();
    } catch (_) {}

    notifyListeners();
    debugPrint('VoiceProvider: 🔄 Force reset completed');
  }
}
