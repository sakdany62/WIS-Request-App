// lib/screens/manager/manager_profile_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:permission_system/services/cloudinary_service.dart';
import '../../app_fonts.dart';
import '../../utils/responsive.dart';

class ManagerProfileScreen extends StatefulWidget {
  const ManagerProfileScreen({super.key});

  @override
  State<ManagerProfileScreen> createState() => _ManagerProfileScreenState();
}

class _ManagerProfileScreenState extends State<ManagerProfileScreen> {
  Map<String, dynamic>? userData;
  bool isLoading = true;
  bool isUploading = false;
  String? errorMessage;
  String? profileImageUrl;

  // Cloudinary Service
  final CloudinaryService _cloudinaryService = CloudinaryService();
  bool _isUploadingToCloudinary = false;
  double _uploadProgress = 0.0;

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

  @override
  void dispose() {
    currentPasswordController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  // =============================================
  // 1. LOAD USER DATA
  // =============================================
  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      setState(() {
        errorMessage = 'no_user_logged_in'.tr();
        isLoading = false;
      });
      return;
    }

    try {
      print(' Loading manager data for UID: ${user.uid}');

      final docSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (docSnapshot.exists) {
        final data = docSnapshot.data()!;
        print(' Manager data found: $data');

        setState(() {
          userData = Map<String, dynamic>.from(data);
          profileImageUrl = data['profileImageUrl'] ?? data['profileImage'] ?? '';
          isLoading = false;
        });
      } else {
        print(' No manager document found for UID: ${user.uid}');
        setState(() {
          errorMessage = 'profile_not_found'.tr();
          isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error loading manager data: $e');
      setState(() {
        errorMessage = 'failed_to_load_profile'.tr(args: [e.toString()]);
        isLoading = false;
      });
    }
  }

  // =============================================
  // 2. UPLOAD IMAGE TO CLOUDINARY
  // =============================================
  Future<void> _uploadImageToCloudinary(ImageSource source) async {
    setState(() {
      _isUploadingToCloudinary = true;
      _uploadProgress = 0.0;
    });

    try {
      _showSnackBar('please_select_image'.tr(), Colors.blue);

      String? imageUrl;

      if (source == ImageSource.gallery) {
        imageUrl = await _cloudinaryService.uploadProfileImageFromGallery(
          onProgress: (progress) {
            setState(() {
              _uploadProgress = progress;
            });
            print(' Upload progress: ${(progress * 100).toStringAsFixed(0)}%');
          },
        );
      } else {
        imageUrl = await _cloudinaryService.uploadProfileImageFromCamera(
          onProgress: (progress) {
            setState(() {
              _uploadProgress = progress;
            });
            print(' Upload progress: ${(progress * 100).toStringAsFixed(0)}%');
          },
        );
      }

      setState(() {
        _isUploadingToCloudinary = false;
      });

      if (imageUrl != null) {
        setState(() {
          profileImageUrl = imageUrl;
          userData?['profileImageUrl'] = imageUrl;
        });
        _showSnackBar('profile_image_uploaded'.tr(), Colors.green);
        print(' Image uploaded to Cloudinary: $imageUrl');
      } else {
        _showSnackBar('failed_to_upload_image'.tr(), Colors.red);
      }
    } catch (e) {
      setState(() {
        _isUploadingToCloudinary = false;
      });
      _showSnackBar('error'.tr() + ': $e', Colors.red);
      print('❌ Upload error: $e');
    }
  }

  // =============================================
  // 3. UPDATE PROFILE IMAGE URL (Manual)
  // =============================================
  Future<void> _updateProfileImageUrl(String imageUrl) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      isUploading = true;
    });

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'profileImageUrl': imageUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        profileImageUrl = imageUrl;
        userData?['profileImageUrl'] = imageUrl;
        isUploading = false;
      });

      _showSnackBar('profile_image_updated'.tr(), Colors.green);
      Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        isUploading = false;
      });
      _showSnackBar('error'.tr() + ': $e', Colors.red);
      print('❌ Error updating profile: $e');
    }
  }

  // =============================================
  // 4. DELETE PROFILE IMAGE
  // =============================================
  Future<void> _deleteProfileImage() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final bool isMobile = Responsive.isMobile(context);
    final double fontSize = Responsive.fontSize(context, 14);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'delete_profile_image'.tr(),
          style: TextStyle(
            fontSize: isMobile ? fontSize : fontSize + 2,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'confirm_delete_profile_image'.tr(),
          style: TextStyle(fontSize: fontSize),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'cancel'.tr(),
              style: TextStyle(fontSize: fontSize),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'delete'.tr(),
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
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'profileImageUrl': '',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        profileImageUrl = null;
        userData?['profileImageUrl'] = '';
        isUploading = false;
      });

      _showSnackBar('profile_image_deleted'.tr(), Colors.orange);
      Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        isUploading = false;
      });
      _showSnackBar('error'.tr() + ': $e', Colors.red);
      print('❌ Image deletion error: $e');
    }
  }

  // =============================================
  // 5. URL DIALOG
  // =============================================
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
          'enter_image_url'.tr(),
          style: TextStyle(
            fontSize: isMobile ? fontSize : fontSize + 2,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'paste_image_url'.tr(),
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
              'image_url_info'.tr(),
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
              'cancel'.tr(),
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
                _showSnackBar('please_enter_valid_url'.tr(), Colors.orange);
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
              'save'.tr(),
              style: TextStyle(fontSize: fontSize),
            ),
          ),
        ],
      ),
    );
  }

  // =============================================
  // 6. SHOW IMAGE PICKER DIALOG
  // =============================================
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
            // ===== GALLERY =====
            ListTile(
              leading: Icon(Icons.photo_library, color: const Color(0xFF173B69)),
              title: Text(
                'choose_from_gallery'.tr(),
                style: TextStyle(fontSize: fontSize),
              ),
              onTap: () {
                Navigator.pop(context);
                _uploadImageToCloudinary(ImageSource.gallery);
              },
            ),
            
            // ===== URL =====
            ListTile(
              leading: Icon(Icons.link, color: const Color(0xFF173B69)),
              title: Text(
                'enter_image_url'.tr(),
                style: TextStyle(fontSize: fontSize),
              ),
              onTap: () {
                Navigator.pop(context);
                _showUrlDialog();
              },
            ),
            
            // ===== DELETE =====
            if (profileImageUrl != null && profileImageUrl!.isNotEmpty) ...[
              const Divider(),
              ListTile(
                leading: Icon(Icons.delete, color: Colors.red),
                title: Text(
                  'remove_photo'.tr(),
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
                'cancel'.tr(),
                style: TextStyle(fontSize: fontSize, color: Colors.grey),
              ),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  // =============================================
  // 7. CHANGE PASSWORD
  // =============================================
  Future<void> _changePasswordWithDialog(StateSetter setDialogState) async {
    setDialogState(() {
      _passwordError = '';
    });

    String currentPassword = currentPasswordController.text.trim();
    String newPassword = newPasswordController.text.trim();
    String confirmPassword = confirmPasswordController.text.trim();

    if (currentPassword.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty) {
      setDialogState(() {
        _passwordError = 'please_fill_all_password_fields'.tr();
      });
      return;
    }

    if (newPassword.length < 6) {
      setDialogState(() {
        _passwordError = 'password_min_length'.tr();
      });
      return;
    }

    if (newPassword != confirmPassword) {
      setDialogState(() {
        _passwordError = 'passwords_do_not_match'.tr();
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
          _passwordError = 'no_user_logged_in'.tr();
          isChangingPassword = false;
        });
        return;
      }

      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );

      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);

      currentPasswordController.clear();
      newPasswordController.clear();
      confirmPasswordController.clear();

      setDialogState(() {
        isChangingPassword = false;
        _passwordError = '';
      });

      _showSnackBar('password_changed'.tr(), Colors.green);
      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      setDialogState(() {
        isChangingPassword = false;
      });

      String errorMessage = 'failed_to_change_password'.tr();
      if (e.code == 'wrong-password') {
        errorMessage = 'current_password_incorrect'.tr();
      } else if (e.code == 'too-many-requests') {
        errorMessage = 'too_many_attempts'.tr();
      } else if (e.code == 'requires-recent-login') {
        errorMessage = 'requires_recent_login'.tr();
      } else {
        errorMessage = e.message ?? 'failed_to_change_password'.tr();
      }

      setDialogState(() {
        _passwordError = errorMessage;
      });

      _showSnackBar('error'.tr() + ': $errorMessage', Colors.red);
    } catch (e) {
      setDialogState(() {
        isChangingPassword = false;
        _passwordError = 'error'.tr() + ': $e';
      });
      _showSnackBar('error'.tr() + ': $e', Colors.red);
    }
  }

  void _showChangePasswordDialog() {
    final bool isMobile = Responsive.isMobile(context);
    final double fontSize = Responsive.fontSize(context, 14);
    final double spacing = Responsive.spacing(context);

    currentPasswordController.clear();
    newPasswordController.clear();
    confirmPasswordController.clear();
    _passwordError = '';
    obscureCurrentPassword = true;
    obscureNewPassword = true;
    obscureConfirmPassword = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AlertDialog(
              title: Text(
                'change_password'.tr(),
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
                    Text(
                      'current_password'.tr(),
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
                        hintText: 'enter_current_password'.tr(),
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
                    Text(
                      'new_password'.tr(),
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
                        hintText: 'enter_new_password'.tr(),
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
                    Text(
                      'confirm_new_password'.tr(),
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
                        hintText: 'confirm_new_password'.tr(),
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
                      'password_min_length_info'.tr(),
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
                  onPressed: isChangingPassword
                      ? null
                      : () {
                          setDialogState(() {
                            _passwordError = '';
                          });
                          Navigator.pop(context);
                        },
                  child: Text(
                    'cancel'.tr(),
                    style: TextStyle(
                      fontSize: fontSize,
                      color: isChangingPassword ? Colors.grey : Colors.grey.shade700,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: isChangingPassword
                      ? null
                      : () {
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
                          'update_password'.tr(),
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

  // =============================================
  // 8. LOGOUT
  // =============================================
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
          'confirm_logout'.tr(),
          style: TextStyle(
            fontSize: isMobile ? fontSize : fontSize + 2,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'confirm_logout_message'.tr(),
          style: TextStyle(fontSize: fontSize),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'cancel'.tr(),
              style: TextStyle(fontSize: fontSize),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _logout();
            },
            child: Text(
              'confirm'.tr(),
              style: TextStyle(fontSize: fontSize, color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  // =============================================
  // 9. HELPER METHODS
  // =============================================
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

  String _getValue(String key, [String? fallbackKey]) {
    final String defaultValue = 'N/A';

    if (userData != null &&
        userData!.containsKey(key) &&
        userData![key] != null &&
        userData![key]!.toString().isNotEmpty) {
      return userData![key].toString();
    }
    if (fallbackKey != null &&
        userData != null &&
        userData!.containsKey(fallbackKey) &&
        userData![fallbackKey] != null) {
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

  @override
  Widget build(BuildContext context) {
  
    EasyLocalization.of(context);
    
    final bool isMobile = Responsive.isMobile(context);
    final double fontSize = Responsive.fontSize(context, 14);
    final double spacing = Responsive.spacing(context);
    final double iconSize = Responsive.iconSize(context, 24);

    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FA),
      appBar: AppBar(
        title: Text(
          'profile'.tr(),
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
                'retry'.tr(),
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
          'no_data'.tr(),
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
                  'manager_information'.tr(),
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

  // ===== PROFILE HEADER =====
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
      final name = userData?['fullName'] ?? userData?['username'] ?? 'manager'.tr();
      if (name.isEmpty) return 'M';
      final parts = name.split(' ');
      if (parts.length >= 2) {
        return parts[0][0].toUpperCase() + parts[1][0].toUpperCase();
      }
      return parts[0][0].toUpperCase();
    }

    bool hasImage = profileImageUrl != null && profileImageUrl!.isNotEmpty;

    return Center(
      child: Column(
        children: [
          Stack(
            children: [
              GestureDetector(
                onTap: (_isUploadingToCloudinary || isUploading)
                    ? null
                    : _showImagePickerDialog,
                child: CircleAvatar(
                  radius: avatarSize / 2,
                  backgroundColor: const Color(0xFF173B69),
                  backgroundImage: hasImage
                      ? CachedNetworkImageProvider(profileImageUrl!)
                      : null,
                  child: !hasImage
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
              // Upload Progress Overlay
              if (_isUploadingToCloudinary)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      shape: BoxShape.circle,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: _uploadProgress,
                          strokeWidth: 3,
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                        SizedBox(height: spacing / 2),
                        Text(
                          '${(_uploadProgress * 100).toInt()}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: (_isUploadingToCloudinary || isUploading)
                      ? null
                      : _showImagePickerDialog,
                  child: Container(
                    padding: EdgeInsets.all(cameraPadding),
                    decoration: BoxDecoration(
                      color: const Color(0xFF173B69),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                    child: isUploading || _isUploadingToCloudinary
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
          // Upload Status Text
          if (_isUploadingToCloudinary) ...[
            SizedBox(height: spacing),
            Text(
              'uploading_image'.tr(),
              style: TextStyle(
                fontSize: fontSize * 0.8,
                color: Colors.blue.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          SizedBox(height: spacing * 1.5),
          Text(
            userData?['fullName'] ?? userData?['username'] ?? 'manager'.tr(),
            style: TextStyle(
              fontSize: isMobile ? fontSize + 2 : fontSize + 4,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: spacing / 2),
          
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: spacing * 1.5,
              vertical: spacing / 2,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF173B69).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'manager'.tr(),
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

  // ===== BUILD INFO CARD =====
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
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _InfoRowManager(
            label: 'employee_id'.tr(),
            value: _getValue('employeeId', 'userId'),
            isMobile: isMobile,
            fontSize: fontSize,
          ),
          _buildDivider(),
          _InfoRowManager(
            label: 'username'.tr(),
            value: _getValue('username'),
            isMobile: isMobile,
            fontSize: fontSize,
          ),
          _buildDivider(),
          _InfoRowManager(
            label: 'full_name'.tr(),
            value: _getValue('fullName'),
            isMobile: isMobile,
            fontSize: fontSize,
          ),
          _buildDivider(),
          _InfoRowManager(
            label: 'email'.tr(),
            value: _getValue('email'),
            isMobile: isMobile,
            fontSize: fontSize,
          ),
          _buildDivider(),
          _InfoRowManager(
            label: 'phone'.tr(),
            value: _getValue('phone'),
            isMobile: isMobile,
            fontSize: fontSize,
          ),
          _buildDivider(),
          _InfoRowManager(
            label: 'department'.tr(),
            value: _getValue('department'),
            isMobile: isMobile,
            fontSize: fontSize,
          ),
          _buildDivider(),
          _InfoRowManager(
            label: 'role'.tr(),
            value: 'manager'.tr(),
            isMobile: isMobile,
            fontSize: fontSize,
          ),
          _buildDivider(),
          _InfoRowManager(
            label: 'status'.tr(),
            value: _getValue('status'),
            isMobile: isMobile,
            fontSize: fontSize,
          ),
          _buildDivider(),
          _InfoRowManager(
            label: 'member_since'.tr(),
            value: _formatDate(userData?['createdAt']),
            isMobile: isMobile,
            fontSize: fontSize,
          ),
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
                'change_password'.tr(),
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
}

// =============================================
// INFO ROW WIDGET
// =============================================
class _InfoRowManager extends StatelessWidget {
  final String label;
  final String value;
  final bool isMobile;
  final double fontSize;

  const _InfoRowManager({
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