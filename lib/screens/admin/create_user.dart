// lib/screens/admin/create_user_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../app_fonts.dart';
import '../../utils/responsive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/telegram_service.dart';

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
  bool _hasManagerInDepartment = false; // សម្រាប់រក្សាទុកស្ថានភាព Manager

  // ===== DEPARTMENT LIST (Default + Dynamic from Firestore) =====
  List<Map<String, String>> _departments = [];

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ===== DEFAULT DEPARTMENTS =====
  List<Map<String, String>> _getDefaultDepartments() {
    return [
      {'id': 'dept_it', 'name': 'IT Department'},
      {'id': 'dept_education', 'name': 'Education Department'},
      {'id': 'dept_administration', 'name': 'Administration Department'},
      {'id': 'dept_service', 'name': 'Service Department'},
    ];
  }

  // ===== LOAD DEPARTMENTS FROM FIRESTORE =====
  Future<void> _loadDepartments() async {
    try {
      final snapshot = await _firestore.collection('departments').orderBy('name').get();

      final List<Map<String, String>> loadedDepartments = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        loadedDepartments.add({
          'id': doc.id,
          'name': data['name']?.toString() ?? 'Unnamed',
        });
      }

      // If no departments in Firestore, use defaults
      if (loadedDepartments.isEmpty) {
        // Save default departments to Firestore
        for (var dept in _getDefaultDepartments()) {
          await _firestore.collection('departments').add({
            'name': dept['name'],
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
        // Reload
        await _loadDepartments();
        return;
      }

      setState(() {
        _departments = loadedDepartments;
      });

      print('✅ Loaded ${_departments.length} departments from Firestore');
    } catch (e) {
      print('❌ Error loading departments: $e');
      // Fallback to default departments
      setState(() {
        _departments = _getDefaultDepartments();
      });
    }
  }

  // ==================== CHECK IF DEPARTMENT HAS MANAGER ====================
  Future<bool> _checkDepartmentHasManager(String departmentId) async {
    try {
      if (departmentId.isEmpty) {
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
      print('❌ Error checking manager in department: $e');
      return false;
    }
  }

  // ==================== CHECK IF MANAGER EXISTS IN DEPARTMENT ====================
  Future<bool> _checkManagerExistsInDepartment(String departmentId) async {
    try {
      if (departmentId.isEmpty) {
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

  // ==================== GET DEPARTMENT MANAGER INFO ====================
  Future<Map<String, dynamic>?> _getDepartmentManager(String departmentId) async {
    try {
      if (departmentId.isEmpty) {
        return null;
      }

      final snapshot = await _firestore
          .collection('users')
          .where('roleId', isEqualTo: '3')
          .where('departmentId', isEqualTo: departmentId)
          .where('status', isEqualTo: 'Active')
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data();
        return {
          'name': data['fullName'] ?? data['username'] ?? 'Unknown',
          'email': data['email'] ?? '',
          'userId': data['userId'] ?? '',
        };
      }
      return null;
    } catch (e) {
      print('❌ Error getting department manager: $e');
      return null;
    }
  }

  // ===== SHOW DEPARTMENT MANAGEMENT DIALOG =====
  void _showDepartmentManagementDialog() {
    final bool isMobile = Responsive.isMobile(context);
    final double fontSize = Responsive.fontSize(context, 14);
    final double spacing = Responsive.spacing(context);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.business, color: const Color(0xFF173B69), size: 24),
                SizedBox(width: spacing),
                Text(
                  'Manage Departments',
                  style: TextStyle(
                    fontSize: isMobile ? fontSize : fontSize + 2,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF173B69),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: isMobile ? double.maxFinite : 400,
              height: 400,
              child: Column(
                children: [
                  // Add Department Button
                  ElevatedButton.icon(
                    onPressed: () => _showAddDepartmentDialog(),
                    icon: Icon(Icons.add, size: 20),
                    label: Text(
                      'Add New Department',
                      style: TextStyle(fontSize: fontSize),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF173B69),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      minimumSize: Size(double.infinity, 45),
                    ),
                  ),
                  SizedBox(height: spacing * 1.5),

                  // Department List
                  Expanded(
                    child: _departments.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.business_outlined,
                                  size: 48,
                                  color: Colors.grey[400],
                                ),
                                SizedBox(height: spacing),
                                Text(
                                  'No departments found',
                                  style: TextStyle(
                                    fontSize: fontSize,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: _departments.length,
                            itemBuilder: (context, index) {
                              final dept = _departments[index];
                              return Card(
                                margin: EdgeInsets.only(bottom: spacing / 2),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: const Color(0xFF173B69).withValues(alpha: 0.1),
                                    child: Text(
                                      dept['name']![0].toUpperCase(),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF173B69),
                                        fontSize: fontSize,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    dept['name']!,
                                    style: TextStyle(
                                      fontSize: fontSize,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  subtitle: Text(
                                    'ID: ${dept['id']}',
                                    style: TextStyle(
                                      fontSize: fontSize * 0.75,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: Icon(
                                          Icons.edit,
                                          color: Colors.blue,
                                          size: 20,
                                        ),
                                        onPressed: () => _showEditDepartmentDialog(dept, index),
                                      ),
                                      IconButton(
                                        icon: Icon(
                                          Icons.delete,
                                          color: Colors.red,
                                          size: 20,
                                        ),
                                        onPressed: () => _showDeleteDepartmentDialog(dept, index),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Close',
                  style: TextStyle(
                    fontSize: fontSize,
                    color: Colors.grey[700],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ===== SHOW ADD DEPARTMENT DIALOG =====
  void _showAddDepartmentDialog() {
    final bool isMobile = Responsive.isMobile(context);
    final double fontSize = Responsive.fontSize(context, 14);
    final double spacing = Responsive.spacing(context);
    final TextEditingController nameController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(
          'Add New Department',
          style: TextStyle(
            fontSize: isMobile ? fontSize : fontSize + 2,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF173B69),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Enter the name of the new department',
              style: TextStyle(
                fontSize: fontSize,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: spacing),
            TextField(
              controller: nameController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'e.g. Marketing Department',
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
                filled: true,
                fillColor: Colors.white,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: spacing * 1.5,
                  vertical: isMobile ? 12 : 14,
                ),
              ),
              style: TextStyle(fontSize: fontSize, color: Colors.black),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(fontSize: fontSize, color: Colors.grey[700]),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a department name'),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }

              // Check if department already exists
              if (_departments.any((d) => d['name']!.toLowerCase() == name.toLowerCase())) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Department "$name" already exists!'),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }

              // Close add dialog
              Navigator.pop(context);

              try {
                // Save to Firestore
                final docRef = await _firestore.collection('departments').add({
                  'name': name,
                  'createdAt': FieldValue.serverTimestamp(),
                });

                // Update local list
                setState(() {
                  _departments.add({
                    'id': docRef.id,
                    'name': name,
                  });
                });

                // Close Management Dialog
                Navigator.pop(context);

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(' Department "$name" added successfully!'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('❌ Error: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF173B69),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              'Add Department',
              style: TextStyle(fontSize: fontSize),
            ),
          ),
        ],
      ),
    );
  }

  // ===== SHOW EDIT DEPARTMENT DIALOG =====
  void _showEditDepartmentDialog(Map<String, String> department, int index) {
    final bool isMobile = Responsive.isMobile(context);
    final double fontSize = Responsive.fontSize(context, 14);
    final double spacing = Responsive.spacing(context);
    final TextEditingController nameController = TextEditingController(text: department['name']);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(
          'Edit Department',
          style: TextStyle(
            fontSize: isMobile ? fontSize : fontSize + 2,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF173B69),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Update the department name',
              style: TextStyle(
                fontSize: fontSize,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: spacing),
            TextField(
              controller: nameController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Department name',
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
                filled: true,
                fillColor: Colors.white,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: spacing * 1.5,
                  vertical: isMobile ? 12 : 14,
                ),
              ),
              style: TextStyle(fontSize: fontSize, color: Colors.black),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(fontSize: fontSize, color: Colors.grey[700]),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a department name'),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }

              // Close edit dialog
              Navigator.pop(context);

              try {
                // Update in Firestore
                await _firestore.collection('departments').doc(department['id']).update({
                  'name': name,
                  'updatedAt': FieldValue.serverTimestamp(),
                });

                // Update local list
                setState(() {
                  _departments[index]['name'] = name;
                });

                // Close Management Dialog
                Navigator.pop(context);

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(' Department updated successfully!'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('❌ Error: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF173B69),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              'Update',
              style: TextStyle(fontSize: fontSize),
            ),
          ),
        ],
      ),
    );
  }

  // ===== SHOW DELETE DEPARTMENT DIALOG =====
  void _showDeleteDepartmentDialog(Map<String, String> department, int index) {
    final bool isMobile = Responsive.isMobile(context);
    final double fontSize = Responsive.fontSize(context, 14);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Delete Department',
          style: TextStyle(
            fontSize: isMobile ? fontSize : fontSize + 2,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete "${department['name']}"?',
              style: TextStyle(fontSize: fontSize),
            ),
            SizedBox(height: 8),
            Text(
              ' This will also remove this department from all users.',
              style: TextStyle(
                fontSize: fontSize * 0.85,
                color: Colors.orange,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(fontSize: fontSize, color: Colors.grey[700]),
            ),
          ),
          TextButton(
            onPressed: () async {
              // Close confirm dialog
              Navigator.pop(context);

              try {
                // 1. Remove department from all users
                final usersSnapshot =
                    await _firestore.collection('users').where('departmentId', isEqualTo: department['id']).get();

                for (var doc in usersSnapshot.docs) {
                  await _firestore.collection('users').doc(doc.id).update({
                    'departmentId': null,
                    'department': null,
                  });
                }

                // 2. Delete department from Firestore
                await _firestore.collection('departments').doc(department['id']).delete();

                // 3. Remove from local list
                setState(() {
                  _departments.removeAt(index);
                  if (_selectedDepartmentId == department['id']) {
                    _selectedDepartmentId = '';
                  }
                });

                // Close Management Dialog
                Navigator.pop(context);

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(' Department "${department['name']}" deleted successfully!'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('❌ Error: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(
              'Delete',
              style: TextStyle(fontSize: fontSize),
            ),
          ),
        ],
      ),
    );
  }

  bool _showDepartment() {
    return _selectedRole != '1' && _selectedRole != '4';
  }

  bool _showPositionField() {
    return _selectedRole == '2';
  }

  bool _isPositionReadOnly() {
    return _selectedRole == '3';
  }

  // ==================== CHECK IF DEPARTMENT CAN HAVE STAFF ====================
  Future<bool> _canCreateStaffInDepartment(String departmentId) async {
    if (departmentId.isEmpty) return false;

    try {
      final hasManager = await _checkManagerExistsInDepartment(departmentId);

      if (!hasManager) {
        if (mounted) {
          setState(() {
            _hasManagerInDepartment = false;
          });
        }
        return false;
      }

      if (mounted) {
        setState(() {
          _hasManagerInDepartment = true;
        });
      }
      return true;
    } catch (e) {
      print('❌ Error checking if staff can be created: $e');
      return false;
    }
  }

  // ===== GENERATE USER NUMBER =====
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

  // ===== FORMAT USER NUMBER =====
  String _formatUserNumber(int number) {
    return number.toString().padLeft(4, '0');
  }

  // ===== GET ROLE NAME =====
  String _getRoleName(String roleId) {
    final roleNames = {
      '1': 'Admin',
      '2': 'Staff',
      '3': 'Manager',
    };
    return roleNames[roleId] ?? 'User';
  }

  // ===== SEND TELEGRAM TO GROUP =====
  Future<void> _sendTelegramToGroup({
    required String fullName,
    required String username,
    required String email,
    required String password,
    required String roleId,
    required String userId,
    required String phone,
    required String position,
    required String department,
  }) async {
    try {
      final roleNames = {
        '1': 'Admin',
        '2': 'Staff',
        '3': 'Manager',
      };

      final String roleName = roleNames[roleId] ?? 'User';

      final String message = '''
NEW USER CREATED!
=================
ACCOUNT DETAILS:
- Full Name: $fullName
- Username: $username
- Email: $email
- Password: $password
- Role: $roleName
- User ID: $userId
- Phone: ${phone.isNotEmpty ? phone : 'N/A'}
${department.isNotEmpty ? '- Department: $department' : ''}
${position.isNotEmpty ? '- Position: $position' : ''}

IMPORTANT: 
- Please change password after first login
- Keep this information safe and secure
''';

      final bool sent = await TelegramService.sendToAll(message);

      if (sent) {
        print(' Telegram sent to Group/Admin/Manager');
      } else {
        print('❌ Failed to send Telegram');
      }
    } catch (e) {
      print('❌ Error sending Telegram: $e');
    }
  }

  // ===== GET ADMIN CREDENTIALS =====
  Future<Map<String, String>?> _getAdminCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('admin_email');
    final password = prefs.getString('admin_password');
    if (email != null && password != null && email.isNotEmpty && password.isNotEmpty) {
      return {'email': email, 'password': password};
    }
    return null;
  }

  // ===== AUTO RE-LOGIN ADMIN =====
  Future<bool> _autoReLoginAdmin() async {
    final credentials = await _getAdminCredentials();

    if (credentials != null) {
      try {
        await _auth.signInWithEmailAndPassword(
          email: credentials['email']!,
          password: credentials['password']!,
        );
        print('✅ Admin auto re-login successful!');
        return true;
      } catch (e) {
        print('❌ Admin auto re-login failed: $e');
        return false;
      }
    }
    print('⚠️ No admin credentials found');
    return false;
  }

  // ===== CHECK IF DEPARTMENT HAS MANAGER BEFORE CREATING STAFF =====
  Future<bool> _validateDepartmentHasManagerForStaff() async {
    // ប្រសិនបើមិនមែន Staff ទេ មិនត្រូវពិនិត្យ
    if (_selectedRole != '2') {
      return true;
    }

    // ប្រសិនបើមិនបានជ្រើស Department
    if (_selectedDepartmentId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Please select a Department for Staff.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
      return false;
    }

    // ពិនិត្យមើលថាតើ Department មាន Manager ហើយឬនៅ
    final hasManager = await _checkManagerExistsInDepartment(_selectedDepartmentId);

    if (!hasManager) {
      // ស្វែងរកឈ្មោះ Department
      String departmentName = '';
      final dept = _departments.firstWhere(
        (d) => d['id'] == _selectedDepartmentId,
        orElse: () => {},
      );
      departmentName = dept['name'] ?? 'this department';

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text(
              '⚠️ Cannot Create Staff',
              style: TextStyle(color: Colors.orange),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Department "$departmentName" does not have a Manager yet.',
                  style: TextStyle(fontSize: Responsive.fontSize(context, 14)),
                ),
                SizedBox(height: 8),
                Text(
                  '📌 Please create a Manager for this department first.',
                  style: TextStyle(
                    fontSize: Responsive.fontSize(context, 13),
                    color: Colors.blue[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Each department must have at least one Manager before Staff can be created.',
                  style: TextStyle(
                    fontSize: Responsive.fontSize(context, 12),
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
      return false;
    }

    return true;
  }

  // ==================== CREATE USER ====================
  Future<void> _createUser() async {
    if (!_formKey.currentState!.validate()) return;

    // ===== ពិនិត្យមើល Department សម្រាប់ Staff =====
    if (_selectedRole == '2') {
      final canCreate = await _validateDepartmentHasManagerForStaff();
      if (!canCreate) {
        return;
      }
    }

    // ===== ពិនិត្យមើល Manager ក្នុង Department =====
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
      final fullName = _fullNameController.text.trim();
      final username = _usernameController.text.trim();
      final phone = _phoneController.text.trim();

      String position;
      if (_selectedRole == '3') {
        position = 'Manager';
      } else {
        position = _positionController.text.trim();
      }

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

      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final newUserUid = userCredential.user!.uid;

      String departmentName = '';
      if (_selectedDepartmentId.isNotEmpty) {
        final dept = _departments.firstWhere(
          (d) => d['id'] == _selectedDepartmentId,
          orElse: () => {},
        );
        departmentName = dept['name'] ?? '';
      }

      final userNumberInt = await _generateUserNumber();
      final userNumberFormatted = _formatUserNumber(userNumberInt);

      print('📝 User Number: $userNumberFormatted');

      await _firestore.collection('users').doc(newUserUid).set({
        'userId': userNumberFormatted,
        'userIdInt': userNumberInt,
        'email': email,
        'fullName': fullName,
        'username': username,
        'phone': phone,
        'roleId': _selectedRole,
        'departmentId': _selectedDepartmentId.isEmpty ? null : _selectedDepartmentId,
        'department': departmentName.isEmpty ? null : departmentName,
        'position': position.isNotEmpty ? position : null,
        'status': _selectedStatus,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await _sendTelegramToGroup(
        fullName: fullName,
        username: username,
        email: email,
        password: password,
        roleId: _selectedRole,
        userId: userNumberFormatted,
        phone: phone,
        position: position,
        department: departmentName,
      );

      await _auth.signOut();
      print('🔓 New user signed out');

      final reLoginSuccess = await _autoReLoginAdmin();

      if (mounted) {
        String successMessage = ' User created successfully!';
        successMessage += '\n Telegram sent to Group/Admin/Manager';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(successMessage),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      }

      if (reLoginSuccess && mounted) {
        Navigator.pop(context);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(' Please login again as Admin'),
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ $message'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _loadDepartments();
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
        actions: [
          IconButton(
            icon: Icon(Icons.business, color: Colors.white, size: iconSize),
            onPressed: _showDepartmentManagementDialog,
            tooltip: 'Manage Departments',
          ),
        ],
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
                  hintText: 'Enter phone number (e.g. 012345678)',
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
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    String cleaned = value.replaceAll(RegExp(r'[^0-9+]'), '');
                    if (cleaned.length < 9) {
                      return 'Phone number must be at least 9 digits';
                    }
                  }
                  return null;
                },
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
                initialValue: _selectedRole,
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
                      if (value == '3') {
                        _positionController.text = 'Manager';
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

              // Department Dropdown - FIXED
              if (_showDepartment()) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Department',
                      style: TextStyle(
                        fontSize: fontSize,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _showDepartmentManagementDialog,
                      icon: Icon(Icons.settings, size: 16, color: const Color(0xFF173B69)),
                      label: Text(
                        'Manage',
                        style: TextStyle(
                          fontSize: fontSize * 0.8,
                          color: const Color(0xFF173B69),
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: spacing * 0.6),
                DropdownButtonFormField<String>(
                  initialValue: _departments.any((d) => d['id'] == _selectedDepartmentId)
                      ? (_selectedDepartmentId.isEmpty ? null : _selectedDepartmentId)
                      : null,
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
                    suffixIcon: IconButton(
                      icon: Icon(Icons.settings, color: const Color(0xFF173B69), size: 20),
                      onPressed: _showDepartmentManagementDialog,
                      tooltip: 'Manage Departments',
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
              if (_showPositionField() || _isPositionReadOnly()) ...[
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
                  readOnly: _isPositionReadOnly(),
                  decoration: InputDecoration(
                    hintText:
                        _isPositionReadOnly() ? 'Manager (Default)' : 'Enter position (e.g. Teacher, Accountant, etc.)',
                    hintStyle: TextStyle(
                      fontSize: fontSize,
                      color: _isPositionReadOnly() ? Colors.grey.shade600 : Colors.grey.shade400,
                    ),
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
                    suffixIcon: _isPositionReadOnly() ? const Icon(Icons.lock, color: Colors.grey, size: 20) : null,
                    filled: true,
                    fillColor: _isPositionReadOnly() ? Colors.grey.shade100 : Colors.white,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: spacing * 1.5,
                      vertical: isMobile ? 12 : 14,
                    ),
                  ),
                  style: TextStyle(
                    fontSize: fontSize,
                    color: _isPositionReadOnly() ? Colors.grey.shade700 : Colors.black,
                  ),
                  validator: (value) {
                    if (_selectedRole == '3') {
                      return null;
                    }
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
                initialValue: _selectedStatus,
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