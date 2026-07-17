// lib/screens/staff/warning_popup_settings_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/warning_service.dart';
import '../../app_fonts.dart';

class WarningPopupSettingsScreen extends StatefulWidget {
  const WarningPopupSettingsScreen({super.key});

  @override
  State<WarningPopupSettingsScreen> createState() => _WarningPopupSettingsScreenState();
}

class _WarningPopupSettingsScreenState extends State<WarningPopupSettingsScreen> {
  bool _isLoading = true;
  bool _showWarnings = true;
  List<Map<String, dynamic>> _warnings = [];

  @override
  void initState() {
    super.initState();
    _loadWarnings();
  }

  Future<void> _loadWarnings() async {
    setState(() => _isLoading = true);
    try {
      final warnings = await WarningService.getActiveWarnings();
      setState(() {
        _warnings = warnings;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Error loading warnings: $e', Colors.red);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(fontSize: AppFonts.md)),
        backgroundColor: color,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Warning Popup Settings',
          style: TextStyle(
            fontSize: AppFonts.md,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF173B69),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Toggle switch
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(
                  color: Colors.grey.shade200,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.notifications_active,
                      color: _showWarnings ? Colors.green : Colors.grey,
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Show Warnings',
                          style: TextStyle(
                            fontSize: AppFonts.md,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          'Display warning popups when opening the app',
                          style: TextStyle(
                            fontSize: AppFonts.md,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Switch(
                  value: _showWarnings,
                  onChanged: (value) {
                    setState(() => _showWarnings = value);
                    // Save preference using shared_preferences
                    // You can implement this if needed
                  },
                  activeColor: const Color(0xFF173B69),
                ),
              ],
            ),
          ),
          
          // Warning list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _warnings.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.check_circle_outline,
                              size: 64,
                              color: Colors.green.shade300,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No active warnings',
                              style: TextStyle(
                                fontSize: AppFonts.md,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'You\'re all caught up!',
                              style: TextStyle(
                                fontSize: AppFonts.md,
                                color: Colors.grey.shade400,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: _loadWarnings,
                              child: Text(
                                'Refresh',
                                style: TextStyle(
                                  fontSize: AppFonts.md,
                                  color: const Color(0xFF173B69),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _warnings.length,
                        itemBuilder: (context, index) {
                          final warning = _warnings[index];
                          final severity = warning['severity'] ?? 'info';
                          final color = _getSeverityColor(severity);
                          
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: Container(
                                width: 4,
                                height: 40,
                                color: color,
                              ),
                              title: Text(
                                warning['title'] ?? 'Warning',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: AppFonts.md,
                                ),
                              ),
                              subtitle: Text(
                                warning['message'] ?? '',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: AppFonts.md,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              trailing: Chip(
                                label: Text(
                                  severity.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: AppFonts.md * 0.7,
                                    color: color,
                                  ),
                                ),
                                backgroundColor: color.withOpacity(0.1),
                                side: BorderSide.none,
                              ),
                              onTap: () {
                                _showWarningDetails(warning);
                              },
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  void _showWarningDetails(Map<String, dynamic> warning) {
    final severity = warning['severity'] ?? 'info';
    final color = _getSeverityColor(severity);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              _getSeverityIcon(severity),
              color: color,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                warning['title'] ?? 'Warning',
                style: TextStyle(
                  fontSize: AppFonts.md + 2,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              warning['message'] ?? 'No message',
              style: TextStyle(
                fontSize: AppFonts.md,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.label,
                    size: 16,
                    color: color,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Severity: ${severity.toUpperCase()}',
                    style: TextStyle(
                      fontSize: AppFonts.md,
                      color: color,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (warning['expiresAt'] != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.alarm,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Expires: ${_formatDate(warning['expiresAt'])}',
                    style: TextStyle(
                      fontSize: AppFonts.md,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: TextStyle(
                fontSize: AppFonts.md,
                color: const Color(0xFF173B69),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getSeverityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return Colors.red;
      case 'warning':
        return Colors.orange;
      case 'info':
        return Colors.blue;
      default:
        return Colors.blue;
    }
  }

  IconData _getSeverityIcon(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return Icons.dangerous;
      case 'warning':
        return Icons.warning_amber_rounded;
      case 'info':
        return Icons.info_outline;
      default:
        return Icons.info_outline;
    }
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      return '${date.day}/${date.month}/${date.year}';
    }
    return 'N/A';
  }
}