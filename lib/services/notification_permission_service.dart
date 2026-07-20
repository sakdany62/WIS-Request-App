// lib/services/notification_permission_service.dart
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

// Global navigator key for use in services
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class NotificationPermissionService {
  static final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static bool _isInitialized = false;

  // Initialize local notifications
  static Future<void> initializeNotifications() async {
    if (_isInitialized) return;

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/launcher_icon');
    
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );
    
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _handleNotificationTap,
    );
    
    _isInitialized = true;
    print('✅ Notification service initialized');
  }

  // Request notification permission
  static Future<bool> requestPermission() async {
    try {
      // Check if running on Android
      final context = navigatorKey.currentContext;
      if (context == null) return false;
      
      if (Theme.of(context).platform == TargetPlatform.android) {
        final status = await Permission.notification.status;
        
        if (status.isDenied) {
          final result = await Permission.notification.request();
          return result.isGranted;
        } else if (status.isPermanentlyDenied) {
          await _showSettingsDialog();
          return false;
        }
        return status.isGranted;
      }
      return true; // iOS auto handles permissions
    } catch (e) {
      print('❌ Error requesting notification permission: $e');
      return false;
    }
  }

  // Check notification permission status
  static Future<bool> checkPermission() async {
    try {
      final context = navigatorKey.currentContext;
      if (context == null) return false;
      
      if (Theme.of(context).platform == TargetPlatform.android) {
        final status = await Permission.notification.status;
        return status.isGranted;
      }
      return true;
    } catch (e) {
      print('❌ Error checking notification permission: $e');
      return false;
    }
  }

  // Show settings dialog
  static Future<void> _showSettingsDialog() async {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Notification Permission Required'),
        content: const Text(
          'Please enable notification permissions in your device settings to receive important updates and alerts.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  // Handle notification tap
  static void _handleNotificationTap(NotificationResponse response) {
    final context = navigatorKey.currentContext;
    if (context != null) {
      // Navigate to notifications screen if needed
      // Navigator.pushNamed(context, '/notifications');
    }
  }

  // Show local notification
  static Future<void> showLocalNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'permission_channel',
      'Permission Notifications',
      channelDescription: 'Notifications for permission system',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
      icon: '@mipmap/launcher_icon',
      enableVibration: true,
    );

    const DarwinNotificationDetails iosPlatformChannelSpecifics =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iosPlatformChannelSpecifics,
    );

    await _flutterLocalNotificationsPlugin.show(
      id,
      title,
      body,
      platformChannelSpecifics,
      payload: payload,
    );
  }
}