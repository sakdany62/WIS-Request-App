import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class UserModel {
  final String id;
  final String userId;
  final String roleId;
  final String fullName;
  final String phone;
  final String email;
  final String username;
  final String status;
  final DateTime? createdAt;
  final String? department;       
  final String? departmentId;     
  final String? profileImage;
  final String? profileImageUrl;
  final String? employeeId;
  final String? position;
  final DateTime? updatedAt;

  UserModel({
    required this.id,
    required this.userId,
    required this.roleId,
    required this.fullName,
    required this.phone,
    required this.email,
    required this.username,
    required this.status,
    this.createdAt,
    this.department,
    this.departmentId,
    this.profileImage,
    this.profileImageUrl,
    this.employeeId,
    this.position,
    this.updatedAt,
  });

  // ============================================================
  // FACTORY FROM FIRESTORE
  // ============================================================
  factory UserModel.fromFirestore(Map<String, dynamic> data, String documentId) {
    return UserModel(
      id: documentId,
      userId: data['userId']?.toString() ?? '',
      roleId: data['roleId']?.toString() ?? '2',
      fullName: data['fullName']?.toString() ?? '',
      phone: data['phone']?.toString() ?? '',
      email: data['email']?.toString() ?? '',
      username: data['username']?.toString() ?? '',
      status: data['status']?.toString() ?? 'Active',
      createdAt: data['createdAt'] != null 
          ? (data['createdAt'] as Timestamp).toDate() 
          : null,
      department: data['department']?.toString() ?? '',
      departmentId: data['departmentId']?.toString() ?? '',
      profileImage: data['profileImage']?.toString() ?? '',
      profileImageUrl: data['profileImageUrl']?.toString() ?? 
          data['profileImage']?.toString() ?? '',
      employeeId: data['employeeId']?.toString() ?? '',
      position: data['position']?.toString() ?? '',
      updatedAt: data['updatedAt'] != null 
          ? (data['updatedAt'] as Timestamp).toDate() 
          : null,
    );
  }

  // ============================================================
  // TO MAP
  // ============================================================
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'roleId': roleId,
      'fullName': fullName,
      'phone': phone,
      'email': email,
      'username': username,
      'status': status,
      'createdAt': createdAt != null 
          ? Timestamp.fromDate(createdAt!) 
          : FieldValue.serverTimestamp(),
      'department': department ?? '',
      'departmentId': departmentId ?? '',
      'profileImage': profileImage ?? '',
      'profileImageUrl': profileImageUrl ?? profileImage ?? '',
      'employeeId': employeeId ?? '',
      'position': position ?? '',
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  // ============================================================
  // ROLE CHECKERS
  // ============================================================
  bool get isAdmin => roleId == '1';
  bool get isDirector => roleId == '4';
  bool get isManager => roleId == '3';
  bool get isStaff => roleId == '2';
  bool get isHead => roleId == '4';

  // ============================================================
  // ROLE NAME
  // ============================================================
  String get roleName {
    switch (roleId) {
      case '1':
        return '👑 Admin';
      case '2':
        return 'Staff';
      case '3':
        return 'Manager';
      case '4':
        return 'Director';
      default:
        return 'Unknown';
    }
  }

  // ============================================================
  // ROLE TYPE (for routing)
  // ============================================================
  String getRoleType() {
    if (isAdmin) return 'admin';
    if (isDirector) return 'director';
    if (isManager) return 'manager';
    return 'staff';
  }

  // ============================================================
  // ROLE COLOR
  // ============================================================
  Color get roleColor {
    switch (roleId) {
      case '1':
        return Colors.purple;
      case '2':
        return Colors.blue;
      case '3':
        return Colors.orange;
      case '4':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  // ============================================================
  // STATUS
  // ============================================================
  bool get isActive => status.toLowerCase() == 'active';
  
  String get statusText {
    switch (status.toLowerCase()) {
      case 'active': return 'Active';
      case 'inactive': return 'Inactive';
      case 'suspended': return 'Suspended';
      default: return status;
    }
  }

  Color get statusColor {
    switch (status.toLowerCase()) {
      case 'active': return Colors.green;
      case 'inactive': return Colors.grey;
      case 'suspended': return Colors.red;
      default: return Colors.grey;
    }
  }

  // ============================================================
  // DEPARTMENT
  // ============================================================
  bool isInSameDepartment(String? otherDepartment) {
    if (department == null || otherDepartment == null) return false;
    return department == otherDepartment;
  }

  String getDepartmentName() {
    return department ?? 'No Department';
  }

  // ============================================================
  // PROFILE IMAGE
  // ============================================================
  String get profileImageUrlWithFallback {
    return profileImageUrl ?? profileImage ?? '';
  }

  bool get hasProfileImage {
    final image = profileImageUrl ?? profileImage;
    return image != null && image.isNotEmpty;
  }

  // ============================================================
  // COPY WITH
  // ============================================================
  UserModel copyWith({
    String? id,
    String? userId,
    String? roleId,
    String? fullName,
    String? phone,
    String? email,
    String? username,
    String? status,
    DateTime? createdAt,
    String? department,
    String? departmentId,
    String? profileImage,
    String? profileImageUrl,
    String? employeeId,
    String? position,
    DateTime? updatedAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      roleId: roleId ?? this.roleId,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      username: username ?? this.username,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      department: department ?? this.department,
      departmentId: departmentId ?? this.departmentId,
      profileImage: profileImage ?? this.profileImage,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      employeeId: employeeId ?? this.employeeId,
      position: position ?? this.position,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // ============================================================
  // TO STRING
  // ============================================================
  @override
  String toString() {
    return 'UserModel(id: $id, fullName: $fullName, roleId: $roleId, email: $email)';
  }

  // ============================================================
  // EQUALITY
  // ============================================================
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}