import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
// 👇 Adjust the import path to your AppFonts class
import 'package:permission_system/app_fonts.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController emailController = TextEditingController();
  bool isLoading = false;
  bool isEmailSent = false;

  Future<void> _sendResetEmail() async {
    String email = emailController.text.trim();

    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please enter your email',
            style: TextStyle(fontSize: AppFonts.md),
          ),
        ),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      setState(() {
        isEmailSent = true;
        isLoading = false;
      });
    } on FirebaseAuthException catch (e) {
      String message;
      if (e.code == 'user-not-found') {
        message = 'No account found with this email';
      } else if (e.code == 'invalid-email') {
        message = 'Invalid email format';
      } else {
        message = 'Error: ${e.message}';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: TextStyle(fontSize: AppFonts.md),
          ),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => isLoading = false);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error: $e',
            style: TextStyle(fontSize: AppFonts.md),
          ),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF173B69),
      appBar: AppBar(
        title: Text(
          'Forgot Password',
          style: TextStyle(
            fontSize: AppFonts.md,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF173B69),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: isEmailSent ? _buildSuccessView() : _buildResetForm(),
      ),
    );
  }

  Widget _buildResetForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 40),
        const Center(
          child: Icon(Icons.lock_reset, size: 80, color: Colors.white),
        ),
        const SizedBox(height: 40),
        Text(
          'Reset Password',
          style: TextStyle(
            fontSize: AppFonts.md,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Enter your email to receive a password reset link',
          style: TextStyle(
            fontSize: AppFonts.md,
            color: Colors.white70,
          ),
        ),
        const SizedBox(height: 30),
        TextField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          style: TextStyle(fontSize: AppFonts.md),
          decoration: InputDecoration(
            hintText: 'Enter your email',
            hintStyle: TextStyle(fontSize: AppFonts.md),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 30),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: isLoading ? null : _sendResetEmail,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF173B69),
            ),
            child: isLoading
                ? const CircularProgressIndicator()
                : Text(
                    'Send Reset Link',
                    style: TextStyle(fontSize: AppFonts.md),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 60),
        const Icon(Icons.check_circle, size: 100, color: Colors.green),
        const SizedBox(height: 30),
        Text(
          'Email Sent!',
          style: TextStyle(
            fontSize: AppFonts.md,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'We have sent a password reset link to\n${emailController.text.trim()}',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: AppFonts.md,
            color: Colors.white70,
          ),
        ),
        const SizedBox(height: 40),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF173B69),
            ),
            child: Text(
              'Back to Login',
              style: TextStyle(fontSize: AppFonts.md),
            ),
          ),
        ),
      ],
    );
  }
}