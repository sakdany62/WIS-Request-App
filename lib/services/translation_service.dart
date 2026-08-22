// lib/services/translation_service.dart
import 'package:translator/translator.dart';

class TranslationService {
  static final GoogleTranslator _translator = GoogleTranslator();
  static final Map<String, String> _cache = {};
  
  static Future<String> translateToEnglish(String text) async {
    if (text.isEmpty) return text;
    
    // Check if text contains Khmer characters
    final bool containsKhmer = text.contains(RegExp(r'[\u1780-\u17FF]'));
    if (!containsKhmer) return text;
    
    // Check cache first
    if (_cache.containsKey(text)) {
      return _cache[text]!;
    }
    
    try {
      final translation = await _translator.translate(text, from: 'km', to: 'en');
      final translatedText = translation.text;
      _cache[text] = translatedText;
      return translatedText;
    } catch (e) {
      print('Translation error for "$text": $e');
      return text;
    }
  }
  
  static void clearCache() {
    _cache.clear();
  }
}