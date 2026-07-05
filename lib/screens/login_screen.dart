import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart'; // <-- NEW
import '../../app_fonts.dart';

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
  bool rememberMe = false; // <-- NEW

  @override
  void initState() { // <-- NEW
    super.initState();
    _loadSavedCredentials();
  }

  // ---------- NEW: Load saved email ----------
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

  // ---------- NEW: Save or clear email ----------
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

  Future<void> _createUserDocumentIfNotExists(User user) async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('userId', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        String name =
            user.displayName ?? user.email?.split('@').first ?? 'User';

        String formattedName = name
            .split(' ')
            .map((word) => word.isNotEmpty
                ? word[0].toUpperCase() + word.substring(1).toLowerCase()
                : '')
            .join(' ');

        await FirebaseFirestore.instance.collection('users').add({
          'userId': user.uid,
          'email': user.email ?? '',
          'fullName': formattedName,
          'username': user.email?.split('@').first ?? 'user',
          'phone': '',
          'roleId': '2',
          'status': 'Active',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        print('✅ User document created for ${user.uid}');
      } else {
        print('✅ User document already exists for ${user.uid}');
      }
    } catch (e) {
      print('❌ Error creating user document: $e');
    }
  }

  Future<String> _getUserRole(String uid) async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('userId', isEqualTo: uid)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final data = querySnapshot.docs.first.data();
        final roleId = data['roleId']?.toString() ?? '2';
        print('✅ User role found: $roleId');
        return roleId;
      }
      return '2';
    } catch (e) {
      print('❌ Error getting user role: $e');
      return '2';
    }
  }

  Future<void> _login() async {
    String email = emailController.text.trim();
    String password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showSnackBar('Please fill all fields', Colors.orange);
      return;
    }

    setState(() => isLoading = true);

    try {
      UserCredential userCredential =
          await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = userCredential.user;
      if (user == null) {
        _showSnackBar('Login failed: User not found', Colors.red);
        setState(() => isLoading = false);
        return;
      }

      print('✅ User logged in: ${user.email}');
      print('✅ User UID: ${user.uid}');

      // ---------- NEW: Save credentials if Remember Me is checked ----------
      await _saveCredentials();

      await _createUserDocumentIfNotExists(user);

      String roleId = await _getUserRole(user.uid);
      print('✅ Role ID: $roleId');

      if (mounted) {
        if (roleId == '1') {
          print('🚀 Navigating to Admin Dashboard');
          Navigator.pushReplacementNamed(context, '/admin-dashboard');
        } else if (roleId == '3') {
          print('🚀 Navigating to Manager Dashboard');
          Navigator.pushReplacementNamed(context, '/manager-dashboard');
        } else if (roleId == '4') {
          print('🚀 Navigating to Director Dashboard');
          Navigator.pushReplacementNamed(context, '/admin-dashboard');
        } else {
          print('🚀 Navigating to Staff Dashboard');
          Navigator.pushReplacementNamed(context, '/dashboard');
        }
      }
    } on FirebaseAuthException catch (e) {
      String message;
      if (e.code == 'user-not-found') {
        message = 'No user found with this email';
      } else if (e.code == 'wrong-password') {
        message = 'Wrong password';
      } else if (e.code == 'invalid-email') {
        message = 'Invalid email format';
      } else if (e.code == 'too-many-requests') {
        message = 'Too many attempts. Please try again later';
      } else if (e.code == 'user-disabled') {
        message = 'This account has been disabled';
      } else {
        message = 'Login failed: ${e.message}';
      }
      _showSnackBar(message, Colors.red);
    } catch (e) {
      print('❌ Login error: $e');
      _showSnackBar('Error: $e', Colors.red);
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
              const SizedBox(height: 50),
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
              const SizedBox(height: 10),
              TextField(
                controller: passwordController,
                obscureText: obscurePassword,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _login(),
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

              // ---------- NEW: Remember Me + Forgot Password Row ----------
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
                          // If unchecked, clear saved email immediately
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
              // ---------- END NEW ----------

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