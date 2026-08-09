// lib/services/telegram_config_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TelegramConfigService {
  static const String _collection = 'telegram_config';
  static const String _docId = 'telegram_settings';

  // ===== Get All Telegram Configs =====
  static Future<Map<String, String>> getTelegramConfigs() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection(_collection)
          .doc(_docId)
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'groupChatId': data['groupChatId']?.toString() ?? '',
          'managerChatId': data['managerChatId']?.toString() ?? '',
          'adminChatId': data['adminChatId']?.toString() ?? '',
          'botToken': data['botToken']?.toString() ?? '',
          'additionalChatIds': data['additionalChatIds']?.toString() ?? '[]',
        };
      }
      return {
        'groupChatId': '',
        'managerChatId': '',
        'adminChatId': '',
        'botToken': '',
        'additionalChatIds': '[]',
      };
    } catch (e) {
      print('❌ Error getting Telegram configs: $e');
      return {
        'groupChatId': '',
        'managerChatId': '',
        'adminChatId': '',
        'botToken': '',
        'additionalChatIds': '[]',
      };
    }
  }

  // ===== Update Telegram Configs =====
  static Future<bool> updateTelegramConfigs({
    required String groupChatId,
    required String managerChatId,
    required String adminChatId,
    required String botToken,
    String additionalChatIds = '[]',
  }) async {
    try {
      await FirebaseFirestore.instance
          .collection(_collection)
          .doc(_docId)
          .set({
        'groupChatId': groupChatId,
        'managerChatId': managerChatId,
        'adminChatId': adminChatId,
        'botToken': botToken,
        'additionalChatIds': additionalChatIds,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': FirebaseAuth.instance.currentUser?.uid ?? 'unknown',
      }, SetOptions(merge: true));

      print(' Telegram configs updated successfully');
      return true;
    } catch (e) {
      print('❌ Error updating Telegram configs: $e');
      return false;
    }
  }

  // ===== Get Single Config =====
  static Future<String> getConfig(String key) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection(_collection)
          .doc(_docId)
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return data[key]?.toString() ?? '';
      }
      return '';
    } catch (e) {
      print('❌ Error getting config $key: $e');
      return '';
    }
  }

  // ===== Initialize Default Configs =====
  static Future<void> initializeDefaultConfigs() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection(_collection)
          .doc(_docId)
          .get();

      if (!doc.exists) {
        await FirebaseFirestore.instance
            .collection(_collection)
            .doc(_docId)
            .set({
          'groupChatId': '-1003899446883',
          'managerChatId': '1273488926',
          'adminChatId': '1273488926',
          'botToken': '8679111334:AAE06FgfbBj-JNB1PtOpOQmnW77q25Qsurc',
          'additionalChatIds': '[]',
          'createdAt': FieldValue.serverTimestamp(),
        });
        print(' Default Telegram configs initialized');
      }
    } catch (e) {
      print('❌ Error initializing Telegram configs: $e');
    }
  }
}