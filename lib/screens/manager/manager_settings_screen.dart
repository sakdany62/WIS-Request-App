// lib/screens/manager/manager_settings_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../app_fonts.dart';
import '../../providers/auth_provider.dart' as app_auth;
import '../../utils/responsive.dart';
import '../../services/terms_service.dart';
import '../../services/warning_service.dart';
import '../staff/warning_popup_settings_screen.dart';
// ✅ ប្តូរ import ទៅកន្លែងដែលត្រឹមត្រូវ
import '../staff/settings_screen.dart'; // ព្រោះ AboutScreen និង TermsConditionsScreen នៅក្នុង settings_screen.dart
import '../staff/dashboard.dart' as staff;

class ManagerSettingsScreen extends StatefulWidget {
  const ManagerSettingsScreen({super.key});

  @override
  State<ManagerSettingsScreen> createState() => _ManagerSettingsScreenState();
}

class _ManagerSettingsScreenState extends State<ManagerSettingsScreen> {
  final Color primary = const Color(0xFF1A3B68);
  bool _isViewingAsStaff = false;

  final List<SettingsItem> _managerItems = const [
    SettingsItem(
      icon: Icons.visibility_outlined,
      title: 'View as Staff',
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
    _checkViewMode();
  }

  Future<void> _checkViewMode() async {
    final prefs = await SharedPreferences.getInstance();
    final isViewing = prefs.getBool('view_as_staff') ?? false;
    if (mounted) {
      setState(() {
        _isViewingAsStaff = isViewing;
      });
    }
  }

  Future<void> _toggleViewMode() async {
    final prefs = await SharedPreferences.getInstance();
    
    if (_isViewingAsStaff) {
      // ✅ ត្រឡប់ទៅមើលជា Manager វិញ
      await prefs.setBool('view_as_staff', false);
      if (mounted) {
        setState(() {
          _isViewingAsStaff = false;
        });
      }
      
      // ✅ ត្រឡប់ទៅ Manager Dashboard
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/manager-dashboard');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Returned to Manager view'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } else {
      // ✅ ប្តូរទៅមើលជា Staff
      await prefs.setBool('view_as_staff', true);
      if (mounted) {
        setState(() {
          _isViewingAsStaff = true;
        });
      }
      
      // ✅ ទៅកាន់ Staff Dashboard
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/staff-dashboard');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Viewing as Staff (You can still approve/reject requests)'),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Responsive
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
                    _isViewingAsStaff ? "Settings (Viewing as Staff)" : "Manager Settings",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: isMobile ? fontSize + 2 : fontSize + 6,
                    ),
                  ),
                ],
              ),
            ),

            // ---------- View Mode Indicator ----------
            if (_isViewingAsStaff)
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                color: Colors.orange.shade100,
                child: Row(
                  children: [
                    Icon(Icons.visibility, color: Colors.orange.shade700, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'You are viewing as Staff. You can still approve/reject requests.',
                        style: TextStyle(
                          fontSize: isMobile ? fontSize * 0.85 : AppFonts.md * 0.85,
                          color: Colors.orange.shade700,
                        ),
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
                    ..._managerItems.map(
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
              
              // ✅ លុប view_as_staff mode ពេល logout
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('view_as_staff');
              
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
    // ✅ ប្រសិនបើជា "View as Staff"
    if (title == 'View as Staff') {
      return Card(
        margin: EdgeInsets.only(bottom: isMobile ? 6 : 8),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(isMobile ? 10 : 12),
        ),
        color: _isViewingAsStaff ? Colors.orange.shade50 : Colors.white,
        child: ListTile(
          leading: Icon(
            _isViewingAsStaff ? Icons.visibility_off : Icons.visibility_outlined,
            color: _isViewingAsStaff ? Colors.orange : primary,
            size: isMobile ? 20 : 24,
          ),
          title: Text(
            _isViewingAsStaff ? 'Return to Manager View' : 'View as Staff',
            style: TextStyle(
              fontSize: isMobile ? fontSize : AppFonts.md,
              color: _isViewingAsStaff ? Colors.orange.shade700 : Colors.black,
              fontWeight: _isViewingAsStaff ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          trailing: Switch(
            value: _isViewingAsStaff,
            onChanged: (_) => _toggleViewMode(),
            activeColor: Colors.orange,
            activeTrackColor: Colors.orange.shade200,
          ),
          onTap: _toggleViewMode,
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
            // ✅ ប្រើ AboutScreen ពី settings_screen.dart
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AboutScreen(),
              ),
            );
          } else if (title == 'Terms & Conditions') {
            // ✅ ប្រើ TermsConditionsScreen ពី settings_screen.dart
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const TermsConditionsScreen(),
              ),
            );
          } else if (title == 'Warning Popup') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const WarningPopupSettingsScreen(),
              ),
            );
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