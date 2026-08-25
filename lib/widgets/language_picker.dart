// lib/widgets/language_picker.dart
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:permission_system/services/language_service.dart';

class LanguagePicker extends StatelessWidget {
  final bool isMobile;
  final double fontSize;

  const LanguagePicker({
    super.key,
    required this.isMobile,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'language'.tr(),
              style: TextStyle(
                fontSize: fontSize + 2,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1A3B68),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.language, color: Color(0xFF1A3B68)),
            title: Text(
              'english'.tr(),
              style: TextStyle(fontSize: fontSize),
            ),
            trailing: context.locale.languageCode == 'en'
                ? const Icon(Icons.check_circle, color: Colors.green)
                : null,
            onTap: () async {
              await context.setLocale(const Locale('en', 'US'));
              await LanguageService.setLanguage('en');
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Language changed to English'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.language, color: Color(0xFF1A3B68)),
            title: Text(
              'khmer'.tr(),
              style: TextStyle(fontSize: fontSize),
            ),
            trailing: context.locale.languageCode == 'km'
                ? const Icon(Icons.check_circle, color: Colors.green)
                : null,
            onTap: () async {
              await context.setLocale(const Locale('km', 'KH'));
              await LanguageService.setLanguage('km');
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('បានប្តូរភាសាទៅជាភាសាខ្មែរ'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}