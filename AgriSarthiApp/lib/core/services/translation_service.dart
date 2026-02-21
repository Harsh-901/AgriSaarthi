import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class TranslationService {
  static const String _apiKey = 'sk_8y7vhbfo_aM5KgvRWnXO8mv9TylGG9qcu';
  static const String _url = 'https://api.sarvam.ai/translate';

  // Cache translations to avoid repeated API calls within the session
  static final Map<String, String> _cache = {};

  static Future<String> translate(String text, String targetLangCode) async {
    if (text.trim().isEmpty) return text;
    if (targetLangCode == 'en') return text; // Assuming source is English
    if (targetLangCode == 'en_US') return text;

    // Normalize target lang ( Sarvam expects 'hi-IN', 'mr-IN', etc.)
    String sarvamLangCode;
    switch (targetLangCode) {
      case 'hi':
        sarvamLangCode = 'hi-IN';
        break;
      case 'mr':
        sarvamLangCode = 'mr-IN';
        break;
      case 'bn':
        sarvamLangCode = 'bn-IN';
        break;
      case 'te':
        sarvamLangCode = 'te-IN';
        break;
      case 'ta':
        sarvamLangCode = 'ta-IN';
        break;
      case 'gu':
        sarvamLangCode = 'gu-IN';
        break;
      case 'kn':
        sarvamLangCode = 'kn-IN';
        break;
      case 'ml':
        sarvamLangCode = 'ml-IN';
        break;
      case 'pa':
        sarvamLangCode = 'pa-IN';
        break;
      case 'or':
        sarvamLangCode = 'od-IN';
        break;
      default:
        // If we don't support it, just return original
        return text;
    }

    final cacheKey = '$text|$sarvamLangCode';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    try {
      final response = await http.post(
        Uri.parse(_url),
        headers: {
          'Content-Type': 'application/json',
          'api-subscription-key': _apiKey,
        },
        body: json.encode({
          "input": text,
          "source_language_code": "en-IN",
          "target_language_code": sarvamLangCode,
          "model": "mayura:v1",
          /* "speaker_gender": "Male", */ // Optional
          /* "mode": "formal" */ // Optional
        }),
      );

      if (response.statusCode == 200) {
        // Sarvam responses are sometimes UTF-8 encoded, ensure we decode correctly
        final responseBody = utf8.decode(response.bodyBytes);
        final data = json.decode(responseBody);
        final translatedText = data['translated_text']?.toString() ?? text;

        // Cache it
        _cache[cacheKey] = translatedText;

        return translatedText;
      } else {
        debugPrint(
            'Sarvam API Error: ${response.statusCode} - ${response.body}');
        return text;
      }
    } catch (e) {
      debugPrint('Sarvam Request Error: $e');
      return text;
    }
  }
}
