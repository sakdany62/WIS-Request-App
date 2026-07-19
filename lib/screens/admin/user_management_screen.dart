import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:permission_system/app_fonts.dart';
import '../../services/user_service.dart';
import '../../models/user_model.dart';
import '../../utils/responsive.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final UserService _userService = UserService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String _searchQuery = '';
  bool _isLoading = true;
  List<UserModel> _users = [];
  String _filterDepartment = 'all';

  final List<Map<String, String>> _departments = [
    {'id': 'dept_it', 'name': 'IT Department'},
    {'id': 'dept_education', 'name': 'Education Department'},
    {'id': 'dept_administration', 'name': 'Administration Department'},
    {'id': 'dept_service', 'name': 'Service Department'},
  ];

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .orderBy('createdAt', descending: true)
          .get();

      setState(() {
        _users = snapshot.docs.map((doc) {
          return UserModel.fromFirestore(
            doc.data() as Map<String, dynamic>,
            doc.id,
          );
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Error loading users: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<UserModel> get _filteredUsers {
    var filtered = _users;
    
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((user) {
        return user.fullName.toLowerCase().contains(query) ||
            user.email.toLowerCase().contains(query) ||
            user.username.toLowerCase().contains(query) ||
            (user.department?.toLowerCase().contains(query) ?? false) ||
            (user.departmentId?.toLowerCase().contains(query) ?? false);
      }).toList();
    }
    
    if (_filterDepartment != 'all') {
      filtered = filtered.where((user) {
        return user.departmentId == _filterDepartment;
      }).toList();
    }
    
    return filtered;
  }

  Future<void> _showEditDialog(UserModel user) async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: user.fullName);
    final phoneController = TextEditingController(text: user.phone);
    final emailController = TextEditingController(text: user.email);
    String selectedRole = user.roleId;
    String selectedStatus = user.status;
    String selectedDepartmentId = user.departmentId ?? '';

    final bool isMobile = Responsive.isMobile(context);
    final double fontSize = Responsive.fontSize(context, 14);
    final double spacing = Responsive.spacing(context);
    final double buttonHeight = Responsive.buttonHeight(context);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Edit User: ${user.username}',
          style: TextStyle(
            fontSize: isMobile ? fontSize : fontSize + 2,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Full Name
                TextFormField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Full Name',
                    labelStyle: TextStyle(fontSize: fontSize, color: Colors.grey[700]),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.grey, width: 1.0),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.grey, width: 1.0),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF173B69), width: 2.0),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: spacing * 1.5,
                      vertical: isMobile ? 12 : 14,
                    ),
                  ),
                  validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                  style: TextStyle(fontSize: fontSize, color: Colors.black),
                ),
                SizedBox(height: spacing * 1.5),

                // Email
                TextFormField(
                  controller: emailController,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    labelStyle: TextStyle(fontSize: fontSize, color: Colors.grey[700]),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.grey, width: 1.0),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.grey, width: 1.0),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF173B69), width: 2.0),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: spacing * 1.5,
                      vertical: isMobile ? 12 : 14,
                    ),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value?.isEmpty ?? true) return 'Required';
                    if (!value!.contains('@')) return 'Invalid email';
                    return null;
                  },
                  style: TextStyle(fontSize: fontSize, color: Colors.black),
                ),
                SizedBox(height: spacing * 1.5),

                // Phone
                TextFormField(
                  controller: phoneController,
                  decoration: InputDecoration(
                    labelText: 'Phone',
                    labelStyle: TextStyle(fontSize: fontSize, color: Colors.grey[700]),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.grey, width: 1.0),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.grey, width: 1.0),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
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
                SizedBox(height: spacing * 1.5),

                // Role Dropdown
                DropdownButtonFormField<String>(
                  value: selectedRole,
                  decoration: InputDecoration(
                    labelText: 'Role',
                    labelStyle: TextStyle(fontSize: fontSize, color: Colors.grey[700]),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.grey, width: 1.0),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.grey, width: 1.0),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF173B69), width: 2.0),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: spacing * 1.5,
                      vertical: isMobile ? 6 : 8,
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: '1',
                      child: Text('👑 Admin'),
                    ),
                    DropdownMenuItem(
                      value: '2',
                      child: Text(' Staff'),
                    ),
                    DropdownMenuItem(
                      value: '3',
                      child: Text(' Manager'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) selectedRole = value;
                  },
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w500,
                    color: Colors.black,
                  ),
                  dropdownColor: Colors.white,
                  icon: const Icon(
                    Icons.arrow_drop_down,
                    color: Color(0xFF173B69),
                  ),
                ),
                SizedBox(height: spacing * 1.5),

                // Department Dropdown
                DropdownButtonFormField<String>(
                  value: selectedDepartmentId.isEmpty ? null : selectedDepartmentId,
                  decoration: InputDecoration(
                    labelText: 'Department',
                    labelStyle: TextStyle(fontSize: fontSize, color: Colors.grey[700]),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.grey, width: 1.0),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.grey, width: 1.0),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF173B69), width: 2.0),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: spacing * 1.5,
                      vertical: isMobile ? 6 : 8,
                    ),
                  ),
                  hint: Text(
                    'Select Department',
                    style: TextStyle(fontSize: fontSize, color: Colors.grey.shade500),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: '',
                      child: Text('No Department'),
                    ),
                    ..._departments.map((dept) {
                      return DropdownMenuItem(
                        value: dept['id'],
                        child: Text(dept['name']!),
                      );
                    }),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      selectedDepartmentId = value;
                    }
                  },
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w500,
                    color: Colors.black,
                  ),
                  dropdownColor: Colors.white,
                  icon: const Icon(
                    Icons.arrow_drop_down,
                    color: Color(0xFF173B69),
                  ),
                ),
                SizedBox(height: spacing * 1.5),

                // Status Dropdown
                DropdownButtonFormField<String>(
                  value: selectedStatus,
                  decoration: InputDecoration(
                    labelText: 'Status',
                    labelStyle: TextStyle(fontSize: fontSize, color: Colors.grey[700]),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.grey, width: 1.0),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.grey, width: 1.0),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF173B69), width: 2.0),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: spacing * 1.5,
                      vertical: isMobile ? 6 : 8,
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'Active',
                      child: Text(' Active'),
                    ),
                    DropdownMenuItem(
                      value: 'Inactive',
                      child: Text(' Inactive'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) selectedStatus = value;
                  },
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w500,
                    color: Colors.black,
                  ),
                  dropdownColor: Colors.white,
                  icon: const Icon(
                    Icons.arrow_drop_down,
                    color: Color(0xFF173B69),
                  ),
                ),
              ],
            ),
          ),
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
              if (!formKey.currentState!.validate()) return;
              
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const Center(
                  child: CircularProgressIndicator(),
                ),
              );
              
              try {
                String departmentName = '';
                if (selectedDepartmentId.isNotEmpty) {
                  final dept = _departments.firstWhere(
                    (d) => d['id'] == selectedDepartmentId,
                    orElse: () => {},
                  );
                  departmentName = dept['name'] ?? '';
                }

                final updatedUser = user.copyWith(
                  fullName: nameController.text,
                  phone: phoneController.text,
                  email: emailController.text,
                  roleId: selectedRole,
                  status: selectedStatus,
                  departmentId: selectedDepartmentId.isEmpty ? null : selectedDepartmentId,
                  department: departmentName.isEmpty ? null : departmentName,
                );
                
                await _userService.updateUser(updatedUser);
                
                Navigator.pop(context);
                Navigator.pop(context);
                
                _loadUsers();
                
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(' User updated successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                Navigator.pop(context);
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('❌ Error: $e'),
                    backgroundColor: Colors.red,
                    duration: const Duration(seconds: 3),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF173B69),
              minimumSize: Size(double.infinity, buttonHeight),
            ),
            child: Text(
              'Save',
              style: TextStyle(fontSize: fontSize, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showDeleteDialog(UserModel user) async {
    final bool isMobile = Responsive.isMobile(context);
    final double fontSize = Responsive.fontSize(context, 14);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Delete User',
          style: TextStyle(fontSize: isMobile ? fontSize : fontSize + 2),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete ${user.fullName}?',
              style: TextStyle(fontSize: fontSize),
            ),
            const SizedBox(height: 8),
            Text(
              ' This will delete the user from Database.',
              style: TextStyle(
                fontSize: fontSize * 0.85,
                color: Colors.orange,
              ),
            ),
            Text(
              ' Email: ${user.email}',
              style: TextStyle(
                fontSize: fontSize * 0.85,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(fontSize: fontSize, color: Colors.grey[700]),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(
              'Delete ',
              style: TextStyle(fontSize: fontSize),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );
      
      try {
        await _userService.deleteUser(user.id, user.userId);
        
        Navigator.pop(context);
        _loadUsers();
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User deleted from Database'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Show additional info about Auth deletion
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'To reuse email "${user.email}", delete from Database ',
              style: TextStyle(fontSize: 12),
            ),
            backgroundColor: Colors.blue,
            duration: const Duration(seconds: 5),
          ),
        );
      } catch (e) {
        Navigator.pop(context);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = Responsive.isMobile(context);
    final double fontSize = Responsive.fontSize(context, 14);
    final double spacing = Responsive.spacing(context);
    final double iconSize = Responsive.iconSize(context, 24);

    final filteredUsers = _filteredUsers;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'User Management',
          style: TextStyle(
            fontSize: isMobile ? 16 : 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF173B69),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white, size: iconSize),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.add, size: iconSize),
            onPressed: () {
              Navigator.pushNamed(context, '/create-user');
            },
            tooltip: 'Add User',
          ),
          IconButton(
            icon: Icon(Icons.refresh, size: iconSize),
            onPressed: _loadUsers,
            tooltip: 'Refresh',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(isMobile ? 110 : 120),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: spacing * 2,
              vertical: spacing,
            ),
            child: Column(
              children: [
                TextField(
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                  style: TextStyle(fontSize: fontSize, color: Colors.black),
                  decoration: InputDecoration(
                    hintText: '🔍 Search users...',
                    hintStyle: TextStyle(fontSize: fontSize, color: Colors.grey),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: spacing,
                      vertical: isMobile ? 4 : 0,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear, size: iconSize - 6, color: Colors.black54),
                            onPressed: () {
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                  ),
                ),
                SizedBox(height: spacing),
                Row(
                  children: [
                    Icon(Icons.filter_list, color: Colors.white70, size: iconSize - 4),
                    SizedBox(width: spacing),
                    Expanded(
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: spacing),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: DropdownButton<String>(
                          value: _filterDepartment,
                          icon: Icon(
                            Icons.arrow_drop_down,
                            color: Colors.grey[700],
                            size: iconSize,
                          ),
                          underline: const SizedBox(),
                          isExpanded: true,
                          style: TextStyle(
                            fontSize: fontSize,
                            color: Colors.black,
                            fontWeight: FontWeight.w500,
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: 'all',
                              child: Text(
                                'All Departments',
                                style: TextStyle(color: Colors.black),
                              ),
                            ),
                            ..._departments.map((dept) {
                              return DropdownMenuItem(
                                value: dept['id']!,
                                child: Text(
                                  dept['name']!,
                                  style: const TextStyle(color: Colors.black),
                                ),
                              );
                            }),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _filterDepartment = value!;
                            });
                          },
                          dropdownColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : filteredUsers.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'No users found',
                        style: TextStyle(color: Colors.grey, fontSize: AppFonts.md),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.all(spacing * 1.5),
                  itemCount: filteredUsers.length,
                  itemBuilder: (context, index) {
                    final user = filteredUsers[index];
                    return _UserCard(
                      user: user,
                      onEdit: () => _showEditDialog(user),
                      onDelete: () => _showDeleteDialog(user),
                      isMobile: isMobile,
                      fontSize: fontSize,
                      spacing: spacing,
                    );
                  },
                ),
    );
  }
}

// ==================== USER CARD ====================
class _UserCard extends StatelessWidget {
  final UserModel user;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool isMobile;
  final double fontSize;
  final double spacing;

  const _UserCard({
    required this.user,
    required this.onEdit,
    required this.onDelete,
    required this.isMobile,
    required this.fontSize,
    required this.spacing,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.only(bottom: spacing),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 10 : 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: isMobile ? 22 : 30,
              backgroundColor: user.roleColor.withOpacity(0.2),
              child: Icon(
                Icons.person,
                color: user.roleColor,
                size: isMobile ? 22 : 30,
              ),
            ),
            SizedBox(width: spacing * 1.5),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.fullName,
                    style: TextStyle(
                      fontSize: isMobile ? fontSize : fontSize + 2,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    user.email,
                    style: TextStyle(
                      fontSize: isMobile ? fontSize * 0.85 : fontSize,
                      color: Colors.grey[600],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: spacing / 2),
                  Wrap(
                    spacing: spacing / 2,
                    runSpacing: spacing / 2,
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: spacing / 2,
                          vertical: spacing / 4,
                        ),
                        decoration: BoxDecoration(
                          color: user.roleColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          user.roleName,
                          style: TextStyle(
                            fontSize: isMobile ? fontSize * 0.8 : fontSize,
                            color: user.roleColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      if (user.department != null && user.department!.isNotEmpty)
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: spacing / 2,
                            vertical: spacing / 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            ' ${user.department}',
                            style: TextStyle(
                              fontSize: isMobile ? fontSize * 0.8 : fontSize,
                              color: Colors.blue[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: spacing / 2,
                          vertical: spacing / 4,
                        ),
                        decoration: BoxDecoration(
                          color: user.isActive
                              ? Colors.green.withOpacity(0.1)
                              : Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          user.status,
                          style: TextStyle(
                            fontSize: isMobile ? fontSize * 0.8 : fontSize,
                            color: user.isActive ? Colors.green : Colors.red,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Action Buttons
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: Icon(Icons.edit, color: Colors.blue, size: isMobile ? 18 : 20),
                  onPressed: onEdit,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                SizedBox(height: spacing / 2),
                IconButton(
                  icon: Icon(Icons.delete, color: Colors.red, size: isMobile ? 18 : 20),
                  onPressed: onDelete,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}