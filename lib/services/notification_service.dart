// lib/services/notification_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'notifications';

  // ===================== SEND NOTIFICATION TO ALL STAFF =====================
  static Future<void> sendNotificationToAllStaff({
    required String title,
    required String body,
    required String type,
    String? termsId,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      // Get all staff and managers
      final usersSnapshot = await _firestore
          .collection('users')
          .get();
      
      final batch = _firestore.batch();
      int notificationCount = 0;
      
      for (var doc in usersSnapshot.docs) {
        final data = doc.data();
        final role = (data['role'] ?? data['roleName'] ?? '').toString().toLowerCase();
        final roleId = data['roleId'] ?? '';
        
        // Check if user is Staff or Manager (not Admin)
        final isAdmin = (role == 'admin' || roleId == '1');
        if (isAdmin) continue;
        
        final userId = doc.id;
        
        // Create notification document
        final notificationRef = _firestore
            .collection(_collection)
            .doc();
        
        batch.set(notificationRef, {
          'userId': userId,
          'title': title,
          'body': body,
          'type': type,
          'termsId': termsId,
          'additionalData': additionalData ?? {},
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'readAt': null,
        });
        
        notificationCount++;
      }
      
      await batch.commit();
      print(' Sent $notificationCount notifications to staff');
    } catch (e) {
      print('❌ Error sending notifications: $e');
      throw Exception('Failed to send notifications: $e');
    }
  }

  // ===================== SEND NOTIFICATION TO SPECIFIC USER =====================
  static Future<void> sendNotificationToUser({
    required String userId,
    required String title,
    required String body,
    required String type,
    String? termsId,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      await _firestore.collection(_collection).add({
        'userId': userId,
        'title': title,
        'body': body,
        'type': type,
        'termsId': termsId,
        'additionalData': additionalData ?? {},
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'readAt': null,
      });
      print(' Notification sent to user: $userId');
    } catch (e) {
      print('❌ Error sending notification to user: $e');
      rethrow;
    }
  }

  // ===================== GET NOTIFICATIONS FOR USER =====================
  static Stream<QuerySnapshot> getUserNotifications(String userId) {
    return _firestore
        .collection(_collection)
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // ===================== GET UNREAD NOTIFICATION COUNT =====================
  static Future<int> getUnreadNotificationCount(String userId) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('userId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();
      
      return snapshot.docs.length;
    } catch (e) {
      print('❌ Error getting unread count: $e');
      return 0;
    }
  }

  // ===================== MARK NOTIFICATION AS READ =====================
  static Future<void> markNotificationAsRead(String notificationId) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(notificationId)
          .update({
        'isRead': true,
        'readAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print(' Notification marked as read');
    } catch (e) {
      print('❌ Error marking notification as read: $e');
      rethrow;
    }
  }

  // ===================== MARK ALL NOTIFICATIONS AS READ =====================
  static Future<void> markAllNotificationsAsRead(String userId) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('userId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();
      
      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.update(doc.reference, {
          'isRead': true,
          'readAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
      print(' All notifications marked as read');
    } catch (e) {
      print('❌ Error marking all notifications as read: $e');
      rethrow;
    }
  }

  // ===================== DELETE NOTIFICATION =====================
  static Future<void> deleteNotification(String notificationId) async {
    try {
      await _firestore.collection(_collection).doc(notificationId).delete();
      print(' Notification deleted');
    } catch (e) {
      print('❌ Error deleting notification: $e');
      rethrow;
    }
  }

  // ===================== DELETE ALL NOTIFICATIONS FOR USER =====================
  static Future<void> deleteAllNotifications(String userId) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('userId', isEqualTo: userId)
          .get();
      
      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      print(' All notifications deleted for user: $userId');
    } catch (e) {
      print('❌ Error deleting all notifications: $e');
      rethrow;
    }
  }
}