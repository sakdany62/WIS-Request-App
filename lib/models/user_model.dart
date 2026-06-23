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
  final String? department;       // ឈ្មោះផ្នែក (ឧ: "ផ្នែកបច្ចេកវិទ្យា")
  final String? departmentId;     // ID ផ្នែក (ឧ: "dept_it")
  final String? profileImage;

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
  });

  factory UserModel.fromFirestore(Map<String, dynamic> data, String documentId) {
    return UserModel(
      id: documentId,
      userId: data['userId'] ?? '',
      roleId: data['roleId']?.toString() ?? '2',
      fullName: data['fullName'] ?? '',
      phone: data['phone'] ?? '',
      email: data['email'] ?? '',
      username: data['username'] ?? '',
      status: data['status'] ?? 'Active',
      createdAt: data['createdAt'] != null 
          ? (data['createdAt'] as Timestamp).toDate() 
          : null,
      department: data['department'] ?? '',
      departmentId: data['departmentId'] ?? '',
      profileImage: data['profileImage'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'roleId': roleId,
      'fullName': fullName,
      'phone': phone,
      'email': email,
      'username': username,
      'status': status,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'department': department ?? '',
      'departmentId': departmentId ?? '',
      'profileImage': profileImage,
    };
  }

  String get roleName {
    switch (roleId) {
      case '1':
        return '👑 Admin';
      case '2':
        return '👤 Staff';
      case '3':
        return '📋 Manager';
      case '4':
        return '🎯 Director';
      default:
        return 'មិនស្គាល់';
    }
  }

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

  bool get isAdmin => roleId == '1';
  bool get isManager => roleId == '3';
  bool get isStaff => roleId == '2';
  bool get isHead => roleId == '4';
  bool get isActive => status == 'Active';
  
  bool isInSameDepartment(String? otherDepartment) {
    if (department == null || otherDepartment == null) return false;
    return department == otherDepartment;
  }

  String getDepartmentName() {
    return department ?? 'គ្មានផ្នែក';
  }

  String getRoleType() {
    if (isAdmin) return 'admin';
    if (isManager) return 'manager';
    if (isHead) return 'director';
    return 'staff';
  }

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
    );
  }
}