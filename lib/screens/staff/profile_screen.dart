// lib/screens/staff/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cross_file/cross_file.dart';
import 'package:permission_system/app_fonts.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? userData;
  bool isLoading = true;
  bool isUploading = false;
  String? errorMessage;
  String? profileImageUrl;
  final ImagePicker _imagePicker = ImagePicker();

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
          profileImageUrl = data['profileImageUrl'] ?? '';
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

  // ============================================================
  // PICK AND UPLOAD PROFILE IMAGE
  // ============================================================
  Future<void> _pickAndUploadImage() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnackBar('Please login first', Colors.red);
      return;
    }

    // Show options: Camera or Gallery
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Choose Image Source',
          style: TextStyle(fontSize: AppFonts.md, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library, color: Color(0xFF173B69)),
              title: Text('Gallery', style: TextStyle(fontSize: AppFonts.md)),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFF173B69)),
              title: Text('Camera', style: TextStyle(fontSize: AppFonts.md)),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(fontSize: AppFonts.md)),
          ),
        ],
      ),
    );

    if (choice == null) return;

    try {
      // Pick image
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

      // Upload to Firebase Storage
      final String imageUrl = await _uploadImageToStorage(image, user.uid);
      
      // Update Firestore with the new image URL
      await _updateProfileImageUrl(imageUrl);

      setState(() {
        profileImageUrl = imageUrl;
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

  // ============================================================
  // UPLOAD IMAGE TO FIREBASE STORAGE - FIXED FOR WEB
  // ============================================================
  Future<String> _uploadImageToStorage(XFile image, String userId) async {
    try {
      // Read image as bytes (works on both Mobile and Web)
      final bytes = await image.readAsBytes();
      
      // Create a reference to the file
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('profile_images')
          .child('$userId.jpg');

      // Upload bytes directly (Works on all platforms)
      final uploadTask = storageRef.putData(
        bytes,
        SettableMetadata(
          contentType: 'image/jpeg',
          cacheControl: 'public,max-age=3600',
        ),
      );
      
      // Wait for upload to complete
      final snapshot = await uploadTask.whenComplete(() => {});
      
      // Get download URL
      final downloadUrl = await snapshot.ref.getDownloadURL();
      
      print('✅ Image uploaded successfully: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      print('❌ Error uploading image: $e');
      throw Exception('Failed to upload image: $e');
    }
  }

  // ============================================================
  // UPDATE FIRESTORE WITH IMAGE URL
  // ============================================================
  Future<void> _updateProfileImageUrl(String imageUrl) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Find the user document
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('userId', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final docRef = querySnapshot.docs.first.reference;
        
        // Update the document with the new image URL
        await docRef.update({
          'profileImageUrl': imageUrl,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        
        print('✅ Firestore updated with profile image URL');
        
        // Update local userData
        setState(() {
          userData?['profileImageUrl'] = imageUrl;
        });
      } else {
        throw Exception('User document not found');
      }
    } catch (e) {
      print('❌ Error updating Firestore: $e');
      throw Exception('Failed to update profile: $e');
    }
  }

  // ============================================================
  // DELETE PROFILE IMAGE
  // ============================================================
  Future<void> _deleteProfileImage() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Confirm deletion
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Delete Profile Image',
          style: TextStyle(fontSize: AppFonts.md, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to delete your profile image?',
          style: TextStyle(fontSize: AppFonts.md),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(fontSize: AppFonts.md)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Delete',
              style: TextStyle(fontSize: AppFonts.md, color: Colors.red),
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

      // Delete from Firebase Storage
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('profile_images')
          .child('${user.uid}.jpg');
      
      try {
        await storageRef.delete();
        print('✅ Image deleted from storage');
      } catch (e) {
        print('⚠️ No image to delete or error: $e');
      }

      // Update Firestore - remove the image URL
      await _updateProfileImageUrl('');

      setState(() {
        profileImageUrl = null;
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

  // ============================================================
  // SHOW SNACKBAR
  // ============================================================
  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(fontSize: AppFonts.md)),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
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
          // ===== PROFILE IMAGE WITH UPLOAD BUTTON =====
          Stack(
            children: [
              // Profile Image Container
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF173B69),
                  border: Border.all(color: const Color(0xFF173B69), width: 4),
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
                    ? const Icon(Icons.person, size: 60, color: Colors.white)
                    : null,
              ),
              
              // Upload/Edit Button (Camera Icon)
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: isUploading ? null : _pickAndUploadImage,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF173B69),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                    child: isUploading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 22,
                          ),
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Image Actions (Delete if image exists)
          if (profileImageUrl != null && profileImageUrl!.isNotEmpty)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton.icon(
                  onPressed: isUploading ? null : _deleteProfileImage,
                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                  label: Text(
                    'Remove Image',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: AppFonts.md,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                ),
              ],
            ),
          
          const SizedBox(height: 8),
          
          // User Name
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
          _InfoRow(label: 'Employee ID', value: _getValue('employeeId', 'userId')),
          _buildDivider(),
          _InfoRow(label: 'User ID', value: _getValue('userId')),
          _buildDivider(),
          _InfoRow(label: 'Username', value: _getValue('username')),
          _buildDivider(),
          _InfoRow(label: 'Full Name', value: _getValue('fullName')),
          _buildDivider(),
          _InfoRow(label: 'Email', value: _getValue('email')),
          _buildDivider(),
          _InfoRow(label: 'Phone', value: _getValue('phone')),
          _buildDivider(),
          _InfoRow(label: 'Department', value: _getValue('department')),
          _buildDivider(),
          _InfoRow(label: 'Position', value: _getValue('position')),
          _buildDivider(),
          _InfoRow(label: 'Role', value: _getRoleName(userData?['roleId']?.toString())),
          _buildDivider(),
          _InfoRow(label: 'Status', value: _getValue('status')),
          _buildDivider(),
          _InfoRow(
            label: 'Member Since', 
            value: _formatDate(userData?['createdAt']),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CUSTOM DIVIDER WITH LIGHTER COLOR AND THINNER LINE
  // ============================================================
  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 0.5,          // ស្តើងជាងមុន
      color: Colors.grey.shade300,  // ពណ៌ស្រាលជាងមុន
      indent: 0,
      endIndent: 0,
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
      padding: const EdgeInsets.symmetric(vertical: 10), // បន្ថែមចន្លោះបន្តិច
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4, 
            child: Text(
              label, 
              style: TextStyle(
                color: Colors.grey.shade600,  // ពណ៌ស្រាលជាងមុន
                fontSize: AppFonts.md,
                fontWeight: FontWeight.w400,   // មិនដិត
              ),
            ),
          ),
          Expanded(
            flex: 6, 
            child: Text(
              value, 
              style: TextStyle(
                fontWeight: FontWeight.w500,   // ដិតបន្តិច
                fontSize: AppFonts.md,
                color: Colors.grey.shade800,   // ពណ៌ងងឹតបន្តិច
              ),
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }
}