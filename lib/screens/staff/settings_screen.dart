// lib/screens/staff/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'package:provider/provider.dart';
import '../../app_fonts.dart';
import '../../providers/auth_provider.dart' as app_auth;
import '../../utils/responsive.dart';
import '../../services/terms_service.dart'; // ✅ Add this
import '../../services/warning_service.dart';
import '../../widgets/warning_popup.dart';
import 'warning_popup_settings_screen.dart';
import '../admin/warning_management_screen.dart'; 

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
    // ✅ Responsive
    final bool isMobile = Responsive.isMobile(context);
    final double fontSize = Responsive.fontSize(context, 14);
    final double spacing = Responsive.spacing(context);
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
                    color: Colors.white.withOpacity(0.9),
                    size: isMobile ? iconSize * 0.8 : iconSize,
                  ),
                  SizedBox(height: isMobile ? 4 : 8),
                  Text(
                    "Settings",
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
                    // ---------- Logout Button ----------
                    _buildLogoutItem(context, isMobile, fontSize),
                    SizedBox(height: spacing),
                    
                    // ---------- Other Settings Items ----------
                    ..._allItems.map(
                      (item) => _buildItem(
                        item.icon, 
                        item.title, 
                        context,
                        isMobile,
                        fontSize,
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
          'Logout',
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
          'Logout',
          style: TextStyle(
            fontSize: isMobile ? fontSize : AppFonts.md + 2,
          ),
        ),
        content: Text(
          'Are you sure you want to logout?',
          style: TextStyle(fontSize: isMobile ? fontSize : AppFonts.md),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
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
              'Logout',
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
            // ✅ Navigate to dynamic Terms & Conditions
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
                  builder: (context) => const WarningManagementScreen(),
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
                  '$title feature coming soon',
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
          'Telegram Notifications',
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
              'Telegram notifications are sent to the staff group when:',
              style: TextStyle(fontSize: isMobile ? fontSize : AppFonts.md),
            ),
            SizedBox(height: isMobile ? 8 : 12),
            _buildBulletPoint('New leave requests are submitted', isMobile, fontSize),
            _buildBulletPoint('Requests are approved or rejected', isMobile, fontSize),
            _buildBulletPoint('Auto-approval occurs', isMobile, fontSize),
            _buildBulletPoint('Manager approvals are needed', isMobile, fontSize),
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
                      'Notifications are sent automatically. No configuration needed.',
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
              'OK',
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
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadTerms();
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
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load terms: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
          _termsData != null 
              ? _termsData!['title'] ?? 'Terms & Conditions' 
              : 'Terms & Conditions',
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
                            'Retry',
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
                              'No terms & conditions available',
                              style: TextStyle(
                                fontSize: isMobile ? fontSize : AppFonts.md,
                                color: Colors.grey,
                              ),
                            ),
                            SizedBox(height: isMobile ? 8 : 12),
                            Text(
                              'Please check back later or contact admin.',
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
                          // Header
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(isMobile ? 12 : 16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E457E).withOpacity(0.05),
                              borderRadius: BorderRadius.circular(isMobile ? 10 : 12),
                              border: Border.all(
                                color: const Color(0xFF1E457E).withOpacity(0.1),
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.description,
                                  size: isMobile ? 36 : 48,
                                  color: const Color(0xFF1E457E),
                                ),
                                SizedBox(height: isMobile ? 4 : 8),
                                Text(
                                  _termsData!['title'] ?? 'Terms & Conditions',
                                  style: TextStyle(
                                    fontSize: isMobile ? fontSize + 4 : AppFonts.md + 4,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF1E457E),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                SizedBox(height: isMobile ? 4 : 8),
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
                                        color: Colors.blue.shade50,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        'Version: ${_termsData!['version'] ?? 'N/A'}',
                                        style: TextStyle(
                                          fontSize: isMobile ? fontSize * 0.85 : AppFonts.md,
                                          color: Colors.blue.shade700,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
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
                                        'Updated: ${_termsData!['lastUpdated'] ?? 'N/A'}',
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

                          // Sections
                          ...(_termsData!['sections'] as List<dynamic>).map((section) {
                            return _buildSection(
                              title: section['title'] ?? '',
                              content: section['content'] ?? '',
                              isMobile: isMobile,
                              fontSize: fontSize,
                            );
                          }).toList(),

                          SizedBox(height: isMobile ? 16 : 24),

                          // Agreement Button
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(isMobile ? 12 : 16),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(isMobile ? 10 : 12),
                              border: Border.all(
                                color: Colors.blue.shade200,
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  color: Colors.blue.shade700,
                                  size: isMobile ? 20 : 24,
                                ),
                                SizedBox(width: isMobile ? 8 : 12),
                                Expanded(
                                  child: Text(
                                    'By using this App, you agree to these Terms & Conditions.',
                                    style: TextStyle(
                                      fontSize: isMobile ? fontSize : AppFonts.md,
                                      color: Colors.blue.shade700,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          SizedBox(height: isMobile ? 24 : 32),

                          // Back to Settings Button
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
                                'Back to Settings',
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
              color: const Color(0xFF1E457E).withOpacity(0.3),
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
    // ✅ Responsive
    final bool isMobile = Responsive.isMobile(context);
    final double fontSize = Responsive.fontSize(context, 14);
    final double iconSize = Responsive.iconSize(context, 70);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E457E),
        elevation: 0,
        centerTitle: true,
        title: Text(
          'About Application',
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
            SizedBox(height: isMobile ? 24 : 40),
            Center(
              child: Container(
                padding: EdgeInsets.all(isMobile ? 16 : 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.school,
                  size: isMobile ? iconSize * 0.7 : iconSize,
                  color: const Color(0xFF1E457E),
                ),
              ),
            ),
            SizedBox(height: isMobile ? 12 : 16),
            Text(
              "Leave Request Mobile App",
              style: TextStyle(
                fontSize: isMobile ? fontSize + 2 : AppFonts.md,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1E457E),
              ),
            ),
            SizedBox(height: isMobile ? 4 : 6),
            Text(
              "Version 1.0.0",
              style: TextStyle(
                fontSize: isMobile ? fontSize * 0.85 : AppFonts.md,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: isMobile ? 20 : 30),
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
                        "Application Description",
                        style: TextStyle(
                          fontSize: isMobile ? fontSize + 2 : AppFonts.md,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1E457E),
                        ),
                      ),
                      SizedBox(height: isMobile ? 4 : 8),
                      Text(
                        "This mobile leave request application is designed to modernize and streamline the leave-taking workflow for staff at Westland International School.",
                        style: TextStyle(
                          fontSize: isMobile ? fontSize : AppFonts.md,
                          color: const Color(0xFF475569),
                          height: 1.5,
                        ),
                        textAlign: TextAlign.justify,
                      ),
                      Divider(height: isMobile ? 20 : 30, thickness: 0.5),
                      _buildInfoRow(
                        "Institution:", 
                        "Westland International School",
                        isMobile,
                        fontSize,
                      ),
                      SizedBox(height: isMobile ? 4 : 8),
                      _buildInfoRow(
                        "Academic Year:", 
                        "2025 - 2026",
                        isMobile,
                        fontSize,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(height: isMobile ? 24 : 40),
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