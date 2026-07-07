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
      print('❌ Error getting staff name: $e');
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
      print('❌ Error getting staff position: $e');
      return 'Employee';
    }
  }

  // ===== Get Full Staff Info from Firebase =====
  static Future<Map<String, String>> _getStaffInfo() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return {'name': 'Staff', 'position': 'Employee'};
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
        };
      }
      return {
        'name': user.displayName ?? user.email ?? 'Staff',
        'position': 'Employee',
      };
    } catch (e) {
      print('❌ Error getting staff info: $e');
      return {'name': 'Staff', 'position': 'Employee'};
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
      
      print('✅ Manager: $managerSent, Admin: $adminSent, Group: $groupSent');
      return managerSent && adminSent && groupSent;
    } catch (e) {
      print('❌ Telegram Error (sendToAll): $e');
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
      print('⚠️ Chat ID is not set or invalid');
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
        print('✅ Message sent to Telegram successfully (Chat: $chatId)');
        return true;
      } else {
        print('❌ Telegram Error: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ Telegram Exception: $e');
      return false;
    }
  }

  // ===== Format permission request message (Async) =====
  static Future<String> formatPermissionRequest({
    String? staffName,
    String? staffPosition,
    required String permissionType,
    required Map<String, dynamic> details,
    required String requestId,
    String status = 'pending',
  }) async {
    String finalStaffName = staffName ?? await _getStaffName();
    String finalStaffPosition = staffPosition ?? await _getStaffPosition();
    String typeDisplay = _getPermissionTypeDisplay(permissionType);
    String reason = details['reason'] ?? typeDisplay;
    String formattedStatus = _formatStatus(status);

    String detailsText = '';
    details.forEach((key, value) {
      final labels = {
        'reason': 'Reason',
        'startDate': 'Start Date',
        'endDate': 'End Date',
        'duration': 'Duration',
      };
      final label = labels[key] ?? key;
      detailsText += '\n  - ${label}: ${value ?? "N/A"}';
    });

    final now = DateTime.now();
    final formattedDate = '${now.day}/${now.month}/${now.year} ${now.hour}:${now.minute.toString().padLeft(2, '0')}';

    return '''
NEW PERMISSION REQUEST

Staff Name: $finalStaffName
Position: $finalStaffPosition
Type: $typeDisplay
Reason: $reason
Request Date: $formattedDate

Details:$detailsText

Request ID: $requestId
Status: $formattedStatus

==========================
Please check the app to approve or reject this request.
    ''';
  }

  // ===== Format permission request message (Synchronous) =====
  static String formatPermissionRequestWithInfo({
    required String staffName,
    required String staffPosition,
    required String permissionType,
    required Map<String, dynamic> details,
    required String requestId,
    String status = 'pending',
  }) {
    String typeDisplay = _getPermissionTypeDisplay(permissionType);
    String reason = details['reason'] ?? typeDisplay;
    String formattedStatus = _formatStatus(status);

    String detailsText = '';
    details.forEach((key, value) {
      final labels = {
        'reason': 'Reason',
        'startDate': 'Start Date',
        'endDate': 'End Date',
        'duration': 'Duration',
      };
      final label = labels[key] ?? key;
      detailsText += '\n  - ${label}: ${value ?? "N/A"}';
    });

    final now = DateTime.now();
    final formattedDate = '${now.day}/${now.month}/${now.year} ${now.hour}:${now.minute.toString().padLeft(2, '0')}';

    return '''
NEW PERMISSION REQUEST

Staff Name: $staffName
Position: $staffPosition
Request Date: $formattedDate

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

    final formattedDate = '${respondedAt.day}/${respondedAt.month}/${respondedAt.year} ${respondedAt.hour}:${respondedAt.minute.toString().padLeft(2, '0')}';

    return '''
PERMISSION REQUEST RESULT

Name: $staffName
Type: $typeDisplay
Status: $formattedStatus

Comment: ${responseNote ?? 'None'}

Responded At: $formattedDate

---
Thank you for using the system!
    ''';
  }

  // ===== Send test message =====
  static Future<bool> sendTestMessage() async {
    final staffInfo = await _getStaffInfo();
    final testMessage = '''
TEST MESSAGE FROM WIS PERMISSION SYSTEM

Staff: ${staffInfo['name']}
Position: ${staffInfo['position']}
Status: Bot is working correctly!
Date: ${DateTime.now().toLocal().toString().substring(0, 16)}

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
          print('✅ Bot is running: ${data['result']['username']}');
          return true;
        }
      }
      print('❌ Bot is not running');
      return false;
    } catch (e) {
      print('❌ Error checking Bot status: $e');
      return false;
    }
  }
}