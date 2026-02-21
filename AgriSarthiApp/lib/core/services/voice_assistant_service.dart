import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:flutter/foundation.dart';
import '../config/api_config.dart';
import 'api_service.dart';

/// Result from voice processing — contains audio bytes + metadata
class VoiceProcessResult {
  final bool success;
  final String? message;

  // Audio
  final Uint8List? audioBytes;

  // Metadata
  final String? intent;
  final double? confidence;
  final String? originalText;
  final String? response;
  final String? speechText;
  final String? action;
  final Map<String, dynamic>? data;

  VoiceProcessResult({
    required this.success,
    this.message,
    this.audioBytes,
    this.intent,
    this.confidence,
    this.originalText,
    this.response,
    this.speechText,
    this.action,
    this.data,
  });

  factory VoiceProcessResult.error(String message) {
    return VoiceProcessResult(success: false, message: message);
  }
}

class VoiceAssistantService {
  final ApiService _apiService = ApiService();

  /// Process voice audio file — sends to backend for STT + Intent + TTS
  /// Returns VoiceProcessResult with audio bytes and metadata
  Future<VoiceProcessResult> processVoice(String audioPath) async {
    final token = _apiService.accessToken;
    if (token == null) {
      return VoiceProcessResult.error(
          'Not authenticated. Please wait for backend sync.');
    }

    // Validate file exists
    final file = File(audioPath);
    if (!await file.exists()) {
      return VoiceProcessResult.error('Audio file not found');
    }

    final fileSize = await file.length();
    debugPrint('VoiceAssistantService: File size: $fileSize bytes');
    if (fileSize < 100) {
      return VoiceProcessResult.error('Audio too short. Please speak longer.');
    }

    try {
      final url = '${ApiConfig.baseUrl}/api/voice/process/';
      debugPrint('VoiceAssistantService: 🌐 POST $url');
      final uri = Uri.parse(url);
      final request = http.MultipartRequest('POST', uri);

      request.headers['Authorization'] = 'Bearer $token';

      // Determine content type from extension
      final extension = audioPath.split('.').last.toLowerCase();
      // Use x-m4a which is in the allowed list
      final mediaSubtype =
          extension == 'wav' ? 'wav' : (extension == 'mp3' ? 'mpeg' : 'x-m4a');

      request.files.add(await http.MultipartFile.fromPath(
        'audio',
        audioPath,
        contentType: MediaType('audio', mediaSubtype),
      ));

      debugPrint(
          'VoiceAssistantService: Sending request ($fileSize bytes, audio/$mediaSubtype)...');

      // 60s timeout — backend does STT (~10s) + Groq (~5s) + TTS (~10s) = ~25s typical
      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          throw Exception('Request timed out after 60 seconds');
        },
      );

      debugPrint(
          'VoiceAssistantService: Response status: ${streamedResponse.statusCode}');

      // Handle 401 — try token refresh
      if (streamedResponse.statusCode == 401) {
        debugPrint('VoiceAssistantService: 401 — attempting token refresh');
        final refreshed = await _apiService.refreshAccessToken();
        if (refreshed) {
          return await _retryProcessVoice(audioPath);
        }
        return VoiceProcessResult.error('Session expired. Please re-login.');
      }

      // Read the full response
      final response = await http.Response.fromStream(streamedResponse).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception('Response reading timed out');
        },
      );

      if (streamedResponse.statusCode != 200) {
        debugPrint('VoiceAssistantService: Error response: ${response.body}');
        try {
          final errorData = jsonDecode(response.body);
          return VoiceProcessResult.error(
            errorData['message'] ??
                errorData['detail'] ??
                'Server error (${streamedResponse.statusCode})',
          );
        } catch (_) {
          return VoiceProcessResult.error(
              'Server error (${streamedResponse.statusCode})');
        }
      }

      // Check content type to determine response format
      final contentType = response.headers['content-type'] ?? '';

      if (contentType.contains('audio/wav') || contentType.contains('audio/')) {
        // Binary audio response — metadata is in headers
        return _parseAudioResponse(response);
      } else {
        // JSON fallback (TTS failed, backend returned JSON)
        return _parseJsonResponse(response);
      }
    } on Exception catch (e) {
      debugPrint('VoiceAssistantService: ❌ Process error: $e');

      String message;
      final errorStr = e.toString();
      if (errorStr.contains('timed out') || errorStr.contains('Timeout')) {
        message = 'Request timed out. Check your internet connection.';
      } else if (errorStr.contains('Connection refused') ||
          errorStr.contains('SocketException')) {
        message = 'Cannot connect to server. Is the backend running?';
      } else {
        message = 'Voice processing failed. Please try again.';
      }

      return VoiceProcessResult.error(message);
    }
  }

  /// Parse binary audio response with metadata in headers
  VoiceProcessResult _parseAudioResponse(http.Response response) {
    Map<String, dynamic>? metadata;
    String? intent;
    String? action;
    String? responseText;
    String? speechText;
    double? confidence;
    Map<String, dynamic>? data;

    // Try to parse the full metadata header first
    final metadataHeader = response.headers['x-voice-metadata'];
    if (metadataHeader != null && metadataHeader.isNotEmpty) {
      try {
        metadata = jsonDecode(metadataHeader);
        intent = metadata?['intent'];
        confidence = (metadata?['confidence'] as num?)?.toDouble();
        responseText = metadata?['response'];
        speechText = metadata?['speech_text'];
        action = metadata?['action'];
        data = metadata?['data'] != null
            ? Map<String, dynamic>.from(metadata!['data'] as Map)
            : null;
      } catch (e) {
        debugPrint(
            'VoiceAssistantService: Failed to parse X-Voice-Metadata: $e');
      }
    }

    // Fallback: read individual headers
    intent ??= response.headers['x-voice-intent'];
    action ??= response.headers['x-voice-action'];
    final confStr = response.headers['x-voice-confidence'];
    if (confStr != null && confidence == null) {
      confidence = double.tryParse(confStr);
    }
    if (responseText == null) {
      final encoded = response.headers['x-voice-response'];
      if (encoded != null) {
        responseText = Uri.decodeComponent(encoded);
      }
    }
    if (speechText == null) {
      final encoded = response.headers['x-voice-speech-text'];
      if (encoded != null) {
        speechText = Uri.decodeComponent(encoded);
      }
    }

    debugPrint(
        'VoiceAssistantService: ✅ Audio response — intent=$intent, action=$action, ${response.bodyBytes.length} bytes');

    return VoiceProcessResult(
      success: true,
      audioBytes: response.bodyBytes,
      intent: intent,
      confidence: confidence,
      originalText: metadata?['original_text'],
      response: responseText ?? '',
      speechText: speechText ?? '',
      action: (action != null && action.isNotEmpty) ? action : null,
      data: data,
    );
  }

  /// Parse JSON fallback response (when TTS failed)
  VoiceProcessResult _parseJsonResponse(http.Response response) {
    try {
      final json = jsonDecode(response.body);
      if (json['success'] != true) {
        return VoiceProcessResult.error(json['message'] ?? 'Processing failed');
      }

      final d = json['data'] ?? json;
      debugPrint(
          'VoiceAssistantService: ✅ JSON fallback — intent=${d['intent']}, action=${d['action']}');

      return VoiceProcessResult(
        success: true,
        audioBytes: null, // No audio in fallback
        intent: d['intent'],
        confidence: (d['confidence'] as num?)?.toDouble(),
        originalText: d['original_text'],
        response: d['response'] ?? '',
        speechText: d['speech_text'] ?? '',
        action: d['action'],
        data: d['data'] != null
            ? Map<String, dynamic>.from(d['data'] as Map)
            : null,
      );
    } catch (e) {
      debugPrint('VoiceAssistantService: Failed to parse JSON response: $e');
      return VoiceProcessResult.error('Failed to parse server response');
    }
  }

  /// Retry once after token refresh
  Future<VoiceProcessResult> _retryProcessVoice(String audioPath) async {
    final token = _apiService.accessToken;
    if (token == null) {
      return VoiceProcessResult.error('Authentication failed after refresh');
    }

    try {
      final url = '${ApiConfig.baseUrl}/api/voice/process/';
      final uri = Uri.parse(url);
      final request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Bearer $token';

      final extension = audioPath.split('.').last.toLowerCase();
      final mediaSubtype =
          extension == 'wav' ? 'wav' : (extension == 'mp3' ? 'mpeg' : 'x-m4a');

      request.files.add(await http.MultipartFile.fromPath(
        'audio',
        audioPath,
        contentType: MediaType('audio', mediaSubtype),
      ));

      final streamedResponse =
          await request.send().timeout(const Duration(seconds: 60));
      final response = await http.Response.fromStream(streamedResponse)
          .timeout(const Duration(seconds: 15));

      final contentType = response.headers['content-type'] ?? '';
      if (contentType.contains('audio/')) {
        return _parseAudioResponse(response);
      } else {
        return _parseJsonResponse(response);
      }
    } catch (e) {
      return VoiceProcessResult.error(
          'Retry failed: ${e.toString().split('\n').first}');
    }
  }

  /// Confirm voice intent (e.g., apply for scheme)
  Future<Map<String, dynamic>> confirmIntent({
    required String action,
    required String schemeId,
    bool confirmed = true,
  }) async {
    return await _apiService.post('/api/voice/confirm/', {
      'action': action,
      'scheme_id': schemeId,
      'confirmed': confirmed,
    });
  }
}
