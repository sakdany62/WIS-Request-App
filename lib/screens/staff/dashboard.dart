import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'staff_home_screen.dart';
import 'request_screen.dart';
import 'settings_screen.dart';
import '../admin/admin_dashboard.dart';
import '../manager/manager_dashboard.dart';
// 👇 Adjust import path to your AppFonts class
import 'package:permission_system/app_fonts.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  int _currentIndex = 0;
  late final List<Widget> _pages;
  String _userRole = 'staff';
  bool _isLoading = true;

  // Gradient matching your primary colour (same as admin/manager)
  static const LinearGradient _gradient = LinearGradient(
    colors: [Color(0xFF173B69), Color(0xFF2A5F8F)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  @override
  void initState() {
    super.initState();
    _checkUserRole();
  }

  Future<void> _checkUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    
    if (user != null) {
      try {
        final querySnapshot = await FirebaseFirestore.instance
            .collection('users')
            .where('userId', isEqualTo: user.uid)
            .limit(1)
            .get();
        
        if (querySnapshot.docs.isNotEmpty) {
          final data = querySnapshot.docs.first.data() as Map<String, dynamic>;
          final roleId = data['roleId']?.toString() ?? '2';
          
          print('🔍 User roleId: $roleId');
          
          String role = 'staff';
          if (roleId == '1') {
            role = 'admin';
          } else if (roleId == '3') {
            role = 'manager';
          } else if (roleId == '4') {
            role = 'director';
          }
          
          print('✅ Role determined: $role');
          
          if (mounted) {
            setState(() {
              _userRole = role;
              _isLoading = false;
            });
          }
        } else {
          if (mounted) {
            setState(() => _isLoading = false);
          }
        }
      } catch (e) {
        print('❌ Error checking user role: $e');
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    } else {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
    _initPages();
  }

  void _initPages() {
    _pages = [
      const StaffHomeScreen(),
      const RequestScreen(),
      const SettingsScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    print('🎯 Current role: $_userRole');

    if (_userRole == 'admin') {
      return const AdminDashboard();
    }

    if (_userRole == 'manager') {
      return const ManagerDashboard();
    }

    // Staff dashboard with modern floating bottom nav
    return Scaffold(
      extendBody: true, // lets the bottom nav float over the body
      body: _pages[_currentIndex],
      bottomNavigationBar: _buildModernBottomNavBar(),
    );
  }

  // --------------------------------------------------------------------------
  // Modern floating bottom navigation (same as AdminDashboard / ManagerDashboard)
  // --------------------------------------------------------------------------
  Widget _buildModernBottomNavBar() {
    return Container(
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Container(
          decoration: BoxDecoration(
            gradient: _gradient,
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(
                    0,
                    Icons.home_outlined,
                    Icons.home,
                    'Home',
                  ),
                  _buildNavItem(
                    1,
                    Icons.assignment_outlined,
                    Icons.assignment,
                    'Request',
                  ),
                  _buildNavItem(
                    2,
                    Icons.settings_outlined,
                    Icons.settings,
                    'Settings',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    IconData outlinedIcon,
    IconData filledIcon,
    String label,
  ) {
    final isSelected = _currentIndex == index;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (mounted) {
            setState(() => _currentIndex = index);
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color:
                isSelected ? Colors.white.withOpacity(0.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(25),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isSelected ? filledIcon : outlinedIcon,
                color: Colors.white,
                size: isSelected ? 26 : 22,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: AppFonts.md, // your existing font size constant
                  color: isSelected ? Colors.white : Colors.white70,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}