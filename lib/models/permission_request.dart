// lib/models/permission_request.dart
class PermissionRequest {
  final String? id;
  final String staffId;
  final String staffName;
  final String staffPosition;
  final String permissionType;
  final Map<String, dynamic> details;
  final String status;
  final String managerId;
  final String managerName;
  final List<String> adminIds;
  final DateTime requestedAt;
  final DateTime? respondedAt;
  final String? responseNote;
  final bool notificationSent;
  final bool staffNotified;

  PermissionRequest({
    this.id,
    required this.staffId,
    required this.staffName,
    required this.staffPosition,
    required this.permissionType,
    required this.details,
    required this.status,
    required this.managerId,
    required this.managerName,
    required this.adminIds,
    required this.requestedAt,
    this.respondedAt,
    this.responseNote,
    this.notificationSent = false,
    this.staffNotified = false,
  });

  Map<String, dynamic> toJson() => {
    'staffId': staffId,
    'staffName': staffName,
    'staffPosition': staffPosition,
    'permissionType': permissionType,
    'details': details,
    'status': status,
    'managerId': managerId,
    'managerName': managerName,
    'adminIds': adminIds,
    'requestedAt': requestedAt.toIso8601String(),
    'respondedAt': respondedAt?.toIso8601String(),
    'responseNote': responseNote,
    'notificationSent': notificationSent,
    'staffNotified': staffNotified,
  };

  factory PermissionRequest.fromJson(String id, Map<String, dynamic> json) {
    return PermissionRequest(
      id: id,
      staffId: json['staffId'] ?? '',
      staffName: json['staffName'] ?? '',
      staffPosition: json['staffPosition'] ?? '',
      permissionType: json['permissionType'] ?? '',
      details: Map<String, dynamic>.from(json['details'] ?? {}),
      status: json['status'] ?? 'pending',
      managerId: json['managerId'] ?? '',
      managerName: json['managerName'] ?? '',
      adminIds: List<String>.from(json['adminIds'] ?? []),
      requestedAt: DateTime.parse(json['requestedAt']),
      respondedAt: json['respondedAt'] != null 
          ? DateTime.parse(json['respondedAt']) 
          : null,
      responseNote: json['responseNote'],
      notificationSent: json['notificationSent'] ?? false,
      staffNotified: json['staffNotified'] ?? false,
    );
  }
}