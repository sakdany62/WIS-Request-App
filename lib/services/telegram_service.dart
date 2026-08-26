// lib/services/telegram_service.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'telegram_config_service.dart';

class TelegramService {
  // ===== TELEGRAM CONFIGURATION (Fallback Defaults) =====
  static const String _defaultBotToken = '8679111334:AAE06FgfbBj-JNB1PtOpOQmnW77q25Qsurc';
  static const String _defaultGroupChatId = '-1003899446883';
  static const String _defaultManagerChatId = '1273488926';
  static const String _defaultAdminChatId = '1273488926';

  // ===== Get Configs from Firestore =====
  static Future<Map<String, String>> _getConfigs() async {
    try {
      return await TelegramConfigService.getTelegramConfigs();
    } catch (e) {
      print('❌ Error getting configs from Firestore, using defaults: $e');
      return {
        'groupChatId': _defaultGroupChatId,
        'managerChatId': _defaultManagerChatId,
        'adminChatId': _defaultAdminChatId,
        'botToken': _defaultBotToken,
        'additionalChatIds': '[]',
      };
    }
  }

  // ===== Get Bot Token =====
  static Future<String> _getBotToken() async {
    try {
      final configs = await _getConfigs();
      final token = configs['botToken'] ?? '';
      if (token.isEmpty) {
        print(' Bot token not found in config, using default');
        return _defaultBotToken;
      }
      return token;
    } catch (e) {
      print('❌ Error getting bot token, using default: $e');
      return _defaultBotToken;
    }
  }

  // ===== Get Base URL =====
  static Future<String> _getBaseUrl() async {
    final token = await _getBotToken();
    if (token.isEmpty) return '';
    return 'https://api.telegram.org/bot$token';
  }

  // ===== Get Chat IDs =====
  static Future<Map<String, String>> _getChatIds() async {
    try {
      final configs = await _getConfigs();
      return {
        'groupChatId': configs['groupChatId'] ?? _defaultGroupChatId,
        'managerChatId': configs['managerChatId'] ?? _defaultManagerChatId,
        'adminChatId': configs['adminChatId'] ?? _defaultAdminChatId,
      };
    } catch (e) {
      print('❌ Error getting chat IDs, using defaults: $e');
      return {
        'groupChatId': _defaultGroupChatId,
        'managerChatId': _defaultManagerChatId,
        'adminChatId': _defaultAdminChatId,
      };
    }
  }

  // ===== Get Additional Chat IDs =====
  static Future<List<Map<String, String>>> _getAdditionalChatIds() async {
    try {
      final configs = await _getConfigs();
      final additionalJson = configs['additionalChatIds'] ?? '[]';

      final List<dynamic> decoded = jsonDecode(additionalJson);
      return decoded
          .map((item) => {
                'chatId': item['chatId']?.toString() ?? '',
                'type': item['type']?.toString() ?? 'Other',
              })
          .toList();
    } catch (e) {
      print('❌ Error parsing additional chat IDs: $e');
      return [];
    }
  }

  // ===== Get Current User Data from Firebase =====
  static Future<Map<String, dynamic>?> _getCurrentUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print(' No user logged in');
        return null;
      }

      print(' Current user email: ${user.email}');
      print(' Current user UID: ${user.uid}');

      final querySnapshot =
          await FirebaseFirestore.instance.collection('users').where('email', isEqualTo: user.email).limit(1).get();

      if (querySnapshot.docs.isNotEmpty) {
        final data = querySnapshot.docs.first.data();
        print(' User data found: $data');
        return data;
      }

      print(' No user document found for email: ${user.email}');
      return null;
    } catch (e) {
      print(' Error getting user data: $e');
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

      print(' _getStaffPosition() called');

      if (data != null) {
        final String roleId = data['roleId']?.toString() ?? '';
        final String position = data['position'] ?? data['department'] ?? 'Employee';

        print(' roleId: "$roleId"');
        print(' position from DB: "$position"');

        if (roleId == '2') {
          print(' This is STAFF, returning position: "$position"');
          return position;
        }

        print(' This is NOT STAFF (roleId: "$roleId"), returning "Manager"');
        return 'Manager';
      }

      print(' No data found, returning "Manager"');
      return 'Manager';
    } catch (e) {
      print(' Error in _getStaffPosition: $e, returning "Manager"');
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

  // ===== Format time =====
  static String formatTimeOnlyAMPM([DateTime? time]) {
    final DateTime now = time ?? DateTime.now();
    final cambodiaTime = now.toUtc().add(const Duration(hours: 7));

    int hour = cambodiaTime.hour;
    final int minute = cambodiaTime.minute;
    final String period = hour >= 12 ? 'PM' : 'AM';

    if (hour == 0) {
      hour = 12;
    } else if (hour > 12) hour = hour - 12;

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

    if (hour == 0) {
      hour = 12;
    } else if (hour > 12) hour = hour - 12;

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
      final chatIds = await _getChatIds();
      final String managerChatId = chatIds['managerChatId'] ?? _defaultManagerChatId;
      final String adminChatId = chatIds['adminChatId'] ?? _defaultAdminChatId;
      final String groupChatId = chatIds['groupChatId'] ?? _defaultGroupChatId;

      final String correctPosition = await _getStaffPosition();

      print('📨 Sending message with Position: "$correctPosition"');

      final RegExp positionRegex = RegExp(r'Position: .+');
      String finalMessage = message.replaceAllMapped(positionRegex, (match) {
        return 'Position: $correctPosition';
      });

      //  ផ្ញើទៅកាន់ Chat IDs សំខាន់ៗ
      print(' Sending to main chats:');
      print('    Manager: $managerChatId');
      print('    Admin: $adminChatId');
      print('    Group: $groupChatId');

      bool managerSent = await _sendMessage(managerChatId, finalMessage);
      bool adminSent = await _sendMessage(adminChatId, finalMessage);
      bool groupSent = await _sendMessage(groupChatId, finalMessage);

      //  ផ្ញើទៅកាន់ Additional Chat IDs
      final additionalChatIds = await _getAdditionalChatIds();
      bool allAdditionalSent = true;

      if (additionalChatIds.isNotEmpty) {
        print(' Sending to additional chats:');
        for (var chat in additionalChatIds) {
          final chatId = chat['chatId'] ?? '';
          final type = chat['type'] ?? 'Other';
          if (chatId.isNotEmpty) {
            print('    Additional ($type): $chatId');
            final sent = await _sendMessage(chatId, finalMessage);
            if (!sent) allAdditionalSent = false;
          }
        }
      }

      print(
          ' Messages sent - Manager: $managerSent, Admin: $adminSent, Group: $groupSent, Additional: $allAdditionalSent');

      return managerSent && adminSent && groupSent && allAdditionalSent;
    } catch (e) {
      print(' Error in sendToAll: $e');
      return false;
    }
  }

  // ===== Core send message =====
  static Future<bool> _sendMessage(String chatId, String message) async {
    if (chatId.isEmpty || chatId == 'MANAGER_CHAT_ID' || chatId == 'ADMIN_CHAT_ID' || chatId == 'GROUP_CHAT_ID') {
      print(' Invalid chat ID: $chatId');
      return false;
    }

    final baseUrl = await _getBaseUrl();
    if (baseUrl.isEmpty) {
      print('❌ Bot token is empty, cannot send message');
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
        Uri.parse('$baseUrl/sendMessage'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'chat_id': chatId,
          'text': finalMessage,
          'parse_mode': 'HTML',
          'disable_web_page_preview': true,
        }),
      );

      if (response.statusCode == 200) {
        print(' Message sent to $chatId');
        return true;
      } else {
        print('❌ Failed to send message to $chatId: ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ Error sending message to $chatId: $e');
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
      print('❌ Error sending message to phone: $e');
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
    if (phoneNumber.isEmpty) {
      print(' Phone number is empty, cannot send credentials');
      return false;
    }

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

    print(' Formatting permission request with Position: "$actualPosition"');

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
- Additional Chats
    ''';
    return sendToAll(testMessage);
  }

  // ===== Check Bot Status =====
  static Future<bool> checkBotStatus() async {
    try {
      final baseUrl = await _getBaseUrl();
      if (baseUrl.isEmpty) {
        print('❌ Bot token is empty, cannot check status');
        return false;
      }

      print(' Checking bot status...');
      final response = await http.get(Uri.parse('$baseUrl/getMe'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final isOk = data['ok'] == true;
        print(' Bot status: ${isOk ? " OK" : " FAILED"}');
        return isOk;
      }
      print('❌ Bot status check failed: ${response.statusCode}');
      return false;
    } catch (e) {
      print('❌ Error checking bot status: $e');
      return false;
    }
  }

  // ===== Get Current Configs (for UI) =====
  static Future<Map<String, String>> getCurrentConfigs() async {
    return await _getConfigs();
  }

  // ================================================================
  // ===== SEND PHOTO TO TELEGRAM =====
  // ================================================================
  
  /// Send a photo to Telegram with caption
  static Future<bool> sendPhotoToTelegram({
    required List<int> photoBytes,
    String? caption,
    String? chatId,
  }) async {
    try {
      final botToken = await _getBotToken();
      if (botToken.isEmpty) {
        print('❌ Bot token is empty, cannot send photo');
        return false;
      }

      // If specific chatId provided, send only to that chat
      if (chatId != null && chatId.isNotEmpty) {
        return await _sendPhoto(chatId, photoBytes, caption);
      }

      // Send to all main chats
      final chatIds = await _getChatIds();
      final List<String> mainChatIds = [
        chatIds['managerChatId'] ?? _defaultManagerChatId,
        chatIds['adminChatId'] ?? _defaultAdminChatId,
        chatIds['groupChatId'] ?? _defaultGroupChatId,
      ];

      bool allSent = true;
      for (String id in mainChatIds) {
        if (id.isNotEmpty && id != 'MANAGER_CHAT_ID' && id != 'ADMIN_CHAT_ID' && id != 'GROUP_CHAT_ID') {
          final sent = await _sendPhoto(id, photoBytes, caption);
          if (!sent) allSent = false;
        }
      }

      // Send to additional chats
      final additionalChatIds = await _getAdditionalChatIds();
      for (var chat in additionalChatIds) {
        final id = chat['chatId'] ?? '';
        if (id.isNotEmpty) {
          final sent = await _sendPhoto(id, photoBytes, caption);
          if (!sent) allSent = false;
        }
      }

      return allSent;
    } catch (e) {
      print('❌ Error sending photo to Telegram: $e');
      return false;
    }
  }

  // ===== CORE SEND PHOTO =====
  static Future<bool> _sendPhoto(String chatId, List<int> photoBytes, String? caption) async {
    if (chatId.isEmpty || chatId == 'MANAGER_CHAT_ID' || chatId == 'ADMIN_CHAT_ID' || chatId == 'GROUP_CHAT_ID') {
      print(' Invalid chat ID: $chatId');
      return false;
    }

    final botToken = await _getBotToken();
    if (botToken.isEmpty) {
      print('❌ Bot token is empty, cannot send photo');
      return false;
    }

    try {
      final url = 'https://api.telegram.org/bot$botToken/sendPhoto';
      
      final request = http.MultipartRequest('POST', Uri.parse(url))
        ..fields['chat_id'] = chatId
        ..fields['caption'] = caption ?? '📸 Attachment'
        ..files.add(http.MultipartFile.fromBytes(
          'photo',
          photoBytes,
          filename: 'attachment_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ));

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        print(' Photo sent to $chatId');
        return true;
      } else {
        print('❌ Failed to send photo to $chatId: $responseBody');
        return false;
      }
    } catch (e) {
      print('❌ Error sending photo to $chatId: $e');
      return false;
    }
  }
}