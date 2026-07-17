// lib/services/warning_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class WarningService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get active warnings for current user
  static Future<List<Map<String, dynamic>>> getActiveWarnings() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    try {
      final now = DateTime.now();
      
      // Get user's role from users collection
      String? userRole = 'staff';
      try {
        final userDoc = await _firestore
            .collection('users')
            .where('userId', isEqualTo: user.uid)
            .limit(1)
            .get();
        
        if (userDoc.docs.isNotEmpty) {
          final data = userDoc.docs.first.data();
          final roleId = data['roleId']?.toString();
          // Map roleId to audience type
          if (roleId == '1' || roleId == '4') {
            userRole = 'admin';
          } else if (roleId == '3') {
            userRole = 'manager';
          } else {
            userRole = 'staff';
          }
        }
      } catch (e) {
        print('Error getting user role: $e');
      }
      
      // Query from notifications collection
      final querySnapshot = await _firestore
          .collection('notifications')
          .where('isWarning', isEqualTo: true)
          .where('isActive', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .get();

      List<Map<String, dynamic>> warnings = [];

      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        
        // Check if warning has expired
        if (data['expiresAt'] != null) {
          final expiresAt = (data['expiresAt'] as Timestamp).toDate();
          if (expiresAt.isBefore(now)) continue;
        }

        // Check target audience
        final targetAudience = data['targetAudience'] ?? 'all';
        if (targetAudience != 'all' && targetAudience != userRole) {
          continue;
        }

        // Check if user has already seen this warning
        final readBy = data['readBy'] as List? ?? [];
        if (readBy.contains(user.uid)) continue;

        warnings.add({
          'id': doc.id,
          ...data,
        });
      }

      return warnings;
    } catch (e) {
      print('❌ Error fetching warnings: $e');
      return [];
    }
  }

  // Mark warning as read
  static Future<void> markWarningAsRead(String warningId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await _firestore.collection('notifications').doc(warningId).update({
        'readBy': FieldValue.arrayUnion([user.uid]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('❌ Error marking warning as read: $e');
    }
  }

  // Get all warnings (for admin)
  static Stream<QuerySnapshot> getAllWarnings() {
    return _firestore
        .collection('notifications')
        .where('isWarning', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Create a new warning
  static Future<void> createWarning({
    required String title,
    required String message,
    required String severity,
    required String targetAudience,
    DateTime? expiresAt,
    String? actionButtonText,
    String? actionUrl,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not logged in');

    try {
      // Get sender info
      String senderName = 'Admin';
      try {
        final userDoc = await _firestore
            .collection('users')
            .where('userId', isEqualTo: user.uid)
            .limit(1)
            .get();
        
        if (userDoc.docs.isNotEmpty) {
          senderName = userDoc.docs.first.data()['fullName'] ?? 'Admin';
        }
      } catch (e) {
        print('Error getting sender name: $e');
      }

      await _firestore.collection('notifications').add({
        'title': title,
        'message': message,
        'type': 'warning',
        'isWarning': true,
        'severity': severity,
        'targetAudience': targetAudience,
        'isActive': true,
        'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt) : null,
        'actionButtonText': actionButtonText ?? 'OK',
        'actionUrl': actionUrl,
        'senderId': user.uid,
        'senderName': senderName,
        'readBy': [],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('❌ Error creating warning: $e');
      throw Exception('Failed to create warning: $e');
    }
  }

  // Update a warning
  static Future<void> updateWarning({
    required String warningId,
    String? title,
    String? message,
    String? severity,
    String? targetAudience,
    bool? isActive,
    DateTime? expiresAt,
    String? actionButtonText,
    String? actionUrl,
  }) async {
    try {
      final Map<String, dynamic> updates = {};
      if (title != null) updates['title'] = title;
      if (message != null) updates['message'] = message;
      if (severity != null) updates['severity'] = severity;
      if (targetAudience != null) updates['targetAudience'] = targetAudience;
      if (isActive != null) updates['isActive'] = isActive;
      if (expiresAt != null) updates['expiresAt'] = Timestamp.fromDate(expiresAt);
      if (actionButtonText != null) updates['actionButtonText'] = actionButtonText;
      if (actionUrl != null) updates['actionUrl'] = actionUrl;
      updates['updatedAt'] = FieldValue.serverTimestamp();

      await _firestore.collection('notifications').doc(warningId).update(updates);
    } catch (e) {
      print('❌ Error updating warning: $e');
      throw Exception('Failed to update warning: $e');
    }
  }

  // Delete a warning
  static Future<void> deleteWarning(String warningId) async {
    try {
      await _firestore.collection('notifications').doc(warningId).delete();
    } catch (e) {
      print('❌ Error deleting warning: $e');
      throw Exception('Failed to delete warning: $e');
    }
  }
}