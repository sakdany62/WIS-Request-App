// lib/services/language_service.dart
import 'package:shared_preferences/shared_preferences.dart';

class LanguageService {
  static const String _languageKey = 'app_language';
  static const String english = 'en';
  static const String khmer = 'km';

  static Future<void> setLanguage(String languageCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, languageCode);
  }

  static Future<String> getLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_languageKey) ?? english;
  }

  static Future<bool> isKhmer() async {
    final lang = await getLanguage();
    return lang == khmer;
  }

  static Future<bool> isEnglish() async {
    final lang = await getLanguage();
    return lang == english;
  }
}