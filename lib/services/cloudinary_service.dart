// lib/services/cloudinary_service.dart
import 'dart:convert';
import 'dart:io' show File;
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';

class CloudinaryService {
  static final CloudinaryService _instance = CloudinaryService._internal();
  factory CloudinaryService() => _instance;
  CloudinaryService._internal();

  final String cloudName = 'teoe5c0s';
  final String uploadPreset = 'permission_system_preset';

  /// Check if running on Web
  bool get isWeb {
    // ignore: undefined_identifier
    return identical(0, 0.0) ? true : false;
  }

  /// Upload profile image from gallery (Supports Web + Mobile)
  Future<String?> uploadProfileImageFromGallery({
    required Function(double) onProgress,
  }) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image == null) {
        debugPrint('❌ No image selected from gallery');
        return null;
      }

      String? imageUrl;

      if (isWeb) {
        // Web: Use bytes upload
        final bytes = await image.readAsBytes();
        imageUrl = await uploadImageFromBytes(
          bytes: bytes,
          fileName: image.name,
          onProgress: onProgress,
        );
      } else {
        // Mobile: Use file path
        imageUrl = await uploadImageFromFile(
          filePath: image.path,
          onProgress: onProgress,
        );
      }

      if (imageUrl != null) {
        final userId = FirebaseAuth.instance.currentUser?.uid;
        if (userId != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .update({
            'profileImageUrl': imageUrl,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          return imageUrl;
        }
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error uploading profile image from gallery: $e');
      return null;
    }
  }

  /// Upload profile image from camera (Supports Web + Mobile)
  Future<String?> uploadProfileImageFromCamera({
    required Function(double) onProgress,
  }) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image == null) {
        debugPrint('❌ No image captured from camera');
        return null;
      }

      String? imageUrl;

      if (isWeb) {
        // Web: Use bytes upload
        final bytes = await image.readAsBytes();
        imageUrl = await uploadImageFromBytes(
          bytes: bytes,
          fileName: image.name,
          onProgress: onProgress,
        );
      } else {
        // Mobile: Use file path
        imageUrl = await uploadImageFromFile(
          filePath: image.path,
          onProgress: onProgress,
        );
      }

      if (imageUrl != null) {
        final userId = FirebaseAuth.instance.currentUser?.uid;
        if (userId != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .update({
            'profileImageUrl': imageUrl,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          return imageUrl;
        }
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error uploading profile image from camera: $e');
      return null;
    }
  }

  /// Upload image from bytes (Web)
  Future<String?> uploadImageFromBytes({
    required Uint8List bytes,
    required String fileName,
    required Function(double) onProgress,
    int quality = 85,
  }) async {
    try {
      final Uri url = Uri.parse(
          'https://api.cloudinary.com/v1_1/$cloudName/image/upload');

      // Create multipart form data
      var request = http.MultipartRequest('POST', url);
      request.fields['upload_preset'] = uploadPreset;
      request.fields['quality'] = quality.toString();

      // Create multipart file from bytes
      var multipartFile = http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: fileName,
      );
      request.files.add(multipartFile);

      onProgress(0.3);
      var streamedResponse = await request.send();
      onProgress(0.7);

      var response = await http.Response.fromStream(streamedResponse);
      onProgress(1.0);

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        final String imageUrl = responseData['secure_url'] ?? responseData['url'];
        debugPrint('✅ Image uploaded to Cloudinary: $imageUrl');
        return imageUrl;
      } else {
        debugPrint('❌ Upload failed: ${response.statusCode}');
        debugPrint('❌ Response: ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Error uploading image from bytes: $e');
      return null;
    }
  }

  /// Upload image from file path (Mobile only)
  Future<String?> uploadImageFromFile({
    required String filePath,
    required Function(double) onProgress,
    int quality = 85,
  }) async {
    try {
      final Uri url = Uri.parse(
          'https://api.cloudinary.com/v1_1/$cloudName/image/upload');

      var request = http.MultipartRequest('POST', url);
      request.fields['upload_preset'] = uploadPreset;
      request.fields['quality'] = quality.toString();

      // Add file from path
      var file = await http.MultipartFile.fromPath('file', filePath);
      request.files.add(file);

      onProgress(0.3);
      var streamedResponse = await request.send();
      onProgress(0.7);

      var response = await http.Response.fromStream(streamedResponse);
      onProgress(1.0);

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        final String imageUrl = responseData['secure_url'] ?? responseData['url'];
        debugPrint('✅ Image uploaded to Cloudinary: $imageUrl');
        return imageUrl;
      } else {
        debugPrint('❌ Upload failed: ${response.statusCode}');
        debugPrint('❌ Response: ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Error uploading image from file: $e');
      return null;
    }
  }

  /// Upload general image (Supports Web + Mobile)
  Future<String?> uploadGeneralImage({
    required Function(double) onProgress,
    int quality = 85,
  }) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: quality,
      );

      if (image == null) return null;

      if (isWeb) {
        final bytes = await image.readAsBytes();
        return await uploadImageFromBytes(
          bytes: bytes,
          fileName: image.name,
          onProgress: onProgress,
          quality: quality,
        );
      } else {
        return await uploadImageFromFile(
          filePath: image.path,
          onProgress: onProgress,
          quality: quality,
        );
      }
    } catch (e) {
      debugPrint('❌ Error uploading general image: $e');
      return null;
    }
  }

  /// Upload multiple images (Supports Web + Mobile)
  Future<List<String?>> uploadMultipleImages({
    required List<XFile> images,
    required Function(int, double) onProgress,
    int quality = 85,
  }) async {
    List<String?> urls = [];
    int total = images.length;

    for (int i = 0; i < total; i++) {
      String? url;

      if (isWeb) {
        final bytes = await images[i].readAsBytes();
        url = await uploadImageFromBytes(
          bytes: bytes,
          fileName: images[i].name,
          onProgress: (progress) {
            onProgress(i, progress);
          },
          quality: quality,
        );
      } else {
        url = await uploadImageFromFile(
          filePath: images[i].path,
          onProgress: (progress) {
            onProgress(i, progress);
          },
          quality: quality,
        );
      }

      urls.add(url);
    }

    return urls;
  }

  /// Delete image from Cloudinary (requires public_id)
  Future<bool> deleteImage(String publicId) async {
    try {
      // Note: Deleting requires API key and secret
      // You'll need to implement this using Cloudinary Admin API
      // Example: DELETE https://api.cloudinary.com/v1_1/cloud_name/image/destroy
      debugPrint('⚠️ Delete image function needs API key/secret');
      return false;
    } catch (e) {
      debugPrint('❌ Error deleting image: $e');
      return false;
    }
  }

  /// Extract public_id from Cloudinary URL
  String? extractPublicId(String imageUrl) {
    try {
      // Example: https://res.cloudinary.com/cloud_name/image/upload/v1234567890/folder/image_name.jpg
      final RegExp regExp = RegExp(r'/v\d+/(.+)\.\w+$');
      final match = regExp.firstMatch(imageUrl);
      if (match != null && match.groupCount >= 1) {
        return match.group(1);
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error extracting public_id: $e');
      return null;
    }
  }

  /// Get transformed image URL (with transformations)
  String getTransformedUrl(String imageUrl, {int width = 200, int height = 200}) {
    try {
      // Example: https://res.cloudinary.com/cloud_name/image/upload/v1234567890/image.jpg
      // -> https://res.cloudinary.com/cloud_name/image/upload/w_200,h_200,c_fill/v1234567890/image.jpg
      final parts = imageUrl.split('/upload/');
      if (parts.length == 2) {
        return '${parts[0]}/upload/w_$width,h_$height,c_fill/${parts[1]}';
      }
      return imageUrl;
    } catch (e) {
      debugPrint('❌ Error transforming URL: $e');
      return imageUrl;
    }
  }
}