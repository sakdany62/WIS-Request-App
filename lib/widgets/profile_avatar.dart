import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfileAvatar extends StatefulWidget {
  final String? userId;
  final String? imageUrl;
  final String? name;
  final double radius;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Color? textColor;
  final bool useInitials;

  const ProfileAvatar({
    super.key,
    this.userId,
    this.imageUrl,
    this.name,
    this.radius = 30,
    this.onTap,
    this.backgroundColor,
    this.textColor,
    this.useInitials = true,
  });

  @override
  State<ProfileAvatar> createState() => _ProfileAvatarState();
}

class _ProfileAvatarState extends State<ProfileAvatar> {
  String? _imageUrl;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _imageUrl = widget.imageUrl;
    // ✅ បើគ្មាន imageUrl ហើយមាន userId សូម Load ពី Firestore
    if (widget.userId != null && 
        widget.userId!.isNotEmpty && 
        (widget.imageUrl == null || widget.imageUrl!.isEmpty)) {
      _loadUserImage();
    }
  }

  @override
  void didUpdateWidget(ProfileAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // ✅ ពិនិត្យមើលថា imageUrl បានផ្លាស់ប្តូរ
    if (widget.imageUrl != oldWidget.imageUrl) {
      print('🔄 ProfileAvatar: imageUrl changed from ${oldWidget.imageUrl} to ${widget.imageUrl}');
      setState(() {
        _imageUrl = widget.imageUrl;
        _isLoading = false;
      });
    }
    
    // ✅ ពិនិត្យមើលថា userId បានផ្លាស់ប្តូរ
    if (widget.userId != oldWidget.userId) {
      print('🔄 ProfileAvatar: userId changed');
      if (widget.userId != null && 
          widget.userId!.isNotEmpty && 
          (widget.imageUrl == null || widget.imageUrl!.isEmpty)) {
        _loadUserImage();
      }
    }
  }

  Future<void> _loadUserImage() async {
    if (widget.userId == null || widget.userId!.isEmpty) return;
    
    setState(() => _isLoading = true);
    
    try {
      print('📥 Loading profile image for userId: ${widget.userId}');
      
      final docSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();
      
      if (docSnapshot.exists) {
        final data = docSnapshot.data();
        final url = data?['profileImageUrl'] ?? data?['profileImage'] ?? '';
        
        print('📥 Loaded image URL: "$url"');
        
        if (url.isNotEmpty && mounted) {
          setState(() {
            _imageUrl = url;
            _isLoading = false;
          });
          return;
        }
      } else {
        print('⚠️ User document not found for: ${widget.userId}');
      }
    } catch (e) {
      print('❌ Error loading profile image: $e');
    }
    
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  String get initials {
    if (widget.name == null || widget.name!.isEmpty) return '?';
    final parts = widget.name!.split(' ');
    if (parts.length >= 2) {
      return parts[0][0].toUpperCase() + parts[1][0].toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final bool hasImage = _imageUrl != null && _imageUrl!.isNotEmpty;
    
    print('🎨 ProfileAvatar build: hasImage=$hasImage, _imageUrl="$_imageUrl"');
    
    return GestureDetector(
      onTap: widget.onTap,
      child: CircleAvatar(
        radius: widget.radius,
        backgroundColor: widget.backgroundColor ?? Colors.grey.shade200,
        backgroundImage: hasImage
            ? CachedNetworkImageProvider(_imageUrl!)
            : null,
        child: _isLoading
            ? SizedBox(
                width: widget.radius * 0.5,
                height: widget.radius * 0.5,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: widget.textColor ?? const Color(0xFF173B69),
                ),
              )
            : (!hasImage && widget.useInitials)
                ? Text(
                    initials,
                    style: TextStyle(
                      fontSize: widget.radius * 0.6,
                      fontWeight: FontWeight.bold,
                      color: widget.textColor ?? const Color(0xFF173B69),
                    ),
                  )
                : null,
      ),
    );
  }
}