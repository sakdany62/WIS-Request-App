import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  User? _user;
  String? _userRole;
  bool _isLoading = false;

  User? get user => _user;
  String? get userRole => _userRole;
  bool get isLoading => _isLoading;

  AuthProvider() {
    _auth.authStateChanges().listen((User? user) {
      _user = user;
      if (user != null) {
        _loadUserRole(user.uid);
      } else {
        _userRole = null;
        notifyListeners();
      }
    });
  }

  Future<void> _loadUserRole(String userId) async {
    try {
      final doc = await _firestore
          .collection('users')
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();
      
      if (doc.docs.isNotEmpty) {
        final data = doc.docs.first.data();
        _userRole = data['roleId']?.toString() ?? '2';
      }
      notifyListeners();
    } catch (e) {
      print('Error loading user role: $e');
    }
  }

  Future<void> signIn(String email, String password) async {
    _isLoading = true;
    notifyListeners();
    
    try {
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    _userRole = null;
    notifyListeners();
  }

  bool get isManager {
    return _userRole == '1' || _userRole == '3';
  }

  bool get isStaff {
    return _userRole == '2';
  }
}