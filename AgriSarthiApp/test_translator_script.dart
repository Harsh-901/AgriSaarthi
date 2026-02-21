import 'package:translator/translator.dart';

void main() async {
  final translator = GoogleTranslator();
  try {
    print('Testing translation...');
    var translation = await translator.translate("Hello", to: 'hi');
    print("Translation result: ${translation.text}");

    translation = await translator.translate("Hello", to: 'bn');
    print("Translation result: ${translation.text}");

    print('Translation successful!');
  } catch (e) {
    print('Translation failed: $e');
  }
}
