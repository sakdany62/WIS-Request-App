// lib/screens/staff/notifications_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/request_service.dart';
import 'package:permission_system/app_fonts.dart';
import '../../utils/responsive.dart';
import '../../services/telegram_service.dart'; // ✅ បន្ថែម import TelegramService

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final RequestService _requestService = RequestService();
  String? userId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _getUserId();
  }

  Future<void> _getUserId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        userId = user.uid;
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _markAllAsRead() async {
    if (userId == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();

      if (snapshot.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'All notifications are already read',
              style: TextStyle(fontSize: AppFonts.md),
            ),
            backgroundColor: Colors.blue,
          ),
        );
        return;
      }

      final batch = FirebaseFirestore.instance.batch();
      for (var doc in snapshot.docs) {
        batch.update(doc.reference, {
          'isRead': true,
          'readAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ ${snapshot.docs.length} notifications marked as read',
              style: TextStyle(fontSize: AppFonts.md),
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('❌ Error marking all as read: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '❌ Error: $e',
              style: TextStyle(fontSize: AppFonts.md),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _markAsRead(String notificationId) async {
    await _requestService.markNotificationAsRead(notificationId);
  }

  // ✅ បង្ហាញ Notification Detail Dialog និងសម្គាល់ថាបានអានដោយស្វ័យប្រវត្តិ
  void _showNotificationDetail(Map<String, dynamic> data, String notificationId) {
    final isRead = data['isRead'] ?? false;
    final title = data['title'] ?? 'Notification';
    final message = data['message'] ?? '';
    final type = data['type'] ?? 'general';
    final createdAt = data['createdAt'];
    final requestId = data['requestId'];
    final metadata = data['metadata'] as Map<String, dynamic>? ?? {};

    // ✅ ប្រសិនបើមិនទាន់បានអាន សម្គាល់ថាបានអានដោយស្វ័យប្រវត្តិ
    if (!isRead) {
      _markAsRead(notificationId);
    }

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: NotificationDetailDialog(
          title: title,
          message: message,
          type: type,
          createdAt: createdAt,
          requestId: requestId,
          metadata: metadata,
          isRead: true,
          notificationId: notificationId,
          onMarkAsRead: null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || userId == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            'Notifications',
            style: TextStyle(fontSize: AppFonts.md, color: Colors.white),
          ),
          backgroundColor: const Color(0xFF173B69),
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Notifications',
          style: TextStyle(fontSize: AppFonts.md, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF173B69),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all),
            onPressed: _markAllAsRead,
            tooltip: 'Mark all as read',
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _requestService.getUserNotifications(userId!),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Error: ${snapshot.error}',
                    style: TextStyle(color: Colors.red, fontSize: AppFonts.md),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {});
                    },
                    child: Text(
                      'Retry',
                      style: TextStyle(fontSize: AppFonts.md),
                    ),
                  ),
                ],
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final notifications = snapshot.data?.docs ?? [];

          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.notifications_off, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    'No notifications',
                    style: TextStyle(color: Colors.grey, fontSize: AppFonts.md),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You are all caught up!',
                    style: TextStyle(color: Colors.grey, fontSize: AppFonts.md),
                  ),
                ],
              ),
            );
          }

          final unreadCount = notifications.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return data['isRead'] == false;
          }).length;

          return Column(
            children: [
              if (unreadCount > 0)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                  color: Colors.blue.shade50,
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 18, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      Text(
                        '$unreadCount unread notification${unreadCount > 1 ? 's' : ''}',
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.w500,
                          fontSize: AppFonts.md,
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: notifications.length,
                  itemBuilder: (context, index) {
                    final notification = notifications[index];
                    final data = notification.data() as Map<String, dynamic>;
                    final isRead = data['isRead'] ?? false;

                    return _NotificationItem(
                      title: data['title'] ?? 'Notification',
                      message: data['message'] ?? '',
                      time: _formatTime(data['createdAt']),
                      isRead: isRead,
                      type: data['type'] ?? 'general',
                      onTap: () {
                        _showNotificationDetail(data, notification.id);
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _formatTime(dynamic timestamp) {
    if (timestamp == null) return 'Just now';
    
    DateTime date;
    if (timestamp is Timestamp) {
      date = timestamp.toDate();
    } else if (timestamp is DateTime) {
      date = timestamp;
    } else {
      return 'Recently';
    }
    
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays > 7) {
      return '${(difference.inDays / 7).floor()}w ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}

// ==================== NOTIFICATION ITEM ====================
class _NotificationItem extends StatelessWidget {
  final String title;
  final String message;
  final String time;
  final bool isRead;
  final String type;
  final VoidCallback? onTap;

  const _NotificationItem({
    required this.title,
    required this.message,
    required this.time,
    this.isRead = false,
    this.type = 'general',
    this.onTap,
  });

  Color get _iconColor {
    if (isRead) return Colors.grey;
    switch (type) {
      case 'request_approved':
        return Colors.green;
      case 'request_rejected':
        return Colors.red;
      case 'need_approval':
        return Colors.orange;
      case 'auto_approved':
        return Colors.purple;
      default:
        return const Color(0xFF173B69);
    }
  }

  IconData get _iconData {
    if (isRead) return Icons.notifications_off;
    switch (type) {
      case 'request_approved':
        return Icons.check_circle;
      case 'request_rejected':
        return Icons.cancel;
      case 'need_approval':
        return Icons.warning;
      case 'auto_approved':
        return Icons.verified;
      default:
        return Icons.notifications_active;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = Responsive.isMobile(context);
    final double fontSize = Responsive.fontSize(context, 14);
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: isRead ? Colors.white : const Color(0xFFE8F0FE),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isRead ? Colors.grey.shade200 : const Color(0xFF173B69).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _iconColor.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(
            _iconData,
            color: _iconColor,
            size: isMobile ? 20 : 24,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
            fontSize: isMobile ? fontSize : fontSize + 2,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: TextStyle(
                fontSize: isMobile ? fontSize * 0.85 : fontSize,
                color: isRead ? Colors.grey[600] : Colors.grey[800],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              time,
              style: TextStyle(
                fontSize: isMobile ? fontSize * 0.75 : fontSize * 0.85,
                color: isRead ? Colors.grey[400] : Colors.grey[500],
              ),
            ),
          ],
        ),
        trailing: isRead
            ? null
            : Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
              ),
        isThreeLine: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }
}

// ==================== NOTIFICATION DETAIL DIALOG ====================
class NotificationDetailDialog extends StatefulWidget {
  final String title;
  final String message;
  final String type;
  final dynamic createdAt;
  final String? requestId;
  final Map<String, dynamic> metadata;
  final bool isRead;
  final String notificationId;
  final VoidCallback? onMarkAsRead;

  const NotificationDetailDialog({
    super.key,
    required this.title,
    required this.message,
    required this.type,
    this.createdAt,
    this.requestId,
    this.metadata = const {},
    this.isRead = false,
    required this.notificationId,
    this.onMarkAsRead,
  });

  @override
  State<NotificationDetailDialog> createState() => _NotificationDetailDialogState();
}

class _NotificationDetailDialogState extends State<NotificationDetailDialog> {
  bool _isMarkingRead = false;

  // ✅ ទ្រង់ទ្រាយពេលវេលាជា AM/PM តាមម៉ោងកម្ពុជា
  String _formatDateTimeAMPM([DateTime? time]) {
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

  // ✅ ទ្រង់ទ្រាយពេលវេលា submit
  String _formatSubmitTime(dynamic timestamp) {
    if (timestamp == null) return _formatDateTimeAMPM();
    
    DateTime date;
    if (timestamp is Timestamp) {
      date = timestamp.toDate();
    } else if (timestamp is DateTime) {
      date = timestamp;
    } else {
      return _formatDateTimeAMPM();
    }
    
    return _formatDateTimeAMPM(date);
  }

  // ✅ ទ្រង់ទ្រាយ status
  String _formatStatus(String status) {
    switch (status.toLowerCase()) {
      case 'pending': return 'PENDING';
      case 'approved': return 'APPROVED ✅';
      case 'rejected': return 'REJECTED ❌';
      default: return status.toUpperCase();
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'request_approved':
        return Colors.green;
      case 'request_rejected':
        return Colors.red;
      case 'need_approval':
        return Colors.orange;
      case 'auto_approved':
        return Colors.purple;
      default:
        return const Color(0xFF173B69);
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'request_approved':
        return Icons.check_circle;
      case 'request_rejected':
        return Icons.cancel;
      case 'need_approval':
        return Icons.warning;
      case 'auto_approved':
        return Icons.verified;
      default:
        return Icons.notifications_active;
    }
  }

  String _getTypeLabel(String type) {
    switch (type) {
      case 'request_approved':
        return 'Approved';
      case 'request_rejected':
        return 'Rejected';
      case 'need_approval':
        return 'Pending Approval';
      case 'auto_approved':
        return 'Auto Approved';
      default:
        return 'General';
    }
  }

  // ✅ Widget សម្រាប់បង្ហាញព័ត៌មាន 1 ជួរ (គ្មាន icon)
  Widget _buildInfoRow(String label, String value, {bool isBold = false}) {
    final bool isMobile = Responsive.isMobile(context);
    final double fontSize = Responsive.fontSize(context, 14);
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: isMobile ? 100 : 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: isMobile ? fontSize * 0.85 : fontSize,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: isMobile ? fontSize * 0.85 : fontSize,
                color: Colors.grey[900],
                fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = Responsive.isMobile(context);
    final double fontSize = Responsive.fontSize(context, 14);
    final double spacing = Responsive.spacing(context);

    // ✅ ទាញយកទិន្នន័យពី metadata (ដែលជា data ទាំងមូល)
    final Map<String, dynamic> data = widget.metadata;
    
    // ✅ ទាញយក Request ID
    final String requestId = widget.requestId ?? 
                             data['requestId']?.toString() ?? 
                             'N/A';
    
    // ✅ ទាញយកឈ្មោះអ្នកអនុម័ត (approvedBy)
    final String approvedBy = data['approvedBy']?.toString() ?? 'N/A';
    
    // ✅ ទាញយកឈ្មោះអ្នកស្នើសុំ (userEmail)
    final String userEmail = data['userEmail']?.toString() ?? 'N/A';
    
    // ✅ ទាញយកចំនួនថ្ងៃ (totalDays)
    final String totalDays = data['totalDays']?.toString() ?? '1';
    
    // ✅ ទាញយក Status
    final String status = data['status']?.toString() ?? 
                          widget.type.replaceFirst('request_', '') ?? 
                          'pending';
    final String formattedStatus = _formatStatus(status);
    
    // ✅ ទាញយក Submit Time - ពី createdAt
    final String submitTime = _formatSubmitTime(widget.createdAt);
    
    // ✅ ទាញយក User ID
    final String userId = data['userId']?.toString() ?? 'N/A';

    return Container(
      width: isMobile ? double.infinity : 500,
      padding: EdgeInsets.all(spacing * 1.5),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ✅ Header with Icon and Status
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _getTypeColor(widget.type).withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _getTypeIcon(widget.type),
                  color: _getTypeColor(widget.type),
                  size: isMobile ? 28 : 32,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: TextStyle(
                        fontSize: isMobile ? fontSize + 4 : fontSize + 6,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF173B69),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: _getTypeColor(widget.type).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _getTypeLabel(widget.type),
                            style: TextStyle(
                              fontSize: isMobile ? fontSize * 0.7 : fontSize * 0.8,
                              color: _getTypeColor(widget.type),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (!widget.isRead)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'UNREAD',
                              style: TextStyle(
                                fontSize: isMobile ? fontSize * 0.7 : fontSize * 0.8,
                                color: Colors.blue,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          const Divider(color: Colors.grey, thickness: 1),
          const SizedBox(height: 12),
          
          // បង្ហាញព័ត៌មានទាំងអស់ 
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Request ID
                _buildInfoRow('Request ID', requestId, isBold: true),                
                // Total Days
                _buildInfoRow('Total Days', '$totalDays day${int.parse(totalDays) > 1 ? 's' : ''}'),
                
                // Submit Time
                _buildInfoRow('Submit Time', submitTime),
                
                // Message
                _buildInfoRow('Message', widget.message),
                
                // Status
                _buildInfoRow('Status', formattedStatus, isBold: true),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          const Divider(color: Colors.grey, thickness: 1),
          const SizedBox(height: 12),
          
          //  Actions - Close Button
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0xFF173B69),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  'Close',
                  style: TextStyle(
                    fontSize: isMobile ? fontSize : fontSize + 2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}