import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../models/user_model.dart';
import '../app_fonts.dart';
import '../utils/responsive.dart';
import '../services/notification_permission_service.dart'; // បន្ថែម

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // ស្នើសុំ notification permission
    await _requestNotificationPermission();
    
    // ពន្យាពេលសម្រាប់ splash animation
    await Future.delayed(const Duration(seconds: 2));
    
    if (!mounted) return;
    
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    // ដំឡើងកម្មវិធី - ពិនិត្យមើល user ដែលកំពុង login
    await authProvider.initializeApp();
    
    if (!mounted) return;
    
    // ចូលទៅកាន់ទំព័រសមស្រប
    _navigateToNextScreen();
  }

  // ស្នើសុំ notification permission
  Future<void> _requestNotificationPermission() async {
    try {
      final granted = await NotificationPermissionService.requestPermission();
      if (granted) {
        print(' Notification permission granted');
      } else {
        print(' Notification permission denied');
      }
    } catch (e) {
      print(' Error requesting notification permission: $e');
    }
  }

  void _navigateToNextScreen() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser;
    
    if (user != null) {
      Navigator.pushReplacementNamed(context, _getDashboardRoute(user));
    } else {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  String _getDashboardRoute(UserModel user) {
    if (user.isAdmin) {
      return '/admin-dashboard';
    } else if (user.isDirector) {
      return '/director-dashboard';
    } else if (user.isManager) {
      return '/manager-dashboard';
    } else if (user.isStaff) {
      return '/dashboard';
    } else {
      return '/dashboard';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = Responsive.isMobile(context);
    final double logoSize = isMobile ? 150 : 200;
    final double spacing = Responsive.spacing(context);

    return Scaffold(
      backgroundColor: const Color(0xFF173B69),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: logoSize,
                height: logoSize,
                child: Image.asset(
                  'assets/img/logo.png',
                  fit: BoxFit.contain,
                ),
              ),
              SizedBox(height: spacing * 3),
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                strokeWidth: 3,
              ),
              SizedBox(height: spacing * 2),
            ],
          ),
        ),
      ),
    );
  }
}