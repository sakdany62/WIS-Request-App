// lib/screens/staff/profile_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_system/screens/staff/staff_home_screen.dart';
import '../../app_fonts.dart';
import '../../utils/responsive.dart';

class StaffProfileScreen extends StatefulWidget {
  const StaffProfileScreen({super.key});

  @override
  State<StaffProfileScreen> createState() => _StaffProfileScreenState();
}

class _StaffProfileScreenState extends State<StaffProfileScreen> {
  Map<String, dynamic>? userData;
  bool isLoading = true;
  bool isUploading = false;
  String? errorMessage;
  String? profileImageUrl;
  final ImagePicker _imagePicker = ImagePicker();

  // ===== Change Password Variables =====
  bool isChangingPassword = false;
  final TextEditingController currentPasswordController = TextEditingController();
  final TextEditingController newPasswordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();
  bool obscureCurrentPassword = true;
  bool obscureNewPassword = true;
  bool obscureConfirmPassword = true;
  String _passwordError = '';

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
      print('🔍 Loading staff data for UID: ${user.uid}');
      
      final docSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      if (docSnapshot.exists) {
        final data = docSnapshot.data()!;
        print('✅ Staff data found: $data');
        
        setState(() {
          userData = Map<String, dynamic>.from(data);
          profileImageUrl = data['profileImageUrl'] ?? data['profileImage'] ?? '';
          isLoading = false;
        });
      } else {
        print('⚠️ No staff document found for UID: ${user.uid}');
        setState(() {
          errorMessage = 'Staff profile not found in database';
          isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error loading staff data: $e');
      setState(() {
        errorMessage = 'Failed to load staff data: $e';
        isLoading = false;
      });
    }
  }

  // ===== CHANGE PASSWORD METHOD WITH DIALOG STATE =====
  Future<void> _changePasswordWithDialog(StateSetter setDialogState) async {
    // Clear previous error
    setDialogState(() {
      _passwordError = '';
    });

    String currentPassword = currentPasswordController.text.trim();
    String newPassword = newPasswordController.text.trim();
    String confirmPassword = confirmPasswordController.text.trim();

    // Validate inputs
    if (currentPassword.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty) {
      setDialogState(() {
        _passwordError = 'Please fill in all password fields';
      });
      return;
    }

    if (newPassword.length < 6) {
      setDialogState(() {
        _passwordError = 'New password must be at least 6 characters';
      });
      return;
    }

    if (newPassword != confirmPassword) {
      setDialogState(() {
        _passwordError = 'New passwords do not match';
      });
      return;
    }

    setDialogState(() {
      isChangingPassword = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setDialogState(() {
          _passwordError = 'No user logged in';
          isChangingPassword = false;
        });
        return;
      }

      // Re-authenticate user before changing password
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      
      await user.reauthenticateWithCredential(credential);
      
      // Change password
      await user.updatePassword(newPassword);
      
      // Clear password fields
      currentPasswordController.clear();
      newPasswordController.clear();
      confirmPasswordController.clear();
      
      setDialogState(() {
        isChangingPassword = false;
        _passwordError = '';
      });

      // Show success message
      _showSnackBar(' Password changed successfully!', Colors.green);
      
      // Close dialog
      Navigator.pop(context);
      
    } on FirebaseAuthException catch (e) {
      setDialogState(() {
        isChangingPassword = false;
      });
      
      String errorMessage = 'Failed to change password';
      if (e.code == 'wrong-password') {
        errorMessage = 'Current password is incorrect';
      } else if (e.code == 'too-many-requests') {
        errorMessage = 'Too many attempts. Please try again later';
      } else if (e.code == 'requires-recent-login') {
        errorMessage = 'Please log out and log in again to change password';
      } else {
        errorMessage = e.message ?? 'Failed to change password';
      }
      
      setDialogState(() {
        _passwordError = errorMessage;
      });
      
      _showSnackBar(' $errorMessage', Colors.red);
    } catch (e) {
      setDialogState(() {
        isChangingPassword = false;
        _passwordError = 'An error occurred: $e';
      });
      _showSnackBar(' Error: $e', Colors.red);
    }
  }

  // ===== SHOW CHANGE PASSWORD DIALOG =====
  void _showChangePasswordDialog() {
    final bool isMobile = Responsive.isMobile(context);
    final double fontSize = Responsive.fontSize(context, 14);
    final double spacing = Responsive.spacing(context);

    // Reset controllers and errors when opening
    currentPasswordController.clear();
    newPasswordController.clear();
    confirmPasswordController.clear();
    
    // Reset password error and visibility states
    _passwordError = '';
    obscureCurrentPassword = true;
    obscureNewPassword = true;
    obscureConfirmPassword = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        // ===== USE StatefulBuilder =====
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AlertDialog(
              title: Text(
                'Change Password',
                style: TextStyle(
                  fontSize: isMobile ? fontSize : fontSize + 2,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF173B69),
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Error message
                    if (_passwordError.isNotEmpty)
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(spacing),
                        margin: EdgeInsets.only(bottom: spacing),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade300),
                        ),
                        child: Text(
                          _passwordError,
                          style: TextStyle(
                            fontSize: fontSize,
                            color: Colors.red.shade700,
                          ),
                        ),
                      ),
                    
                    // Current Password
                    Text(
                      'Current Password',
                      style: TextStyle(
                        fontSize: fontSize * 0.9,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    SizedBox(height: spacing / 2),
                    TextField(
                      controller: currentPasswordController,
                      obscureText: obscureCurrentPassword,
                      style: TextStyle(fontSize: fontSize),
                      decoration: InputDecoration(
                        hintText: 'Enter current password',
                        hintStyle: TextStyle(fontSize: fontSize, color: Colors.grey.shade400),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureCurrentPassword ? Icons.visibility : Icons.visibility_off,
                            size: 20,
                          ),
                          onPressed: () {
                            setDialogState(() {
                              obscureCurrentPassword = !obscureCurrentPassword;
                            });
                          },
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: spacing * 1.5,
                          vertical: isMobile ? 12 : 14,
                        ),
                      ),
                    ),
                    
                    SizedBox(height: spacing * 1.5),
                    
                    // New Password
                    Text(
                      'New Password',
                      style: TextStyle(
                        fontSize: fontSize * 0.9,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    SizedBox(height: spacing / 2),
                    TextField(
                      controller: newPasswordController,
                      obscureText: obscureNewPassword,
                      style: TextStyle(fontSize: fontSize),
                      decoration: InputDecoration(
                        hintText: 'Enter new password (min 6 chars)',
                        hintStyle: TextStyle(fontSize: fontSize, color: Colors.grey.shade400),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureNewPassword ? Icons.visibility : Icons.visibility_off,
                            size: 20,
                          ),
                          onPressed: () {
                            setDialogState(() {
                              obscureNewPassword = !obscureNewPassword;
                            });
                          },
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: spacing * 1.5,
                          vertical: isMobile ? 12 : 14,
                        ),
                      ),
                    ),
                    
                    SizedBox(height: spacing * 1.5),
                    
                    // Confirm Password
                    Text(
                      'Confirm New Password',
                      style: TextStyle(
                        fontSize: fontSize * 0.9,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    SizedBox(height: spacing / 2),
                    TextField(
                      controller: confirmPasswordController,
                      obscureText: obscureConfirmPassword,
                      style: TextStyle(fontSize: fontSize),
                      onSubmitted: (_) => _changePasswordWithDialog(setDialogState),
                      decoration: InputDecoration(
                        hintText: 'Confirm new password',
                        hintStyle: TextStyle(fontSize: fontSize, color: Colors.grey.shade400),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
                            size: 20,
                          ),
                          onPressed: () {
                            setDialogState(() {
                              obscureConfirmPassword = !obscureConfirmPassword;
                            });
                          },
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: spacing * 1.5,
                          vertical: isMobile ? 12 : 14,
                        ),
                      ),
                    ),
                    
                    SizedBox(height: spacing / 2),
                    Text(
                      'Password must be at least 6 characters',
                      style: TextStyle(
                        fontSize: fontSize * 0.75,
                        color: Colors.grey.shade500,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isChangingPassword ? null : () {
                    setDialogState(() {
                      _passwordError = '';
                    });
                    Navigator.pop(context);
                  },
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      fontSize: fontSize,
                      color: isChangingPassword ? Colors.grey : Colors.grey.shade700,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: isChangingPassword ? null : () {
                    _changePasswordWithDialog(setDialogState);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF173B69),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: isChangingPassword
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'Update Password',
                          style: TextStyle(fontSize: fontSize),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ✅ URL Dialog
  Future<void> _showUrlDialog() async {
    final bool isMobile = Responsive.isMobile(context);
    final double fontSize = Responsive.fontSize(context, 14);
    final double spacing = Responsive.spacing(context);

    final TextEditingController urlController = TextEditingController();
    urlController.text = profileImageUrl ?? '';

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Enter Image URL',
          style: TextStyle(
            fontSize: isMobile ? fontSize : fontSize + 2,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Paste the URL of your profile image',
              style: TextStyle(
                fontSize: fontSize,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: spacing),
            TextField(
              controller: urlController,
              decoration: InputDecoration(
                hintText: 'https://example.com/profile.jpg',
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
              keyboardType: TextInputType.url,
            ),
            SizedBox(height: spacing / 2),
            Text(
              ' You can use images from: Facebook, Google Drive, etc.',
              style: TextStyle(
                fontSize: fontSize * 0.8,
                color: Colors.blue[700],
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
          ElevatedButton(
            onPressed: () async {
              final url = urlController.text.trim();
              if (url.isNotEmpty) {
                await _updateProfileImageUrl(url);
                Navigator.pop(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Please enter a valid URL',
                      style: TextStyle(fontSize: fontSize),
                    ),
                    backgroundColor: Colors.orange,
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
              'Save',
              style: TextStyle(fontSize: fontSize),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ Update Profile Image
  Future<void> _updateProfileImageUrl(String imageUrl) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      isUploading = true;
    });

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
            'profileImageUrl': imageUrl,
            'updatedAt': FieldValue.serverTimestamp(),
          });
      
      setState(() {
        profileImageUrl = imageUrl;
        userData?['profileImageUrl'] = imageUrl;
        isUploading = false;
      });

      _showSnackBar(' Profile image updated successfully!', Colors.green);
      
      Navigator.pop(context, true);
      
    } catch (e) {
      setState(() {
        isUploading = false;
      });
      _showSnackBar('❌ Error: $e', Colors.red);
      print('❌ Error updating profile: $e');
    }
  }

  // ✅ Delete Profile Image
  Future<void> _deleteProfileImage() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final bool isMobile = Responsive.isMobile(context);
    final double fontSize = Responsive.fontSize(context, 14);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Delete Profile Image',
          style: TextStyle(
            fontSize: isMobile ? fontSize : fontSize + 2,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Are you sure you want to delete your profile image?',
          style: TextStyle(fontSize: fontSize),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(fontSize: fontSize),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Delete',
              style: TextStyle(fontSize: fontSize, color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      isUploading = true;
    });

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
            'profileImageUrl': '',
            'updatedAt': FieldValue.serverTimestamp(),
          });

      setState(() {
        profileImageUrl = null;
        userData?['profileImageUrl'] = '';
        isUploading = false;
      });

      _showSnackBar('Profile image deleted successfully', Colors.orange);
      
      Navigator.pop(context, true);
      
    } catch (e) {
      setState(() {
        isUploading = false;
      });
      _showSnackBar('Error deleting image: $e', Colors.red);
      print('❌ Image deletion error: $e');
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(fontSize: AppFonts.md),
        ),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  //  Show Image Picker Dialog
  Future<void> _showImagePickerDialog() async {
    final bool isMobile = Responsive.isMobile(context);
    final double fontSize = Responsive.fontSize(context, 14);

    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.link, color: const Color(0xFF173B69)),
              title: Text(
                'Enter Image URL',
                style: TextStyle(fontSize: fontSize),
              ),
              onTap: () {
                Navigator.pop(context);
                _showUrlDialog();
              },
            ),
            if (profileImageUrl != null && profileImageUrl!.isNotEmpty) ...[
              const Divider(),
              ListTile(
                leading: Icon(Icons.delete, color: Colors.red),
                title: Text(
                  'Remove Photo',
                  style: TextStyle(fontSize: fontSize, color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _deleteProfileImage();
                },
              ),
            ],
            const Divider(),
            ListTile(
              leading: Icon(Icons.close, color: Colors.grey),
              title: Text(
                'Cancel',
                style: TextStyle(fontSize: fontSize, color: Colors.grey),
              ),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (context.mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  void _showLogoutDialog() {
    final bool isMobile = Responsive.isMobile(context);
    final double fontSize = Responsive.fontSize(context, 14);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Confirm Logout',
          style: TextStyle(
            fontSize: isMobile ? fontSize : fontSize + 2,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Are you sure you want to logout?',
          style: TextStyle(fontSize: fontSize),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(fontSize: fontSize),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _logout();
            },
            child: Text(
              'Confirm',
              style: TextStyle(fontSize: fontSize, color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = Responsive.isMobile(context);
    final double fontSize = Responsive.fontSize(context, 14);
    final double spacing = Responsive.spacing(context);
    final double iconSize = Responsive.iconSize(context, 24);

    final user = FirebaseAuth.instance.currentUser;
    
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FA),
      appBar: AppBar(
        title: Text(
          'Staff Profile',
          style: TextStyle(
            fontSize: isMobile ? 16 : 18,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF173B69),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.logout, size: iconSize),
            onPressed: _showLogoutDialog,
          ),
        ],
      ),
      body: _buildBody(user),
    );
  }

  Widget _buildBody(User? user) {
    final bool isMobile = Responsive.isMobile(context);
    final double fontSize = Responsive.fontSize(context, 14);
    final double spacing = Responsive.spacing(context);

    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            SizedBox(height: spacing * 2),
            Text(
              errorMessage!,
              style: TextStyle(color: Colors.red, fontSize: fontSize),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: spacing * 2),
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
                style: TextStyle(fontSize: fontSize),
              ),
            ),
          ],
        ),
      );
    }
    
    if (userData == null) {
      return Center(
        child: Text(
          'No staff data available',
          style: TextStyle(fontSize: fontSize),
        ),
      );
    }
    
    return SingleChildScrollView(
      child: Column(
        children: [
          SizedBox(height: spacing * 2.5),
          _buildProfileHeader(user),
          SizedBox(height: spacing * 3),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: spacing * 2.5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Staff Information',
                  style: TextStyle(
                    fontSize: isMobile ? fontSize : fontSize + 2,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: spacing * 1.5),
                _buildInfoCard(),
              ],
            ),
          ),
          SizedBox(height: isMobile ? 60 : 80),
        ],
      ),
    );
  }

  // Profile Header
  Widget _buildProfileHeader(User? user) {
    final bool isMobile = Responsive.isMobile(context);
    final double fontSize = Responsive.fontSize(context, 14);
    final double spacing = Responsive.spacing(context);
    final double iconSize = Responsive.iconSize(context, 24);
    final double avatarSize = isMobile ? 100 : 120;
    final double avatarIconSize = isMobile ? 50 : 60;
    final double cameraIconSize = isMobile ? 18 : 22;
    final double cameraPadding = isMobile ? 8 : 10;

    String getInitials() {
      final name = userData?['fullName'] ?? userData?['username'] ?? 'Staff';
      if (name.isEmpty) return 'S';
      final parts = name.split(' ');
      if (parts.length >= 2) {
        return parts[0][0].toUpperCase() + parts[1][0].toUpperCase();
      }
      return parts[0][0].toUpperCase();
    }

    return Center(
      child: Column(
        children: [
          Stack(
            children: [
              GestureDetector(
                onTap: isUploading ? null : _showImagePickerDialog,
                child: CircleAvatar(
                  radius: avatarSize / 2,
                  backgroundColor: const Color(0xFF173B69),
                  backgroundImage: (profileImageUrl != null && profileImageUrl!.isNotEmpty)
                      ? NetworkImage(profileImageUrl!)
                      : null,
                  child: (profileImageUrl == null || profileImageUrl!.isEmpty)
                      ? Text(
                          getInitials(),
                          style: TextStyle(
                            fontSize: avatarIconSize * 0.6,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        )
                      : null,
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: isUploading ? null : _showImagePickerDialog,
                  child: Container(
                    padding: EdgeInsets.all(cameraPadding),
                    decoration: BoxDecoration(
                      color: const Color(0xFF173B69),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                    child: isUploading
                        ? SizedBox(
                            width: iconSize - 4,
                            height: iconSize - 4,
                            child: const CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(
                            Icons.edit,
                            color: Colors.white,
                            size: cameraIconSize,
                          ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: spacing * 1.5),
          Text(
            userData?['fullName'] ?? userData?['username'] ?? 'Staff User',
            style: TextStyle(
              fontSize: isMobile ? fontSize + 2 : fontSize + 4,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: spacing / 2),
          Text(
            userData?['email'] ?? user?.email ?? 'staff@westland.com',
            style: TextStyle(
              fontSize: isMobile ? fontSize * 0.85 : fontSize,
              color: Colors.grey,
            ),
          ),
          SizedBox(height: spacing),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: spacing * 1.5,
              vertical: spacing / 2,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF173B69).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Staff',
              style: TextStyle(
                fontSize: isMobile ? fontSize * 0.85 : fontSize,
                color: const Color(0xFF173B69),
              ),
            ),
          ),
        ],
      ),
    );
  }

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

  // ===== BUILD INFO CARD WITH CHANGE PASSWORD BUTTON =====
  Widget _buildInfoCard() {
    final bool isMobile = Responsive.isMobile(context);
    final double fontSize = Responsive.fontSize(context, 14);
    final double spacing = Responsive.spacing(context);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(spacing * 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _InfoRowStaff(
            label: 'Employee ID',
            value: _getValue('employeeId', 'userId'),
            isMobile: isMobile,
            fontSize: fontSize,
          ),
          _buildDivider(),
          _InfoRowStaff(
            label: 'Username',
            value: _getValue('username'),
            isMobile: isMobile,
            fontSize: fontSize,
          ),
          _buildDivider(),
          _InfoRowStaff(
            label: 'Full Name',
            value: _getValue('fullName'),
            isMobile: isMobile,
            fontSize: fontSize,
          ),
          _buildDivider(),
          _InfoRowStaff(
            label: 'Email',
            value: _getValue('email'),
            isMobile: isMobile,
            fontSize: fontSize,
          ),
          _buildDivider(),
          _InfoRowStaff(
            label: 'Phone',
            value: _getValue('phone'),
            isMobile: isMobile,
            fontSize: fontSize,
          ),
          _buildDivider(),
          _InfoRowStaff(
            label: 'Department',
            value: _getValue('department'),
            isMobile: isMobile,
            fontSize: fontSize,
          ),
          _buildDivider(),
          _InfoRowStaff(
            label: 'Position',
            value: _getValue('position'),
            isMobile: isMobile,
            fontSize: fontSize,
          ),
          _buildDivider(),
          _InfoRowStaff(
            label: 'Role',
            value: 'Staff',
            isMobile: isMobile,
            fontSize: fontSize,
          ),
          _buildDivider(),
          _InfoRowStaff(
            label: 'Status',
            value: _getValue('status'),
            isMobile: isMobile,
            fontSize: fontSize,
          ),
          _buildDivider(),
          _InfoRowStaff(
            label: 'Member Since',
            value: _formatDate(userData?['createdAt']),
            isMobile: isMobile,
            fontSize: fontSize,
          ),
          
          // ===== CHANGE PASSWORD BUTTON =====
          SizedBox(height: spacing * 2),
          Divider(
            height: 1,
            thickness: 1,
            color: Colors.grey.shade300,
          ),
          SizedBox(height: spacing * 1.5),
          
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _showChangePasswordDialog,
              icon: Icon(
                Icons.lock_outline,
                size: Responsive.iconSize(context, 20),
                color: Colors.white,
              ),
              label: Text(
                'Change Password',
                style: TextStyle(
                  fontSize: isMobile ? fontSize : fontSize + 2,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF173B69),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  vertical: isMobile ? 14 : 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          
          SizedBox(height: spacing / 2),
          
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 0.5,
      color: Colors.grey.shade300,
      indent: 0,
      endIndent: 0,
    );
  }

  @override
  void dispose() {
    currentPasswordController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }
}

class _InfoRowStaff extends StatelessWidget {
  final String label;
  final String value;
  final bool isMobile;
  final double fontSize;

  const _InfoRowStaff({
    required this.label,
    required this.value,
    required this.isMobile,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: isMobile ? 6 : 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: isMobile ? fontSize * 0.85 : fontSize,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          Expanded(
            flex: 6,
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: isMobile ? fontSize * 0.85 : fontSize,
                color: Colors.grey.shade800,
              ),
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }
}