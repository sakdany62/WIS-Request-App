// lib/services/request_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../models/policy_model.dart';

class RequestService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CollectionReference _requestsCollection = 
      FirebaseFirestore.instance.collection('leave_requests');
  final CollectionReference _notificationsCollection = 
      FirebaseFirestore.instance.collection('notifications');
  final CollectionReference _policiesCollection = 
      FirebaseFirestore.instance.collection('permission_policies');

  // ==================== SUBMIT REQUEST ====================
  Future<Map<String, dynamic>> submitRequestWithAutoApprove({
    required String startDate,
    required String endDate,
    required int totalDays,
    required String reason,
    required String? otherReason,
    required String? fileUrl,
    required String? imageUrl,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not logged in');

    final userDoc = await _firestore
        .collection('users')
        .where('userId', isEqualTo: user.uid)
        .limit(1)
        .get();

    String userName = user.email?.split('@').first ?? 'Staff';
    String userEmail = user.email ?? '';
    String userDepartment = '';
    String userRoleId = '2';
    
    if (userDoc.docs.isNotEmpty) {
      final data = userDoc.docs.first.data() as Map<String, dynamic>;
      userName = data['fullName'] ?? data['username'] ?? userName;
      userEmail = data['email'] ?? userEmail;
      userDepartment = data['department'] ?? '';
      userRoleId = data['roleId']?.toString() ?? '2';
    }

    print('📝 Submitting request for: $userName');
    print('📝 Department: "$userDepartment"');
    print('📝 Role: $userRoleId');

    final finalReason = reason == 'Other' ? (otherReason ?? reason) : reason;
    
    final policy = await _getActivePolicy();
    final requestCountInMonth = await _getUserRequestCountInCurrentMonth(user.uid);
    
    final currentYear = DateTime.now().year;
    final daysUsedThisYear = await getTotalDaysUsedByStaff(user.uid, currentYear);
    
    final startDateTime = _parseDateString(startDate);
    final daysAdvance = startDateTime != null 
        ? startDateTime.difference(DateTime.now()).inDays 
        : 0;
    
    if (policy != null) {
      final errors = _validateRequestAgainstPolicy(
        policy: policy,
        totalDays: totalDays,
        reason: finalReason,
        hasDocument: fileUrl != null || imageUrl != null,
        daysUsedThisYear: daysUsedThisYear,
        daysAdvance: daysAdvance,
      );
      
      if (errors.isNotEmpty) {
        throw Exception(errors.join('\n'));
      }
    }
    
    String status;
    String? autoMessage;
    bool needManagerApproval = false;
    int requestNumber = requestCountInMonth + 1;
    
    if (policy != null && policy.autoApprove) {
      if (requestNumber == 1) {
        status = 'approved';
        autoMessage = policy.firstRequestMessage;
      } else if (requestNumber == 2) {
        status = 'approved';
        autoMessage = policy.secondRequestMessage;
      } else {
        status = 'pending';
        needManagerApproval = true;
        autoMessage = policy.thirdRequestMessage;
      }
    } else {
      status = 'pending';
      needManagerApproval = true;
      autoMessage = "សំណើរបស់អ្នកកំពុងរង់ចាំការអនុម័តពី Manager";
    }

    final requestData = {
      'userId': user.uid,
      'userEmail': userEmail,
      'userName': userName,
      'department': userDepartment,
      'startDate': startDate,
      'endDate': endDate,
      'totalDays': totalDays,
      'reason': finalReason,
      'fileUrl': fileUrl,
      'imageUrl': imageUrl,
      'status': status,
      'requestNumber': requestNumber,
      'requestCountInMonth': requestCountInMonth + 1,
      'month': DateTime.now().month,
      'year': DateTime.now().year,
      'autoApproved': status == 'approved',
      'needManagerApproval': needManagerApproval,
      'policyId': policy?.id,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    final docRef = await _requestsCollection.add(requestData);
    await docRef.update({'requestId': docRef.id});

    // ============ បញ្ជូន Notification ============
    
    // 1. បញ្ជូនទៅកាន់ Staff (អ្នកដាក់សំណើ)
    await _sendNotificationToUser(
      userId: user.uid,
      userEmail: userEmail,
      title: status == 'approved' ? 'សំណើត្រូវបានអនុម័តដោយស្វ័យប្រវត្តិ' : 'សំណើត្រូវការអនុម័ត',
      message: autoMessage ?? 'សំណើរបស់អ្នកបានដាក់ជូនដោយជោគជ័យ',
      type: status == 'approved' ? 'auto_approved' : 'submitted',
      requestId: docRef.id,
      extraData: {
        'requestNumber': requestNumber,
        'totalDays': totalDays,
      },
    );

    // 2. ប្រសិនបើត្រូវការអនុម័ត បញ្ជូនទៅកាន់ Managers និង Admins
    if (needManagerApproval) {
      await _notifyManagersForApproval(requestData, docRef.id);
      await _notifyAdminsForApproval(requestData, docRef.id);
    } else {
      // 3. ប្រសិនបើ Auto Approved បញ្ជូនទៅកាន់ Admins
      await _notifyAdminsForAutoApproval(requestData, docRef.id);
    }

    return {
      'status': status,
      'message': autoMessage,
      'requestId': docRef.id,
      'requestNumber': requestNumber,
      'needManagerApproval': needManagerApproval,
    };
  }

  // ==================== GET PENDING REQUESTS FOR MANAGER ====================
  Stream<QuerySnapshot> getPendingRequestsForManager(String managerDepartment) {
    try {
      if (managerDepartment.isEmpty) {
        return _requestsCollection
            .where('status', isEqualTo: 'pending')
            .orderBy('createdAt', descending: true)
            .snapshots();
      }
      
      return _requestsCollection
          .where('status', isEqualTo: 'pending')
          .where('department', isEqualTo: managerDepartment)
          .orderBy('createdAt', descending: true)
          .snapshots();
    } catch (e) {
      print('❌ Error in getPendingRequestsForManager: $e');
      return Stream.empty();
    }
  }

  // ==================== GET ALL PENDING REQUESTS ====================
  Stream<QuerySnapshot> getPendingRequests() {
    return _requestsCollection
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // ==================== APPROVE REQUEST AS MANAGER ====================
  Future<void> approveRequestAsManager(
    String requestId, 
    String managerId, 
    String managerName,
    String managerDepartment,
  ) async {
    try {
      final requestDoc = await _requestsCollection.doc(requestId).get();
      final requestData = requestDoc.data() as Map<String, dynamic>?;
      
      if (requestData == null) {
        throw Exception('Request not found');
      }
      
      final requestDepartment = requestData['department'] ?? '';
      
      if (managerDepartment.isNotEmpty && requestDepartment != managerDepartment) {
        throw Exception('អ្នកមិនអាចអនុម័តសំណើរបស់បុគ្គលិកក្រៅផ្នែករបស់អ្នកបានទេ');
      }
      
      if (requestData['status'] != 'pending') {
        throw Exception('សំណើនេះត្រូវបានដំណើរការរួចហើយ');
      }
      
      await _requestsCollection.doc(requestId).update({
        'status': 'approved',
        'approvedBy': managerId,
        'approvedByName': managerName,
        'approvedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // ============ បញ្ជូន Notification ============
      
      // 1. បញ្ជូនទៅកាន់ Staff (អ្នកដាក់សំណើ)
      await _sendNotificationToUser(
        userId: requestData['userId'],
        userEmail: requestData['userEmail'],
        title: 'សំណើត្រូវបានអនុម័ត',
        message: 'សំណើរបស់អ្នកសម្រាប់ ${requestData['totalDays']} ថ្ងៃត្រូវបានអនុម័តដោយ $managerName',
        type: 'request_approved',
        requestId: requestId,
        extraData: {
          'approvedBy': managerName,
          'totalDays': requestData['totalDays'],
        },
      );

      // 2. បញ្ជូនទៅកាន់ Admins
      await _notifyAdminsForRequestApproved(requestData, managerName, requestId);
      
      print('✅ Request approved by Manager: $managerName');
    } on FirebaseException catch (e) {
      print('❌ Firebase Error: ${e.code} - ${e.message}');
      if (e.code == 'permission-denied') {
        throw Exception('អ្នកមិនមានសិទ្ធិអនុម័តសំណើនេះទេ');
      }
      throw Exception('Failed to approve request: ${e.message}');
    } catch (e) {
      throw Exception('Failed to approve request: $e');
    }
  }

  // ==================== REJECT REQUEST AS MANAGER ====================
  Future<void> rejectRequestAsManager(
    String requestId, 
    String managerId, 
    String managerName,
    String managerDepartment,
    {String? reason}
  ) async {
    try {
      final requestDoc = await _requestsCollection.doc(requestId).get();
      final requestData = requestDoc.data() as Map<String, dynamic>?;
      
      if (requestData == null) {
        throw Exception('Request not found');
      }
      
      final requestDepartment = requestData['department'] ?? '';
      
      if (managerDepartment.isNotEmpty && requestDepartment != managerDepartment) {
        throw Exception('អ្នកមិនអាចបដិសេធសំណើរបស់បុគ្គលិកក្រៅផ្នែករបស់អ្នកបានទេ');
      }
      
      if (requestData['status'] != 'pending') {
        throw Exception('សំណើនេះត្រូវបានដំណើរការរួចហើយ');
      }
      
      await _requestsCollection.doc(requestId).update({
        'status': 'rejected',
        'rejectedBy': managerId,
        'rejectedByName': managerName,
        'rejectionReason': reason,
        'rejectedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // ============ បញ្ជូន Notification ============
      
      // 1. បញ្ជូនទៅកាន់ Staff (អ្នកដាក់សំណើ)
      await _sendNotificationToUser(
        userId: requestData['userId'],
        userEmail: requestData['userEmail'],
        title: 'សំណើត្រូវបានបដិសេធ',
        message: 'សំណើរបស់អ្នកសម្រាប់ ${requestData['totalDays']} ថ្ងៃត្រូវបានបដិសេធ${reason != null ? '។ ហេតុផល: $reason' : ''}',
        type: 'request_rejected',
        requestId: requestId,
        extraData: {
          'rejectedBy': managerName,
          'rejectionReason': reason,
          'totalDays': requestData['totalDays'],
        },
      );

      // 2. បញ្ជូនទៅកាន់ Admins
      await _notifyAdminsForRequestRejected(requestData, managerName, reason, requestId);
      
      print('✅ Request rejected by Manager: $managerName');
    } on FirebaseException catch (e) {
      print('❌ Firebase Error: ${e.code} - ${e.message}');
      if (e.code == 'permission-denied') {
        throw Exception('អ្នកមិនមានសិទ្ធិបដិសេធសំណើនេះទេ');
      }
      throw Exception('Failed to reject request: ${e.message}');
    } catch (e) {
      throw Exception('Failed to reject request: $e');
    }
  }

  // ==================== APPROVE REQUEST (Admin) ====================
  Future<void> approveRequest(String requestId, String adminId, String adminName) async {
    try {
      final requestDoc = await _requestsCollection.doc(requestId).get();
      final requestData = requestDoc.data() as Map<String, dynamic>?;
      
      if (requestData == null) {
        throw Exception('Request not found');
      }
      
      await _requestsCollection.doc(requestId).update({
        'status': 'approved',
        'approvedBy': adminId,
        'approvedByName': adminName,
        'approvedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // ============ បញ្ជូន Notification ============
      
      // 1. បញ្ជូនទៅកាន់ Staff (អ្នកដាក់សំណើ)
      await _sendNotificationToUser(
        userId: requestData['userId'],
        userEmail: requestData['userEmail'],
        title: 'សំណើត្រូវបានអនុម័ត',
        message: 'សំណើរបស់អ្នកសម្រាប់ ${requestData['totalDays']} ថ្ងៃត្រូវបានអនុម័តដោយ $adminName',
        type: 'request_approved',
        requestId: requestId,
        extraData: {
          'approvedBy': adminName,
          'totalDays': requestData['totalDays'],
        },
      );

      // 2. បញ្ជូនទៅកាន់ Managers ក្នុង Department
      if (requestData['department'] != null && requestData['department'].isNotEmpty) {
        await _notifyManagersInDepartment(
          department: requestData['department'],
          title: 'សំណើត្រូវបានអនុម័ត',
          message: 'សំណើរបស់ ${requestData['userName']} (${requestData['totalDays']} ថ្ងៃ) ត្រូវបានអនុម័តដោយ $adminName',
          type: 'request_approved',
          requestId: requestId,
          extraData: {
            'staffName': requestData['userName'],
            'approvedBy': adminName,
            'totalDays': requestData['totalDays'],
          },
        );
      }
      
      print('✅ Request approved by Admin: $adminName');
    } catch (e) {
      throw Exception('Failed to approve request: $e');
    }
  }

  // ==================== REJECT REQUEST (Admin) ====================
  Future<void> rejectRequest(String requestId, String adminId, String adminName, {String? reason}) async {
    try {
      final requestDoc = await _requestsCollection.doc(requestId).get();
      final requestData = requestDoc.data() as Map<String, dynamic>?;
      
      if (requestData == null) {
        throw Exception('Request not found');
      }
      
      await _requestsCollection.doc(requestId).update({
        'status': 'rejected',
        'rejectedBy': adminId,
        'rejectedByName': adminName,
        'rejectionReason': reason,
        'rejectedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // ============ បញ្ជូន Notification ============
      
      // 1. បញ្ជូនទៅកាន់ Staff (អ្នកដាក់សំណើ)
      await _sendNotificationToUser(
        userId: requestData['userId'],
        userEmail: requestData['userEmail'],
        title: 'សំណើត្រូវបានបដិសេធ',
        message: 'សំណើរបស់អ្នកសម្រាប់ ${requestData['totalDays']} ថ្ងៃត្រូវបានបដិសេធ${reason != null ? '។ ហេតុផល: $reason' : ''}',
        type: 'request_rejected',
        requestId: requestId,
        extraData: {
          'rejectedBy': adminName,
          'rejectionReason': reason,
          'totalDays': requestData['totalDays'],
        },
      );

      // 2. បញ្ជូនទៅកាន់ Managers ក្នុង Department
      if (requestData['department'] != null && requestData['department'].isNotEmpty) {
        await _notifyManagersInDepartment(
          department: requestData['department'],
          title: 'សំណើត្រូវបានបដិសេធ',
          message: 'សំណើរបស់ ${requestData['userName']} (${requestData['totalDays']} ថ្ងៃ) ត្រូវបានបដិសេធដោយ $adminName',
          type: 'request_rejected',
          requestId: requestId,
          extraData: {
            'staffName': requestData['userName'],
            'rejectedBy': adminName,
            'totalDays': requestData['totalDays'],
          },
        );
      }
      
      print('✅ Request rejected by Admin: $adminName');
    } catch (e) {
      throw Exception('Failed to reject request: $e');
    }
  }

  // ==================== NOTIFICATION METHODS ====================

  /// បញ្ជូន Notification ទៅកាន់អ្នកប្រើប្រាស់ម្នាក់
  Future<void> _sendNotificationToUser({
    required String userId,
    required String userEmail,
    required String title,
    required String message,
    required String type,
    String? requestId,
    Map<String, dynamic>? extraData,
  }) async {
    try {
      final notificationRef = _notificationsCollection.doc();
      final notificationData = {
        'notificationId': notificationRef.id,
        'userId': userId,
        'userEmail': userEmail,
        'title': title,
        'message': message,
        'type': type,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
        ...?extraData,
      };
      if (requestId != null) {
        notificationData['requestId'] = requestId;
      }
      await notificationRef.set(notificationData);
      print('✅ Notification sent to user: $userEmail');
    } catch (e) {
      print('❌ Error sending notification to user: $e');
    }
  }

  /// បញ្ជូន Notification ទៅកាន់ Managers ក្នុង Department
  Future<void> _notifyManagersInDepartment({
    required String department,
    required String title,
    required String message,
    required String type,
    String? requestId,
    Map<String, dynamic>? extraData,
  }) async {
    try {
      Query query = _firestore
          .collection('users')
          .where('roleId', isEqualTo: '3')
          .where('status', isEqualTo: 'Active');
      
      if (department.isNotEmpty) {
        query = query.where('department', isEqualTo: department);
      }
      
      final managerSnapshot = await query.get();

      if (managerSnapshot.docs.isEmpty) return;

      final batch = _firestore.batch();
      
      for (var managerDoc in managerSnapshot.docs) {
        final data = managerDoc.data() as Map<String, dynamic>;
        final notificationRef = _notificationsCollection.doc();
        final notificationData = {
          'notificationId': notificationRef.id,
          'userId': data['userId'],
          'userEmail': data['email'],
          'title': title,
          'message': message,
          'type': type,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
          'department': department,
          ...?extraData,
        };
        if (requestId != null) {
          notificationData['requestId'] = requestId;
        }
        batch.set(notificationRef, notificationData);
      }

      await batch.commit();
      print('✅ Notifications sent to Managers in department: $department');
    } catch (e) {
      print('❌ Error notifying managers: $e');
    }
  }

  /// បញ្ជូន Notification ទៅកាន់ Admins ទាំងអស់
  Future<void> _notifyAllAdmins({
    required String title,
    required String message,
    required String type,
    String? requestId,
    Map<String, dynamic>? extraData,
  }) async {
    try {
      final adminSnapshot = await _firestore
          .collection('users')
          .where('roleId', isEqualTo: '1')
          .where('status', isEqualTo: 'Active')
          .get();

      if (adminSnapshot.docs.isEmpty) return;

      final batch = _firestore.batch();
      
      for (var adminDoc in adminSnapshot.docs) {
        final data = adminDoc.data() as Map<String, dynamic>;
        final notificationRef = _notificationsCollection.doc();
        final notificationData = {
          'notificationId': notificationRef.id,
          'userId': data['userId'],
          'userEmail': data['email'],
          'title': title,
          'message': message,
          'type': type,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
          ...?extraData,
        };
        if (requestId != null) {
          notificationData['requestId'] = requestId;
        }
        batch.set(notificationRef, notificationData);
      }

      await batch.commit();
      print('✅ Notifications sent to all Admins');
    } catch (e) {
      print('❌ Error notifying admins: $e');
    }
  }

  /// បញ្ជូន Notification ពេលមានសំណើថ្មីត្រូវការអនុម័តទៅកាន់ Managers
  Future<void> _notifyManagersForApproval(Map<String, dynamic> requestData, String requestId) async {
    final department = requestData['department'] ?? '';
    await _notifyManagersInDepartment(
      department: department,
      title: 'សំណើថ្មីត្រូវការអនុម័ត',
      message: '${requestData['userName']}${department.isNotEmpty ? " ($department)" : ""} បានដាក់សំណើលេខ #${requestData['requestNumber']} (${requestData['totalDays']} ថ្ងៃ)',
      type: 'need_approval',
      requestId: requestId,
      extraData: {
        'staffName': requestData['userName'],
        'requestNumber': requestData['requestNumber'],
        'totalDays': requestData['totalDays'],
        'department': department,
      },
    );
  }

  /// បញ្ជូន Notification ពេលមានសំណើថ្មីត្រូវការអនុម័តទៅកាន់ Admins
  Future<void> _notifyAdminsForApproval(Map<String, dynamic> requestData, String requestId) async {
    final department = requestData['department'] ?? '';
    await _notifyAllAdmins(
      title: 'សំណើថ្មីត្រូវការអនុម័ត',
      message: '${requestData['userName']}${department.isNotEmpty ? " ($department)" : ""} បានដាក់សំណើលេខ #${requestData['requestNumber']} (${requestData['totalDays']} ថ្ងៃ)',
      type: 'need_approval',
      requestId: requestId,
      extraData: {
        'staffName': requestData['userName'],
        'requestNumber': requestData['requestNumber'],
        'totalDays': requestData['totalDays'],
        'department': department,
      },
    );
  }

  /// បញ្ជូន Notification ពេល Auto Approved ទៅកាន់ Admins
  Future<void> _notifyAdminsForAutoApproval(Map<String, dynamic> requestData, String requestId) async {
    final department = requestData['department'] ?? '';
    await _notifyAllAdmins(
      title: 'សំណើត្រូវបានអនុម័តដោយស្វ័យប្រវត្តិ',
      message: '${requestData['userName']}${department.isNotEmpty ? " ($department)" : ""} បានដាក់សំណើលេខ #${requestData['requestNumber']} (${requestData['totalDays']} ថ្ងៃ) និងត្រូវបានអនុម័តដោយស្វ័យប្រវត្តិ',
      type: 'auto_approved',
      requestId: requestId,
      extraData: {
        'staffName': requestData['userName'],
        'requestNumber': requestData['requestNumber'],
        'totalDays': requestData['totalDays'],
        'department': department,
      },
    );
  }

  /// បញ្ជូន Notification ពេល Request ត្រូវបាន Approved ទៅកាន់ Admins
  Future<void> _notifyAdminsForRequestApproved(Map<String, dynamic> requestData, String approvedBy, String requestId) async {
    final department = requestData['department'] ?? '';
    await _notifyAllAdmins(
      title: 'សំណើត្រូវបានអនុម័ត',
      message: 'សំណើរបស់ ${requestData['userName']}${department.isNotEmpty ? " ($department)" : ""} (${requestData['totalDays']} ថ្ងៃ) ត្រូវបានអនុម័តដោយ $approvedBy',
      type: 'request_approved',
      requestId: requestId,
      extraData: {
        'staffName': requestData['userName'],
        'approvedBy': approvedBy,
        'totalDays': requestData['totalDays'],
        'department': department,
      },
    );
  }

  /// បញ្ជូន Notification ពេល Request ត្រូវបាន Rejected ទៅកាន់ Admins
  Future<void> _notifyAdminsForRequestRejected(Map<String, dynamic> requestData, String rejectedBy, String? reason, String requestId) async {
    final department = requestData['department'] ?? '';
    await _notifyAllAdmins(
      title: 'សំណើត្រូវបានបដិសេធ',
      message: 'សំណើរបស់ ${requestData['userName']}${department.isNotEmpty ? " ($department)" : ""} (${requestData['totalDays']} ថ្ងៃ) ត្រូវបានបដិសេធដោយ $rejectedBy${reason != null ? "។ ហេតុផល: $reason" : ""}',
      type: 'request_rejected',
      requestId: requestId,
      extraData: {
        'staffName': requestData['userName'],
        'rejectedBy': rejectedBy,
        'rejectionReason': reason,
        'totalDays': requestData['totalDays'],
        'department': department,
      },
    );
  }

  // ==================== HELPER METHODS ====================
  Future<int> _getUserRequestCountInCurrentMonth(String userId) async {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0);
    
    final snapshot = await _requestsCollection
        .where('userId', isEqualTo: userId)
        .where('createdAt', isGreaterThanOrEqualTo: startOfMonth)
        .where('createdAt', isLessThanOrEqualTo: endOfMonth)
        .get();
    
    return snapshot.docs.length;
  }

  Future<PolicyModel?> _getActivePolicy() async {
    try {
      final snapshot = await _policiesCollection
          .where('isActive', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();
      
      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data() as Map<String, dynamic>;
        return PolicyModel.fromFirestore(data, snapshot.docs.first.id);
      }
      return null;
    } catch (e) {
      print('Error getting active policy: $e');
      return null;
    }
  }

  DateTime? _parseDateString(String dateStr) {
    try {
      return DateFormat('dd MMM yyyy').parse(dateStr);
    } catch (e) {
      return null;
    }
  }

  List<String> _validateRequestAgainstPolicy({
    required PolicyModel policy,
    required int totalDays,
    required String reason,
    required bool hasDocument,
    required int daysUsedThisYear,
    required int daysAdvance,
  }) {
    final errors = <String>[];
    
    if (totalDays > policy.maxDaysPerRequest) {
      errors.add('មិនអាចស្នើសុំលើស ${policy.maxDaysPerRequest} ថ្ងៃក្នុងមួយដង');
    }
    
    final remainingDays = policy.maxDaysPerYear - daysUsedThisYear;
    if (totalDays > remainingDays) {
      errors.add('នៅសល់តែ $remainingDays ថ្ងៃប៉ុណ្ណោះក្នុងឆ្នាំនេះ');
    }
    
    if (reason != 'Other' && !policy.allowedReasons.contains(reason)) {
      errors.add('មូលហេតុ "$reason" មិនត្រូវបានអនុញ្ញាត');
    }
    
    if (policy.requireDocument && !hasDocument) {
      errors.add('តម្រូវឱ្យភ្ជាប់ឯកសារ');
    }
    
    if (daysAdvance < policy.minDaysAdvance) {
      errors.add('តម្រូវឱ្យស្នើសុំ ${policy.minDaysAdvance} ថ្ងៃជាមុន');
    }
    
    if (daysAdvance > policy.maxDaysAdvance) {
      errors.add('មិនអាចស្នើសុំលើស ${policy.maxDaysAdvance} ថ្ងៃជាមុន');
    }
    
    return errors;
  }

  Future<int> getTotalDaysUsedByStaff(String userId, int year) async {
    try {
      final startDate = DateTime(year, 1, 1);
      final endDate = DateTime(year, 12, 31);
      
      final startTimestamp = Timestamp.fromDate(startDate);
      final endTimestamp = Timestamp.fromDate(endDate);
      
      final snapshot = await _requestsCollection
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'approved')
          .where('createdAt', isGreaterThanOrEqualTo: startTimestamp)
          .where('createdAt', isLessThanOrEqualTo: endTimestamp)
          .get();
      
      int totalDays = 0;
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final daysValue = data['totalDays'];
        if (daysValue != null) {
          if (daysValue is int) {
            totalDays += daysValue;
          } else if (daysValue is double) {
            totalDays += daysValue.toInt();
          } else if (daysValue is num) {
            totalDays += daysValue.toInt();
          }
        }
      }
      
      return totalDays;
    } catch (e) {
      print('Error getting total days used: $e');
      return 0;
    }
  }

  // ==================== NOTIFICATION CRUD METHODS ====================
  
  /// ទទួលបានបញ្ជីសារជូនដំណឹងរបស់អ្នកប្រើប្រាស់
  Stream<QuerySnapshot> getUserNotifications(String userId) {
    return _notificationsCollection
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// សម្គាល់សារជូនដំណឹងមួយថាបានអាន
  Future<void> markNotificationAsRead(String notificationId) async {
    try {
      await _notificationsCollection.doc(notificationId).update({
        'isRead': true,
        'readAt': FieldValue.serverTimestamp(),
      });
      print('✅ Notification marked as read: $notificationId');
    } catch (e) {
      print('❌ Error marking notification as read: $e');
      throw Exception('Failed to mark notification as read: $e');
    }
  }

  /// សម្គាល់សារជូនដំណឹងទាំងអស់ថាបានអាន
  Future<void> markAllNotificationsAsRead(String userId) async {
    try {
      final snapshot = await _notificationsCollection
          .where('userId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();

      if (snapshot.docs.isEmpty) {
        print('ℹ️ No unread notifications to mark as read');
        return;
      }

      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.update(doc.reference, {
          'isRead': true,
          'readAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
      print('✅ All notifications marked as read for user: $userId');
    } catch (e) {
      print('❌ Error marking all notifications as read: $e');
      throw Exception('Failed to mark all notifications as read: $e');
    }
  }

  /// ទទួលបានចំនួនសារជូនដំណឹងដែលមិនទាន់អាន
  Future<int> getUnreadNotificationCount(String userId) async {
    try {
      final snapshot = await _notificationsCollection
          .where('userId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();
      return snapshot.docs.length;
    } catch (e) {
      print('❌ Error getting unread notification count: $e');
      return 0;
    }
  }

  /// លុបសារជូនដំណឹង
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _notificationsCollection.doc(notificationId).delete();
      print('✅ Notification deleted: $notificationId');
    } catch (e) {
      print('❌ Error deleting notification: $e');
      throw Exception('Failed to delete notification: $e');
    }
  }

  /// លុបសារជូនដំណឹងទាំងអស់របស់អ្នកប្រើប្រាស់
  Future<void> deleteAllNotifications(String userId) async {
    try {
      final snapshot = await _notificationsCollection
          .where('userId', isEqualTo: userId)
          .get();

      if (snapshot.docs.isEmpty) return;

      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      print('✅ All notifications deleted for user: $userId');
    } catch (e) {
      print('❌ Error deleting all notifications: $e');
      throw Exception('Failed to delete all notifications: $e');
    }
  }
}