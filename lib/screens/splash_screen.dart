// lib/screens/splash_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../models/user_model.dart';
import '../app_fonts.dart';

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
    } else if (user.isManager) {
      return '/manager-dashboard';
    } else {
      return '/dashboard'; // staff
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF173B69),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ✅ ប្រើ Image.asset ដូច Login Screen
              SizedBox(
                width: 200,
                height: 200,
                child: Image.asset(
                  'assets/img/logo.png',
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 50),
              const CircularProgressIndicator(
                color: Colors.white,
              ),
            ],
          ),
        ),
      ),
    );
  }
}