import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../models/user_model.dart';
import '../app_fonts.dart';
import '../utils/responsive.dart';
import '../services/notification_permission_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String? _errorMessage;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      // ✅ ស្នើសុំ notification permission
      await _requestNotificationPermission();
      
      // ✅ ពន្យាពេលសម្រាប់ splash animation
      await Future.delayed(const Duration(seconds: 2));
      
      if (!mounted) return;
      
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      // ✅ ដំឡើងកម្មវិធី - ពិនិត្យមើល user ដែលកំពុង login
      await authProvider.initializeApp();
      
      if (!mounted) return;
      
      // ✅ ចូលទៅកាន់ទំព័រសមស្រប
      _navigateToNextScreen();
    } catch (e, stackTrace) {
      print('❌ Error in SplashScreen: $e');
      print('📚 Stack trace: $stackTrace');
      
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _requestNotificationPermission() async {
    try {
      final granted = await NotificationPermissionService.requestPermission();
      if (granted) {
        print('✅ Notification permission granted');
      } else {
        print('⚠️ Notification permission denied');
      }
    } catch (e) {
      print('❌ Error requesting notification permission: $e');
    }
  }

  void _navigateToNextScreen() {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.currentUser;
      
      if (user != null) {
        Navigator.pushReplacementNamed(context, _getDashboardRoute(user));
      } else {
        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      print('❌ Navigation error: $e');
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  String _getDashboardRoute(UserModel user) {
    try {
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
    } catch (e) {
      print('❌ Role detection error: $e');
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
              // ✅ Logo
              SizedBox(
                width: logoSize,
                height: logoSize,
                child: Image.asset(
                  'assets/img/logo.png',
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    print('❌ Logo image error: $error');
                    return Container(
                      width: logoSize,
                      height: logoSize,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.error_outline,
                        color: Colors.white,
                        size: 60,
                      ),
                    );
                  },
                ),
              ),
              SizedBox(height: spacing * 3),
              
              // ✅ Loading or Error
              if (_errorMessage != null)
                Column(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: Colors.red.shade300,
                      size: 40,
                    ),
                    SizedBox(height: spacing),
                    Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: spacing),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _errorMessage = null;
                          _isLoading = true;
                        });
                        _initializeApp();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF173B69),
                      ),
                      child: const Text('Retry'),
                    ),
                  ],
                )
              else
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