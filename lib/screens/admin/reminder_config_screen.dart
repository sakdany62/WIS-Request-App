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
  final _formKey = GlobalKey<FormState>();
  final _intervalController = TextEditingController();
  
  final ReminderService _reminderService = ReminderService();
  bool _isRunning = false;
  int _currentInterval = 300; // 5 minutes default
  int _pendingCount = 0;
  bool _isLoading = true;

  // Firestore reference for saving interval
  final CollectionReference _configCollection = 
      FirebaseFirestore.instance.collection('reminder_config');
  final String _configDocId = 'reminder_settings';

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  @override
  void dispose() {
    _intervalController.dispose();
    super.dispose();
  }

  Future<void> _loadStatus() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Load saved interval from Firestore
      final savedInterval = await _loadSavedInterval();
      
      setState(() {
        _isRunning = _reminderService.isRunning;
        _currentInterval = savedInterval;
        _intervalController.text = savedInterval.toString();
      });
      
      // Update service with saved interval
      if (_isRunning) {
        _reminderService.setInterval(savedInterval);
      }
      
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

  Future<int> _loadSavedInterval() async {
    try {
      final doc = await _configCollection.doc(_configDocId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final interval = data['intervalSeconds'] ?? 300;
        return interval;
      }
      return 300;
    } catch (e) {
      print('Error loading saved interval: $e');
      return 300;
    }
  }

  Future<void> _saveInterval(int seconds) async {
    try {
      await _configCollection.doc(_configDocId).set({
        'intervalSeconds': seconds,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': 'admin',
      }, SetOptions(merge: true));
      print('✅ Interval saved to Firestore: $seconds');
    } catch (e) {
      print('❌ Error saving interval: $e');
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

  void _updateInterval() {
    if (_formKey.currentState!.validate()) {
      final int seconds = int.parse(_intervalController.text.trim());
      
      setState(() {
        _currentInterval = seconds;
      });
      
      // Save to Firestore
      _saveInterval(seconds);
      
      // Update service
      _reminderService.setInterval(seconds);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Reminder interval updated to ${_formatDuration(seconds)}'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  String _formatDuration(int seconds) {
    if (seconds >= 3600) {
      final hours = seconds ~/ 3600;
      final minutes = (seconds % 3600) ~/ 60;
      return '${hours}h ${minutes}m';
    } else if (seconds >= 60) {
      final minutes = seconds ~/ 60;
      final remainingSeconds = seconds % 60;
      return '${minutes}m ${remainingSeconds}s';
    } else {
      return '${seconds}s';
    }
  }

  void _toggleService() {
    setState(() {
      if (_isRunning) {
        _reminderService.stopReminderService();
        _isRunning = false;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⏸️ Reminder service paused'),
            backgroundColor: Colors.orange,
          ),
        );
      } else {
        _reminderService.startReminderService(intervalSeconds: _currentInterval);
        _isRunning = true;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('▶️ Reminder service started'),
            backgroundColor: Colors.green,
          ),
        );
      }
    });
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
                  // ===== Status Card =====
                  Container(
                    padding: EdgeInsets.all(spacing * 1.5),
                    decoration: BoxDecoration(
                      color: _isRunning ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _isRunning ? Colors.green : Colors.red,
                        width: 2,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _isRunning ? Icons.play_circle : Icons.pause_circle,
                          color: _isRunning ? Colors.green : Colors.red,
                          size: 40,
                        ),
                        SizedBox(width: spacing),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _isRunning ? ' Service is Running' : ' Service is Paused',
                                style: TextStyle(
                                  fontSize: isMobile ? fontSize + 2 : fontSize + 4,
                                  fontWeight: FontWeight.bold,
                                  color: _isRunning ? Colors.green : Colors.red,
                                ),
                              ),
                              Text(
                                _isRunning 
                                    ? 'Reminders will be sent every ${_formatDuration(_currentInterval)}'
                                    : 'Click "Start Service" to begin sending reminders',
                                style: TextStyle(
                                  fontSize: isMobile ? fontSize * 0.85 : fontSize,
                                  color: Colors.grey[600],
                                ),
                              ),
                              // បង្ហាញតម្លៃដែលបានរក្សាទុក
                              Text(
                                'Saved interval: ${_formatDuration(_currentInterval)}',
                                style: TextStyle(
                                  fontSize: isMobile ? fontSize * 0.75 : fontSize,
                                  color: Colors.blue[700],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: spacing * 2),

                  // ===== Set Custom Interval =====
                  Container(
                    padding: EdgeInsets.all(spacing * 1.5),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Custom Interval',
                            style: TextStyle(
                              fontSize: isMobile ? fontSize + 1 : fontSize + 2,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: spacing / 2),
                          
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _intervalController,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    labelText: 'Interval (seconds)',
                                    hintText: 'e.g., 300',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    suffixText: 'sec',
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: spacing,
                                      vertical: isMobile ? 12 : 16,
                                    ),
                                  ),
                                  style: TextStyle(
                                    fontSize: isMobile ? fontSize : fontSize + 1,
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Please enter interval';
                                    }
                                    final int? seconds = int.tryParse(value.trim());
                                    if (seconds == null) {
                                      return 'Please enter a valid number';
                                    }
                                    if (seconds < 30) {
                                      return 'Minimum interval is 30 seconds';
                                    }
                                    if (seconds > 86400) {
                                      return 'Maximum interval is 24 hours';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              SizedBox(width: spacing),
                              SizedBox(
                                height: isMobile ? 44 : 48,
                                child: ElevatedButton(
                                  onPressed: _updateInterval,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF173B69),
                                    foregroundColor: Colors.white,
                                  ),
                                  child: Text(
                                    'Update',
                                    style: TextStyle(
                                      fontSize: isMobile ? fontSize * 0.9 : fontSize,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: spacing * 2),

                  

                  // ===== Control Buttons =====
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: isMobile ? 44 : 48,
                          child: ElevatedButton.icon(
                            onPressed: _toggleService,
                            icon: Icon(
                              _isRunning ? Icons.pause : Icons.play_arrow,
                              size: 20,
                            ),
                            label: Text(
                              _isRunning ? ' Pause Service' : ' Start Service',
                              style: TextStyle(
                                fontSize: isMobile ? fontSize * 0.9 : fontSize,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isRunning ? Colors.orange : Colors.green,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: spacing * 2),

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
                          '• System checks for pending requests every interval\n'
                          '• Each pending request receives one reminder per cycle\n'
                          '• Reminders stop automatically when request is Approved or Rejected\n'
                          '• All pending requests will be reminded until resolved\n'
                          '• Each reminder includes waiting time and reminder count',
                          style: TextStyle(
                            fontSize: isMobile ? fontSize * 0.85 : fontSize,
                            color: Colors.grey[600],
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  
                ],
              ),
            ),
    );
  }

  Widget _buildPresetButton(String label, int seconds, bool isMobile, double fontSize) {
    final isActive = _currentInterval == seconds;
    return ElevatedButton(
      onPressed: () {
        setState(() {
          _intervalController.text = seconds.toString();
          _currentInterval = seconds;
        });
        _updateInterval();
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: isActive ? const Color(0xFF173B69) : Colors.grey[200],
        foregroundColor: isActive ? Colors.white : Colors.black87,
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 12 : 16,
          vertical: isMobile ? 6 : 8,
        ),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: isMobile ? fontSize * 0.75 : fontSize * 0.8,
          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value, bool isMobile, double fontSize) {
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
            ),
          ),
        ],
      ),
    );
  }
}