// lib/screens/splash_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../models/user_model.dart';
import '../app_fonts.dart';
import '../utils/responsive.dart';

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

  void _navigateToNextScreen() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser;
    
    if (user != null) {
      // លុប splash screen ចេញពីប្រវត្តិ
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
      // Default to staff dashboard if role is unknown
      return '/dashboard';
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get responsive values
    final bool isMobile = Responsive.isMobile(context);
    final double logoSize = isMobile ? 150 : 200;
    final double spacing = Responsive.spacing(context);
    
    // ✅ Use AppFonts.md for both texts (since that's the only one available)
    // Or use Responsive.fontSize with a number directly
    final double mainFontSize = Responsive.fontSize(context, AppFonts.md);
    final double smallFontSize = Responsive.fontSize(context, 12); // Use number directly

    return Scaffold(
      backgroundColor: const Color(0xFF173B69),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo - Responsive size
              SizedBox(
                width: logoSize,
                height: logoSize,
                child: Image.asset(
                  'assets/img/logo.png',
                  fit: BoxFit.contain,
                ),
              ),
              SizedBox(height: spacing * 3),
              
              // Loading indicator
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                strokeWidth: 3,
              ),
              
              SizedBox(height: spacing * 2),
              
              // App name - Responsive font
              Text(
                'Westland Permission System',
                style: TextStyle(
                  fontSize: mainFontSize,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: spacing),
              
              // Loading text - Responsive font
              Text(
                'Loading...',
                style: TextStyle(
                  fontSize: smallFontSize, // Now using 12 instead of AppFonts.sm
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}