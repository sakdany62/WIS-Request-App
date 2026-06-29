// lib/screens/staff/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:permission_system/app_fonts.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? userData;
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    
    if (user == null) {
      setState(() {
        errorMessage = 'No user logged in';
        isLoading = false;
      });
      return;
    }
    
    try {
      print('🔍 Loading user data for UID: ${user.uid}');
      
      // Query user by userId
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('userId', isEqualTo: user.uid)
          .limit(1)
          .get();
      
      print('📊 Query snapshot size: ${querySnapshot.docs.length}');
      
      if (querySnapshot.docs.isNotEmpty) {
        final data = querySnapshot.docs.first.data();
        print('✅ User data found: $data');
        
        setState(() {
          userData = Map<String, dynamic>.from(data);
          isLoading = false;
        });
      } else {
        print('⚠️ No user document found for UID: ${user.uid}');
        setState(() {
          errorMessage = 'User profile not found in database';
          isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error loading user data: $e');
      setState(() {
        errorMessage = 'Failed to load user data: $e';
        isLoading = false;
      });
    }
  }

  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (context.mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Confirm Logout',
          style: TextStyle(fontSize: AppFonts.md, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to logout?',
          style: TextStyle(fontSize: AppFonts.md),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(fontSize: AppFonts.md),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _logout(context);
            },
            child: Text(
              'Confirm',
              style: TextStyle(fontSize: AppFonts.md, color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FA),
      appBar: AppBar(
        title: Text(
          'Profile',
          style: TextStyle(
            fontSize: AppFonts.md,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF173B69),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _showLogoutDialog(context),
          ),
        ],
      ),
      body: _buildBody(user),
    );
  }

  Widget _buildBody(User? user) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              errorMessage!,
              style: TextStyle(color: Colors.red, fontSize: AppFonts.md),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  isLoading = true;
                  errorMessage = null;
                });
                _loadUserData();
              },
              child: Text(
                'Retry',
                style: TextStyle(fontSize: AppFonts.md),
              ),
            ),
          ],
        ),
      );
    }
    
    if (userData == null) {
      return Center(
        child: Text(
          'No user data available',
          style: TextStyle(fontSize: AppFonts.md),
        ),
      );
    }
    
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 20),
          _buildProfileHeader(user),
          const SizedBox(height: 30),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Personal Information',
                  style: TextStyle(fontSize: AppFonts.md, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                _buildInfoCard(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(User? user) {
    return Center(
      child: Column(
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF173B69),
              border: Border.all(color: const Color(0xFF173B69), width: 3),
            ),
            child: const Icon(Icons.person, size: 50, color: Colors.white),
          ),
          const SizedBox(height: 16),
          Text(
            userData?['fullName'] ?? userData?['username'] ?? 'Staff User',
            style: TextStyle(fontSize: AppFonts.md, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            userData?['email'] ?? user?.email ?? 'staff@westland.com',
            style: TextStyle(fontSize: AppFonts.md, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF173B69).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _getRoleName(userData?['roleId']?.toString()),
              style: TextStyle(fontSize: AppFonts.md, color: const Color(0xFF173B69)),
            ),
          ),
        ],
      ),
    );
  }

  String _getRoleName(String? roleId) {
    switch (roleId) {
      case '1':
        return 'Executive Director';
      case '2':
        return 'Staff';
      case '3':
        return 'Manager';
      case '4':
        return 'Head of Department';
      default:
        return 'Staff';
    }
  }

  // Helper method to safely get a value from userData
  String _getValue(String key, [String? fallbackKey]) {
    final String defaultValue = 'N/A';
    
    if (userData != null && userData!.containsKey(key) && userData![key] != null && userData![key]!.toString().isNotEmpty) {
      return userData![key].toString();
    }
    if (fallbackKey != null && userData != null && userData!.containsKey(fallbackKey) && userData![fallbackKey] != null) {
      return userData![fallbackKey].toString();
    }
    return defaultValue;
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    
    try {
      if (timestamp is Timestamp) {
        final date = timestamp.toDate();
        return '${date.day}/${date.month}/${date.year}';
      } else if (timestamp is DateTime) {
        return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
      }
    } catch (e) {
      print('Error formatting date: $e');
    }
    return 'N/A';
  }

  Widget _buildInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _InfoRow(label: 'Employee ID', value: _getValue('employeeId', 'userId')),
          const Divider(),
          _InfoRow(label: 'User ID', value: _getValue('userId')),
          const Divider(),
          _InfoRow(label: 'Username', value: _getValue('username')),
          const Divider(),
          _InfoRow(label: 'Full Name', value: _getValue('fullName')),
          const Divider(),
          _InfoRow(label: 'Email', value: _getValue('email')),
          const Divider(),
          _InfoRow(label: 'Phone', value: _getValue('phone')),
          const Divider(),
          _InfoRow(label: 'Department', value: _getValue('department')),
          const Divider(),
          _InfoRow(label: 'Position', value: _getValue('position')),
          const Divider(),
          _InfoRow(label: 'Role', value: _getRoleName(userData?['roleId']?.toString())),
          const Divider(),
          _InfoRow(label: 'Status', value: _getValue('status')),
          const Divider(),
          _InfoRow(
            label: 'Member Since', 
            value: _formatDate(userData?['createdAt']),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4, 
            child: Text(
              label, 
              style: TextStyle(
                color: Colors.grey,
                fontSize: AppFonts.md,
              ),
            ),
          ),
          Expanded(
            flex: 6, 
            child: Text(
              value, 
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: AppFonts.md,
              ),
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }
}