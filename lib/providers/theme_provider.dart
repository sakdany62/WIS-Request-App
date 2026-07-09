import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../app_fonts.dart';

class ThemeProvider extends ChangeNotifier {
  bool _isDarkMode = false;
  static const String _darkModeKey = 'isDarkMode';

  bool get isDarkMode => _isDarkMode;

  ThemeProvider() {
    _loadThemePreference();
  }

  // ============================================================
  // ⏰ Load theme preference from SharedPreferences
  // ============================================================
  Future<void> _loadThemePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isDark = prefs.getBool(_darkModeKey) ?? false;
      _isDarkMode = isDark;
      notifyListeners();
    } catch (e) {
      print('❌ Error loading theme preference: $e');
      _isDarkMode = false;
      notifyListeners();
    }
  }

  // ============================================================
  // ⏰ Save theme preference to SharedPreferences
  // ============================================================
  Future<void> _saveThemePreference(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_darkModeKey, value);
    } catch (e) {
      print('❌ Error saving theme preference: $e');
    }
  }

  // ============================================================
  // ⏰ Toggle theme
  // ============================================================
  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    await _saveThemePreference(_isDarkMode);
    notifyListeners();
  }

  // ============================================================
  // ⏰ Set dark mode
  // ============================================================
  Future<void> setDarkMode(bool value) async {
    if (_isDarkMode != value) {
      _isDarkMode = value;
      await _saveThemePreference(_isDarkMode);
      notifyListeners();
    }
  }

  // ============================================================
  // ⏰ Light Theme
  // ============================================================
  ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      primaryColor: const Color(0xFF1A3B68),
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF1A3B68),
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: const Color(0xFFF7F8FA),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1A3B68),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: AppFonts.md,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(  // ← Changed from CardTheme to CardThemeData
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        color: Colors.white,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1A3B68),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(fontSize: AppFonts.md, color: Colors.black87),
        bodyMedium: TextStyle(fontSize: AppFonts.md, color: Colors.black87),
        bodySmall: TextStyle(fontSize: AppFonts.md, color: Colors.black54),
        titleLarge: TextStyle(fontSize: AppFonts.md, color: Colors.black87),
        titleMedium: TextStyle(fontSize: AppFonts.md, color: Colors.black87),
        titleSmall: TextStyle(fontSize: AppFonts.md, color: Colors.black87),
        labelLarge: TextStyle(fontSize: AppFonts.md, color: Colors.black87),
        labelMedium: TextStyle(fontSize: AppFonts.md, color: Colors.black87),
        labelSmall: TextStyle(fontSize: AppFonts.md, color: Colors.black54),
      ),
      dividerTheme: const DividerThemeData(
        color: Colors.grey,
        thickness: 0.5,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: Color(0xFF1A3B68),
        unselectedItemColor: Colors.grey,
      ),
    );
  }

  // ============================================================
  // ⏰ Dark Theme
  // ============================================================
  ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: const Color(0xFF1A3B68),
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF1A3B68),
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: Colors.grey[900],
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFF1A3B68),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: const TextStyle(
          fontSize: AppFonts.md,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(  // ← Changed from CardTheme to CardThemeData
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        color: Colors.grey[850],
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: Colors.grey[800],
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1A3B68),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(fontSize: AppFonts.md, color: Colors.white),
        bodyMedium: TextStyle(fontSize: AppFonts.md, color: Colors.white),
        bodySmall: TextStyle(fontSize: AppFonts.md, color: Colors.white70),
        titleLarge: TextStyle(fontSize: AppFonts.md, color: Colors.white),
        titleMedium: TextStyle(fontSize: AppFonts.md, color: Colors.white),
        titleSmall: TextStyle(fontSize: AppFonts.md, color: Colors.white),
        labelLarge: TextStyle(fontSize: AppFonts.md, color: Colors.white),
        labelMedium: TextStyle(fontSize: AppFonts.md, color: Colors.white),
        labelSmall: TextStyle(fontSize: AppFonts.md, color: Colors.white70),
      ),
      dividerTheme: const DividerThemeData(
        color: Colors.grey,
        thickness: 0.5,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.grey[900],
        selectedItemColor: const Color(0xFF1A3B68),
        unselectedItemColor: Colors.grey[500],
      ),
    );
  }
}