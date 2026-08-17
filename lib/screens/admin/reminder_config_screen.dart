// lib/screens/admin/reminder_config_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/reminder_service.dart';
import '../../utils/responsive.dart';

class ReminderConfigScreen extends StatefulWidget {
  const ReminderConfigScreen({super.key});

  @override
  State<ReminderConfigScreen> createState() => _ReminderConfigScreenState();
}

class _ReminderConfigScreenState extends State<ReminderConfigScreen> {
  int _pendingCount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Load pending count
      final pending = await _getPendingCount();
      setState(() {
        _pendingCount = pending;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading status: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<int> _getPendingCount() async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('leave_requests')
          .where('status', isEqualTo: 'pending')
          .get();
      return querySnapshot.docs.length;
    } catch (e) {
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = Responsive.isMobile(context);
    final double fontSize = Responsive.fontSize(context, 14);
    final double spacing = Responsive.spacing(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reminder Configuration'),
        backgroundColor: const Color(0xFF173B69),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: _isLoading 
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadStatus,
            tooltip: 'Refresh Status',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(spacing * 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ===== Info Card =====
                  Container(
                    padding: EdgeInsets.all(spacing * 1.5),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                            SizedBox(width: spacing / 2),
                            Text(
                              ' How it works:',
                              style: TextStyle(
                                fontSize: isMobile ? fontSize : fontSize + 1,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[700],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: spacing / 2),
                        Text(
                          ' Background Service (Workmanager):\n'
                          '  • Sends reminders every 30 minutes automatically\n'
                          '  • Works even when app is closed\n'
                          '  • No need to keep app running\n\n'

                          ' How to stop:\n'
                          '  • Uninstall the app\n'
                          '  • Or disable background service in device settings',
                          style: TextStyle(
                            fontSize: isMobile ? fontSize * 0.85 : fontSize,
                            color: Colors.grey[600],
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: spacing * 2),

                  

                  // ===== Status Info =====
                  Container(
                    padding: EdgeInsets.all(spacing * 1.5),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ' Current Status',
                          style: TextStyle(
                            fontSize: isMobile ? fontSize + 1 : fontSize + 2,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: spacing / 2),
                        _buildStatusRow(
                          'Service Status',
                          ' Active',
                          isMobile,
                          fontSize,
                        ),
                        _buildStatusRow(
                          'Reminder Interval',
                          '30 minutes',
                          isMobile,
                          fontSize,
                        ),
                        _buildStatusRow(
                          'Pending Requests',
                          '$_pendingCount',
                          isMobile,
                          fontSize,
                        ),
                        _buildStatusRow(
                          'Platform',
                          'Android / iOS',
                          isMobile,
                          fontSize,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatusRow(String label, String value, bool isMobile, double fontSize) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isMobile ? fontSize * 0.85 : fontSize,
              color: Colors.grey[600],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isMobile ? fontSize * 0.85 : fontSize,
              fontWeight: FontWeight.w600,
              color: Colors.green[700],
            ),
          ),
        ],
      ),
    );
  }
}