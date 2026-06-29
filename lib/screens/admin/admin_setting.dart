// lib/screens/admin/admin_settings.dart
import 'package:flutter/material.dart';
import 'user_management_screen.dart';
import 'policy_screen.dart';
import '../../app_fonts.dart'; // ✅ added


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
      appBar: AppBar(
        title: const Text(
          "Admin Settings",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            // optional: you could also set fontSize: AppFonts.md here
          ),
        ),
        centerTitle: true,
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // ============ USER MANAGEMENT CARD ============
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

              // ============ POLICY MANAGEMENT CARD ============
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

              const Spacer(),

              // ============ VERSION INFO ============
              Text(
                'Version 1.0.0',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: AppFonts.md, // was 12
                ),
              ),
            ],
          ),
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
                        fontSize: AppFonts.md, // was 16
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: AppFonts.md, // was 13
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