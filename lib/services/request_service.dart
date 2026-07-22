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

  // ==================== GENERATE REQUEST NUMBER ====================
  Future<int> _generateRequestNumber() async {
    try {
      final counterRef = _firestore.collection('counters').doc('request_counter');
      
      final result = await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(counterRef);
        
        int currentCount = 0;
        if (snapshot.exists) {
          final data = snapshot.data();
          currentCount = (data?['value'] as int?) ?? 0;
        }
        
        final newCount = currentCount + 1;
        transaction.set(counterRef, {'value': newCount});
        
        return newCount;
      });
      
      return result;
    } catch (e) {
      print('❌ Error generating request number: $e');
      return DateTime.now().millisecondsSinceEpoch ~/ 1000;
    }
  }

  // ==================== FORMAT REQUEST NUMBER ====================
  String _formatRequestNumber(int number) {
    return number.toString().padLeft(4, '0');
  }

  // ==================== SUBMIT REQUEST ====================
  Future<Map<String, dynamic>> submitRequestWithAutoApprove({
    required String startDate,
    required String endDate,
    required int totalDays,
    required String reason,
    required String? otherReason,
    required String? fileUrl,
    required String? imageUrl,
    DateTime? submitTime,
    String? department,     // ✅ បន្ថែម
    String? departmentId,   // ✅ បន្ថែម
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
    String userDepartment = department ?? '';
    String userDepartmentId = departmentId ?? '';
    String userRoleId = '2';
    
    if (userDoc.docs.isNotEmpty) {
      final data = userDoc.docs.first.data() as Map<String, dynamic>;
      userName = data['fullName'] ?? data['username'] ?? userName;
      userEmail = data['email'] ?? userEmail;
      if (department == null || department.isEmpty) {
        userDepartment = data['department'] ?? '';
      }
      if (departmentId == null || departmentId.isEmpty) {
        userDepartmentId = data['departmentId'] ?? data['deptId'] ?? '';
      }
      userRoleId = data['roleId']?.toString() ?? '2';
    }

    print('📝 Submitting request for: $userName');
    print('📝 Department: "$userDepartment"');
    print('📝 Department ID: "$userDepartmentId"');
    print('📝 Role: $userRoleId');

    String reasonForValidation = reason;
    String reasonForStorage = reason;
    
    if (reason == 'Other') {
      reasonForStorage = otherReason ?? reason;
      reasonForValidation = 'Other';
    }
    
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
        reason: reasonForValidation,
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
    int requestCountInMonthValue = requestCountInMonth + 1;
    
    if (policy != null && policy.autoApprove) {
      if (requestCountInMonthValue == 1) {
        status = 'approved';
        autoMessage = policy.firstRequestMessage;
      } else if (requestCountInMonthValue == 2) {
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
      autoMessage = "Your request is pending approval from Manager";
    }

    String? submitTimeString;
    if (submitTime != null) {
      final utcTime = submitTime.toUtc().subtract(const Duration(hours: 7));
      submitTimeString = utcTime.toIso8601String();
    }

    final requestNumberInt = await _generateRequestNumber();
    final requestNumberFormatted = _formatRequestNumber(requestNumberInt);
    
    print('📝 Request Number: $requestNumberFormatted');

    final requestData = {
      'userId': user.uid,
      'userEmail': userEmail,
      'userName': userName,
      'department': userDepartment,
      'departmentId': userDepartmentId, // ✅ រក្សាទុក departmentId
      'startDate': startDate,
      'endDate': endDate,
      'totalDays': totalDays,
      'reason': reasonForStorage,
      'originalReason': reason,
      'fileUrl': fileUrl,
      'imageUrl': imageUrl,
      'status': status,
      'requestNumber': requestNumberFormatted,
      'requestNumberInt': requestNumberInt,
      'requestCountInMonth': requestCountInMonthValue,
      'month': DateTime.now().month,
      'year': DateTime.now().year,
      'autoApproved': status == 'approved',
      'needManagerApproval': needManagerApproval,
      'policyId': policy?.id,
      'submitTime': submitTimeString,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    final docRef = await _requestsCollection.add(requestData);
    
    await docRef.update({
      'requestId': requestNumberFormatted,
    });

    print('🔔 ====== SENDING NOTIFICATIONS ======');
    print('🔔 Request ID: $requestNumberFormatted');
    print('🔔 Status: $status');
    print('🔔 Need Manager Approval: $needManagerApproval');
    print('🔔 Department: "$userDepartment"');
    print('🔔 Department ID: "$userDepartmentId"');
    
    await _sendNotificationToUser(
      userId: user.uid,
      userEmail: userEmail,
      title: status == 'approved' ? 'Request Auto-Approved' : 'Request Needs Approval',
      message: autoMessage ?? 'Your request has been submitted successfully',
      type: status == 'approved' ? 'auto_approved' : 'submitted',
      requestId: requestNumberFormatted,
      extraData: {
        'requestNumber': requestNumberFormatted,
        'totalDays': totalDays,
        'submitTime': submitTimeString,
        'department': userDepartment,
        'departmentId': userDepartmentId,
      },
    );

    await _notifyManagersForNewRequest(requestData, requestNumberFormatted, status, submitTimeString);

    if (needManagerApproval) {
      await _notifyAdminsForApproval(requestData, requestNumberFormatted, submitTimeString);
    } else {
      await _notifyAdminsForAutoApproval(requestData, requestNumberFormatted, submitTimeString);
    }

    print('🔔 ====== NOTIFICATIONS COMPLETED ======');

    return {
      'status': status,
      'message': autoMessage,
      'requestId': requestNumberFormatted,
      'requestNumber': requestNumberFormatted,
      'needManagerApproval': needManagerApproval,
    };
  }

  // ==================== NOTIFY MANAGERS FOR NEW REQUEST ====================
  Future<void> _notifyManagersForNewRequest(Map<String, dynamic> requestData, String requestId, String status, String? submitTimeString) async {
    final department = requestData['department'] ?? '';
    final departmentId = requestData['departmentId'] ?? '';
    final isAutoApproved = status == 'approved';
    final staffName = requestData['userName'] ?? 'Unknown';
    final requestNumber = requestData['requestNumber'] ?? '0000';
    final totalDays = requestData['totalDays'] ?? 0;
    final userEmail = requestData['userEmail'] ?? '';
    
    print('🔔 ----- Notifying Managers for New Request -----');
    print('🔔 Department: "$department"');
    print('🔔 Department ID: "$departmentId"');
    print('🔔 Staff: $staffName');
    print('🔔 Request #: $requestNumber');
    print('🔔 Total Days: $totalDays');
    print('🔔 Is Auto Approved: $isAutoApproved');
    
    try {
      final managerSnapshot = await _firestore
          .collection('users')
          .where('roleId', isEqualTo: '3')
          .where('status', isEqualTo: 'Active')
          .get();
      
      print(' Total managers found (roleId=3): ${managerSnapshot.docs.length}');
      
      QuerySnapshot directorSnapshot = await _firestore
          .collection('users')
          .where('roleId', isEqualTo: '4')
          .where('status', isEqualTo: 'Active')
          .get();
      
      print(' Total directors found (roleId=4): ${directorSnapshot.docs.length}');
      
      List<QueryDocumentSnapshot> allManagers = [];
      allManagers.addAll(managerSnapshot.docs);
      allManagers.addAll(directorSnapshot.docs);
      
      Set<String> userIds = {};
      List<QueryDocumentSnapshot> uniqueManagers = [];
      for (var doc in allManagers) {
        final data = doc.data() as Map<String, dynamic>;
        final userId = data['userId'] ?? '';
        if (userId.isNotEmpty && !userIds.contains(userId)) {
          userIds.add(userId);
          uniqueManagers.add(doc);
        }
      }
      
      print(' Total unique managers/directors: ${uniqueManagers.length}');
      
      if (uniqueManagers.isEmpty) {
        print('❌ No managers found in the system at all!');
        return;
      }
      
      print(' Sending notifications to ${uniqueManagers.length} managers/directors');
      
      int sentCount = 0;
      for (var doc in uniqueManagers) {
        final data = doc.data() as Map<String, dynamic>;
        final userId = data['userId'] ?? '';
        final managerEmail = data['email'] ?? '';
        final managerName = data['fullName'] ?? 'Manager';
        final managerDepartment = data['department'] ?? 'No Department';
        final roleId = data['roleId']?.toString() ?? '';
        
        if (userId.isEmpty) {
          print('⚠️ Manager has no userId: $managerEmail');
          continue;
        }
        
        if (userId == requestData['userId']) {
          print('⚠️ Skipping self notification for: $managerEmail');
          continue;
        }
        
        print('📨 Sending to manager: $managerEmail ($managerName) - Dept: $managerDepartment - Role: $roleId');
        
        String deptInfo = department.isNotEmpty ? ' ($department)' : '';
        String statusText = isAutoApproved ? 'Auto-approved' : 'Needs approval';
        String timeInfo = submitTimeString != null ? ' Submitted: $submitTimeString' : '';
        
        await _sendNotificationToUser(
          userId: userId,
          userEmail: managerEmail,
          title: isAutoApproved ? 'New Request Auto-Approved' : 'New Request Needs Your Approval',
          message: '$staffName$deptInfo submitted request #$requestNumber ($totalDays day(s)) - $statusText$timeInfo',
          type: isAutoApproved ? 'auto_approved' : 'need_approval',
          requestId: requestId,
          extraData: {
            'staffName': staffName,
            'staffEmail': userEmail,
            'requestNumber': requestNumber,
            'totalDays': totalDays,
            'department': department,
            'departmentId': departmentId,
            'status': status,
            'autoApproved': isAutoApproved,
            'managerDepartment': managerDepartment,
            'roleId': roleId,
            'submitTime': submitTimeString,
          },
        );
        sentCount++;
      }
      
      print(' Successfully sent $sentCount notifications to managers/directors');
      
    } catch (e) {
      print('❌ Error in _notifyManagersForNewRequest: $e');
    }
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
        throw Exception('You cannot approve requests from staff outside your department');
      }
      
      if (requestData['status'] != 'pending') {
        throw Exception('This request has already been processed');
      }
      
      await _requestsCollection.doc(requestId).update({
        'status': 'approved',
        'approvedBy': managerId,
        'approvedByName': managerName,
        'approvedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await _sendNotificationToUser(
        userId: requestData['userId'],
        userEmail: requestData['userEmail'],
        title: 'Request Approved',
        message: 'Your request for ${requestData['totalDays']} day(s) has been approved by $managerName',
        type: 'request_approved',
        requestId: requestId,
        extraData: {
          'approvedBy': managerName,
          'totalDays': requestData['totalDays'],
        },
      );

      await _notifyAdminsForRequestApproved(requestData, managerName, requestId);
      
      print(' Request approved by Manager: $managerName');
    } on FirebaseException catch (e) {
      print('❌ Firebase Error: ${e.code} - ${e.message}');
      if (e.code == 'permission-denied') {
        throw Exception('You do not have permission to approve this request');
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
        throw Exception('You cannot reject requests from staff outside your department');
      }
      
      if (requestData['status'] != 'pending') {
        throw Exception('This request has already been processed');
      }
      
      await _requestsCollection.doc(requestId).update({
        'status': 'rejected',
        'rejectedBy': managerId,
        'rejectedByName': managerName,
        'rejectionReason': reason,
        'rejectedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await _sendNotificationToUser(
        userId: requestData['userId'],
        userEmail: requestData['userEmail'],
        title: 'Request Rejected',
        message: 'Your request for ${requestData['totalDays']} day(s) has been rejected${reason != null ? '. Reason: $reason' : ''}',
        type: 'request_rejected',
        requestId: requestId,
        extraData: {
          'rejectedBy': managerName,
          'rejectionReason': reason,
          'totalDays': requestData['totalDays'],
        },
      );

      await _notifyAdminsForRequestRejected(requestData, managerName, reason, requestId);
      
      print(' Request rejected by Manager: $managerName');
    } on FirebaseException catch (e) {
      print('❌ Firebase Error: ${e.code} - ${e.message}');
      if (e.code == 'permission-denied') {
        throw Exception('You do not have permission to reject this request');
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

      await _sendNotificationToUser(
        userId: requestData['userId'],
        userEmail: requestData['userEmail'],
        title: 'Request Approved',
        message: 'Your request for ${requestData['totalDays']} day(s) has been approved by $adminName',
        type: 'request_approved',
        requestId: requestId,
        extraData: {
          'approvedBy': adminName,
          'totalDays': requestData['totalDays'],
        },
      );

      if (requestData['department'] != null && requestData['department'].isNotEmpty) {
        await _notifyManagersInDepartment(
          department: requestData['department'],
          title: 'Request Approved',
          message: '${requestData['userName']}\'s request (${requestData['totalDays']} day(s)) has been approved by $adminName',
          type: 'request_approved',
          requestId: requestId,
          extraData: {
            'staffName': requestData['userName'],
            'approvedBy': adminName,
            'totalDays': requestData['totalDays'],
          },
        );
      }
      
      print('Request approved by Admin: $adminName');
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

      await _sendNotificationToUser(
        userId: requestData['userId'],
        userEmail: requestData['userEmail'],
        title: 'Request Rejected',
        message: 'Your request for ${requestData['totalDays']} day(s) has been rejected${reason != null ? '. Reason: $reason' : ''}',
        type: 'request_rejected',
        requestId: requestId,
        extraData: {
          'rejectedBy': adminName,
          'rejectionReason': reason,
          'totalDays': requestData['totalDays'],
        },
      );

      if (requestData['department'] != null && requestData['department'].isNotEmpty) {
        await _notifyManagersInDepartment(
          department: requestData['department'],
          title: 'Request Rejected',
          message: '${requestData['userName']}\'s request (${requestData['totalDays']} day(s)) has been rejected by $adminName',
          type: 'request_rejected',
          requestId: requestId,
          extraData: {
            'staffName': requestData['userName'],
            'rejectedBy': adminName,
            'totalDays': requestData['totalDays'],
          },
        );
      }
      
      print(' Request rejected by Admin: $adminName');
    } catch (e) {
      throw Exception('Failed to reject request: $e');
    }
  }

  // ==================== NOTIFICATION METHODS ====================

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
      print('📨 Sending notification to: $userEmail');
      print('📨 Title: $title');
      
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
      print(' Notification sent to: $userEmail');
    } catch (e) {
      print('❌ Error sending notification to user: $e');
    }
  }

  Future<void> _notifyManagersInDepartment({
    required String department,
    required String title,
    required String message,
    required String type,
    String? requestId,
    Map<String, dynamic>? extraData,
  }) async {
    try {
      print('🔔 ----- Notifying Managers in Department -----');
      print('🔔 Department: "$department"');
      
      Query query = _firestore
          .collection('users')
          .where('roleId', isEqualTo: '3')
          .where('status', isEqualTo: 'Active');
      
      if (department.isNotEmpty) {
        query = query.where('department', isEqualTo: department);
      }
      
      final managerSnapshot = await query.get();

      if (managerSnapshot.docs.isEmpty) {
        print('⚠️ No managers found for department: $department');
        return;
      }

      print(' Found ${managerSnapshot.docs.length} managers');

      final batch = _firestore.batch();
      int count = 0;
      
      for (var managerDoc in managerSnapshot.docs) {
        final data = managerDoc.data() as Map<String, dynamic>;
        final managerUserId = data['userId'];
        
        if (managerUserId == null || managerUserId.isEmpty) {
          print('⚠️ Manager has no userId: ${data['email']}');
          continue;
        }
        
        final notificationRef = _notificationsCollection.doc();
        final notificationData = {
          'notificationId': notificationRef.id,
          'userId': managerUserId,
          'userEmail': data['email'] ?? '',
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
        count++;
        print('📨 Notification prepared for manager: ${data['email']}');
      }

      await batch.commit();
      print(' Sent $count notifications to managers');
    } catch (e) {
      print('❌ Error notifying managers: $e');
    }
  }

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

      if (adminSnapshot.docs.isEmpty) {
        print('⚠️ No admins found');
        return;
      }

      print(' Found ${adminSnapshot.docs.length} admins');

      final batch = _firestore.batch();
      int count = 0;
      
      for (var adminDoc in adminSnapshot.docs) {
        final data = adminDoc.data() as Map<String, dynamic>;
        final adminUserId = data['userId'];
        
        if (adminUserId == null || adminUserId.isEmpty) {
          print('⚠️ Admin has no userId: ${data['email']}');
          continue;
        }
        
        final notificationRef = _notificationsCollection.doc();
        final notificationData = {
          'notificationId': notificationRef.id,
          'userId': adminUserId,
          'userEmail': data['email'] ?? '',
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
        count++;
      }

      await batch.commit();
      print('Sent $count notifications to admins');
    } catch (e) {
      print('❌ Error notifying admins: $e');
    }
  }

  Future<void> _notifyManagersForApproval(Map<String, dynamic> requestData, String requestId) async {
    final department = requestData['department'] ?? '';
    await _notifyManagersInDepartment(
      department: department,
      title: 'New Request Needs Approval',
      message: '${requestData['userName']}${department.isNotEmpty ? " ($department)" : ""} submitted request #${requestData['requestNumber']} (${requestData['totalDays']} day(s))',
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

  Future<void> _notifyAdminsForApproval(Map<String, dynamic> requestData, String requestId, String? submitTimeString) async {
    final department = requestData['department'] ?? '';
    String timeInfo = submitTimeString != null ? ' Submitted: $submitTimeString' : '';
    await _notifyAllAdmins(
      title: 'New Request Needs Approval',
      message: '${requestData['userName']}${department.isNotEmpty ? " ($department)" : ""} submitted request #${requestData['requestNumber']} (${requestData['totalDays']} day(s))$timeInfo',
      type: 'need_approval',
      requestId: requestId,
      extraData: {
        'staffName': requestData['userName'],
        'requestNumber': requestData['requestNumber'],
        'totalDays': requestData['totalDays'],
        'department': department,
        'submitTime': submitTimeString,
      },
    );
  }

  Future<void> _notifyAdminsForAutoApproval(Map<String, dynamic> requestData, String requestId, String? submitTimeString) async {
    final department = requestData['department'] ?? '';
    String timeInfo = submitTimeString != null ? ' Submitted: $submitTimeString' : '';
    await _notifyAllAdmins(
      title: 'Request Auto-Approved',
      message: '${requestData['userName']}${department.isNotEmpty ? " ($department)" : ""} submitted request #${requestData['requestNumber']} (${requestData['totalDays']} day(s)) and was auto-approved$timeInfo',
      type: 'auto_approved',
      requestId: requestId,
      extraData: {
        'staffName': requestData['userName'],
        'requestNumber': requestData['requestNumber'],
        'totalDays': requestData['totalDays'],
        'department': department,
        'submitTime': submitTimeString,
      },
    );
  }

  Future<void> _notifyAdminsForRequestApproved(Map<String, dynamic> requestData, String approvedBy, String requestId) async {
    final department = requestData['department'] ?? '';
    await _notifyAllAdmins(
      title: 'Request Approved',
      message: '${requestData['userName']}\'s request${department.isNotEmpty ? " ($department)" : ""} (${requestData['totalDays']} day(s)) was approved by $approvedBy',
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

  Future<void> _notifyAdminsForRequestRejected(Map<String, dynamic> requestData, String rejectedBy, String? reason, String requestId) async {
    final department = requestData['department'] ?? '';
    await _notifyAllAdmins(
      title: 'Request Rejected',
      message: '${requestData['userName']}\'s request${department.isNotEmpty ? " ($department)" : ""} (${requestData['totalDays']} day(s)) was rejected by $rejectedBy${reason != null ? ". Reason: $reason" : ""}',
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
      errors.add('Cannot request more than ${policy.maxDaysPerRequest} day(s) per request');
    }
    
    final remainingDays = policy.maxDaysPerYear - daysUsedThisYear;
    if (totalDays > remainingDays) {
      errors.add('Only $remainingDays day(s) remaining this year');
    }
    
    if (reason != 'Other' && !policy.allowedReasons.contains(reason)) {
      errors.add('Reason "$reason" is not allowed');
    }
    
    if (policy.requireDocument && !hasDocument) {
      errors.add('Document attachment is required');
    }
    
    if (daysAdvance < policy.minDaysAdvance) {
      errors.add('Must request at least ${policy.minDaysAdvance} day(s) in advance');
    }
    
    if (daysAdvance > policy.maxDaysAdvance) {
      errors.add('Cannot request more than ${policy.maxDaysAdvance} day(s) in advance');
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
  
  Stream<QuerySnapshot> getUserNotifications(String userId) {
    return _notificationsCollection
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> markNotificationAsRead(String notificationId) async {
    try {
      await _notificationsCollection.doc(notificationId).update({
        'isRead': true,
        'readAt': FieldValue.serverTimestamp(),
      });
      print(' Notification marked as read: $notificationId');
    } catch (e) {
      print('❌ Error marking notification as read: $e');
      throw Exception('Failed to mark notification as read: $e');
    }
  }

  Future<void> markAllNotificationsAsRead(String userId) async {
    try {
      final snapshot = await _notificationsCollection
          .where('userId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();

      if (snapshot.docs.isEmpty) {
        print('ℹNo unread notifications to mark as read');
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
      print(' All notifications marked as read for user: $userId');
    } catch (e) {
      print('❌ Error marking all notifications as read: $e');
      throw Exception('Failed to mark all notifications as read: $e');
    }
  }

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

  Future<void> deleteNotification(String notificationId) async {
    try {
      await _notificationsCollection.doc(notificationId).delete();
      print(' Notification deleted: $notificationId');
    } catch (e) {
      print('❌ Error deleting notification: $e');
      throw Exception('Failed to delete notification: $e');
    }
  }

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
      print(' All notifications deleted for user: $userId');
    } catch (e) {
      print('❌ Error deleting all notifications: $e');
      throw Exception('Failed to delete all notifications: $e');
    }
  }
}