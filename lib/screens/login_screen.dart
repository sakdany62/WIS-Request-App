import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/auth_provider.dart';
import '../app_fonts.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool isLoading = false;
  bool obscurePassword = true;
  bool rememberMe = false;
  String _errorMessage = ''; // ✅ បន្ថែមសម្រាប់ទុកសារកំហុស

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString('remember_email') ?? '';
      final remember = prefs.getBool('remember_me') ?? false;
      
      if (mounted) {
        setState(() {
          emailController.text = email;
          rememberMe = remember;
        });
      }
    } catch (e) {
      print('❌ Error loading saved credentials: $e');
    }
  }

  // ✅ រក្សាទុក Admin Credentials (សម្រាប់ Auto Re-login)
  Future<void> _saveAdminCredentials(String email, String password, String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('admin_email', email);
      await prefs.setString('admin_password', password);
      await prefs.setString('admin_uid', uid);
      print(' Admin credentials saved successfully');
    } catch (e) {
      print('❌ Error saving admin credentials: $e');
    }
  }

  Future<void> _saveCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (rememberMe) {
        await prefs.setString('remember_email', emailController.text.trim());
        await prefs.setBool('remember_me', true);
      } else {
        await prefs.remove('remember_email');
        await prefs.setBool('remember_me', false);
      }
    } catch (e) {
      print('❌ Error saving credentials: $e');
    }
  }

  Future<void> _login() async {
    // ✅ លុបសារកំហុសចាស់
    setState(() {
      _errorMessage = '';
    });

    String email = emailController.text.trim();
    String password = passwordController.text.trim();

    // ✅ ពិនិត្យមើលថាមានបំពេញទាំងអស់ឬទេ
    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = 'Please fill all fields';
      });
      return;
    }

    setState(() => isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      bool success = await authProvider.signIn(email, password);

      if (success && mounted) {
        await _saveCredentials();

        final user = authProvider.currentUser;
        if (user != null) {
          // ✅ ប្រសិនបើជា Admin រក្សាទុក Admin Credentials
          if (user.isAdmin) {
            await _saveAdminCredentials(email, password, user.userId);
            print(' Admin credentials saved!');
          }

          String route;
          if (user.isAdmin) {
            route = '/admin-dashboard';
          } else if (user.isManager) {
            route = '/manager-dashboard';
          } else {
            route = '/dashboard';
          }
          
          Navigator.pushNamedAndRemoveUntil(
            context,
            route,
            (route) => false,
          );
        }
      } else {
        // ✅ បង្ហាញសារកំហុសពី AuthProvider
        final error = authProvider.errorMessage ?? 'Invalid email or password';
        setState(() {
          _errorMessage = error;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Login failed: ${e.toString()}';
      });
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(fontSize: AppFonts.md)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _navigateToForgotPassword() {
    Navigator.pushNamed(context, '/forgot-password');
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF173B69),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),

              // ✅ បង្ហាញសារកំហុសនៅផ្នែកខាងលើ
              if (_errorMessage.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade300),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: Colors.red.shade700,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _errorMessage,
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontSize: AppFonts.md,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _errorMessage = '';
                          });
                        },
                        child: Icon(
                          Icons.close,
                          color: Colors.red.shade400,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 30),
              Center(
                child: Column(
                  children: [
                    SizedBox(
                      width: 200,
                      height: 200,
                      child: Image.asset(
                        'assets/img/logo.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 2),
                  ],
                ),
              ),
              const SizedBox(height: 50),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Welcome Back to WIS",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Roboto',
                  ),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                style: TextStyle(fontSize: AppFonts.md),
                onChanged: (_) {
                  // ✅ លុបសារកំហុសពេលអ្នកប្រើកំពុងវាយ
                  if (_errorMessage.isNotEmpty) {
                    setState(() {
                      _errorMessage = '';
                    });
                  }
                },
                decoration: InputDecoration(
                  hintText: "Enter email",
                  hintStyle: TextStyle(fontSize: AppFonts.md),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(50),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              TextField(
                controller: passwordController,
                obscureText: obscurePassword,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _login(),
                onChanged: (_) {
                  // ✅ លុបសារកំហុសពេលអ្នកប្រើកំពុងវាយ
                  if (_errorMessage.isNotEmpty) {
                    setState(() {
                      _errorMessage = '';
                    });
                  }
                },
                style: TextStyle(fontSize: AppFonts.md),
                decoration: InputDecoration(
                  hintText: "Enter password",
                  hintStyle: TextStyle(fontSize: AppFonts.md),
                  filled: true,
                  fillColor: Colors.white,
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscurePassword ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () =>
                        setState(() => obscurePassword = !obscurePassword),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(50),
                  ),
                ),
              ),
              const SizedBox(height: 15),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Checkbox(
                        value: rememberMe,
                        onChanged: (bool? value) {
                          setState(() {
                            rememberMe = value ?? false;
                          });
                          if (!rememberMe) {
                            _saveCredentials();
                          }
                        },
                        activeColor: Colors.white,
                        checkColor: const Color(0xFF173B69),
                        side: const BorderSide(color: Colors.white),
                      ),
                      const Text(
                        "Remember Me",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: _navigateToForgotPassword,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white70,
                    ),
                    child: const Text(
                      "Forgot Password?",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Roboto',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 58,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF173B69),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(50),
                    ),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF173B69),
                          ),
                        )
                      : const Text(
                          "Login",
                          style: TextStyle(
                            color: Color(0xFF173B69),
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Roboto',
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}