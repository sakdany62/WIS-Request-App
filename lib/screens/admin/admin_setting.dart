// lib/screens/admin/admin_settings_screen.dart
import 'package:flutter/material.dart';
import 'user_management_screen.dart';
import 'policy_screen.dart';
import 'warning_management_screen.dart';
import 'terms_management_screen.dart'; 
import '../../app_fonts.dart';
import '../../utils/responsive.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  final Color primaryColor = const Color(0xFF173B69);

  @override
  Widget build(BuildContext context) {
    final bool isMobile = Responsive.isMobile(context);
    final double fontSize = Responsive.fontSize(context, 14);
    final double spacing = Responsive.spacing(context);
    final EdgeInsets padding = Responsive.padding(context);
    final double iconSize = Responsive.iconSize(context, 28);

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
                horizontal: spacing,
              ),
              decoration: const BoxDecoration(
                color: Color(0xFF173B69),
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
                    size: isMobile ? 32 : 40,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Admin Settings",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: isMobile ? fontSize + 4 : fontSize + 6,
                    ),
                  ),
                ],
              ),
            ),

            // ---------- Settings content ----------
            Expanded(
              child: SingleChildScrollView(
                padding: padding,
                child: Column(
                  children: [
                    // User Management Card
                    _buildSettingsCard(
                      icon: Icons.people_alt,
                      title: 'User Management',
                      subtitle: 'Create, edit, and manage user accounts',
                      iconColor: Colors.blue,
                      isMobile: isMobile,
                      fontSize: fontSize,
                      spacing: spacing,
                      iconSize: iconSize,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const UserManagementScreen(),
                          ),
                        );
                      },
                    ),

                    SizedBox(height: spacing * 2),

                    // Policy Management Card
                    _buildSettingsCard(
                      icon: Icons.gavel,
                      title: 'Policy Management',
                      subtitle: 'Manage leave policies and rules',
                      iconColor: Colors.orange,
                      isMobile: isMobile,
                      fontSize: fontSize,
                      spacing: spacing,
                      iconSize: iconSize,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const PolicyScreen(),
                          ),
                        );
                      },
                    ),

                    SizedBox(height: spacing * 2),

                    // ✅ Terms & Conditions Management Card (NEW)
                    _buildSettingsCard(
                      icon: Icons.description,
                      title: 'Terms & Conditions',
                      subtitle: 'Create and manage terms & conditions versions',
                      iconColor: Colors.purple,
                      isMobile: isMobile,
                      fontSize: fontSize,
                      spacing: spacing,
                      iconSize: iconSize,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const TermsManagementScreen(),
                          ),
                        );
                      },
                    ),

                    SizedBox(height: spacing * 2),

                    // Warning Management Card
                    _buildSettingsCard(
                      icon: Icons.warning_amber_rounded,
                      title: 'Warning Management',
                      subtitle: 'Create and manage warning notifications for users',
                      iconColor: Colors.red,
                      isMobile: isMobile,
                      fontSize: fontSize,
                      spacing: spacing,
                      iconSize: iconSize,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const WarningManagementScreen(),
                          ),
                        );
                      },
                    ),

                    SizedBox(height: isMobile ? 60 : 80),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconColor,
    required VoidCallback onTap,
    required bool isMobile,
    required double fontSize,
    required double spacing,
    required double iconSize,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 12 : 16),
          child: Row(
            children: [
              // Icon Container
              Container(
                width: isMobile ? 48 : 56,
                height: isMobile ? 48 : 56,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(isMobile ? 12 : 14),
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: isMobile ? iconSize - 4 : iconSize,
                ),
              ),
              SizedBox(width: isMobile ? 12 : 16),
              
              // Title & Subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: isMobile ? fontSize : fontSize + 2,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: isMobile ? 2 : 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: isMobile ? fontSize * 0.8 : fontSize,
                        color: Colors.grey[600],
                      ),
                      maxLines: isMobile ? 2 : 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              
              // Arrow Icon
              Icon(
                Icons.arrow_forward_ios,
                size: isMobile ? 14 : 16,
                color: Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }
}