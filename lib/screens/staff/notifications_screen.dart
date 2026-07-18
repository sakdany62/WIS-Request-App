// lib/screens/staff/notifications_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/request_service.dart';
import 'package:permission_system/app_fonts.dart';
import '../../utils/responsive.dart';

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

  // ============ Mark all notifications as read ============
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

  // ============ Mark a single notification as read ============
  Future<void> _markAsRead(String notificationId) async {
    await _requestService.markNotificationAsRead(notificationId);
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
          // ============ Mark All as Read button ============
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

          // Count unread notifications
          final unreadCount = notifications.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return data['isRead'] == false;
          }).length;

          return Column(
            children: [
              // ============ Show unread count ============
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
                      onTap: () async {
                        // Mark as read
                        if (!isRead) {
                          await _markAsRead(notification.id);
                        }
                        // If there is a requestId, we could navigate to details
                        if (data['requestId'] != null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'View request details coming soon',
                                style: TextStyle(fontSize: AppFonts.md),
                              ),
                              backgroundColor: Colors.blue,
                            ),
                          );
                        }
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
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: isRead ? Colors.white : const Color(0xFFE8F0FE),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isRead ? Colors.grey.shade200 : const Color(0xFF173B69).withOpacity(0.3),
        ),
      ),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: _iconColor.withOpacity(0.2),
          child: Icon(
            _iconData,
            color: _iconColor,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
            fontSize: AppFonts.md,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: TextStyle(
                fontSize: AppFonts.md,
                color: isRead ? Colors.grey[600] : Colors.grey[800],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              time,
              style: TextStyle(
                fontSize: AppFonts.md,
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
      ),
    );
  }
}