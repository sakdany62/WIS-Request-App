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
    this.firstRequestMessage = "អ្នកនៅសល់ថ្ងៃឈប់ ១ ដងទៀត!",
    this.secondRequestMessage = "អ្នកអស់ថ្ងៃដែលត្រូវឈប់បន្តទៀតហើយ!",
    this.thirdRequestMessage = "សំណើរបស់អ្នកកំពុងរង់ចាំការអនុម័តពី Admin",
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
      firstRequestMessage: data['firstRequestMessage'] ?? "អ្នកនៅសល់ថ្ងៃឈប់ ១ ដងទៀត!",
      secondRequestMessage: data['secondRequestMessage'] ?? "អ្នកអស់ថ្ងៃដែលត្រូវឈប់បន្តទៀតហើយ!",
      thirdRequestMessage: data['thirdRequestMessage'] ?? "សំណើរបស់អ្នកកំពុងរង់ចាំការអនុម័តពី Admin",
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
    };
  }

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
}