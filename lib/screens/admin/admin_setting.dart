// lib/screens/admin/admin_settings.dart
import 'package:flutter/material.dart';
import 'user_management_screen.dart';
import 'policy_screen.dart';
import '../../app_fonts.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  final Color primaryColor = const Color(0xFF173B69);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: SafeArea(
        child: Column(
          children: [
            // ---------- Custom header with icon under title ----------
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
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
                  const SizedBox(height: 8),
                  Icon(
                    Icons.settings,
                    color: Colors.white.withOpacity(0.9),
                    size: 40,
                  ),
                  const Text(
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

            // ---------- Settings content (scrollable) ----------
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // User Management Card
                    _buildSettingsCard(
                      icon: Icons.people_alt,
                      title: 'User Management',
                      subtitle: 'Create, edit, and manage user accounts',
                      iconColor: Colors.blue,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const UserManagementScreen(),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 16),

                    // Policy Management Card
                    _buildSettingsCard(
                      icon: Icons.gavel,
                      title: 'Policy Management',
                      subtitle: 'Manage leave policies and rules',
                      iconColor: Colors.orange,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const PolicyScreen(),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 40),

                    // Version info
                    Text(
                      'Version 1.0.0',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: AppFonts.md,
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


  Widget _buildSettingsCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: AppFonts.md,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: AppFonts.md,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
