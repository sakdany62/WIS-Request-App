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

    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          if (mounted) {
            setState(() => _currentIndex = index);
          }
        },
        selectedItemColor: const Color(0xFF173B69),
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        // ✅ Apply AppFonts.md to labels
        selectedLabelStyle: TextStyle(
          fontSize: AppFonts.md,
          fontWeight: FontWeight.w500,
        ),
        unselectedLabelStyle: TextStyle(
          fontSize: AppFonts.md,
          fontWeight: FontWeight.w400,
        ),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: "Home",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment_outlined),
            activeIcon: Icon(Icons.assignment),
            label: "Request",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: "Settings",
          ),
        ],
      ),
    );
  }
}