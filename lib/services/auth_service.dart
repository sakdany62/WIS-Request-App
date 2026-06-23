// lib/services/auth_service.dart
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Stream of auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Login with email and password
  Future<UserModel?> signInWithEmail(String email, String password) async {
    try {
      // សាកល្បង Connection មុន
      await _testConnection();
      
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      
      User? user = userCredential.user;
      if (user != null) {
        // ពិនិត្យមើលថាអ្នកប្រើមានក្នុង Firestore ដែរឬទេ
        DocumentSnapshot userDoc = await _firestore
            .collection('users')
            .doc(user.uid)
            .get();
        
        if (userDoc.exists) {
          return UserModel.fromFirestore(
            userDoc.data() as Map<String, dynamic>, 
            userDoc.id
          );
        } else {
          // ប្រសិនបើមិនមានក្នុង Firestore បង្កើតថ្មី
          debugPrint('⚠️ User exists in Auth but not in Firestore');
          return null;
        }
      }
      return null;
    } on FirebaseAuthException catch (e) {
      debugPrint('🔥 Firebase Auth Error: ${e.code} - ${e.message}');
      // បកប្រែ error message ឱ្យអ្នកប្រើយល់
      throw _handleAuthError(e);
    } catch (e) {
      debugPrint('❌ Login error: $e');
      rethrow;
    }
  }

  // Get current user with error handling
  Future<UserModel?> getCurrentUser() async {
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        DocumentSnapshot userDoc = await _firestore
            .collection('users')
            .doc(user.uid)
            .get();
        
        if (userDoc.exists) {
          return UserModel.fromFirestore(
            userDoc.data() as Map<String, dynamic>, 
            userDoc.id
          );
        } else {
          debugPrint('⚠️ User ${user.uid} not found in Firestore');
          // ប្រហែលជាត្រូវ logout អ្នកប្រើនេះ
          await signOut();
          return null;
        }
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error getting current user: $e');
      return null;
    }
  }

  // Logout with error handling
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      debugPrint('✅ User signed out successfully');
    } catch (e) {
      debugPrint('❌ Sign out error: $e');
      rethrow;
    }
  }

  // Send password reset email
  Future<bool> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      debugPrint('✅ Password reset email sent to $email');
      return true;
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ Password reset error: ${e.code}');
      return false;
    } catch (e) {
      debugPrint('❌ Unexpected error: $e');
      return false;
    }
  }

  // Check if email exists in Firebase Auth (better method)
  Future<bool> checkEmailExists(String email) async {
    try {
      // Use fetchSignInMethodsForEmail instead of sending reset email
      List<String> methods = await _auth.fetchSignInMethodsForEmail(email.trim());
      return methods.isNotEmpty;
    } catch (e) {
      debugPrint('❌ Check email error: $e');
      return false;
    }
  }

  // Test connection to Firebase
  Future<bool> _testConnection() async {
    try {
      // Try to access Firestore
      await _firestore.collection('users').limit(1).get();
      debugPrint('✅ Firebase connection successful');
      return true;
    } catch (e) {
      debugPrint('❌ Firebase connection failed: $e');
      throw Exception('No internet connection or Firebase unavailable');
    }
  }

  // Handle Firebase Auth errors
  String _handleAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found with this email.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'invalid-email':
        return 'Invalid email format.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      default:
        return 'Login failed. Please check your connection.';
    }
  }
}