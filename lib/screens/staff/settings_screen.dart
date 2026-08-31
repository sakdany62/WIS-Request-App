// lib/screens/staff/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../app_fonts.dart';
import '../../providers/auth_provider.dart' as app_auth;
import '../../utils/responsive.dart';
import '../../services/terms_service.dart';
import '../../services/warning_service.dart';
import '../../services/language_service.dart';
import '../../widgets/warning_popup.dart';
import 'warning_popup_settings_screen.dart';
import '../admin/warning_management_screen.dart' as warning;
import '../admin/terms_read_tracking_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final Color primary = const Color(0xFF1A3B68);
  bool _isKhmer = false;

  final List<SettingsItem> _allItems = const [
    SettingsItem(
      icon: Icons.language,
      title: 'Language',
    ),
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
  void initState() {
    super.initState();
    _loadLanguage();
  }

  Future<void> _loadLanguage() async {
    final isKhmer = await LanguageService.isKhmer();
    if (mounted) {
      setState(() {
        _isKhmer = isKhmer;
      });
    }
  }

  Future<void> _toggleLanguage() async {
    final newLocale = _isKhmer ? Locale('en', 'US') : Locale('km', 'KH');
    final newLang = _isKhmer ? 'en' : 'km';
    
    await context.setLocale(newLocale);
    await LanguageService.setLanguage(newLang);
    
    setState(() {
      _isKhmer = !_isKhmer;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isKhmer ? 'បានប្តូរទៅជាភាសាខ្មែរ' : 'Switched to English',
          style: TextStyle(fontSize: Responsive.fontSize(context, 14)),
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    EasyLocalization.of(context);
    
    final bool isMobile = Responsive.isMobile(context);
    final double fontSize = Responsive.fontSize(context, 14);
    final double iconSize = Responsive.iconSize(context, 40);
    final EdgeInsets padding = Responsive.padding(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: SafeArea(
        child: Column(
          children: [
            // ---------- Custom header ----------
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                vertical: isMobile ? 14 : 20,
                horizontal: isMobile ? 12 : 24,
              ),
              decoration: const BoxDecoration(
                color: Color(0xFF1A3B68),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(height: isMobile ? 4 : 8),
                  Icon(
                    Icons.settings,
                    color: Colors.white.withValues(alpha: 0.9),
                    size: isMobile ? iconSize * 0.8 : iconSize,
                  ),
                  SizedBox(height: isMobile ? 4 : 8),
                  Text(
                    'settings'.tr(),
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: isMobile ? fontSize + 2 : fontSize + 6,
                    ),
                  ),
                ],
              ),
            ),

            // ---------- Settings List ----------
            Expanded(
              child: SingleChildScrollView(
                padding: padding,
                child: Column(
                  children: [
                    ..._allItems.map(
                      (item) => _buildItem(
                        item.icon,
                        item.title,
                        context,
                        isMobile,
                        fontSize,
                      ),
                    ),
                    _buildLogoutItem(context, isMobile, fontSize),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- Build Logout Item ----------
  Widget _buildLogoutItem(BuildContext context, bool isMobile, double fontSize) {
    return Card(
      margin: EdgeInsets.only(bottom: isMobile ? 6 : 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isMobile ? 10 : 12),
      ),
      color: Colors.white,
      child: ListTile(
        leading: const Icon(Icons.logout, color: Colors.red),
        title: Text(
          'logout'.tr(),
          style: TextStyle(
            fontSize: isMobile ? fontSize : AppFonts.md,
            color: Colors.red,
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: isMobile ? 14 : 16,
          color: Colors.grey,
        ),
        onTap: () {
          _showLogoutDialog(context, isMobile, fontSize);
        },
      ),
    );
  }

  // ---------- Show Logout Dialog ----------
  void _showLogoutDialog(BuildContext context, bool isMobile, double fontSize) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'logout'.tr(),
          style: TextStyle(
            fontSize: isMobile ? fontSize : AppFonts.md + 2,
          ),
        ),
        content: Text(
          'confirm_logout'.tr(),
          style: TextStyle(fontSize: isMobile ? fontSize : AppFonts.md),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'cancel'.tr(),
              style: TextStyle(fontSize: isMobile ? fontSize : AppFonts.md),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);

              final authProvider = Provider.of<app_auth.AuthProvider>(context, listen: false);
              await authProvider.signOut();

              if (mounted) {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/login',
                  (route) => false,
                );
              }
            },
            child: Text(
              'logout'.tr(),
              style: TextStyle(
                fontSize: isMobile ? fontSize : AppFonts.md,
                color: Colors.red,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------- Build Regular Item ----------
  Widget _buildItem(
    IconData icon,
    String title,
    BuildContext context,
    bool isMobile,
    double fontSize,
  ) {
    final isAdmin = _isUserAdmin();

    // ✅ Language Toggle Switch
    if (title == 'Language') {
      return Card(
        margin: EdgeInsets.only(bottom: isMobile ? 6 : 8),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(isMobile ? 10 : 12),
        ),
        color: Colors.white,
        child: SwitchListTile(
          contentPadding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
          secondary: Icon(
            Icons.language,
            color: primary,
            size: isMobile ? 24 : 28,
          ),
          title: Text(
            'language'.tr(),
            style: TextStyle(
              fontSize: isMobile ? fontSize : AppFonts.md,
              color: Colors.black,
              fontWeight: FontWeight.w500,
            ),
          ),
          subtitle: Text(
            _isKhmer ? 'ភាសាខ្មែរ' : 'English',
            style: TextStyle(
              fontSize: isMobile ? fontSize * 0.8 : AppFonts.md * 0.8,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          value: _isKhmer,
          onChanged: (_) => _toggleLanguage(),
          activeColor: const Color(0xFF173B69),
          activeTrackColor: const Color(0xFF173B69).withValues(alpha: 0.3),
          inactiveThumbColor: Colors.white,
          inactiveTrackColor: Colors.grey.shade300,
        ),
      );
    }

    return Card(
      margin: EdgeInsets.only(bottom: isMobile ? 6 : 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isMobile ? 10 : 12),
      ),
      color: Colors.white,
      child: ListTile(
        leading: Icon(
          icon,
          color: primary,
          size: isMobile ? 20 : 24,
        ),
        title: Text(
          title == 'Terms & Conditions' ? 'terms_conditions'.tr() :
          title == 'Telegram Notifications' ? 'telegram_notifications'.tr() :
          title == 'Warning Popup' ? 'warning_popup'.tr() :
          title == 'About App' ? 'about_app'.tr() :
          title,
          style: TextStyle(
            fontSize: isMobile ? fontSize : AppFonts.md,
            color: Colors.black,
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: isMobile ? 14 : 16,
          color: Colors.grey,
        ),
        onTap: () {
          if (title == 'About App') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AboutScreen(),
              ),
            );
          } else if (title == 'Terms & Conditions') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const TermsConditionsScreen(),
              ),
            );
          } else if (title == 'Warning Popup') {
            if (isAdmin) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => warning.WarningManagementScreen(),
                ),
              );
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const WarningPopupSettingsScreen(),
                ),
              );
            }
          } else if (title == 'Telegram Notifications') {
            _showTelegramSettings(context, isMobile, fontSize);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '${title.tr()} feature coming soon',
                  style: TextStyle(fontSize: isMobile ? fontSize : AppFonts.md),
                ),
                backgroundColor: Colors.grey[800],
              ),
            );
          }
        },
      ),
    );
  }

  // Check if current user is admin
  bool _isUserAdmin() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    return false;
  }

  // Show Telegram Notification Settings
  void _showTelegramSettings(BuildContext context, bool isMobile, double fontSize) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'telegram_notifications'.tr(),
          style: TextStyle(
            fontSize: isMobile ? fontSize + 2 : AppFonts.md + 2,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'telegram_notifications_description'.tr(),
              style: TextStyle(fontSize: isMobile ? fontSize : AppFonts.md),
            ),
            SizedBox(height: isMobile ? 8 : 12),
            _buildBulletPoint('telegram_notification_1'.tr(), isMobile, fontSize),
            _buildBulletPoint('telegram_notification_2'.tr(), isMobile, fontSize),
            _buildBulletPoint('telegram_notification_3'.tr(), isMobile, fontSize),
            _buildBulletPoint('telegram_notification_4'.tr(), isMobile, fontSize),
            SizedBox(height: isMobile ? 8 : 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue.shade700, size: isMobile ? 18 : 20),
                  SizedBox(width: isMobile ? 6 : 8),
                  Expanded(
                    child: Text(
                      'telegram_notifications_info'.tr(),
                      style: TextStyle(
                        fontSize: isMobile ? fontSize : AppFonts.md,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'ok'.tr(),
              style: TextStyle(fontSize: isMobile ? fontSize : AppFonts.md),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBulletPoint(String text, bool isMobile, double fontSize) {
    return Padding(
      padding: EdgeInsets.only(bottom: isMobile ? 4 : 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '• ',
            style: TextStyle(
              fontSize: isMobile ? fontSize : AppFonts.md,
              color: const Color(0xFF1A3B68),
              fontWeight: FontWeight.bold,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: isMobile ? fontSize : AppFonts.md),
            ),
          ),
        ],
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

// ===================== TERMS & CONDITIONS SCREEN (DYNAMIC FROM FIRESTORE) =====================
class TermsConditionsScreen extends StatefulWidget {
  const TermsConditionsScreen({super.key});

  @override
  State<TermsConditionsScreen> createState() => _TermsConditionsScreenState();
}

class _TermsConditionsScreenState extends State<TermsConditionsScreen> {
  Map<String, dynamic>? _termsData;
  bool _isLoading = true;
  bool _isMarkingRead = false;
  bool _hasRead = false;
  bool _isCheckboxChecked = false;
  String? _errorMessage;
  String? _staffId;

  @override
  void initState() {
    super.initState();
    _getCurrentUser();
    _loadTerms();
  }

  void _getCurrentUser() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _staffId = user.uid;
    }
  }

  Future<void> _loadTerms() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final terms = await TermsService.getCurrentTerms();
      setState(() {
        _termsData = terms;
        _isLoading = false;
      });

      if (terms != null && _staffId != null) {
        _checkIfRead(terms['id']);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load terms: $e';
      });
    }
  }

  Future<void> _checkIfRead(String termsId) async {
    try {
      final hasRead = await TermsService.hasStaffReadTerms(_staffId!, termsId);
      setState(() {
        _hasRead = hasRead;
        _isCheckboxChecked = hasRead;
      });
    } catch (e) {
      print('Error checking read status: $e');
    }
  }

  Future<void> _onCheckboxChanged(bool? value) async {
    if (value == null) return;

    if (_staffId == null || _termsData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please login to confirm reading'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_hasRead) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You have already confirmed reading. Cannot uncheck.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isCheckboxChecked = value;
    });

    if (value) {
      setState(() => _isMarkingRead = true);

      try {
        final termsId = _termsData!['id'];
        await TermsService.markTermsAsRead(_staffId!, termsId);

        setState(() {
          _hasRead = true;
          _isMarkingRead = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(' Thank you for confirming you have read the Terms & Conditions'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      } catch (e) {
        setState(() {
          _isCheckboxChecked = false;
          _isMarkingRead = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to confirm: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    EasyLocalization.of(context);
    
    final bool isMobile = Responsive.isMobile(context);
    final double fontSize = Responsive.fontSize(context, 14);
    final double spacing = Responsive.spacing(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E457E),
        elevation: 0,
        centerTitle: true,
        title: Text(
          _termsData != null ? _termsData!['title'] ?? 'terms_conditions'.tr() : 'terms_conditions'.tr(),
          style: TextStyle(
            fontSize: isMobile ? fontSize : AppFonts.md,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: Colors.white,
            size: isMobile ? 18 : 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadTerms,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF1E457E),
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: EdgeInsets.all(isMobile ? 16 : 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.red,
                        ),
                        SizedBox(height: isMobile ? 12 : 16),
                        Text(
                          _errorMessage!,
                          style: TextStyle(
                            fontSize: isMobile ? fontSize : AppFonts.md,
                            color: Colors.red,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: isMobile ? 16 : 24),
                        ElevatedButton.icon(
                          onPressed: _loadTerms,
                          icon: const Icon(Icons.refresh),
                          label: Text(
                            'retry'.tr(),
                            style: TextStyle(
                              fontSize: isMobile ? fontSize : AppFonts.md,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E457E),
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(
                              horizontal: isMobile ? 20 : 32,
                              vertical: isMobile ? 12 : 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : _termsData == null
                  ? Center(
                      child: Padding(
                        padding: EdgeInsets.all(isMobile ? 16 : 24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.description_outlined,
                              size: 64,
                              color: Colors.grey,
                            ),
                            SizedBox(height: isMobile ? 12 : 16),
                            Text(
                              'no_terms'.tr(),
                              style: TextStyle(
                                fontSize: isMobile ? fontSize : AppFonts.md,
                                color: Colors.grey,
                              ),
                            ),
                            SizedBox(height: isMobile ? 8 : 12),
                            Text(
                              'contact_admin'.tr(),
                              style: TextStyle(
                                fontSize: isMobile ? fontSize * 0.85 : AppFonts.md * 0.85,
                                color: Colors.grey.shade400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : SingleChildScrollView(
                      padding: EdgeInsets.all(isMobile ? 16 : 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(isMobile ? 12 : 16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E457E).withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(isMobile ? 10 : 12),
                              border: Border.all(
                                color: const Color(0xFF1E457E).withValues(alpha: 0.1),
                              ),
                            ),
                            child: Column(
                              children: [
                                Wrap(
                                  alignment: WrapAlignment.center,
                                  spacing: isMobile ? 8 : 16,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade50,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '${'updated'.tr()}: ${_termsData!['lastUpdated'] ?? 'N/A'}',
                                        style: TextStyle(
                                          fontSize: isMobile ? fontSize * 0.85 : AppFonts.md,
                                          color: Colors.green.shade700,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          SizedBox(height: isMobile ? 16 : 24),

                          ...(_termsData!['sections'] as List<dynamic>).map((section) {
                            return _buildSection(
                              title: section['title'] ?? '',
                              content: section['content'] ?? '',
                              isMobile: isMobile,
                              fontSize: fontSize,
                            );
                          }),

                          SizedBox(height: isMobile ? 24 : 32),

                          if (_staffId != null)
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.all(isMobile ? 12 : 16),
                              margin: EdgeInsets.only(bottom: spacing),
                              decoration: BoxDecoration(
                                color: _hasRead ? Colors.green.shade50 : Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(isMobile ? 10 : 12),
                                border: Border.all(
                                  color: _hasRead ? Colors.green.shade200 : Colors.orange.shade200,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  if (!_isMarkingRead)
                                    Checkbox(
                                      value: _isCheckboxChecked,
                                      onChanged: _onCheckboxChanged,
                                      activeColor: Colors.green,
                                      checkColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      side: BorderSide(
                                        color: _hasRead ? Colors.green : Colors.orange,
                                        width: 2,
                                      ),
                                    )
                                  else
                                    const SizedBox(
                                      height: 24,
                                      width: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Color(0xFF1E457E),
                                      ),
                                    ),
                                  SizedBox(width: spacing),
                                  Expanded(
                                    child: Text(
                                      _hasRead
                                          ? 'confirmed_read_terms'.tr()
                                          : 'please_confirm_read_terms'.tr(),
                                      style: TextStyle(
                                        fontSize: isMobile ? fontSize : AppFonts.md,
                                        color: _hasRead ? Colors.green.shade700 : Colors.orange.shade700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          SizedBox(
                            width: double.infinity,
                            height: Responsive.buttonHeight(context),
                            child: ElevatedButton(
                              onPressed: () => Navigator.pop(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1E457E),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(isMobile ? 10 : 12),
                                ),
                              ),
                              child: Text(
                                'back_to_settings'.tr(),
                                style: TextStyle(
                                  fontSize: isMobile ? fontSize : AppFonts.md,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),

                          SizedBox(height: isMobile ? 16 : 20),
                        ],
                      ),
                    ),
    );
  }

  Widget _buildSection({
    required String title,
    required String content,
    required bool isMobile,
    required double fontSize,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: isMobile ? 14 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: isMobile ? fontSize + 2 : AppFonts.md + 2,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1E457E),
            ),
          ),
          SizedBox(height: isMobile ? 4 : 8),
          Container(
            width: isMobile ? 30 : 40,
            height: 3,
            decoration: BoxDecoration(
              color: const Color(0xFF1E457E).withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(height: isMobile ? 8 : 12),
          Text(
            content,
            style: TextStyle(
              fontSize: isMobile ? fontSize : AppFonts.md,
              color: Colors.grey.shade700,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

// ===================== ABOUT SCREEN =====================
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    EasyLocalization.of(context);
    
    final bool isMobile = Responsive.isMobile(context);
    final double fontSize = Responsive.fontSize(context, 14);
    final double logoSize = isMobile ? 90 : 120;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E457E),
        elevation: 0,
        centerTitle: true,
        title: Text(
          'about_app'.tr(),
          style: TextStyle(
            fontSize: isMobile ? fontSize : AppFonts.md,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: Colors.white,
            size: isMobile ? 18 : 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(height: isMobile ? 20 : 32),

            Center(
              child: Container(
                width: logoSize,
                height: logoSize,
                decoration: BoxDecoration(
                  color: const Color(0xFF173B69),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                padding: EdgeInsets.all(isMobile ? 12 : 16),
                child: Image.asset(
                  'assets/img/logo.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),

            SizedBox(height: isMobile ? 10 : 14),

            Text(
              "app_name".tr(),
              style: TextStyle(
                fontSize: isMobile ? fontSize + 2 : AppFonts.md,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1E457E),
              ),
            ),
            SizedBox(height: isMobile ? 4 : 6),
            Text(
              "Version 1.2.0",
              style: TextStyle(
                fontSize: isMobile ? fontSize * 0.85 : AppFonts.md,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: isMobile ? 16 : 24),

            Padding(
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 20),
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(isMobile ? 12 : 15),
                ),
                elevation: 1,
                color: Colors.white,
                child: Padding(
                  padding: EdgeInsets.all(isMobile ? 12 : 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "about_description_title".tr(),
                        style: TextStyle(
                          fontSize: isMobile ? fontSize + 2 : AppFonts.md,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1E457E),
                        ),
                      ),
                      SizedBox(height: isMobile ? 4 : 8),
                      Text(
                        "about_description".tr(),
                        style: TextStyle(
                          fontSize: isMobile ? fontSize : AppFonts.md,
                          color: const Color(0xFF475569),
                          height: 1.5,
                        ),
                        textAlign: TextAlign.justify,
                      ),
                      Divider(height: isMobile ? 16 : 24, thickness: 0.5),
                      _buildInfoRow(
                        "institution".tr(),
                        "Westland International School",
                        isMobile,
                        fontSize,
                      ),
                      SizedBox(height: isMobile ? 4 : 8),
                      _buildInfoRow(
                        "academic_year".tr(),
                        "2025 - 2026",
                        isMobile,
                        fontSize,
                      ),
                      SizedBox(height: isMobile ? 4 : 8),
                      _buildInfoRow(
                        "developed_by".tr(),
                        "WIS IT Team",
                        isMobile,
                        fontSize,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            SizedBox(height: isMobile ? 20 : 32),

            Text(
              "© 2026 Westland International School. All Rights Reserved.",
              style: TextStyle(
                fontSize: isMobile ? fontSize * 0.85 : AppFonts.md,
                color: Colors.grey,
              ),
            ),
            SizedBox(height: isMobile ? 16 : 20),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, bool isMobile, double fontSize) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isMobile ? fontSize : AppFonts.md,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isMobile ? fontSize : AppFonts.md,
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}