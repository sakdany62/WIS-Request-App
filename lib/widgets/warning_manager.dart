// lib/widgets/warning_popup.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:permission_system/app_fonts.dart';
import '../services/warning_service.dart';

class WarningPopup extends StatefulWidget {
  final Map<String, dynamic> warning;
  final VoidCallback? onDismiss;

  const WarningPopup({
    super.key,
    required this.warning,
    this.onDismiss,
  });

  @override
  State<WarningPopup> createState() => _WarningPopupState();
}

class _WarningPopupState extends State<WarningPopup> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final severity = widget.warning['severity'] ?? 'info';
    final color = _getSeverityColor(severity);
    final icon = _getSeverityIcon(severity);

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with severity color
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color, color.withOpacity(0.8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    icon,
                    color: Colors.white,
                    size: 48,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.warning['title'] ?? 'Warning',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: AppFonts.md + 2,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    severity.toUpperCase(),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: AppFonts.md,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            // Body
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.warning['message'] ?? 'No message provided',
                    style: TextStyle(
                      fontSize: AppFonts.md,
                      color: Colors.grey.shade800,
                      height: 1.6,
                    ),
                  ),
                  if (widget.warning['expiresAt'] != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(
                          Icons.alarm,
                          size: 16,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Expires: ${_formatDate(widget.warning['expiresAt'])}',
                          style: TextStyle(
                            fontSize: AppFonts.md,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (widget.warning['senderName'] != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.person_outline,
                          size: 16,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'From: ${widget.warning['senderName']}',
                          style: TextStyle(
                            fontSize: AppFonts.md,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 20),
                  // Action Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _dismissWarning,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: color,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              widget.warning['actionButtonText'] ?? 'OK',
                              style: TextStyle(
                                fontSize: AppFonts.md,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
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

  Future<void> _dismissWarning() async {
    setState(() => _isLoading = true);

    try {
      await WarningService.markWarningAsRead(widget.warning['id']);
      
      if (mounted) {
        Navigator.pop(context);
        widget.onDismiss?.call();
      }
    } catch (e) {
      print('❌ Error dismissing warning: $e');
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }
}

// Show warning popup
Future<void> showWarningPopup(
  BuildContext context,
  Map<String, dynamic> warning, {
  VoidCallback? onDismiss,
}) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => WarningPopup(
      warning: warning,
      onDismiss: onDismiss,
    ),
  );
}