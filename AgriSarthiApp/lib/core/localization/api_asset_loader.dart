import 'dart:convert';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:translator/translator.dart';

class ApiAssetLoader extends AssetLoader {
  final GoogleTranslator _translator = GoogleTranslator();

  // Cache already translated content
  final Map<String, Map<String, dynamic>> _cache = {};

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async {
    final languageCode = locale.languageCode;

    // 1. Try to load from "en" (base) file first as reference structure
    final String enString = await rootBundle.loadString('$path/en.json');
    final Map<String, dynamic> enJson = json.decode(enString);

    // If English, just return it
    if (languageCode == 'en') {
      return enJson;
    }

    // 2. Check in-memory cache
    if (_cache.containsKey(languageCode)) {
      return _cache[languageCode]!;
    }

    // 3. Try to load local file if exists (for manual overrides like Hindi)
    try {
      // We use try-catch because asset loading throws if file doesn't exist
      // Note: In release builds, checking existence is tricky, so we rely on catching
      final String localString =
          await rootBundle.loadString('$path/$languageCode.json');
      final Map<String, dynamic> localJson = json.decode(localString);
      _cache[languageCode] = localJson;
      return localJson;
    } catch (_) {
      // File doesn't exist, proceed to translate
    }

    // 4. Translate dynamically using Google Translate API
    debugPrint('ApiAssetLoader: Starting translation to $languageCode...');
    final Map<String, dynamic> translatedJson = {};

    try {
      // Recursively translate the JSON map
      await _translateMap(enJson, translatedJson, languageCode);

      debugPrint(
          'ApiAssetLoader: Translation to $languageCode completed successfully.');

      // Cache the result
      _cache[languageCode] = translatedJson;
      return translatedJson;
    } catch (e, stackTrace) {
      debugPrint('ApiAssetLoader: Translation error: $e');
      debugPrint('ApiAssetLoader: Stack trace: $stackTrace');
      // Fallback to English on error
      return enJson;
    }
  }

  Future<void> _translateMap(Map<String, dynamic> source,
      Map<String, dynamic> target, String languageCode) async {
    for (final key in source.keys) {
      final value = source[key];

      if (value is String) {
        // Translate format strings carefully (skip placeholders if any)
        // For simplicity, we just translate the whole string now
        try {
          final translation =
              await _translator.translate(value, to: languageCode);
          target[key] = translation.text;
        } catch (e) {
          debugPrint('Error translating key $key: $e');
          target[key] = value; // Fallback
        }
      } else if (value is Map<String, dynamic>) {
        final Map<String, dynamic> nestedTarget = {};
        target[key] = nestedTarget;
        await _translateMap(value, nestedTarget, languageCode);
      } else {
        target[key] = value;
      }
    }
  }
}
