import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

Future<void> main() async {
  // Sarvam API Key from env
  final sarvamIds = const String.fromEnvironment('SARVAM_API_KEY',
      defaultValue: 'sk_8y7vhbfo_aM5KgvRWnXO8mv9TylGG9qcu');

  if (sarvamIds.isEmpty) {
    print('Error: SARVAM_API_KEY not found');
    return;
  }

  // Sarvam API Endpoint
  const sarvamUrl = 'https://api.sarvam.ai/translate';

  final languages = {
    'hi': 'hi-IN',
    'bn': 'bn-IN',
    'te': 'te-IN',
    'mr': 'mr-IN',
    'ta': 'ta-IN',
    'gu': 'gu-IN',
    'kn': 'kn-IN',
    'ml': 'ml-IN',
    'pa': 'pa-IN',
    'or': 'od-IN',
  };

  final enFile = File('assets/translations/en.json');
  if (!await enFile.exists()) {
    print('Error: en.json not found');
    return;
  }

  final enContent = await enFile.readAsString();
  final Map<String, dynamic> enJson = json.decode(enContent);

  for (final langCode in languages.keys) {
    final targetLang = languages[langCode];
    print('Generating translation for $targetLang ($langCode) using Sarvam...');

    final targetFile = File('assets/translations/$langCode.json');

    try {
      final Map<String, dynamic> translatedJson = {};

      // Sarvam translate is best with batch, but let's do simple recursive for now
      // to match structure. Optimization: Collect all strings, translate in batch, then re-map.
      // For now, let's just do recursive to ensure correct mapping.
      await _translateMapSarvam(
          sarvamIds, sarvamUrl, enJson, translatedJson, targetLang!);

      const encoder = JsonEncoder.withIndent('    ');
      await targetFile.writeAsString(encoder.convert(translatedJson));
      print('Saved $langCode.json');
    } catch (e) {
      print('Failed to generate $langCode: $e');
    }
  }
}

Future<void> _translateMapSarvam(
  String apiKey,
  String url,
  Map<String, dynamic> source,
  Map<String, dynamic> target,
  String targetLang,
) async {
  for (final key in source.keys) {
    final value = source[key];

    if (value is String) {
      if (value.trim().isEmpty) {
        target[key] = value;
        continue;
      }

      try {
        final translatedText =
            await _callSarvamTranslate(apiKey, url, value, targetLang);
        target[key] = translatedText;
        // print('  $key: $translatedText');
      } catch (e) {
        print('  Error translating $key: $e');
        target[key] = value;
      }
    } else if (value is Map<String, dynamic>) {
      final Map<String, dynamic> nestedTarget = {};
      target[key] = nestedTarget;
      await _translateMapSarvam(apiKey, url, value, nestedTarget, targetLang);
    } else {
      target[key] = value;
    }
  }
}

Future<String> _callSarvamTranslate(
    String apiKey, String url, String text, String targetLang) async {
  // Sarvam Translate API structure
  // POST https://api.sarvam.ai/translate
  // Body: { "input": "text", "source_language_code": "en-IN", "target_language_code": "hi-IN", "speaker_gender": "Male", "mode": "formal", "model": "mayura:v1" }

  try {
    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        'api-subscription-key': apiKey,
      },
      body: json.encode({
        "input": text,
        "source_language_code": "en-IN",
        "target_language_code": targetLang,
        "model": "mayura:v1", // Using Mayura model for translation
        "speaker_gender": "Male",
        "mode": "formal"
      }),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['translated_text'] ?? text;
    } else {
      print('Sarvam API Error: ${response.statusCode} - ${response.body}');
      return text;
    }
  } catch (e) {
    print('Sarvam Request Error: $e');
    return text;
  }
}
