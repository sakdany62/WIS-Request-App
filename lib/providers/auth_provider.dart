// lib/providers/auth_provider.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  UserModel? _currentUser;
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _errorMessage;

  // ============================================================
  // GETTERS
  // ============================================================
  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  bool get isLoggedIn => _currentUser != null;
  String? get errorMessage => _errorMessage;

  bool get isAdmin => _currentUser?.isAdmin ?? false;
  bool get isManager => _currentUser?.isManager ?? false;
  bool get isStaff => _currentUser?.isStaff ?? false;
  bool get isHead => _currentUser?.isHead ?? false;
  bool get isDirector => _currentUser?.isDirector ?? false;
  String? get userRole => _currentUser?.roleId;
  String? get userFullName => _currentUser?.fullName;
  String? get userEmail => _currentUser?.email;

  // ============================================================
  // CONSTRUCTOR
  // ============================================================
  AuthProvider() {
    _auth.authStateChanges().listen((User? user) async {
      if (user != null) {
        await _loadUserFromFirestore(user.uid);
      } else {
        _currentUser = null;
        _isInitialized = true;
        _errorMessage = null;
        notifyListeners();
      }
    });
  }

  // ============================================================
  // INITIALIZE APP
  // ============================================================
  Future<void> initializeApp() async {
    if (_isInitialized) return;
    
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      User? firebaseUser = _auth.currentUser;
      if (firebaseUser != null) {
        await _loadUserFromFirestore(firebaseUser.uid);
      } else {
        _isInitialized = true;
      }
    } catch (e) {
      print('❌ Error initializing app: $e');
      _errorMessage = 'Failed to initialize app: $e';
    } finally {
      _isLoading = false;
      _isInitialized = true;
      notifyListeners();
    }
  }

  // ============================================================
  // LOAD USER FROM FIRESTORE
  // ============================================================
  Future<void> _loadUserFromFirestore(String userId) async {
    try {
      print('🔄 Loading user data for: $userId');
      
      final docSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .get();
      
      if (docSnapshot.exists) {
        final data = docSnapshot.data()!;
        _currentUser = UserModel.fromFirestore(data, docSnapshot.id);
        _errorMessage = null;
        print('✅ User loaded: ${_currentUser?.fullName}, Role: ${_currentUser?.roleId}');
      } else {
        print('⚠️ User document not found for userId: $userId');
        _currentUser = null;
        _errorMessage = 'User profile not found. Please contact admin.';
      }
    } catch (e) {
      print('❌ Error loading user: $e');
      _currentUser = null;
      _errorMessage = 'Failed to load user data';
    }
    notifyListeners();
  }

  // ============================================================
  // SIGN IN
  // ============================================================
  Future<bool> signIn(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (email.isEmpty || password.isEmpty) {
        _errorMessage = 'Please enter email and password';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      
      if (userCredential.user != null) {
        await _loadUserFromFirestore(userCredential.user!.uid);
        _isLoading = false;
        notifyListeners();
        
        if (_currentUser != null) {
          print('✅ Sign in successful: ${_currentUser!.fullName}');
          return true;
        } else {
          _errorMessage = 'User account not properly configured. Please contact admin.';
          await _auth.signOut();
          return false;
        }
      }
      
      _isLoading = false;
      notifyListeners();
      return false;
      
    } on FirebaseAuthException catch (e) {
      print('❌ Firebase Auth Error: ${e.code}');
      _errorMessage = _handleAuthError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      print('❌ Login error: $e');
      _errorMessage = 'An unexpected error occurred. Please try again.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ============================================================
  // SIGN OUT
  // ============================================================
  Future<void> signOut() async {
    try {
      // ✅ លុប view_as_staff mode ពេល logout
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('view_as_staff');
      
      await _auth.signOut();
      _currentUser = null;
      _isInitialized = false;
      _errorMessage = null;
      notifyListeners();
      print('✅ User signed out successfully');
    } catch (e) {
      print('❌ Sign out error: $e');
      _errorMessage = 'Failed to sign out';
      notifyListeners();
    }
  }

  // ============================================================
  // REFRESH USER
  // ============================================================
  Future<void> refreshUser() async {
    if (_currentUser != null) {
      await _loadUserFromFirestore(_currentUser!.userId);
    } else {
      final user = _auth.currentUser;
      if (user != null) {
        await _loadUserFromFirestore(user.uid);
      }
    }
  }

  // ============================================================
  // VIEW MODE METHODS
  // ============================================================
  
  /// ពិនិត្យមើលថាតើកំពុង View as Staff ដែរឬទេ
  Future<bool> isViewingAsStaff() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('view_as_staff') ?? false;
    } catch (e) {
      print('❌ Error checking view mode: $e');
      return false;
    }
  }

  /// លុប View Mode
  Future<void> clearViewMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('view_as_staff');
      print('✅ View mode cleared');
    } catch (e) {
      print('❌ Error clearing view mode: $e');
    }
  }

  /// ទទួលបាន Route ត្រឹមត្រូវ (គិតពី View Mode)
  Future<String> getDashboardRoute() async {
    // ✅ ពិនិត្យ View Mode មុន - ប្រើឈ្មោះអថេរផ្សេង
    final bool isViewing = await isViewingAsStaff();
    if (isViewing) {
      return '/staff-dashboard';
    }
    
    // ✅ បើមិនមែន View Mode ប្រើ Role
    if (isAdmin) return '/admin-dashboard';
    if (isDirector) return '/director-dashboard';
    if (isManager) return '/manager-dashboard';
    if (isStaff) return '/dashboard';
    return '/login';
  }

  // ============================================================
  // UPDATE USER IN FIRESTORE
  // ============================================================
  Future<bool> updateUserInFirestore(Map<String, dynamic> data) async {
    if (_currentUser == null) {
      _errorMessage = 'No user logged in';
      return false;
    }

    try {
      await _firestore
          .collection('users')
          .doc(_currentUser!.userId)
          .update({
            ...data,
            'updatedAt': FieldValue.serverTimestamp(),
          });
      
      await refreshUser();
      print('✅ User updated successfully');
      return true;
      
    } catch (e) {
      print('❌ Error updating user: $e');
      _errorMessage = 'Failed to update user: $e';
      return false;
    }
  }

  // ============================================================
  // GET USER BY ID
  // ============================================================
  Future<UserModel?> getUserById(String userId) async {
    try {
      final docSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .get();

      if (docSnapshot.exists) {
        final data = docSnapshot.data()!;
        return UserModel.fromFirestore(data, docSnapshot.id);
      }
      return null;
    } catch (e) {
      print('❌ Error getting user: $e');
      return null;
    }
  }

  // ============================================================
  // GET ALL USERS
  // ============================================================
  Future<List<UserModel>> getAllUsers() async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .orderBy('fullName')
          .get();

      return querySnapshot.docs.map((doc) {
        return UserModel.fromFirestore(
          doc.data() as Map<String, dynamic>,
          doc.id,
        );
      }).toList();
    } catch (e) {
      print('❌ Error getting users: $e');
      return [];
    }
  }

  // ============================================================
  // GET USERS BY ROLE
  // ============================================================
  Future<List<UserModel>> getUsersByRole(String roleId) async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .where('roleId', isEqualTo: roleId)
          .orderBy('fullName')
          .get();

      return querySnapshot.docs.map((doc) {
        return UserModel.fromFirestore(
          doc.data() as Map<String, dynamic>,
          doc.id,
        );
      }).toList();
    } catch (e) {
      print('❌ Error getting users by role: $e');
      return [];
    }
  }

  // ============================================================
  // CHECK EMAIL EXISTS
  // ============================================================
  Future<bool> checkEmailExists(String email) async {
    try {
      List<String> methods = await _auth.fetchSignInMethodsForEmail(
        email.trim()
      );
      return methods.isNotEmpty;
    } catch (e) {
      print('❌ Check email error: $e');
      return false;
    }
  }

  // ============================================================
  // SEND PASSWORD RESET EMAIL
  // ============================================================
  Future<bool> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      print('✅ Password reset email sent to $email');
      return true;
    } on FirebaseAuthException catch (e) {
      print('❌ Password reset error: ${e.code}');
      _errorMessage = _handleAuthError(e);
      return false;
    } catch (e) {
      print('❌ Unexpected error: $e');
      _errorMessage = 'Failed to send reset email';
      return false;
    }
  }

  // ============================================================
  // HANDLE AUTH ERRORS
  // ============================================================
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
      case 'email-already-in-use':
        return 'This email is already registered.';
      case 'weak-password':
        return 'Password is too weak.';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection.';
      default:
        return 'Authentication failed: ${e.message}';
    }
  }

  // ============================================================
  // CLEAR ERROR MESSAGE
  // ============================================================
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // ============================================================
  // DISPOSE
  // ============================================================
  @override
  void dispose() {
    super.dispose();
  }
}