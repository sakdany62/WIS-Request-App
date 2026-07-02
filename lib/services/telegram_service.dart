import 'package:http/http.dart' as http;
import 'dart:convert';

class TelegramService {
  // ===== TELEGRAM CONFIGURATION =====
  // Replace with your actual values
  static const String _botToken = '8679111334:AAE06FgfbBj-JNB1PtOpOQmnW77q25Qsurc';
  static const String _managerChatId = '1273488926'; // Replace with Manager's Chat ID
  static const String _adminChatId = '1273488926'; // Replace with Admin's Chat ID
  static const String _baseUrl = 'https://api.telegram.org/bot$_botToken';

  // ===== Send message to Manager =====
  static Future<bool> sendToManager(String message) async {
    return _sendMessage(_managerChatId, message);
  }

  // ===== Send message to Admin =====
  static Future<bool> sendToAdmin(String message) async {
    return _sendMessage(_adminChatId, message);
  }

  // ===== Send message to both Manager and Admin =====
  static Future<bool> sendToAll(String message) async {
    try {
      bool managerSent = await _sendMessage(_managerChatId, message);
      bool adminSent = await _sendMessage(_adminChatId, message);
      return managerSent && adminSent;
    } catch (e) {
      print('❌ Telegram Error (sendToAll): $e');
      return false;
    }
  }

  // ===== Send message to any Chat ID =====
  static Future<bool> sendToChatId(String chatId, String message) async {
    return _sendMessage(chatId, message);
  }

  // ===== Core send message function (Private) =====
  static Future<bool> _sendMessage(String chatId, String message) async {
    // Check that Chat ID is not empty
    if (chatId.isEmpty || chatId == 'MANAGER_CHAT_ID' || chatId == 'ADMIN_CHAT_ID') {
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

  // ===== Format permission request message in HTML =====
  static String formatPermissionRequest({
    required String staffName,
    required String staffPosition,
    required String permissionType,
    required Map<String, dynamic> details,
    required String requestId,
  }) {
    final typeLabels = {
      'leave': 'Leave',
      'overtime': 'Overtime',
      'travel': 'Business Travel',
      'sick': 'Sick Leave',
      'personal': 'Personal',
      'other': 'Other',
    };

    String detailsText = '';
    details.forEach((key, value) {
      final labels = {
        'reason': '📝 Reason',
        'startDate': '📅 Start Date',
        'endDate': '📅 End Date',
        'duration': '⏱️ Duration',
      };
      final label = labels[key] ?? key;
      detailsText += '\n${label}: ${value ?? "N/A"}';
    });

    // Get current date and time
    final now = DateTime.now();
    final formattedDate = '${now.day}/${now.month}/${now.year} ${now.hour}:${now.minute.toString().padLeft(2, '0')}';

    return '''
 <b>New Permission Request!</b>

 <b>- Staff Name:</b> $staffName
 <b>- Position:</b> ${staffPosition ?? 'Employee'}
 <b>- Type:</b> ${typeLabels[permissionType] ?? permissionType}
 <b>- Request Date:</b> $formattedDate

<b>Details:</b>$detailsText

🔗 <b>Request ID:</b> <code>$requestId</code>
📌 <b>Status:</b> ⏳ Pending Approval

---
Please click the button below to respond:
    ''';
  }

  // ===== Format response result back to Staff =====
  static String formatResponseResult({
    required String staffName,
    required String permissionType,
    required String status,
    required String? responseNote,
    required DateTime respondedAt,
  }) {
    final statusEmoji = status == 'approved' ? '✅' : '❌';
    final statusText = status == 'approved' ? 'Approved' : 'Rejected';
    final color = status == 'approved' ? '🟢' : '🔴';

    final typeLabels = {
      'leave': 'Leave',
      'overtime': 'Overtime',
      'travel': 'Business Travel',
      'sick': 'Sick Leave',
      'personal': 'Personal',
      'other': 'Other',
    };

    final formattedDate = '${respondedAt.day}/${respondedAt.month}/${respondedAt.year} ${respondedAt.hour}:${respondedAt.minute.toString().padLeft(2, '0')}';

    return '''
${color} <b>Permission Request Result</b>

👤 <b>Name:</b> $staffName
📝 <b>Type:</b> ${typeLabels[permissionType] ?? permissionType}
${statusEmoji} <b>Status:</b> $statusText

📌 <b>Comment:</b> ${responseNote ?? 'None'}

⏰ <b>Responded At:</b> $formattedDate

---
Thank you for using the system!
    ''';
  }

  // ===== Send test message (for Testing) =====
  static Future<bool> sendTestMessage() async {
    final testMessage = '''
🧪 <b>Test Message from WIS Permission System</b>

✅ Bot is working correctly!
📅 Date: ${DateTime.now().toLocal().toString().substring(0, 16)}

---
Thank you for using the system!
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