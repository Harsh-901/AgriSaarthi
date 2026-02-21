import 'dart:convert';
import 'dart:io';
import 'package:translator/translator.dart';

void main() async {
  final translator = GoogleTranslator();
  final languages = {
    'hi': 'Hindi',
    'bn': 'Bengali',
    'te': 'Telugu',
    'mr': 'Marathi',
    'ta': 'Tamil',
    'gu': 'Gujarati',
    'kn': 'Kannada',
    'ml': 'Malayalam',
    'pa': 'Punjabi',
    'or': 'Odia',
  };

  final enFile = File('assets/translations/en.json');
  if (!await enFile.exists()) {
    print('Error: en.json not found');
    return;
  }

  final enContent = await enFile.readAsString();
  final Map<String, dynamic> enJson = json.decode(enContent);

  for (final langCode in languages.keys) {
    print('Generating translation for ${languages[langCode]} ($langCode)...');

    // Skip if file exists? No, overwrite to ensure latest
    final targetFile = File('assets/translations/$langCode.json');

    try {
      final Map<String, dynamic> translatedJson = {};
      await _translateMap(translator, enJson, translatedJson, langCode);

      const encoder = JsonEncoder.withIndent('    ');
      await targetFile.writeAsString(encoder.convert(translatedJson));
      print('Saved $langCode.json');
    } catch (e) {
      print('Failed to generate $langCode: $e');
    }
  }
}

Future<void> _translateMap(
  GoogleTranslator translator,
  Map<String, dynamic> source,
  Map<String, dynamic> target,
  String langCode,
) async {
  for (final key in source.keys) {
    final value = source[key];

    if (value is String) {
      try {
        // Simple optimization: don't translate if it looks like a URL or simple number
        if (value.trim().isEmpty) {
          target[key] = value;
          continue;
        }

        // Batching would be better, but simple recursive is easier to implement for now
        final translation = await translator.translate(value, to: langCode);
        target[key] = translation.text;
        // print('  $key: ${translation.text}');
      } catch (e) {
        print('  Error translating $key: $e');
        target[key] = value;
      }
    } else if (value is Map<String, dynamic>) {
      final Map<String, dynamic> nestedTarget = {};
      target[key] = nestedTarget;
      await _translateMap(translator, value, nestedTarget, langCode);
    } else {
      target[key] = value;
    }
  }
}
