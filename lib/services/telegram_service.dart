// lib/services/telegram_service.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TelegramService {
  // ===== TELEGRAM CONFIGURATION =====
  static const String _botToken = '8679111334:AAE06FgfbBj-JNB1PtOpOQmnW77q25Qsurc';
  static const String _groupChatId = '-1003899446883';
  static const String _managerChatId = '1273488926';
  static const String _adminChatId = '1273488926';
  static const String _baseUrl = 'https://api.telegram.org/bot$_botToken';

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
      print(' Error getting staff name: $e');
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
      print(' Error getting staff position: $e');
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
      print(' Error getting staff department: $e');
      return 'N/A';
    }
  }

  // ===== Get Full Staff Info from Firebase (including department) =====
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
        return {
          'name': data['fullName'] ?? data['name'] ?? user.displayName ?? user.email ?? 'Staff',
          'position': data['position'] ?? data['department'] ?? 'Employee',
          'department': data['department'] ?? 'N/A',
        };
      }
      return {
        'name': user.displayName ?? user.email ?? 'Staff',
        'position': 'Employee',
        'department': 'N/A',
      };
    } catch (e) {
      print(' Error getting staff info: $e');
      return {'name': 'Staff', 'position': 'Employee', 'department': 'N/A'};
    }
  }

  // ===== Map permission type to display name =====
  static String _getPermissionTypeDisplay(String type) {
    final Map<String, String> typeMap = {
      'Sick': 'Sick Leave',
      'Personal issue': 'Personal Issue',
      'Vacation': 'Vacation',
      'Emergency': 'Emergency',
      'Other': 'Other',
      'sick': 'Sick Leave',
      'personal': 'Personal Issue',
      'leave': 'Vacation',
      'emergency': 'Emergency',
      'other': 'Other',
    };
    return typeMap[type] ?? type;
  }

  // ===== Format status =====
  static String _formatStatus(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'PENDING';
      case 'approved':
        return 'APPROVED';
      case 'rejected':
        return 'REJECTED';
      default:
        return status.toUpperCase();
    }
  }

  // ===== Get current Cambodia time (UTC+7) =====
  static DateTime _getCambodiaTime() {
    return DateTime.now().toUtc().add(const Duration(hours: 7));
  }

  // ===== Format time only (HH:MM AM/PM) Cambodia Time =====
  static String formatTimeOnlyAMPM([DateTime? time]) {
    final DateTime now = time ?? DateTime.now();
    
    // Convert to Cambodia time (UTC+7)
    final cambodiaTime = now.toUtc().add(const Duration(hours: 7));
    
    int hour = cambodiaTime.hour;
    final int minute = cambodiaTime.minute;
    final String period = hour >= 12 ? 'PM' : 'AM';
    
    // Convert to 12-hour format
    if (hour == 0) {
      hour = 12;
    } else if (hour > 12) {
      hour = hour - 12;
    }
    
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
  }

  // ===== Format date and time to AM/PM (Cambodia Time UTC+7) =====
  static String _formatDateTimeAMPM([DateTime? time]) {
    final DateTime now = time ?? DateTime.now();
    
    // Convert to Cambodia time (UTC+7)
    final cambodiaTime = now.toUtc().add(const Duration(hours: 7));
    
    final day = cambodiaTime.day.toString().padLeft(2, '0');
    final month = cambodiaTime.month.toString().padLeft(2, '0');
    final year = cambodiaTime.year;
    int hour = cambodiaTime.hour;
    final int minute = cambodiaTime.minute;
    final String period = hour >= 12 ? 'PM' : 'AM';
    
    // Convert to 12-hour format
    if (hour == 0) {
      hour = 12;
    } else if (hour > 12) {
      hour = hour - 12;
    }
    
    return '$day/$month/$year ${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
  }

  // ===== Format submit time from details (supports both DateTime and String) =====
  static String _formatSubmitTime(dynamic submitTime) {
    // If no submitTime, use current Cambodia time
    if (submitTime == null) {
      return formatTimeOnlyAMPM();
    }
    
    // If it's a String, use it directly (already formatted)
    if (submitTime is String) {
      if (submitTime.isNotEmpty) {
        return submitTime;
      }
      return formatTimeOnlyAMPM();
    }
    
    // If it's a DateTime, convert to AM/PM
    if (submitTime is DateTime) {
      return formatTimeOnlyAMPM(submitTime);
    }
    
    // Default: use current Cambodia time
    return formatTimeOnlyAMPM();
  }

  // ===== Send message to Group =====
  static Future<bool> sendToGroup(String message) async {
    return _sendMessage(_groupChatId, message);
  }

  // ===== Send message to Manager =====
  static Future<bool> sendToManager(String message) async {
    return _sendMessage(_managerChatId, message);
  }

  // ===== Send message to Admin =====
  static Future<bool> sendToAdmin(String message) async {
    return _sendMessage(_adminChatId, message);
  }

  // ===== Send message to Manager, Admin, AND Group =====
  static Future<bool> sendToAll(String message) async {
    try {
      bool managerSent = await _sendMessage(_managerChatId, message);
      bool adminSent = await _sendMessage(_adminChatId, message);
      bool groupSent = await _sendMessage(_groupChatId, message);
      
      print(' Manager: $managerSent, Admin: $adminSent, Group: $groupSent');
      return managerSent && adminSent && groupSent;
    } catch (e) {
      print(' Telegram Error (sendToAll): $e');
      return false;
    }
  }

  // ===== Send message to any Chat ID =====
  static Future<bool> sendToChatId(String chatId, String message) async {
    return _sendMessage(chatId, message);
  }

  // ===== Core send message function =====
  static Future<bool> _sendMessage(String chatId, String message) async {
    if (chatId.isEmpty || 
        chatId == 'MANAGER_CHAT_ID' || 
        chatId == 'ADMIN_CHAT_ID' ||
        chatId == 'GROUP_CHAT_ID') {
      print(' Chat ID is not set or invalid');
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

      if (response.statusCode == 200) {
        print(' Message sent to Telegram successfully (Chat: $chatId)');
        return true;
      } else {
        print(' Telegram Error: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print(' Telegram Exception: $e');
      return false;
    }
  }

  // ===== Send message to User by Phone Number =====
  static Future<bool> sendMessageToPhoneNumber({
    required String phoneNumber,
    required String message,
  }) async {
    try {
      if (phoneNumber.isEmpty) {
        print('Phone number is empty');
        return false;
      }

      // Format phone number for Telegram (remove + and special chars)
      String formattedPhone = phoneNumber.trim();
      formattedPhone = formattedPhone.replaceAll(RegExp(r'[^0-9]'), '');
      
      // If starts with 0, change to 855
      if (formattedPhone.startsWith('0')) {
        formattedPhone = '855${formattedPhone.substring(1)}';
      }
      // If no 855, add
      else if (!formattedPhone.startsWith('855')) {
        formattedPhone = '855$formattedPhone';
      }
      
      final String chatId = formattedPhone;
      
      print('Sending Telegram to phone: $phoneNumber -> Chat ID: $chatId');
      
      return await _sendMessage(chatId, message);
      
    } catch (e) {
      print('Error sending Telegram to phone: $e');
      return false;
    }
  }

  // ===== Send User Credentials to User's Telegram =====
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
    if (phoneNumber.isEmpty) {
      print('No phone number provided, skipping Telegram');
      return false;
    }

    final roleNames = {
      '1': 'Admin',
      '2': 'Staff',
      '3': 'Manager',
    };
    
    final String roleName = roleNames[roleId] ?? 'User';
    
    final String message = '''
WELCOME TO LEAVE REQUEST SYSTEM!
================================
YOUR ACCOUNT DETAILS
- Full Name: $fullName
- Username: $username
- Email: $email
- Password: $password
Role: $roleName
- User ID: $userId
${position.isNotEmpty ? '- Position: $position' : ''}
${department.isNotEmpty ? '- Department: $department' : ''}

================================
IMPORTANT: 
- Please change your password after first login
- Keep this information safe and secure
          Thanks!
''';

    return await sendMessageToPhoneNumber(
      phoneNumber: phoneNumber,
      message: message,
    );
  }

  // ===== Format permission request message (Async) =====
  static Future<String> formatPermissionRequest({
    String? staffName,
    String? staffPosition,
    String? staffDepartment,
    required String permissionType,
    required Map<String, dynamic> details,
    required String requestId,
    String status = 'pending',
  }) async {
    String finalStaffName = staffName ?? await _getStaffName();
    String finalStaffPosition = staffPosition ?? await _getStaffPosition();
    String finalStaffDepartment = staffDepartment ?? await _getStaffDepartment();
    String typeDisplay = _getPermissionTypeDisplay(permissionType);
    String reason = details['reason'] ?? typeDisplay;
    String formattedStatus = _formatStatus(status);

    // Get submit time from details (supports both DateTime and String)
    String submitTime = _formatSubmitTime(details['submitTime']);

    String detailsText = '';
    details.forEach((key, value) {
      final labels = {
        'reason': 'Reason',
        'startDate': 'Start Date',
        'endDate': 'End Date',
        'duration': 'Duration',
      };
      final label = labels[key] ?? key;
      // Skip if value is null or empty, and skip submitTime (already displayed above)
      if (value != null && value.toString().isNotEmpty && key != 'submitTime') {
        detailsText += '\n  - ${label}: ${value}';
      }
    });

    return '''
NEW PERMISSION REQUEST

Staff Name: $finalStaffName
Department: $finalStaffDepartment
Position: $finalStaffPosition
Submit Time: $submitTime

Details:$detailsText

Request ID: $requestId
Status: $formattedStatus
    ''';
  }

  // ===== Format permission request message (Synchronous) =====
  static String formatPermissionRequestWithInfo({
    required String staffName,
    required String staffPosition,
    required String staffDepartment,
    required String permissionType,
    required Map<String, dynamic> details,
    required String requestId,
    String status = 'pending',
  }) {
    String typeDisplay = _getPermissionTypeDisplay(permissionType);
    String reason = details['reason'] ?? typeDisplay;
    String formattedStatus = _formatStatus(status);

    // Get submit time from details (supports both DateTime and String)
    String submitTime = _formatSubmitTime(details['submitTime']);

    String detailsText = '';
    details.forEach((key, value) {
      final labels = {
        'reason': 'Reason',
        'startDate': 'Start Date',
        'endDate': 'End Date',
        'duration': 'Duration',
      };
      final label = labels[key] ?? key;
      // Skip if value is null or empty, and skip submitTime (already displayed above)
      if (value != null && value.toString().isNotEmpty && key != 'submitTime') {
        detailsText += '\n  - ${label}: ${value}';
      }
    });

    return '''
NEW PERMISSION REQUEST

Staff Name: $staffName
Department: $staffDepartment
Position: $staffPosition
Submit Time: $submitTime

Details:$detailsText

Request ID: $requestId
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
    
    // Use Cambodia time for response
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
    // Use Cambodia time for test message
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
      final response = await http.get(
        Uri.parse('$_baseUrl/getMe'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['ok'] == true) {
          print(' Bot is running: ${data['result']['username']}');
          return true;
        }
      }
      print('Bot is not running');
      return false;
    } catch (e) {
      print('Error checking Bot status: $e');
      return false;
    }
  }
}