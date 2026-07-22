// lib/screens/admin/warning_management_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../services/warning_service.dart';
import '../../app_fonts.dart';
import '../../utils/responsive.dart';

class WarningManagementScreen extends StatefulWidget {
  const WarningManagementScreen({super.key});

  @override
  State<WarningManagementScreen> createState() => _WarningManagementScreenState();
}

class _WarningManagementScreenState extends State<WarningManagementScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _expiresAtController = TextEditingController();
  
  String _selectedSeverity = 'info';
  String _selectedAudience = 'all';
  DateTime? _expiresAt;
  bool _isCreating = false;

  late TabController _tabController;
  int _currentTabIndex = 0;

  final List<String> _severityOptions = ['info', 'warning', 'critical'];
  final List<String> _audienceOptions = ['all', 'staff', 'manager', 'admin'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _currentTabIndex = _tabController.index;
      });
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    _expiresAtController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _createWarning() async {
    if (_titleController.text.trim().isEmpty) {
      _showSnackBar('Please enter a title', Colors.red);
      return;
    }
    if (_messageController.text.trim().isEmpty) {
      _showSnackBar('Please enter a message', Colors.red);
      return;
    }

    setState(() => _isCreating = true);

    try {
      await WarningService.createWarning(
        title: _titleController.text.trim(),
        message: _messageController.text.trim(),
        severity: _selectedSeverity,
        targetAudience: _selectedAudience,
        expiresAt: _expiresAt,
      );

      _showSnackBar(' Warning created successfully!', Colors.green);
      
      _titleController.clear();
      _messageController.clear();
      _expiresAtController.clear();
      setState(() {
        _expiresAt = null;
        _selectedSeverity = 'info';
        _selectedAudience = 'all';
      });
    } catch (e) {
      _showSnackBar('Error: $e', Colors.red);
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }

  Future<void> _pickExpiryDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
    );

    if (picked != null) {
      setState(() {
        _expiresAt = picked;
        _expiresAtController.text = DateFormat('dd MMM yyyy').format(picked);
      });
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
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = Responsive.isMobile(context);
    final double fontSize = Responsive.fontSize(context, AppFonts.md);
    final double spacing = Responsive.spacing(context);
    final EdgeInsets padding = Responsive.padding(context);
    final double buttonHeight = Responsive.buttonHeight(context);
    final double iconSize = Responsive.iconSize(context, 22);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Warning Management',
          style: TextStyle(
            fontSize: isMobile ? 16 : 18,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF173B69),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_alert,
                    size: Responsive.iconSize(context, 18),
                    color: _currentTabIndex == 0 ? Colors.white : Colors.white70,
                  ),
                  SizedBox(width: spacing / 2),
                  Text(
                    'Create Warning',
                    style: TextStyle(
                      fontSize: Responsive.fontSize(context, 14),
                      color: _currentTabIndex == 0 ? Colors.white : Colors.white70,
                      fontWeight: _currentTabIndex == 0 ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: Responsive.iconSize(context, 18),
                    color: _currentTabIndex == 1 ? Colors.white : Colors.white70,
                  ),
                  SizedBox(width: spacing / 2),
                  Text(
                    'Active Warnings',
                    style: TextStyle(
                      fontSize: Responsive.fontSize(context, 14),
                      color: _currentTabIndex == 1 ? Colors.white : Colors.white70,
                      fontWeight: _currentTabIndex == 1 ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCreateWarningTab(context, fontSize, spacing, padding, buttonHeight, iconSize),
          _buildActiveWarningsTab(context, fontSize, spacing, padding),
        ],
      ),
    );
  }

  Widget _buildCreateWarningTab(
    BuildContext context,
    double fontSize,
    double spacing,
    EdgeInsets padding,
    double buttonHeight,
    double iconSize,
  ) {
    final bool isMobile = Responsive.isMobile(context);
    
    return SingleChildScrollView(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Create New Warning',
            style: TextStyle(
              fontSize: isMobile ? fontSize + 2 : fontSize + 4,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF173B69),
            ),
          ),
          SizedBox(height: spacing * 2.5),

          // Title Field
          Text(
            'Title *',
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: spacing),
          TextField(
            controller: _titleController,
            decoration: InputDecoration(
              hintText: 'Enter warning title',
              hintStyle: TextStyle(
                fontSize: fontSize,
                color: Colors.grey.shade400,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Colors.grey.shade300,
                  width: 1.5,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Colors.grey.shade300,
                  width: 1.5,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0xFF173B69),
                  width: 2,
                ),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: EdgeInsets.symmetric(
                horizontal: spacing * 2,
                vertical: isMobile ? 12 : 16,
              ),
            ),
            style: TextStyle(
              fontSize: fontSize,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: spacing * 2),

          // Message Field
          Text(
            'Message *',
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: spacing),
          TextField(
            controller: _messageController,
            maxLines: isMobile ? 4 : 5,
            decoration: InputDecoration(
              hintText: 'Enter warning message',
              hintStyle: TextStyle(
                fontSize: fontSize,
                color: Colors.grey.shade400,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Colors.grey.shade300,
                  width: 1.5,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Colors.grey.shade300,
                  width: 1.5,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0xFF173B69),
                  width: 2,
                ),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: EdgeInsets.symmetric(
                horizontal: spacing * 2,
                vertical: isMobile ? 12 : 16,
              ),
            ),
            style: TextStyle(
              fontSize: fontSize,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: spacing * 2),

          // Severity Dropdown
          Text(
            'Severity',
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: spacing),
          Container(
            padding: EdgeInsets.symmetric(horizontal: spacing * 2),
            decoration: BoxDecoration(
              border: Border.all(
                color: Colors.grey.shade300,
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(12),
              color: Colors.white,
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedSeverity,
                items: _severityOptions.map((severity) {
                  return DropdownMenuItem(
                    value: severity,
                    child: Row(
                      children: [
                        Icon(
                          _getSeverityIcon(severity),
                          color: _getSeverityColor(severity),
                          size: Responsive.iconSize(context, 20),
                        ),
                        SizedBox(width: spacing),
                        Text(
                          severity.toUpperCase(),
                          style: TextStyle(
                            color: _getSeverityColor(severity),
                            fontWeight: FontWeight.w500,
                            fontSize: fontSize,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedSeverity = value);
                  }
                },
                isExpanded: true,
                dropdownColor: Colors.white,
                style: TextStyle(
                  fontSize: fontSize,
                  color: Colors.black87,
                ),
              ),
            ),
          ),
          SizedBox(height: spacing * 2),

          // Audience Dropdown
          Text(
            'Target Audience',
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: spacing),
          Container(
            padding: EdgeInsets.symmetric(horizontal: spacing * 2),
            decoration: BoxDecoration(
              border: Border.all(
                color: Colors.grey.shade300,
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(12),
              color: Colors.white,
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedAudience,
                items: _audienceOptions.map((audience) {
                  return DropdownMenuItem(
                    value: audience,
                    child: Text(
                      audience.toUpperCase(),
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: fontSize,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedAudience = value);
                  }
                },
                isExpanded: true,
                dropdownColor: Colors.white,
                style: TextStyle(
                  fontSize: fontSize,
                  color: Colors.black87,
                ),
              ),
            ),
          ),
          SizedBox(height: spacing * 2),

          // Expiry Date
          Text(
            'Expiry Date (Optional)',
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: spacing),
          GestureDetector(
            onTap: _pickExpiryDate,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: spacing * 2, vertical: isMobile ? 12 : 16),
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.grey.shade300,
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(12),
                color: Colors.white,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    color: Colors.grey.shade600,
                    size: Responsive.iconSize(context, 20),
                  ),
                  SizedBox(width: spacing * 1.5),
                  Expanded(
                    child: Text(
                      _expiresAtController.text.isEmpty
                          ? 'No expiry date set'
                          : _expiresAtController.text,
                      style: TextStyle(
                        fontSize: fontSize,
                        color: _expiresAtController.text.isEmpty
                            ? Colors.grey.shade500
                            : Colors.black87,
                      ),
                    ),
                  ),
                  if (_expiresAtController.text.isNotEmpty)
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        size: Responsive.iconSize(context, 20),
                        color: Colors.grey.shade600,
                      ),
                      onPressed: () {
                        setState(() {
                          _expiresAt = null;
                          _expiresAtController.clear();
                        });
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                ],
              ),
            ),
          ),
          SizedBox(height: spacing * 3),

          // Create Button
          SizedBox(
            width: double.infinity,
            height: buttonHeight,
            child: ElevatedButton(
              onPressed: _isCreating ? null : _createWarning,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF173B69),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
                disabledBackgroundColor: Colors.grey.shade400,
              ),
              child: _isCreating
                  ? SizedBox(
                      height: Responsive.iconSize(context, 24),
                      width: Responsive.iconSize(context, 24),
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_alert, size: Responsive.iconSize(context, 22)),
                        SizedBox(width: spacing),
                        Text(
                          'Create Warning',
                          style: TextStyle(
                            fontSize: fontSize,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          SizedBox(height: Responsive.isMobile(context) ? 60 : 80),
        ],
      ),
    );
  }

  Widget _buildActiveWarningsTab(
    BuildContext context,
    double fontSize,
    double spacing,
    EdgeInsets padding,
  ) {
    final bool isMobile = Responsive.isMobile(context);
    
    return StreamBuilder<QuerySnapshot>(
      stream: WarningService.getAllWarnings(),
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
                  style: TextStyle(color: Colors.red, fontSize: fontSize),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    setState(() {});
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF173B69),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    'Retry',
                    style: TextStyle(fontSize: fontSize),
                  ),
                ),
              ],
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              color: Color(0xFF173B69),
            ),
          );
        }

        final warnings = snapshot.data?.docs ?? [];

        if (warnings.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(spacing * 2.5),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.warning_amber_outlined,
                    size: Responsive.iconSize(context, 64),
                    color: Colors.grey,
                  ),
                ),
                SizedBox(height: spacing * 2),
                Text(
                  'No warnings created yet',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: isMobile ? fontSize + 2 : fontSize + 4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: spacing),
                Text(
                  'Start by creating your first warning',
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: fontSize,
                  ),
                ),
              ],
            ),
          );
        }

        final activeCount = warnings.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['isActive'] == true;
        }).length;

        return Column(
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: spacing * 2, vertical: spacing * 1.5),
              color: Colors.grey.shade50,
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: Responsive.iconSize(context, 20),
                    color: Colors.grey.shade600,
                  ),
                  SizedBox(width: spacing),
                  Text(
                    'Total: ${warnings.length} | Active: $activeCount',
                    style: TextStyle(
                      fontSize: fontSize,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.all(spacing * 1.5),
                itemCount: warnings.length,
                itemBuilder: (context, index) {
                  final doc = warnings[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final isActive = data['isActive'] ?? true;
                  final severity = data['severity'] ?? 'info';
                  final color = _getSeverityColor(severity);
                  
                  final readBy = data['readBy'] as List? ?? [];
                  final readCount = readBy.length;

                  return Card(
                    margin: EdgeInsets.only(bottom: spacing),
                    elevation: isActive ? 2 : 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isActive ? Colors.transparent : Colors.grey.shade200,
                        width: 1,
                      ),
                    ),
                    child: ListTile(
                      leading: Container(
                        width: 4,
                        height: 50,
                        decoration: BoxDecoration(
                          color: isActive ? color : Colors.grey,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      title: Text(
                        data['title'] ?? 'Untitled',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: fontSize,
                          decoration: isActive ? null : TextDecoration.lineThrough,
                          color: isActive ? Colors.black87 : Colors.grey.shade500,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: spacing / 2),
                          Text(
                            data['message'] ?? 'No message',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: fontSize,
                              color: isActive ? Colors.grey.shade700 : Colors.grey.shade400,
                            ),
                          ),
                          SizedBox(height: spacing * 0.8),
                          Wrap(
                            spacing: spacing / 2,
                            runSpacing: spacing / 2,
                            children: [
                              _buildChip(
                                context,
                                severity.toUpperCase(),
                                color.withOpacity(0.15),
                                color,
                              ),
                              _buildChip(
                                context,
                                'Audience: ${data['targetAudience'] ?? 'all'}',
                                Colors.grey.shade200,
                                Colors.grey.shade700,
                              ),
                              if (data['expiresAt'] != null)
                                _buildChip(
                                  context,
                                  'Expires: ${_formatDate(data['expiresAt'])}',
                                  Colors.orange.shade50,
                                  Colors.orange.shade700,
                                ),
                              _buildChip(
                                context,
                                isActive ? 'Active' : 'Inactive',
                                isActive ? Colors.green.shade50 : Colors.red.shade50,
                                isActive ? Colors.green.shade700 : Colors.red.shade700,
                              ),
                              _buildChip(
                                context,
                                'Read: $readCount',
                                Colors.blue.shade50,
                                Colors.blue.shade700,
                              ),
                            ],
                          ),
                        ],
                      ),
                      trailing: PopupMenuButton(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'toggle',
                            child: Row(
                              children: [
                                Icon(
                                  isActive ? Icons.pause : Icons.play_arrow,
                                  color: isActive ? Colors.orange : Colors.green,
                                  size: Responsive.iconSize(context, 20),
                                ),
                                SizedBox(width: spacing),
                                Text(
                                  isActive ? 'Deactivate' : 'Activate',
                                  style: TextStyle(
                                    fontSize: fontSize,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                const Icon(Icons.delete, size: 20, color: Colors.red),
                                SizedBox(width: spacing),
                                Text(
                                  'Delete',
                                  style: TextStyle(
                                    fontSize: fontSize,
                                    color: Colors.red,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        onSelected: (value) async {
                          if (value == 'toggle') {
                            await WarningService.updateWarning(
                              warningId: doc.id,
                              isActive: !isActive,
                            );
                            _showSnackBar(
                              isActive ? 'Warning deactivated' : 'Warning activated',
                              Colors.green,
                            );
                          } else if (value == 'delete') {
                            await _confirmDelete(doc.id);
                          }
                        },
                      ),
                      isThreeLine: true,
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildChip(BuildContext context, String label, Color bgColor, Color textColor) {
    final double fontSize = Responsive.fontSize(context, AppFonts.md);
    
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.spacing(context),
        vertical: Responsive.spacing(context) * 0.6,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: textColor.withOpacity(0.2),
          width: 0.5,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: fontSize * 0.7,
          color: textColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Future<void> _confirmDelete(String warningId) async {
    final bool isMobile = Responsive.isMobile(context);
    final double fontSize = Responsive.fontSize(context, AppFonts.md);
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Delete Warning',
          style: TextStyle(
            fontSize: isMobile ? fontSize + 2 : fontSize + 4,
            fontWeight: FontWeight.bold,
            color: Colors.red.shade700,
          ),
        ),
        content: Text(
          'Are you sure you want to delete this warning? This action cannot be undone.',
          style: TextStyle(
            fontSize: fontSize,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: Text(
              'Delete',
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await WarningService.deleteWarning(warningId);
        _showSnackBar('Warning deleted successfully', Colors.green);
      } catch (e) {
        _showSnackBar('Error: $e', Colors.red);
      }
    }
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
      return DateFormat('dd MMM yyyy').format(date);
    }
    return 'N/A';
  }
}