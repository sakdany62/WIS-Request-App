// ============================================================
// lib/screens/staff/staff_profile_screen.dart
// ============================================================
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cross_file/cross_file.dart';
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
  StreamSubscription<DocumentSnapshot>? _userSubscription;

  @override
  void initState() {
    super.initState();
    _listenToUserData();
  }

  // 👇 ប្រើ Stream ដើម្បីស្តាប់ការផ្លាស់ប្តូរ Real-time
  void _listenToUserData() {
    final user = FirebaseAuth.instance.currentUser;
    
    if (user == null) {
      setState(() {
        errorMessage = 'No user logged in';
        isLoading = false;
      });
      return;
    }
    
    setState(() {
      isLoading = true;
    });
    
    _userSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen(
      (docSnapshot) {
        if (docSnapshot.exists) {
          final data = docSnapshot.data()!;
          print('🔄 Staff data updated: $data');
          
          setState(() {
            userData = Map<String, dynamic>.from(data);
            profileImageUrl = data['profileImageUrl'] ?? data['profileImage'] ?? '';
            isLoading = false;
            errorMessage = null;
          });
        } else {
          setState(() {
            errorMessage = 'Staff profile not found in database';
            isLoading = false;
          });
        }
      },
      onError: (error) {
        print('❌ Error listening to staff data: $error');
        setState(() {
          errorMessage = 'Failed to load staff data: $error';
          isLoading = false;
        });
      },
    );
  }

  Future<void> _pickAndUploadImage() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnackBar('Please login first', Colors.red);
      return;
    }

    final bool isMobile = Responsive.isMobile(context);
    final double fontSize = Responsive.fontSize(context, 14);

    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Choose Image Source',
          style: TextStyle(
            fontSize: isMobile ? fontSize : fontSize + 2,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library, color: Color(0xFF173B69)),
              title: Text(
                'Gallery',
                style: TextStyle(fontSize: fontSize),
              ),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFF173B69)),
              title: Text(
                'Camera',
                style: TextStyle(fontSize: fontSize),
              ),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(fontSize: fontSize),
            ),
          ),
        ],
      ),
    );

    if (choice == null) return;

    try {
      final XFile? image = await _imagePicker.pickImage(
        source: choice == 'camera' ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 500,
        maxHeight: 500,
        imageQuality: 80,
      );

      if (image == null) return;

      setState(() {
        isUploading = true;
      });

      final String imageUrl = await _uploadImageToStorage(image, user.uid);
      await _updateProfileImageUrl(imageUrl);

      setState(() {
        profileImageUrl = imageUrl;
        userData?['profileImageUrl'] = imageUrl;
        isUploading = false;
      });

      _showSnackBar('Profile image updated successfully!', Colors.green);
    } catch (e) {
      setState(() {
        isUploading = false;
      });
      _showSnackBar('Error uploading image: $e', Colors.red);
      print('❌ Image upload error: $e');
    }
  }

  Future<String> _uploadImageToStorage(XFile image, String userId) async {
    try {
      final bytes = await image.readAsBytes();
      
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('profile_images')
          .child('$userId.jpg');

      final uploadTask = storageRef.putData(
        bytes,
        SettableMetadata(
          contentType: 'image/jpeg',
          cacheControl: 'public,max-age=3600',
        ),
      );
      
      final snapshot = await uploadTask.whenComplete(() => {});
      final downloadUrl = await snapshot.ref.getDownloadURL();
      
      print(' Image uploaded successfully: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      print('❌ Error uploading image: $e');
      throw Exception('Failed to upload image: $e');
    }
  }

  Future<void> _updateProfileImageUrl(String imageUrl) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
            'profileImageUrl': imageUrl,
            'updatedAt': FieldValue.serverTimestamp(),
          });
      
      print(' database updated with profile image URL');
    } catch (e) {
      print(' Error updating Firestore: $e');
      throw Exception('Failed to update profile: $e');
    }
  }

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

    try {
      setState(() {
        isUploading = true;
      });

      final storageRef = FirebaseStorage.instance
          .ref()
          .child('profile_images')
          .child('${user.uid}.jpg');
      
      try {
        await storageRef.delete();
        print(' Image deleted from storage');
      } catch (e) {
        print('No image to delete or error: $e');
      }

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
  void dispose() {
    _userSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = Responsive.isMobile(context);
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
                _listenToUserData();
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

  Widget _buildProfileHeader(User? user) {
    final bool isMobile = Responsive.isMobile(context);
    final double fontSize = Responsive.fontSize(context, 14);
    final double spacing = Responsive.spacing(context);
    final double iconSize = Responsive.iconSize(context, 24);
    final double avatarSize = isMobile ? 100 : 120;
    final double avatarIconSize = isMobile ? 50 : 60;
    final double cameraIconSize = isMobile ? 18 : 22;
    final double cameraPadding = isMobile ? 8 : 10;

    return Center(
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: avatarSize,
                height: avatarSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.blue,
                  border: Border.all(color: Colors.blue, width: 4),
                  image: (profileImageUrl != null && profileImageUrl!.isNotEmpty)
                      ? DecorationImage(
                          image: NetworkImage(profileImageUrl!),
                          fit: BoxFit.cover,
                          onError: (exception, stackTrace) {
                            print('⚠️ Error loading image: $exception');
                          },
                        )
                      : null,
                ),
                child: (profileImageUrl == null || profileImageUrl!.isEmpty)
                    ? Icon(
                        Icons.person,
                        size: avatarIconSize,
                        color: Colors.white,
                      )
                    : null,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: isUploading ? null : _pickAndUploadImage,
                  child: Container(
                    padding: EdgeInsets.all(cameraPadding),
                    decoration: BoxDecoration(
                      color: Colors.blue,
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
                            Icons.camera_alt,
                            color: Colors.white,
                            size: cameraIconSize,
                          ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: spacing * 1.5),
          
          if (profileImageUrl != null && profileImageUrl!.isNotEmpty)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton.icon(
                  onPressed: isUploading ? null : _deleteProfileImage,
                  icon: Icon(
                    Icons.delete_outline,
                    color: Colors.red,
                    size: iconSize - 6,
                  ),
                  label: Text(
                    'Remove Image',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: isMobile ? fontSize * 0.85 : fontSize,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.symmetric(
                      horizontal: spacing * 2,
                      vertical: spacing,
                    ),
                  ),
                ),
              ],
            ),
          
          SizedBox(height: spacing),
          
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
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              ' Staff',
              style: TextStyle(
                fontSize: isMobile ? fontSize * 0.85 : fontSize,
                color: Colors.blue,
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
          _InfoRow(
            label: 'User ID',
            value: _getValue('userId'),
            isMobile: isMobile,
            fontSize: fontSize,
          ),
          _buildDivider(),
          _InfoRow(
            label: 'Username',
            value: _getValue('username'),
            isMobile: isMobile,
            fontSize: fontSize,
          ),
          _buildDivider(),
          _InfoRow(
            label: 'Full Name',
            value: _getValue('fullName'),
            isMobile: isMobile,
            fontSize: fontSize,
          ),
          _buildDivider(),
          _InfoRow(
            label: 'Email',
            value: _getValue('email'),
            isMobile: isMobile,
            fontSize: fontSize,
          ),
          _buildDivider(),
          _InfoRow(
            label: 'Phone',
            value: _getValue('phone'),
            isMobile: isMobile,
            fontSize: fontSize,
          ),
          _buildDivider(),
          _InfoRow(
            label: 'Department',
            value: _getValue('department'),
            isMobile: isMobile,
            fontSize: fontSize,
          ),
          _buildDivider(),
          _InfoRow(
            label: 'Position',
            value: _getValue('position'),
            isMobile: isMobile,
            fontSize: fontSize,
          ),
          _buildDivider(),
          _InfoRow(
            label: 'Status',
            value: _getValue('status'),
            isMobile: isMobile,
            fontSize: fontSize,
          ),
          _buildDivider(),
          _InfoRow(
            label: 'Member Since',
            value: _formatDate(userData?['createdAt']),
            isMobile: isMobile,
            fontSize: fontSize,
          ),
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
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isMobile;
  final double fontSize;

  const _InfoRow({
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