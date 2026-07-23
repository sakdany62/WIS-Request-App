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

  // ===== Get Current User Data from Firebase =====
  static Future<Map<String, dynamic>?> _getCurrentUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('❌ No user logged in');
        return null;
      }

      print('📧 Current user email: ${user.email}');
      print('🆔 Current user UID: ${user.uid}');

      // 🔥 FIX: ស្វែងរកដោយ email
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: user.email)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final data = querySnapshot.docs.first.data();
        print('✅ User data found: $data');
        return data;
      }

      print('❌ No user document found for email: ${user.email}');
      return null;
    } catch (e) {
      print('❌ Error getting user data: $e');
      return null;
    }
  }

  // ===== Get Staff Name from Firebase =====
  static Future<String> _getStaffName() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return 'Staff';

      final data = await _getCurrentUserData();
      if (data != null) {
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
      final data = await _getCurrentUserData();
      
      print('📊 _getStaffPosition() called');
      
      if (data != null) {
        final String roleId = data['roleId']?.toString() ?? '';
        final String position = data['position'] ?? data['department'] ?? 'Employee';
        
        print('📌 roleId: "$roleId"');
        print('📌 position from DB: "$position"');
        
        // 🔥 FIX: យក position ពី Database សម្រាប់តែ Staff (roleId = 2) ប៉ុណ្ណោះ
        if (roleId == '2') {
          print('✅ This is STAFF, returning position: "$position"');
          return position;
        }
        
        // 🔥 FIX: បើមិនមែន Staff → កំណត់ជា "Manager" ទាំងអស់
        print('❌ This is NOT STAFF (roleId: "$roleId"), returning "Manager"');
        return 'Manager';
      }
      
      print('❌ No data found, returning "Manager"');
      return 'Manager';
    } catch (e) {
      print('❌ Error in _getStaffPosition: $e, returning "Manager"');
      return 'Manager';
    }
  }

  // ===== Get Staff Department from Firebase =====
  static Future<String> _getStaffDepartment() async {
    try {
      final data = await _getCurrentUserData();
      if (data != null) {
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
        return {'name': 'Staff', 'position': 'Manager', 'department': 'N/A'};
      }

      final data = await _getCurrentUserData();
      if (data != null) {
        final String roleId = data['roleId']?.toString() ?? '';
        String position = data['position'] ?? data['department'] ?? 'Employee';
        
        // 🔥 FIX: យក position ពី Database សម្រាប់តែ Staff (roleId = 2) ប៉ុណ្ណោះ
        if (roleId == '2') {
          position = position;
        } else {
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
        'position': 'Manager',
        'department': 'N/A',
      };
    } catch (e) {
      return {'name': 'Staff', 'position': 'Manager', 'department': 'N/A'};
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
      final String correctPosition = await _getStaffPosition();
      
      print('📤 Sending message with Position: "$correctPosition"');
      
      final RegExp positionRegex = RegExp(r'Position: .+');
      String finalMessage = message.replaceAllMapped(positionRegex, (match) {
        return 'Position: $correctPosition';
      });
      
      bool managerSent = await _sendMessage(_managerChatId, finalMessage);
      bool adminSent = await _sendMessage(_adminChatId, finalMessage);
      bool groupSent = await _sendMessage(_groupChatId, finalMessage);
      return managerSent && adminSent && groupSent;
    } catch (e) {
      print('❌ Error in sendToAll: $e');
      return false;
    }
  }

  // ===== Core send message =====
  static Future<bool> _sendMessage(String chatId, String message) async {
    if (chatId.isEmpty || chatId == 'MANAGER_CHAT_ID' || chatId == 'ADMIN_CHAT_ID' || chatId == 'GROUP_CHAT_ID') {
      return false;
    }

    try {
      String finalMessage = message;
      final RegExp positionRegex = RegExp(r'Position: .+');
      if (positionRegex.hasMatch(message)) {
        final String correctPosition = await _getStaffPosition();
        finalMessage = message.replaceAllMapped(positionRegex, (match) {
          return 'Position: $correctPosition';
        });
      }
      
      final response = await http.post(
        Uri.parse('$_baseUrl/sendMessage'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'chat_id': chatId,
          'text': finalMessage,
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

    final String actualPosition = await _getStaffPosition();
    
    print('📝 Formatting permission request with Position: "$actualPosition"');
    
    return '''
NEW PERMISSION REQUEST

Request ID: $requestId
Staff Name: $staffName
Department: $staffDepartment
Position: $actualPosition
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