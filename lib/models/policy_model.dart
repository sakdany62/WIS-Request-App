// lib/models/policy_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class PolicyModel {
  final String id;
  final String name;
  final String description;
  final int maxDaysPerRequest;
  final int maxDaysPerYear;
  final int minDaysAdvance;
  final int maxDaysAdvance;
  final List<String> allowedReasons;
  final bool requireDocument;
  final bool autoApprove;
  final String applicableTo;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;
  
  final int autoApproveFirstCount;
  final int autoApproveSecondCount;
  final String firstRequestMessage;
  final String secondRequestMessage;
  final String thirdRequestMessage;

  // ✅ បន្ថែម field ថ្មី
  final bool allowCustomReason;
  final int? maxCustomReasonLength; // កំណត់ប្រវែងអតិបរមា

  // Notification Settings
  final bool enableNotifications;
  final String notificationTitle;
  final String notificationBody;
  final bool notifyOnRequestSubmit;
  final bool notifyOnStatusChange;
  final bool notifyOnApproval;
  final bool notifyOnRejection;
  final bool notifyAdminOnNewRequest;

  PolicyModel({
    required this.id,
    required this.name,
    required this.description,
    required this.maxDaysPerRequest,
    required this.maxDaysPerYear,
    required this.minDaysAdvance,
    required this.maxDaysAdvance,
    required this.allowedReasons,
    required this.requireDocument,
    required this.autoApprove,
    required this.applicableTo,
    required this.isActive,
    required this.createdAt,
    this.updatedAt,
    this.autoApproveFirstCount = 1,
    this.autoApproveSecondCount = 2,
    this.firstRequestMessage = "You have 1 day of leave remaining!",
    this.secondRequestMessage = "You have no more leave days remaining!",
    this.thirdRequestMessage = "Your request is pending Admin approval",
    this.allowCustomReason = false, // ✅ Default false
    this.maxCustomReasonLength = 255, // ✅ Default 255 characters
    this.enableNotifications = true,
    this.notificationTitle = "Leave Request Notification",
    this.notificationBody = "Your leave request has been processed",
    this.notifyOnRequestSubmit = true,
    this.notifyOnStatusChange = true,
    this.notifyOnApproval = true,
    this.notifyOnRejection = true,
    this.notifyAdminOnNewRequest = true,
  });

  factory PolicyModel.fromFirestore(Map<String, dynamic> data, String documentId) {
    return PolicyModel(
      id: documentId,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      maxDaysPerRequest: data['maxDaysPerRequest'] ?? 30,
      maxDaysPerYear: data['maxDaysPerYear'] ?? 24,
      minDaysAdvance: data['minDaysAdvance'] ?? 1,
      maxDaysAdvance: data['maxDaysAdvance'] ?? 30,
      allowedReasons: List<String>.from(data['allowedReasons'] ?? ['Sick', 'Personal issue', 'Vacation', 'Emergency']),
      requireDocument: data['requireDocument'] ?? false,
      autoApprove: data['autoApprove'] ?? false,
      applicableTo: data['applicableTo'] ?? 'all',
      isActive: data['isActive'] ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      autoApproveFirstCount: data['autoApproveFirstCount'] ?? 1,
      autoApproveSecondCount: data['autoApproveSecondCount'] ?? 2,
      firstRequestMessage: data['firstRequestMessage'] ?? "You have 1 day of leave remaining!",
      secondRequestMessage: data['secondRequestMessage'] ?? "You have no more leave days remaining!",
      thirdRequestMessage: data['thirdRequestMessage'] ?? "Your request is pending Admin approval",
      
      // ✅ អាន allowCustomReason ពី Firestore
      allowCustomReason: data['allowCustomReason'] ?? false,
      maxCustomReasonLength: data['maxCustomReasonLength'] ?? 255,
      
      enableNotifications: data['enableNotifications'] ?? true,
      notificationTitle: data['notificationTitle'] ?? "Leave Request Notification",
      notificationBody: data['notificationBody'] ?? "Your leave request has been processed",
      notifyOnRequestSubmit: data['notifyOnRequestSubmit'] ?? true,
      notifyOnStatusChange: data['notifyOnStatusChange'] ?? true,
      notifyOnApproval: data['notifyOnApproval'] ?? true,
      notifyOnRejection: data['notifyOnRejection'] ?? true,
      notifyAdminOnNewRequest: data['notifyAdminOnNewRequest'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'maxDaysPerRequest': maxDaysPerRequest,
      'maxDaysPerYear': maxDaysPerYear,
      'minDaysAdvance': minDaysAdvance,
      'maxDaysAdvance': maxDaysAdvance,
      'allowedReasons': allowedReasons,
      'requireDocument': requireDocument,
      'autoApprove': autoApprove,
      'applicableTo': applicableTo,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'autoApproveFirstCount': autoApproveFirstCount,
      'autoApproveSecondCount': autoApproveSecondCount,
      'firstRequestMessage': firstRequestMessage,
      'secondRequestMessage': secondRequestMessage,
      'thirdRequestMessage': thirdRequestMessage,
      
      // ✅ រក្សាទុក allowCustomReason ទៅ Firestore
      'allowCustomReason': allowCustomReason,
      'maxCustomReasonLength': maxCustomReasonLength,
      
      'enableNotifications': enableNotifications,
      'notificationTitle': notificationTitle,
      'notificationBody': notificationBody,
      'notifyOnRequestSubmit': notifyOnRequestSubmit,
      'notifyOnStatusChange': notifyOnStatusChange,
      'notifyOnApproval': notifyOnApproval,
      'notifyOnRejection': notifyOnRejection,
      'notifyAdminOnNewRequest': notifyAdminOnNewRequest,
    };
  }

  // ============================================================
  // ✅ បន្ថែម method សម្រាប់ពិនិត្យ Custom Reason
  // ============================================================
  
  /// ពិនិត្យថាតើ reason ត្រូវបានអនុញ្ញាតឬទេ
  bool isReasonAllowed(String reason) {
    // ប្រសិនបើ reason ស្ថិតក្នុងបញ្ជី allowedReasons
    if (allowedReasons.contains(reason)) {
      return true;
    }
    
    // ប្រសិនបើ reason ជា "Other" (តម្លៃថេរ)
    if (reason == 'Other' && allowedReasons.contains('Other')) {
      return true;
    }
    
    return false;
  }

  /// ពិនិត្យថាតើ custom reason ត្រឹមត្រូវឬទេ
  bool isValidCustomReason(String customReason) {
    // ត្រូវតែបើក allowCustomReason
    if (!allowCustomReason) {
      return false;
    }
    
    // ត្រូវតែមាន "Other" ក្នុងបញ្ជី
    if (!allowedReasons.contains('Other')) {
      return false;
    }
    
    // Custom reason មិនអាចទទេ
    if (customReason.trim().isEmpty) {
      return false;
    }
    
    // Custom reason មិនអាចខ្លីពេក (យ៉ាងតិច 3 តួអក្សរ)
    if (customReason.trim().length < 3) {
      return false;
    }
    
    // Custom reason មិនអាចវែងពេក
    if (customReason.trim().length > (maxCustomReasonLength ?? 255)) {
      return false;
    }
    
    return true;
  }

  /// ទទួលបាន reason ចុងក្រោយ (សម្រាប់រក្សាទុក)
  String getFinalReason(String selectedReason, String customReason) {
    if (selectedReason == 'Other' && customReason.trim().isNotEmpty) {
      return customReason.trim();
    }
    return selectedReason;
  }

  /// ពិនិត្យថាតើ reason គឺជា custom reason
  bool isCustomReason(String selectedReason) {
    return selectedReason == 'Other' && allowedReasons.contains('Other');
  }

  // ============================================================
  // Method ដើម (មិនផ្លាស់ប្តូរ)
  // ============================================================

  bool shouldAutoApprove(int requestNumber) {
    return autoApprove && 
           (requestNumber == autoApproveFirstCount || 
            requestNumber == autoApproveSecondCount);
  }

  String getAutoApproveMessage(int requestNumber) {
    if (requestNumber == autoApproveFirstCount) {
      return firstRequestMessage;
    } else if (requestNumber == autoApproveSecondCount) {
      return secondRequestMessage;
    } else {
      return thirdRequestMessage;
    }
  }

  String getRequestStatus(int requestNumber) {
    if (shouldAutoApprove(requestNumber)) {
      return 'approved';
    }
    return 'pending';
  }

  bool needsAdminApproval(int requestNumber) {
    return !shouldAutoApprove(requestNumber);
  }

  bool shouldSendNotification(String eventType) {
    if (!enableNotifications) return false;
    
    switch(eventType) {
      case 'submit':
        return notifyOnRequestSubmit;
      case 'status_change':
        return notifyOnStatusChange;
      case 'approval':
        return notifyOnApproval;
      case 'rejection':
        return notifyOnRejection;
      case 'admin_new_request':
        return notifyAdminOnNewRequest;
      default:
        return true;
    }
  }

  Map<String, String> getNotificationMessage(String eventType) {
    String title = notificationTitle;
    String body = notificationBody;
    
    switch(eventType) {
      case 'submit':
        body = 'Your leave request has been submitted successfully';
        break;
      case 'approval':
        body = 'Your leave request has been approved successfully';
        break;
      case 'rejection':
        body = 'Your leave request has been rejected';
        break;
      case 'status_change':
        body = 'Your leave request status has been changed';
        break;
      case 'admin_new_request':
        title = 'New Leave Request';
        body = 'A staff member has submitted a new leave request. Please review it.';
        break;
    }
    
    return {
      'title': title,
      'body': body,
    };
  }
}