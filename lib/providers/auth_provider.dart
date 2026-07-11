import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  UserModel? _currentUser;
  bool _isLoading = false;
  bool _isInitialized = false;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  bool get isLoggedIn => _currentUser != null;

  // Getters សម្រាប់ពិនិត្យ role
  bool get isAdmin => _currentUser?.isAdmin ?? false;
  bool get isManager => _currentUser?.isManager ?? false;
  bool get isStaff => _currentUser?.isStaff ?? false;
  bool get isHead => _currentUser?.isHead ?? false;
  String? get userRole => _currentUser?.roleId;

  AuthProvider() {
    _auth.authStateChanges().listen((User? user) async {
      if (user != null) {
        await _loadUserFromFirestore(user.uid);
      } else {
        _currentUser = null;
        _isInitialized = true;
        notifyListeners();
      }
    });
  }

  Future<void> initializeApp() async {
    if (_isInitialized) return;
    
    _isLoading = true;
    notifyListeners();

    try {
      User? firebaseUser = _auth.currentUser;
      if (firebaseUser != null) {
        await _loadUserFromFirestore(firebaseUser.uid);
      }
    } catch (e) {
      print('❌ Error initializing app: $e');
    } finally {
      _isLoading = false;
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<void> _loadUserFromFirestore(String userId) async {
    try {
      print('🔄 Loading user data for: $userId');
      
      final QuerySnapshot query = await _firestore
          .collection('users')
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();
      
      if (query.docs.isNotEmpty) {
        final doc = query.docs.first;
        _currentUser = UserModel.fromFirestore(
          doc.data() as Map<String, dynamic>,
          doc.id,
        );
        print('✅ User loaded: ${_currentUser?.fullName}, Role: ${_currentUser?.roleId}');
      } else {
        print('⚠️ User document not found in Firestore');
        await _auth.signOut();
        _currentUser = null;
      }
    } catch (e) {
      print('❌ Error loading user: $e');
      _currentUser = null;
    }
    notifyListeners();
  }

  Future<bool> signIn(String email, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      if (userCredential.user != null) {
        await _loadUserFromFirestore(userCredential.user!.uid);
        _isLoading = false;
        notifyListeners();
        return _currentUser != null;
      }
      return false;
    } catch (e) {
      print('❌ Login error: $e');
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
      _currentUser = null;
      _isInitialized = false;
      notifyListeners();
      print('✅ User signed out successfully');
    } catch (e) {
      print('❌ Sign out error: $e');
    }
  }

  Future<void> refreshUser() async {
    if (_currentUser != null) {
      await _loadUserFromFirestore(_currentUser!.userId);
    }
  }

  void updateUser(UserModel user) {
    _currentUser = user;
    notifyListeners();
  }
}