// ============================================================
// lib/screens/admin/create_user_screen.dart
// ============================================================
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../app_fonts.dart';
import '../../utils/responsive.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CreateUserScreen extends StatefulWidget {
  const CreateUserScreen({super.key});

  @override
  State<CreateUserScreen> createState() => _CreateUserScreenState();
}

class _CreateUserScreenState extends State<CreateUserScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _positionController = TextEditingController();
  String _selectedRole = '2';
  String _selectedDepartmentId = '';
  String _selectedStatus = 'Active';
  bool _isLoading = false;

  final List<Map<String, String>> _departments = [
    {'id': 'dept_it', 'name': 'IT Department'},
    {'id': 'dept_education', 'name': 'Education Department'},
    {'id': 'dept_administration', 'name': 'Administration Department'},
    {'id': 'dept_service', 'name': 'Service Department'},
  ];

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _showDepartment() {
    return _selectedRole != '1' && _selectedRole != '4';
  }

  bool _showPositionField() {
    return _selectedRole == '2';
  }

  // ==================== CHECK IF MANAGER EXISTS IN DEPARTMENT ====================
  Future<bool> _checkManagerExistsInDepartment(String departmentId) async {
    try {
      if (departmentId.isEmpty) {
        // ប្រសិនបើមិនបានជ្រើសរើស Department
        return false;
      }
      
      final snapshot = await _firestore
          .collection('users')
          .where('roleId', isEqualTo: '3')
          .where('departmentId', isEqualTo: departmentId)
          .where('status', isEqualTo: 'Active')
          .get();
      
      return snapshot.docs.isNotEmpty;
    } catch (e) {
      print('❌ Error checking manager exists in department: $e');
      return false;
    }
  }

  // ==================== GENERATE USER NUMBER ====================
  Future<int> _generateUserNumber() async {
    try {
      final counterRef = _firestore.collection('counters').doc('user_counter');
      
      final result = await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(counterRef);
        
        int currentCount = 0;
        if (snapshot.exists) {
          final data = snapshot.data();
          currentCount = (data?['value'] as int?) ?? 0;
        }
        
        final newCount = currentCount + 1;
        transaction.set(counterRef, {'value': newCount});
        
        return newCount;
      });
      
      return result;
    } catch (e) {
      print('❌ Error generating user number: $e');
      return DateTime.now().millisecondsSinceEpoch ~/ 1000;
    }
  }

  // ==================== FORMAT USER NUMBER ====================
  String _formatUserNumber(int number) {
    return number.toString().padLeft(4, '0');
  }

  // ទាញយក Admin Credentials
  Future<Map<String, String>?> _getAdminCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('admin_email');
    final password = prefs.getString('admin_password');
    if (email != null && password != null && email.isNotEmpty && password.isNotEmpty) {
      return {'email': email, 'password': password};
    }
    return null;
  }

  // Auto Re-login Admin
  Future<bool> _autoReLoginAdmin() async {
    final credentials = await _getAdminCredentials();
    
    if (credentials != null) {
      try {
        await _auth.signInWithEmailAndPassword(
          email: credentials['email']!,
          password: credentials['password']!,
        );
        print(' Admin auto re-login successful!');
        return true;
      } catch (e) {
        print('❌ Admin auto re-login failed: $e');
        return false;
      }
    }
    print('❌ No admin credentials found');
    return false;
  }

  Future<void> _createUser() async {
    if (!_formKey.currentState!.validate()) return;

    // 🔥 ពិនិត្យមើលថា Manager មានរួចហើយក្នុង Department នេះឬនៅ
    if (_selectedRole == '3') {
      if (_selectedDepartmentId.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ Please select a department for Manager.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }
      
      final managerExists = await _checkManagerExistsInDepartment(_selectedDepartmentId);
      if (managerExists) {
        // ស្វែងរកឈ្មោះ Department
        String departmentName = '';
        final dept = _departments.firstWhere(
          (d) => d['id'] == _selectedDepartmentId,
          orElse: () => {},
        );
        departmentName = dept['name'] ?? 'this department';
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '⚠️ A Manager already exists in "$departmentName". Only one Manager per department is allowed.',
              ),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 5),
            ),
          );
        }
        return;
      }
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();
      
      // ពិនិត្យមើលថា Email មានហើយឬនៅ
      try {
        final methods = await _auth.fetchSignInMethodsForEmail(email);
        if (methods.isNotEmpty) {
          if (mounted) {
            await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Email Already Registered'),
                content: Text(
                  'The email "$email" is already registered. Please use a different email.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
            setState(() {
              _isLoading = false;
            });
            return;
          }
          return;
        }
      } catch (e) {
        if (e is FirebaseAuthException && e.code == 'email-already-in-use') {
          rethrow;
        }
      }
      
      // 1. Create user in Firebase Auth
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final newUserUid = userCredential.user!.uid;

      // Find department name
      String departmentName = '';
      if (_selectedDepartmentId.isNotEmpty) {
        final dept = _departments.firstWhere(
          (d) => d['id'] == _selectedDepartmentId,
          orElse: () => {},
        );
        departmentName = dept['name'] ?? '';
      }

      // 🔥 បង្កើត User Number
      final userNumberInt = await _generateUserNumber();
      final userNumberFormatted = _formatUserNumber(userNumberInt);
      
      print(' User Number: $userNumberFormatted');

      // 2. Save user to Firestore
      await _firestore.collection('users').doc(newUserUid).set({
        'userId': userNumberFormatted,
        'userIdInt': userNumberInt,
        'email': email,
        'fullName': _fullNameController.text.trim(),
        'username': _usernameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'roleId': _selectedRole,
        'departmentId': _selectedDepartmentId.isEmpty ? null : _selectedDepartmentId,
        'department': departmentName.isEmpty ? null : departmentName,
        'position': _showPositionField() ? _positionController.text.trim() : null,
        'status': _selectedStatus,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 3. Sign out the new user
      await _auth.signOut();
      print('New user signed out');

      // 4. Auto Re-login Admin
      final reLoginSuccess = await _autoReLoginAdmin();
      
      if (reLoginSuccess && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(' User created successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        Navigator.pop(context);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ Please login again as Admin'),
              backgroundColor: Colors.orange,
            ),
          );
          Navigator.pushReplacementNamed(context, '/login');
        }
      }
      
    } on FirebaseAuthException catch (e) {
      String message = 'Failed to create user';
      if (e.code == 'email-already-in-use') {
        message = 'Email already in use. Please use a different email.';
      } else if (e.code == 'weak-password') {
        message = 'Password is too weak';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ $message'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _fullNameController.dispose();
    _phoneController.dispose();
    _usernameController.dispose();
    _positionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = Responsive.isMobile(context);
    final double fontSize = Responsive.fontSize(context, AppFonts.md);
    final double spacing = Responsive.spacing(context);
    final double buttonHeight = Responsive.buttonHeight(context);
    final double iconSize = Responsive.iconSize(context, 24);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Create New User',
          style: TextStyle(
            fontSize: isMobile ? AppFonts.md : AppFonts.md * 1.1,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF173B69),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white, size: iconSize),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(spacing * 2),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Email
              Text(
                'Email',
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey,
                ),
              ),
              SizedBox(height: spacing * 0.6),
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(
                  hintText: 'Enter email',
                  hintStyle: TextStyle(fontSize: fontSize, color: Colors.grey.shade400),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Colors.grey, width: 1.0),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Colors.grey, width: 1.0),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF173B69), width: 2.0),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Colors.red, width: 1.5),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Colors.red, width: 2.0),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: spacing * 1.5,
                    vertical: isMobile ? 12 : 14,
                  ),
                ),
                keyboardType: TextInputType.emailAddress,
                style: TextStyle(fontSize: fontSize, color: Colors.black),
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Email is required';
                  if (!value!.contains('@')) return 'Invalid email';
                  return null;
                },
              ),
              SizedBox(height: spacing * 1.5),

              // Password
              Text(
                'Password',
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey,
                ),
              ),
              SizedBox(height: spacing * 0.6),
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(
                  hintText: 'Enter password (min 6 characters)',
                  hintStyle: TextStyle(fontSize: fontSize, color: Colors.grey.shade400),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Colors.grey, width: 1.0),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Colors.grey, width: 1.0),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF173B69), width: 2.0),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Colors.red, width: 1.5),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Colors.red, width: 2.0),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: spacing * 1.5,
                    vertical: isMobile ? 12 : 14,
                  ),
                ),
                obscureText: true,
                style: TextStyle(fontSize: fontSize, color: Colors.black),
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Password is required';
                  if (value!.length < 6) return 'Min 6 characters';
                  return null;
                },
              ),
              SizedBox(height: spacing * 1.5),

              // Full Name
              Text(
                'Full Name',
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey,
                ),
              ),
              SizedBox(height: spacing * 0.6),
              TextFormField(
                controller: _fullNameController,
                decoration: InputDecoration(
                  hintText: 'Enter full name',
                  hintStyle: TextStyle(fontSize: fontSize, color: Colors.grey.shade400),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Colors.grey, width: 1.0),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Colors.grey, width: 1.0),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF173B69), width: 2.0),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Colors.red, width: 1.5),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Colors.red, width: 2.0),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: spacing * 1.5,
                    vertical: isMobile ? 12 : 14,
                  ),
                ),
                style: TextStyle(fontSize: fontSize, color: Colors.black),
                validator: (value) => value?.isEmpty ?? true ? 'Full name is required' : null,
              ),
              SizedBox(height: spacing * 1.5),

              // Username
              Text(
                'Username',
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey,
                ),
              ),
              SizedBox(height: spacing * 0.6),
              TextFormField(
                controller: _usernameController,
                decoration: InputDecoration(
                  hintText: 'Enter username',
                  hintStyle: TextStyle(fontSize: fontSize, color: Colors.grey.shade400),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Colors.grey, width: 1.0),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Colors.grey, width: 1.0),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF173B69), width: 2.0),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Colors.red, width: 1.5),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Colors.red, width: 2.0),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: spacing * 1.5,
                    vertical: isMobile ? 12 : 14,
                  ),
                ),
                style: TextStyle(fontSize: fontSize, color: Colors.black),
                validator: (value) => value?.isEmpty ?? true ? 'Username is required' : null,
              ),
              SizedBox(height: spacing * 1.5),

              // Phone
              Text(
                'Phone',
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey,
                ),
              ),
              SizedBox(height: spacing * 0.6),
              TextFormField(
                controller: _phoneController,
                decoration: InputDecoration(
                  hintText: 'Enter phone number',
                  hintStyle: TextStyle(fontSize: fontSize, color: Colors.grey.shade400),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Colors.grey, width: 1.0),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Colors.grey, width: 1.0),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF173B69), width: 2.0),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Colors.red, width: 1.5),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Colors.red, width: 2.0),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: spacing * 1.5,
                    vertical: isMobile ? 12 : 14,
                  ),
                ),
                keyboardType: TextInputType.phone,
                style: TextStyle(fontSize: fontSize, color: Colors.black),
              ),
              SizedBox(height: spacing * 1.5),

              // Role Dropdown
              Text(
                'Role',
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey,
                ),
              ),
              SizedBox(height: spacing * 0.6),
              DropdownButtonFormField<String>(
                value: _selectedRole,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Colors.grey, width: 1.0),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Colors.grey, width: 1.0),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF173B69), width: 2.0),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Colors.red, width: 1.5),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Colors.red, width: 2.0),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: spacing * 1.5,
                    vertical: isMobile ? 6 : 8,
                  ),
                ),
                items: const [
                  DropdownMenuItem(value: '1', child: Text('👑 Admin')),
                  DropdownMenuItem(value: '2', child: Text(' Staff')),
                  DropdownMenuItem(value: '3', child: Text(' Manager')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedRole = value;
                      if (value == '1') {
                        _selectedDepartmentId = '';
                      }
                      if (value != '2') {
                        _positionController.clear();
                      }
                    });
                  }
                },
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w500,
                  color: Colors.black,
                ),
                dropdownColor: Colors.white,
                icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF173B69)),
                isExpanded: true,
                menuMaxHeight: 250,
              ),
              SizedBox(height: spacing * 1.5),

              // Department Dropdown
              if (_showDepartment()) ...[
                Text(
                  'Department',
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey,
                  ),
                ),
                SizedBox(height: spacing * 0.6),
                DropdownButtonFormField<String>(
                  value: _selectedDepartmentId.isEmpty ? null : _selectedDepartmentId,
                  hint: Text(
                    'Select Department',
                    style: TextStyle(fontSize: fontSize, color: Colors.grey.shade500),
                  ),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Colors.grey, width: 1.0),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Colors.grey, width: 1.0),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF173B69), width: 2.0),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Colors.red, width: 1.5),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Colors.red, width: 2.0),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: spacing * 1.5,
                      vertical: isMobile ? 6 : 8,
                    ),
                  ),
                  items: [
                    const DropdownMenuItem(value: '', child: Text('No Department')),
                    ..._departments.map((dept) {
                      return DropdownMenuItem(
                        value: dept['id'],
                        child: Text(
                          dept['name']!,
                          style: TextStyle(
                            fontSize: fontSize,
                            fontWeight: FontWeight.w500,
                            color: Colors.black,
                          ),
                        ),
                      );
                    }),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedDepartmentId = value ?? '';
                    });
                  },
                  validator: (value) {
                    if (_showDepartment() && (value == null || value.isEmpty)) {
                      return 'Please select a department';
                    }
                    return null;
                  },
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w500,
                    color: Colors.black,
                  ),
                  dropdownColor: Colors.white,
                  icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF173B69)),
                  isExpanded: true,
                  menuMaxHeight: 300,
                ),
                SizedBox(height: spacing * 1.5),
              ],

              // POSITION TEXTFIELD
              if (_showPositionField()) ...[
                Text(
                  'Position',
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey,
                  ),
                ),
                SizedBox(height: spacing * 0.6),
                TextFormField(
                  controller: _positionController,
                  decoration: InputDecoration(
                    hintText: 'Enter position (e.g. Teacher, Accountant, etc.)',
                    hintStyle: TextStyle(fontSize: fontSize, color: Colors.grey.shade400),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Colors.grey, width: 1.0),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Colors.grey, width: 1.0),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF173B69), width: 2.0),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Colors.red, width: 1.5),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Colors.red, width: 2.0),
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: spacing * 1.5,
                      vertical: isMobile ? 12 : 14,
                    ),
                  ),
                  style: TextStyle(fontSize: fontSize, color: Colors.black),
                  validator: (value) {
                    if (_showPositionField() && (value?.isEmpty ?? true)) {
                      return 'Position is required for Staff';
                    }
                    return null;
                  },
                ),
                SizedBox(height: spacing * 1.5),
              ],

              // Status Dropdown
              Text(
                'Status',
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey,
                ),
              ),
              SizedBox(height: spacing * 0.6),
              DropdownButtonFormField<String>(
                value: _selectedStatus,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Colors.grey, width: 1.0),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Colors.grey, width: 1.0),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF173B69), width: 2.0),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Colors.red, width: 1.5),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Colors.red, width: 2.0),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: spacing * 1.5,
                    vertical: isMobile ? 6 : 8,
                  ),
                ),
                items: const [
                  DropdownMenuItem(value: 'Active', child: Text(' Active')),
                  DropdownMenuItem(value: 'Inactive', child: Text(' Inactive')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedStatus = value;
                    });
                  }
                },
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w500,
                  color: Colors.black,
                ),
                dropdownColor: Colors.white,
                icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF173B69)),
                isExpanded: true,
                menuMaxHeight: 200,
              ),
              SizedBox(height: spacing * 3),

              // Create Button
              SizedBox(
                width: double.infinity,
                height: buttonHeight,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _createUser,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF173B69),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _isLoading
                      ? SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'Create User',
                          style: TextStyle(
                            fontSize: fontSize,
                            fontWeight: FontWeight.w600,
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