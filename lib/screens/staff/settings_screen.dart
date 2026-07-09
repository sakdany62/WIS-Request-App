import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../app_fonts.dart';
import '../../providers/theme_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final Color primary = const Color(0xFF1A3B68);

  final List<SettingsItem> _allItems = const [
    SettingsItem(
      icon: Icons.description,
      title: 'Terms & Conditions',
    ),
    SettingsItem(
      icon: Icons.telegram,
      title: 'Telegram Notifications',
    ),
    SettingsItem(
      icon: Icons.warning_amber_rounded,
      title: 'Warning Popup',
    ),
    SettingsItem(
      icon: Icons.info_outline,
      title: 'About App',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    final bgColor = isDarkMode ? Colors.grey[900] : const Color(0xFFF7F8FA);
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final cardColor = isDarkMode ? Colors.grey[850] : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            // ---------- Custom header ----------
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
              decoration: BoxDecoration(
                color: primary,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 8),
                  Icon(
                    Icons.settings,
                    color: Colors.white.withOpacity(0.9),
                    size: 40,
                  ),
                  Text(
                    "Settings",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: AppFonts.md,
                    ),
                  ),
                ],
              ),
            ),

            // ---------- Settings List ----------
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // ---------- Dark Mode Toggle ----------
                    _buildToggleItem(
                      icon: Icons.dark_mode,
                      title: 'Dark Mode',
                      value: isDarkMode,
                      onChanged: (value) {
                        themeProvider.setDarkMode(value);
                      },
                      isDarkMode: isDarkMode,
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // ---------- Other Settings Items ----------
                    ..._allItems.map(
                      (item) => _buildItem(
                        item.icon, 
                        item.title, 
                        context,
                        isDarkMode: isDarkMode,
                        cardColor: cardColor!,
                        textColor: textColor!,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- Build Toggle Item ----------
  Widget _buildToggleItem({
    required IconData icon,
    required String title,
    required bool value,
    required Function(bool) onChanged,
    required bool isDarkMode,
  }) {
    final cardColor = isDarkMode ? Colors.grey[850] : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: cardColor,
      child: ListTile(
        leading: Icon(icon, color: primary),
        title: Text(
          title,
          style: TextStyle(
            fontSize: AppFonts.md,
            color: textColor,
          ),
        ),
        trailing: Switch(
          value: value,
          onChanged: onChanged,
          activeColor: primary,
          activeTrackColor: primary.withOpacity(0.3),
        ),
        onTap: () {
          onChanged(!value);
        },
      ),
    );
  }

  // ---------- Build Regular Item ----------
  Widget _buildItem(
    IconData icon, 
    String title, 
    BuildContext context, {
    required bool isDarkMode,
    required Color cardColor,
    required Color textColor,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: cardColor,
      child: ListTile(
        leading: Icon(icon, color: primary),
        title: Text(
          title,
          style: TextStyle(
            fontSize: AppFonts.md,
            color: textColor,
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: isDarkMode ? Colors.grey[400] : Colors.grey,
        ),
        onTap: () {
          if (title == 'About App') {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AboutScreen()),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '$title feature coming soon',
                  style: TextStyle(fontSize: AppFonts.md),
                ),
                backgroundColor: isDarkMode ? Colors.grey[800] : null,
              ),
            );
          }
        },
      ),
    );
  }
}

// ---------- SettingsItem ----------
class SettingsItem {
  final IconData icon;
  final String title;

  const SettingsItem({
    required this.icon,
    required this.title,
  });
}

// ===================== ABOUT SCREEN WITH DARK MODE =====================
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    final bgColor = isDarkMode ? Colors.grey[900] : const Color(0xFFF8FAFC);
    final cardColor = isDarkMode ? Colors.grey[850] : Colors.white;
    final textColor = isDarkMode ? Colors.white : const Color(0xFF475569);
    final labelColor = isDarkMode ? Colors.grey[400]! : Colors.grey;
    final valueColor = isDarkMode ? Colors.white : Colors.black87;
    
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E457E),
        elevation: 0,
        centerTitle: true,
        title: Text(
          'About Application',
          style: TextStyle(
            fontSize: AppFonts.md,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 40),
            Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cardColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4)),
                  ],
                ),
                child: const Icon(Icons.school,
                    size: 70, color: Color(0xFF1E457E)),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "Leave Request Mobile App",
              style: TextStyle(
                fontSize: AppFonts.md,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1E457E),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "Version 1.0.0",
              style: TextStyle(
                fontSize: AppFonts.md,
                color: isDarkMode ? Colors.grey[400] : Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 30),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Card(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15)),
                elevation: 1,
                color: cardColor,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Application Description",
                        style: TextStyle(
                          fontSize: AppFonts.md,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1E457E),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "This mobile leave request application is designed to modernize and streamline the leave-taking workflow for staff at Westland International School.",
                        style: TextStyle(
                          fontSize: AppFonts.md,
                          color: textColor,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.justify,
                      ),
                      const Divider(height: 30, thickness: 0.5),
                      _buildInfoRow(
                          "Institution:", 
                          "Westland International School",
                          labelColor,
                          valueColor!,
                      ),
                      const SizedBox(height: 8),
                      _buildInfoRow(
                          "Academic Year:", 
                          "2025 - 2026",
                          labelColor,
                          valueColor!,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
            Text(
              "© 2026 Westland International School. All Rights Reserved.",
              style: TextStyle(
                fontSize: AppFonts.md,
                color: isDarkMode ? Colors.grey[500] : Colors.grey,
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, Color labelColor, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: AppFonts.md,
            color: labelColor,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: AppFonts.md,
            color: valueColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}