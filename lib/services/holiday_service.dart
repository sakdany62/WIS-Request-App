// lib/services/holiday_service.dart
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class HolidayService {
  // ✅ ប្រើ API Key ពី .env ឬ Remote Config (សម្រាប់ឧទាហរណ៍នេះ ខ្ញុំរក្សាទុកដូចដើម)
  static const String _apiKey = 'uk7LE6jZDEjpDprLsf5NsSUVQYlmL4rz';
  static const String _baseUrl = 'https://calendarific.com/api/v2/holidays';

  // ✅ Cache រយៈពេល ២៤ ម៉ោង
  static const Duration _cacheDuration = Duration(hours: 24);

  /// ទាញយកថ្ងៃឈប់សម្រាកសម្រាប់ប្រទេសកម្ពុជា (KH) តាមឆ្នាំ
  /// ប្រើ Cache ដើម្បីកាត់បន្ថយការហៅ API
  static Future<List<Map<String, dynamic>>> getCambodiaHolidays(int year) async {
    final cacheKey = 'holidays_KH_$year';
    final cacheTimeKey = 'holidays_KH_${year}_timestamp';

    // ===== ពិនិត្យ Cache ជាមុន =====
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(cacheKey);
      final cachedTime = prefs.getInt(cacheTimeKey);

      if (cachedJson != null && cachedTime != null) {
        final cacheAge = DateTime.now().millisecondsSinceEpoch - cachedTime;
        if (cacheAge < _cacheDuration.inMilliseconds) {
          final decoded = jsonDecode(cachedJson) as List;
          print('✅ Loaded ${decoded.length} holidays from cache ($year)');
          return decoded.cast<Map<String, dynamic>>();
        } else {
          print('⏰ Cache expired for $year, fetching fresh data...');
        }
      }
    } catch (e) {
      print('⚠️ Cache read error: $e');
    }

    // ===== ហៅ API =====
    try {
      // ✅ បន្ថែម &language=km ប្រសិនបើគម្រោងរបស់អ្នកគាំទ្រ
      // final url = '$_baseUrl?api_key=$_apiKey&country=KH&year=$year&language=km';
      final url = '$_baseUrl?api_key=$_apiKey&country=KH&year=$year';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final holidays = (data['response']?['holidays'] as List?) ?? [];

        final List<Map<String, dynamic>> result = holidays.map((h) {
          final dateInfo = h['date'] as Map<String, dynamic>? ?? {};
          return {
            'name': h['name'] ?? 'Unknown Holiday',
            'description': h['description'] ?? '',
            'iso': dateInfo['iso'] ?? '',
            'datetime': dateInfo['datetime'] ?? {},
            'type': (h['type'] as List?)?.join(', ') ?? 'National holiday',
            'locations': h['locations'] ?? '',
            'states': h['states'] ?? '',
          };
        }).toList();

        // ===== រក្សាទុកក្នុង Cache =====
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(cacheKey, jsonEncode(result));
          await prefs.setInt(cacheTimeKey, DateTime.now().millisecondsSinceEpoch);
          print('✅ Cached ${result.length} holidays ($year)');
        } catch (e) {
          print('⚠️ Cache write error: $e');
        }

        return result;
      } else if (response.statusCode == 429) {
        print('❌ API rate limit exceeded. Please try again later.');
        return [];
      } else {
        print('❌ API error: ${response.statusCode} - ${response.body}');
        return [];
      }
    } catch (e) {
      print('❌ Exception: $e');
      return [];
    }
  }

  /// សម្អាត Cache (ប្រើពេលត្រូវការ refresh)
  static Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((k) => k.startsWith('holidays_KH_'));
      for (final key in keys) {
        await prefs.remove(key);
      }
      print('✅ Holiday cache cleared');
    } catch (e) {
      print('⚠️ Cache clear error: $e');
    }
  }

  /// ✅ ទាញយកថ្ងៃឈប់សម្រាកដែលនៅសល់ក្នុងឆ្នាំនេះ (សម្រាប់បង្ហាញក្នុង UI)
  static Future<List<Map<String, dynamic>>> getUpcomingHolidays() async {
    final currentYear = DateTime.now().year;
    final holidays = await getCambodiaHolidays(currentYear);
    final now = DateTime.now();

    return holidays.where((h) {
      final iso = h['iso'] as String? ?? '';
      if (iso.isEmpty) return false;
      try {
        final date = DateTime.parse(iso);
        return date.isAfter(now) || date.isAtSameMomentAs(DateTime(now.year, now.month, now.day));
      } catch (e) {
        return false;
      }
    }).toList()
      ..sort((a, b) {
        final dateA = DateTime.tryParse(a['iso'] ?? '') ?? DateTime(2100);
        final dateB = DateTime.tryParse(b['iso'] ?? '') ?? DateTime(2100);
        return dateA.compareTo(dateB);
      });
  }

  /// ✅ ពិនិត្យថាតើថ្ងៃណាមួយជាថ្ងៃឈប់សម្រាកឬអត់
  static Future<bool> isHoliday(DateTime date) async {
    final holidays = await getCambodiaHolidays(date.year);
    final dateStr = '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return holidays.any((h) => h['iso'] == dateStr);
  }
}