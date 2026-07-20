// lib/screens/staff/warning_popup_settings_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/warning_service.dart';
import '../../app_fonts.dart';
import '../../utils/responsive.dart';

class WarningPopupSettingsScreen extends StatefulWidget {
  const WarningPopupSettingsScreen({super.key});

  @override
  State<WarningPopupSettingsScreen> createState() => _WarningPopupSettingsScreenState();
}

class _WarningPopupSettingsScreenState extends State<WarningPopupSettingsScreen> {
  bool _isLoading = true;
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
        content: Text(
          message, 
          style: TextStyle(fontSize: Responsive.fontSize(context, AppFonts.md)),
        ),
        backgroundColor: color,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = Responsive.isMobile(context);
    final double fontSize = Responsive.fontSize(context, AppFonts.md);
    final double spacing = Responsive.spacing(context);
    final EdgeInsets padding = Responsive.padding(context);
    final double iconSize = Responsive.iconSize(context, 22);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Warning Popup',
          style: TextStyle(
            fontSize: isMobile ? AppFonts.md : AppFonts.md + 2,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF173B69),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, size: iconSize),
            onPressed: _loadWarnings,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: const Color(0xFF173B69),
              ),
            )
          : _warnings.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: iconSize * 2.9,
                        color: Colors.green.shade300,
                      ),
                      SizedBox(height: spacing * 2),
                      Text(
                        'No active warnings',
                        style: TextStyle(
                          fontSize: fontSize + 2,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      SizedBox(height: spacing),
                      Text(
                        'You\'re all caught up!',
                        style: TextStyle(
                          fontSize: fontSize,
                          color: Colors.grey.shade400,
                        ),
                      ),
                      SizedBox(height: spacing),
                      TextButton(
                        onPressed: _loadWarnings,
                        child: Text(
                          'Refresh',
                          style: TextStyle(
                            fontSize: fontSize,
                            color: const Color(0xFF173B69),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.all(spacing * 1.5),
                  itemCount: _warnings.length,
                  itemBuilder: (context, index) {
                    final warning = _warnings[index];
                    final severity = warning['severity'] ?? 'info';
                    final color = _getSeverityColor(severity);
                    
                    return Card(
                      margin: EdgeInsets.only(bottom: spacing),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        leading: Container(
                          width: 4,
                          height: 40,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        title: Text(
                          warning['title'] ?? 'Warning',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: fontSize,
                          ),
                        ),
                        subtitle: Text(
                          warning['message'] ?? '',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: fontSize,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        trailing: Chip(
                          label: Text(
                            severity.toUpperCase(),
                            style: TextStyle(
                              fontSize: fontSize * 0.7,
                              color: color,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          backgroundColor: color.withOpacity(0.1),
                          side: BorderSide.none,
                        ),
                        onTap: () {
                          _showWarningDetails(warning);
                        },
                        isThreeLine: false,
                      ),
                    );
                  },
                ),
    );
  }

  void _showWarningDetails(Map<String, dynamic> warning) {
    final severity = warning['severity'] ?? 'info';
    final color = _getSeverityColor(severity);
    final double fontSize = Responsive.fontSize(context, AppFonts.md);
    final double spacing = Responsive.spacing(context);
    final double iconSize = Responsive.iconSize(context, 22);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(
              _getSeverityIcon(severity),
              color: color,
              size: iconSize,
            ),
            SizedBox(width: spacing),
            Expanded(
              child: Text(
                warning['title'] ?? 'Warning',
                style: TextStyle(
                  fontSize: fontSize + 2,
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
                fontSize: fontSize,
                height: 1.5,
              ),
            ),
            SizedBox(height: spacing * 1.5),
            Container(
              padding: EdgeInsets.all(spacing),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.label,
                    size: iconSize * 0.7,
                    color: color,
                  ),
                  SizedBox(width: spacing),
                  Text(
                    'Severity: ${severity.toUpperCase()}',
                    style: TextStyle(
                      fontSize: fontSize,
                      color: color,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (warning['expiresAt'] != null) ...[
              SizedBox(height: spacing),
              Row(
                children: [
                  Icon(
                    Icons.alarm,
                    size: iconSize * 0.7,
                    color: Colors.grey.shade600,
                  ),
                  SizedBox(width: spacing),
                  Text(
                    'Expires: ${_formatDate(warning['expiresAt'])}',
                    style: TextStyle(
                      fontSize: fontSize,
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
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF173B69),
            ),
            child: Text(
              'Close',
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w500,
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