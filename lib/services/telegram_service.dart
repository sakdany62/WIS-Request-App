// lib/services/telegram_service.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TelegramService {
  // ===== TELEGRAM CONFIGURATION =====
  static const String _botToken = '8679111334:AAE06FgfbBj-JNB1PtOpOQmnW77q25Qsurc';
  static const String _groupChatId = '-1003899446883';
  static const String _managerChatId = '1273488926';
  static const String _adminChatId = '1273488926';
  static const String _baseUrl = 'https://api.telegram.org/bot$_botToken';

  // ===== Check if user is viewing as staff =====
  static Future<bool> _isViewingAsStaff() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('view_as_staff') ?? false;
    } catch (e) {
      return false;
    }
  }

  // ===== Check if user is Manager =====
  static Future<bool> _isManager() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('userId', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final data = querySnapshot.docs.first.data();
        final roleId = data['roleId']?.toString() ?? '';
        return roleId == '3';
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // ===== Get Staff Name from Firebase =====
  static Future<String> _getStaffName() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return 'Staff';

      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('userId', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final data = querySnapshot.docs.first.data();
        return data['fullName'] ?? data['name'] ?? user.displayName ?? user.email ?? 'Staff';
      }
      return user.displayName ?? user.email ?? 'Staff';
    } catch (e) {
      return 'Staff';
    }
  }

  // ===== Get Staff Position from Firebase =====
  static Future<String> _getStaffPosition() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return 'Employee';

      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('userId', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final data = querySnapshot.docs.first.data();
        return data['position'] ?? data['department'] ?? 'Employee';
      }
      return 'Employee';
    } catch (e) {
      return 'Employee';
    }
  }

  // ===== Get Staff Department from Firebase =====
  static Future<String> _getStaffDepartment() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return 'N/A';

      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('userId', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final data = querySnapshot.docs.first.data();
        return data['department'] ?? 'N/A';
      }
      return 'N/A';
    } catch (e) {
      return 'N/A';
    }
  }

  // ===== Get Full Staff Info from Firebase =====
  static Future<Map<String, String>> _getStaffInfo() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return {'name': 'Staff', 'position': 'Employee', 'department': 'N/A'};
      }

      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('userId', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final data = querySnapshot.docs.first.data();
        
        final bool isViewing = await _isViewingAsStaff();
        final bool isManagerUser = await _isManager();
        
        String position = data['position'] ?? data['department'] ?? 'Employee';
        if (isViewing && isManagerUser) {
          position = 'Manager';
        }
        
        return {
          'name': data['fullName'] ?? data['name'] ?? user.displayName ?? user.email ?? 'Staff',
          'position': position,
          'department': data['department'] ?? 'N/A',
        };
      }
      return {
        'name': user.displayName ?? user.email ?? 'Staff',
        'position': 'Employee',
        'department': 'N/A',
      };
    } catch (e) {
      return {'name': 'Staff', 'position': 'Employee', 'department': 'N/A'};
    }
  }

  // ===== Map permission type =====
  static String _getPermissionTypeDisplay(String type) {
    final Map<String, String> typeMap = {
      'Sick': 'Sick Leave',
      'Personal issue': 'Personal Issue',
      'Vacation': 'Vacation',
      'Emergency': 'Emergency',
      'Other': 'Other',
    };
    return typeMap[type] ?? type;
  }

  // ===== Format status =====
  static String _formatStatus(String status) {
    switch (status.toLowerCase()) {
      case 'pending': return 'PENDING';
      case 'approved': return 'APPROVED';
      case 'rejected': return 'REJECTED';
      default: return status.toUpperCase();
    }
  }

  // ===== Format time =====
  static String formatTimeOnlyAMPM([DateTime? time]) {
    final DateTime now = time ?? DateTime.now();
    final cambodiaTime = now.toUtc().add(const Duration(hours: 7));
    
    int hour = cambodiaTime.hour;
    final int minute = cambodiaTime.minute;
    final String period = hour >= 12 ? 'PM' : 'AM';
    
    if (hour == 0) hour = 12;
    else if (hour > 12) hour = hour - 12;
    
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
  }

  // ===== Format date and time =====
  static String _formatDateTimeAMPM([DateTime? time]) {
    final DateTime now = time ?? DateTime.now();
    final cambodiaTime = now.toUtc().add(const Duration(hours: 7));
    
    final day = cambodiaTime.day.toString().padLeft(2, '0');
    final month = cambodiaTime.month.toString().padLeft(2, '0');
    final year = cambodiaTime.year;
    int hour = cambodiaTime.hour;
    final int minute = cambodiaTime.minute;
    final String period = hour >= 12 ? 'PM' : 'AM';
    
    if (hour == 0) hour = 12;
    else if (hour > 12) hour = hour - 12;
    
    return '$day/$month/$year ${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
  }

  // ===== Format submit time =====
  static String _formatSubmitTime(dynamic submitTime) {
    if (submitTime == null) return formatTimeOnlyAMPM();
    if (submitTime is String && submitTime.isNotEmpty) return submitTime;
    if (submitTime is DateTime) return formatTimeOnlyAMPM(submitTime);
    return formatTimeOnlyAMPM();
  }

  // ===== Send message =====
  static Future<bool> sendToAll(String message) async {
    try {
      bool managerSent = await _sendMessage(_managerChatId, message);
      bool adminSent = await _sendMessage(_adminChatId, message);
      bool groupSent = await _sendMessage(_groupChatId, message);
      return managerSent && adminSent && groupSent;
    } catch (e) {
      return false;
    }
  }

  // ===== Core send message =====
  static Future<bool> _sendMessage(String chatId, String message) async {
    if (chatId.isEmpty || chatId == 'MANAGER_CHAT_ID' || chatId == 'ADMIN_CHAT_ID' || chatId == 'GROUP_CHAT_ID') {
      return false;
    }

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/sendMessage'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'chat_id': chatId,
          'text': message,
          'parse_mode': 'HTML',
          'disable_web_page_preview': true,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // ===== Send to Phone Number =====
  static Future<bool> sendMessageToPhoneNumber({
    required String phoneNumber,
    required String message,
  }) async {
    try {
      if (phoneNumber.isEmpty) return false;
      String formattedPhone = phoneNumber.trim().replaceAll(RegExp(r'[^0-9]'), '');
      if (formattedPhone.startsWith('0')) {
        formattedPhone = '855${formattedPhone.substring(1)}';
      } else if (!formattedPhone.startsWith('855')) {
        formattedPhone = '855$formattedPhone';
      }
      return await _sendMessage(formattedPhone, message);
    } catch (e) {
      return false;
    }
  }

  // ===== Send User Credentials =====
  static Future<bool> sendUserCredentialsToUser({
    required String fullName,
    required String username,
    required String email,
    required String password,
    required String roleId,
    required String userId,
    required String phoneNumber,
    required String position,
    required String department,
  }) async {
    if (phoneNumber.isEmpty) return false;

    final roleNames = {'1': 'Admin', '2': 'Staff', '3': 'Manager'};
    final String roleName = roleNames[roleId] ?? 'User';
    
    final String message = '''
WELCOME TO LEAVE REQUEST SYSTEM!
===============================
YOUR ACCOUNT DETAILS
- Full Name: $fullName
- Username: $username
- Email: $email
- Password: $password
- Role: $roleName
- User ID: $userId
${position.isNotEmpty ? '- Position: $position' : ''}
${department.isNotEmpty ? '- Department: $department' : ''}

IMPORTANT: 
- Please change your password after first login
- Keep this information safe and secure
''';

    return await sendMessageToPhoneNumber(phoneNumber: phoneNumber, message: message);
  }

  // ===== FORMAT PERMISSION REQUEST MESSAGE =====
  static Future<String> formatPermissionRequestWithInfo({
    required String staffName,
    required String staffPosition,
    required String staffDepartment,
    required String permissionType,
    required Map<String, dynamic> details,
    required String requestId,
    String status = 'pending',
  }) async {
    String typeDisplay = _getPermissionTypeDisplay(permissionType);
    String formattedStatus = _formatStatus(status);
    String submitTime = _formatSubmitTime(details['submitTime']);

    String reasonText = details['reason'] ?? typeDisplay;
    String startDate = details['startDate'] ?? 'N/A';
    String endDate = details['endDate'] ?? 'N/A';
    String duration = details['duration']?.toString() ?? 'N/A';

    final bool isViewing = await _isViewingAsStaff();
    final bool isManagerUser = await _isManager();
    
    // ✅ If manager view as staff - remove position
    if (isViewing && isManagerUser) {
      return '''
NEW PERMISSION REQUEST

Request ID: $requestId
Staff Name: $staffName
Department: $staffDepartment
Submit Time: $submitTime

Details:
 - Reason: $reasonText
 - Start Date: $startDate
 - End Date: $endDate
 - Duration: $duration day

Status: $formattedStatus
    ''';
    }

    // ✅ Staff normal - show position
    return '''
NEW PERMISSION REQUEST

Request ID: $requestId
Staff Name: $staffName
Department: $staffDepartment
Position: $staffPosition
Submit Time: $submitTime
Details:
 - Reason: $reasonText
 - Start Date: $startDate
 - End Date: $endDate
 - Duration: $duration day

 Status: $formattedStatus
    ''';
  }

  // ===== Format response result =====
  static String formatResponseResult({
    required String staffName,
    required String permissionType,
    required String status,
    required String? responseNote,
    required DateTime respondedAt,
  }) {
    String formattedStatus = _formatStatus(status);
    String typeDisplay = _getPermissionTypeDisplay(permissionType);
    String formattedTime = _formatDateTimeAMPM(respondedAt);

    return '''
PERMISSION REQUEST RESULT

Name: $staffName
Type: $typeDisplay
Status: $formattedStatus

Comment: ${responseNote ?? 'None'}

Responded At: $formattedTime

---
Thank you for using the system!
    ''';
  }

  // ===== Send test message =====
  static Future<bool> sendTestMessage() async {
    final staffInfo = await _getStaffInfo();
    final testMessage = '''
TEST MESSAGE FROM PERMISSION SYSTEM

Staff: ${staffInfo['name']}
Position: ${staffInfo['position']}
Department: ${staffInfo['department']}
Status: Bot is working correctly!
Date: ${_formatDateTimeAMPM()}

---
This is a test message sent to:
- Manager
- Admin
- Group
    ''';
    return sendToAll(testMessage);
  }

  // ===== Check Bot Status =====
  static Future<bool> checkBotStatus() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/getMe'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['ok'] == true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}