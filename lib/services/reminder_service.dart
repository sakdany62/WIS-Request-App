// lib/services/reminder_service.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'telegram_service.dart';
import 'telegram_config_service.dart';

class ReminderService {
  static final ReminderService _instance = ReminderService._internal();
  factory ReminderService() => _instance;
  ReminderService._internal();

  Timer? _reminderTimer;
  bool _isRunning = false;
  
  // រយៈពេលចន្លោះពេលផ្ញើសារ (គិតជាវិនាទី) - Default 5 នាទី
  int _reminderIntervalSeconds = 300; // 5 minutes
  
  // បញ្ជី request IDs ដែលកំពុងរង់ចាំ
  Set<String> _pendingRequestIds = {};

  void startReminderService({int intervalSeconds = 300}) {
    if (_isRunning) {
      print('⚠️ Reminder service is already running');
      return;
    }
    
    _reminderIntervalSeconds = intervalSeconds;
    _isRunning = true;
    
    print('🚀 Starting reminder service with interval: ${_reminderIntervalSeconds}s');
    
    // ចាប់ផ្ដើមផ្ញើសារភ្លាមៗ
    _sendReminders();
    
    // កំណត់ timer
    _reminderTimer = Timer.periodic(
      Duration(seconds: _reminderIntervalSeconds),
      (timer) => _sendReminders(),
    );
  }

  void stopReminderService() {
    if (_reminderTimer != null) {
      _reminderTimer?.cancel();
      _reminderTimer = null;
    }
    _isRunning = false;
    _pendingRequestIds.clear();
    print('🛑 Reminder service stopped');
  }

  bool get isRunning => _isRunning;

  void setInterval(int seconds) {
    _reminderIntervalSeconds = seconds;
    if (_isRunning) {
      // Restart timer with new interval
      stopReminderService();
      startReminderService(intervalSeconds: seconds);
    }
  }

  // ===== ផ្ញើសាររំលឹក =====
  Future<void> _sendReminders() async {
    try {
      print('🔔 Checking for pending requests...');
      
      final pendingRequests = await _getPendingRequests();
      
      if (pendingRequests.isEmpty) {
        print('📭 No pending requests found');
        return;
      }
      
      print('📨 Found ${pendingRequests.length} pending requests');
      
      // ត្រងយកតែ request ដែលមិនទាន់បានផ្ញើក្នុងជុំនេះ
      final requestsToSend = pendingRequests
          .where((r) => !_pendingRequestIds.contains(r['requestId']))
          .toList();
      
      if (requestsToSend.isEmpty) {
        print('⏳ All pending requests already sent in this cycle');
        return;
      }
      
      // ផ្ញើសារសម្រាប់ request នីមួយៗ
      for (var request in requestsToSend) {
        await _sendReminderForRequest(request);
        _pendingRequestIds.add(request['requestId']);
      }
      
      print('✅ Sent ${requestsToSend.length} reminder(s)');
      
    } catch (e) {
      print('❌ Error sending reminders: $e');
    }
  }

  // ===== ទាញយក pending requests =====
  Future<List<Map<String, dynamic>>> _getPendingRequests() async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('leave_requests')
          .where('status', isEqualTo: 'pending')
          .get();
      
      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'requestId': doc.id,
          ...data,
        };
      }).toList();
      
    } catch (e) {
      print('❌ Error getting pending requests: $e');
      return [];
    }
  }

  // ===== បម្លែងម៉ោងទៅជា AM/PM តាមម៉ោងកម្ពុជា =====
  String _formatToCambodiaTime(DateTime dateTime) {
    try {
      // បម្លែងទៅជាម៉ោងកម្ពុជា (UTC+7)
      final cambodiaTime = dateTime.toUtc().add(const Duration(hours: 7));
      
      final day = cambodiaTime.day.toString().padLeft(2, '0');
      final month = cambodiaTime.month.toString().padLeft(2, '0');
      final year = cambodiaTime.year;
      
      int hour = cambodiaTime.hour;
      final int minute = cambodiaTime.minute;
      final String period = hour >= 12 ? 'PM' : 'AM';
      
      // បម្លែងម៉ោងពី 24-hour ទៅ 12-hour
      if (hour == 0) {
        hour = 12;
      } else if (hour > 12) {
        hour = hour - 12;
      }
      
      return '$day/$month/$year ${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
    } catch (e) {
      return 'N/A';
    }
  }

  // ===== គណនារយៈពេលរង់ចាំ =====
  String _calculateWaitingTime(DateTime createdAt) {
    try {
      final now = DateTime.now().toUtc();
      final diff = now.difference(createdAt.toUtc());
      final hours = diff.inHours;
      final minutes = diff.inMinutes % 60;
      
      if (hours > 24) {
        final days = hours ~/ 24;
        final remainingHours = hours % 24;
        if (remainingHours > 0) {
          return '$days day(s) ${remainingHours}h';
        }
        return '$days day(s)';
      } else if (hours > 0) {
        if (minutes > 0) {
          return '${hours}h ${minutes}m';
        }
        return '${hours}h';
      } else {
        if (minutes > 0) {
          return '${minutes}m';
        }
        return 'Less than 1 minute';
      }
    } catch (e) {
      return 'N/A';
    }
  }

  // ===== ផ្ញើសាររំលឹកសម្រាប់ request មួយ =====
  Future<void> _sendReminderForRequest(Map<String, dynamic> request) async {
    try {
      final requestId = request['requestId'] ?? request['requestNumber'] ?? 'N/A';
      final staffName = request['userName'] ?? request['userEmail'] ?? 'Unknown';
      final reason = request['reason'] ?? 'No reason';
      final startDate = request['startDate'] ?? 'N/A';
      final endDate = request['endDate'] ?? 'N/A';
      final totalDays = request['totalDays'] ?? 0;
      final department = request['department'] ?? 'N/A';
      final createdAt = request['createdAt'] as Timestamp?;
      
      // បង្កើតពេលវេលាជា AM/PM តាមម៉ោងកម្ពុជា
      String createdTime = 'N/A';
      if (createdAt != null) {
        createdTime = _formatToCambodiaTime(createdAt.toDate());
      }
      
      // គណនារយៈពេលរង់ចាំ
      String waitingTime = 'N/A';
      if (createdAt != null) {
        waitingTime = _calculateWaitingTime(createdAt.toDate());
      }
      
      // រាប់ចំនួន reminders ដែលបានផ្ញើ
      int reminderCount = request['reminderCount'] ?? 0;
      final reminderNumber = reminderCount + 1;
      
      // បង្កើត message
      final message = '''
⚠️ <b>PENDING REQUEST REMINDER </b> ⚠️

 <b>Request ID:</b> $requestId
 <b>Staff:</b> $staffName
 <b>Department:</b> $department
 <b>Reason:</b> $reason
​ <b>Start Date:</b> $startDate
 <b>End Date:</b> $endDate
 <b>Total Days:</b> $totalDays
 <b>Created At:</b> $createdTime
 <b>Waiting Time:</b> $waitingTime
🔹 Status: <b>PENDING</b>

📌 <i>This is an automated reminder message.</i>
 <i>You will receive reminders until this request is approved or rejected.</i>
      ''';
      
      // ផ្ញើសារទៅ Telegram
      final sent = await TelegramService.sendToAll(message);
      
      if (sent) {
        // កត់ត្រាក្នុង Firestore ថាបានផ្ញើ reminder
        await _logReminder(request['requestId'] ?? requestId);
        print('📤 Reminder #$reminderNumber sent for request: $requestId');
      } else {
        print('❌ Failed to send reminder for request: $requestId');
      }
      
    } catch (e) {
      print('❌ Error sending reminder for request: $e');
    }
  }

  // ===== កត់ត្រាការផ្ញើ reminder =====
  Future<void> _logReminder(String requestId) async {
    try {
      if (requestId.isEmpty) return;
      
      // អាប់ដេត lastReminderSent និង reminderCount
      await FirebaseFirestore.instance
          .collection('leave_requests')
          .doc(requestId)
          .update({
        'lastReminderSent': FieldValue.serverTimestamp(),
        'reminderCount': FieldValue.increment(1),
      });
      
      // កត់ត្រាលម្អិតក្នុង subcollection
      await FirebaseFirestore.instance
          .collection('leave_requests')
          .doc(requestId)
          .collection('reminders')
          .add({
        'sentAt': FieldValue.serverTimestamp(),
        'type': 'pending_reminder',
        'sentBy': 'system',
      });
      
    } catch (e) {
      print('❌ Error logging reminder: $e');
    }
  }

  // ===== សម្អាត pending IDs ពេល request ត្រូវបាន updated =====
  void clearPendingRequestId(String requestId) {
    _pendingRequestIds.remove(requestId);
    print(' Cleared pending ID: $requestId');
  }

  // ===== ប្រើសម្រាប់ Stream Listener ដើម្បី track status changes =====
  void listenToRequestStatusChanges() {
    FirebaseFirestore.instance
        .collection('leave_requests')
        .where('status', whereIn: ['approved', 'rejected'])
        .snapshots()
        .listen((snapshot) {
      for (var doc in snapshot.docChanges) {
        if (doc.type == DocumentChangeType.modified || doc.type == DocumentChangeType.added) {
          final requestId = doc.doc.id;
          // ប្រសិនបើ request ត្រូវបាន approved ឬ rejected សូមលុបចេញពី pending list
          clearPendingRequestId(requestId);
          print(' Request $requestId is no longer pending, removed from reminder list');
        }
      }
    });
  }
}