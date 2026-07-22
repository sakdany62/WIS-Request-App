// lib/services/manager_telegram_service.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ManagerTelegramService {
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

  // ===== Format status =====
  static String _formatStatus(String status) {
    switch (status.toLowerCase()) {
      case 'pending': return 'PENDING';
      case 'approved': return 'APPROVED';
      case 'rejected': return 'REJECTED';
      default: return status.toUpperCase();
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

  // ===== FORMAT PERMISSION REQUEST FOR MANAGER VIEW AS STAFF =====
  static Future<String> formatManagerViewRequest({
    required String staffName,
    required String staffDepartment,
    required String permissionType,
    required Map<String, dynamic> details,
    required String requestId,
    String status = 'pending',
  }) async {
    // ✅ Check if viewing as staff and is manager
    final bool isViewing = await _isViewingAsStaff();
    final bool isManagerUser = await _isManager();
    
    // ✅ If not manager view as staff, don't use this service
    if (!isViewing || !isManagerUser) {
      return '';
    }

    String typeDisplay = _getPermissionTypeDisplay(permissionType);
    String formattedStatus = _formatStatus(status);
    String submitTime = _formatSubmitTime(details['submitTime']);

    String reasonText = details['reason'] ?? typeDisplay;
    String startDate = details['startDate'] ?? 'N/A';
    String endDate = details['endDate'] ?? 'N/A';
    String duration = details['duration']?.toString() ?? 'N/A';

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
}