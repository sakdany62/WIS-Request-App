// lib/screens/admin/terms_management_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/terms_service.dart';
import '../../services/notification_service.dart'; 
import '../../app_fonts.dart';
import '../../utils/responsive.dart';
import 'terms_read_tracking_screen.dart';

class TermsManagementScreen extends StatefulWidget {
  const TermsManagementScreen({super.key});

  @override
  State<TermsManagementScreen> createState() => _TermsManagementScreenState();
}

class _TermsManagementScreenState extends State<TermsManagementScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _sectionTitleController = TextEditingController();
  final TextEditingController _sectionContentController = TextEditingController();
  
  List<Map<String, String>> _sections = [];
  bool _isLoading = true;
  bool _isSaving = false;
  String _termsId = '';

  @override
  void initState() {
    super.initState();
    _loadCurrentTerms();
  }

  Future<void> _loadCurrentTerms() async {
    setState(() => _isLoading = true);
    try {
      // Clear old data first
      _sections = [];
      _termsId = '';
      _titleController.clear();
      
      final terms = await TermsService.getCurrentTerms();
      if (terms != null) {
        // Convert sections from List<Map<String, dynamic>> to List<Map<String, String>>
        List<Map<String, String>> convertedSections = [];
        final sectionsData = terms['sections'] as List? ?? [];
        for (var section in sectionsData) {
          if (section is Map<String, dynamic>) {
            convertedSections.add({
              'title': section['title']?.toString() ?? '',
              'content': section['content']?.toString() ?? '',
            });
          }
        }
        
        setState(() {
          _titleController.text = terms['title']?.toString() ?? '';
          _sections = convertedSections;
          _termsId = terms['id']?.toString() ?? '';
          _isLoading = false;
        });
        print(' Loaded terms: ${terms['title']} (ID: ${terms['id']})');
      } else {
        setState(() => _isLoading = false);
        print('ℹ️ No terms found');
      }
    } catch (e) {
      print('❌ Error loading terms: $e');
      setState(() => _isLoading = false);
    }
  }

  void _addSection() {
    final title = _sectionTitleController.text.trim();
    final content = _sectionContentController.text.trim();
    
    if (title.isEmpty || content.isEmpty) {
      _showSnackBar('Please enter both section title and content', Colors.red);
      return;
    }

    setState(() {
      _sections.add({
        'title': title,
        'content': content,
      });
      _sectionTitleController.clear();
      _sectionContentController.clear();
    });
  }

  void _removeSection(int index) {
    setState(() {
      _sections.removeAt(index);
    });
  }

  void _editSection(int index) {
    final section = _sections[index];
    _sectionTitleController.text = section['title'] ?? '';
    _sectionContentController.text = section['content'] ?? '';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Section'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _sectionTitleController,
              decoration: const InputDecoration(
                labelText: 'Section Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _sectionContentController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Section Content',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final newTitle = _sectionTitleController.text.trim();
              final newContent = _sectionContentController.text.trim();
              if (newTitle.isNotEmpty && newContent.isNotEmpty) {
                setState(() {
                  _sections[index] = {
                    'title': newTitle,
                    'content': newContent,
                  };
                });
                Navigator.pop(context);
                _sectionTitleController.clear();
                _sectionContentController.clear();
                _showSnackBar('Section updated successfully', Colors.green);
              } else {
                _showSnackBar('Please fill in both fields', Colors.red);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveTerms() async {
    final title = _titleController.text.trim();
    
    if (title.isEmpty) {
      _showSnackBar('Please enter a title', Colors.red);
      return;
    }
    if (_sections.isEmpty) {
      _showSnackBar('Please add at least one section', Colors.red);
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Generate content from sections
      String content = '';
      for (var section in _sections) {
        content += '${section['title']}\n${section['content']}\n\n';
      }

      final now = DateFormat('dd MMM yyyy').format(DateTime.now());
      String notificationTitle = '';
      String notificationBody = '';
      String? termsId;
      
      if (_termsId.isNotEmpty) {
        // Update existing terms
        await TermsService.updateTerms(
          termsId: _termsId,
          title: title,
          content: content,
          sections: _sections,
          lastUpdated: now,
        );
        termsId = _termsId;
        notificationTitle = ' Terms & Conditions Updated';
        notificationBody = 'Admin has updated the Terms & Conditions. Please review the changes.';
        _showSnackBar(' Terms & Conditions updated successfully!', Colors.green);
      } else {
        // Create new terms
        await TermsService.createTerms(
          title: title,
          content: content,
          sections: _sections,
          version: '1.0.0',
          lastUpdated: now,
        );
        notificationTitle = ' New Terms & Conditions Available';
        notificationBody = 'Admin has published new Terms & Conditions. Please read and confirm.';
        _showSnackBar('Terms & Conditions created successfully!', Colors.green);
      }
      
      // ✅ Get the current terms ID after save
      final currentTerms = await TermsService.getCurrentTerms();
      if (currentTerms != null) {
        termsId = currentTerms['id'];
      }
      
      // ✅ Send notification to all staff
      if (termsId != null) {
        await NotificationService.sendNotificationToAllStaff(
          title: notificationTitle,
          body: notificationBody,
          type: 'terms_update',
          termsId: termsId,
          additionalData: {
            'title': title,
            'lastUpdated': now,
            'version': currentTerms?['version'] ?? '1.0.0',
          },
        );
        _showSnackBar('📨 Notifications sent to all staff!', Colors.blue);
      }
      
      // Force refresh data from server (clear cache)
      await TermsService.clearCache();
      
      // Load current terms again
      await _loadCurrentTerms();
      
      setState(() => _isSaving = false);
    } catch (e) {
      _showSnackBar('Error: $e', Colors.red);
      setState(() => _isSaving = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(fontSize: AppFonts.md)),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = Responsive.isMobile(context);
    final double fontSize = Responsive.fontSize(context, 14);
    final double spacing = Responsive.spacing(context);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            'Terms & Conditions Management',
            style: TextStyle(
              fontSize: AppFonts.md,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: const Color(0xFF173B69),
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: CircularProgressIndicator(
            color: Color(0xFF173B69),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Terms & Conditions Management',
          style: TextStyle(
            fontSize: AppFonts.md,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF173B69),
        foregroundColor: Colors.white,
        actions: [
          // View Read Status Button
          if (_termsId.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.people_alt, color: Colors.white),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TermsReadTrackingScreen(
                      termsId: _termsId,
                      termsTitle: _titleController.text.trim().isNotEmpty 
                          ? _titleController.text.trim() 
                          : 'Terms & Conditions',
                    ),
                  ),
                );
              },
              tooltip: 'View Staff Read Status',
            ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadCurrentTerms,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Text(
              'Edit Terms & Conditions',
              style: TextStyle(
                fontSize: isMobile ? fontSize + 4 : AppFonts.md + 4,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF173B69),
              ),
            ),
            SizedBox(height: spacing * 2),

            // Title Field
            Text(
              'Title *',
              style: TextStyle(
                fontSize: isMobile ? fontSize : AppFonts.md,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: spacing),
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                hintText: 'e.g., Terms & Conditions',
                hintStyle: TextStyle(fontSize: isMobile ? fontSize : AppFonts.md),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF173B69), width: 2),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              style: TextStyle(fontSize: isMobile ? fontSize : AppFonts.md),
            ),
            SizedBox(height: spacing * 2),

            // Sections Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Sections (${_sections.length})',
                  style: TextStyle(
                    fontSize: isMobile ? fontSize + 2 : AppFonts.md + 2,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF173B69),
                  ),
                ),
                Text(
                  'Minimum: 1 section required',
                  style: TextStyle(
                    fontSize: isMobile ? fontSize * 0.8 : AppFonts.md * 0.8,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            SizedBox(height: spacing),

            // Add Section Form
            Container(
              padding: EdgeInsets.all(isMobile ? 12 : 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                children: [
                  TextField(
                    controller: _sectionTitleController,
                    decoration: InputDecoration(
                      hintText: 'Section Title (e.g., 1. Privacy Policy)',
                      hintStyle: TextStyle(fontSize: isMobile ? fontSize : AppFonts.md),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 12 : 16,
                        vertical: isMobile ? 10 : 14,
                      ),
                    ),
                    style: TextStyle(fontSize: isMobile ? fontSize : AppFonts.md),
                  ),
                  SizedBox(height: spacing),
                  TextField(
                    controller: _sectionContentController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Section Content',
                      hintStyle: TextStyle(fontSize: isMobile ? fontSize : AppFonts.md),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 12 : 16,
                        vertical: isMobile ? 10 : 14,
                      ),
                    ),
                    style: TextStyle(fontSize: isMobile ? fontSize : AppFonts.md),
                  ),
                  SizedBox(height: spacing),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _addSection,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF173B69),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          icon: const Icon(Icons.add, size: 20),
                          label: Text(
                            'Add Section',
                            style: TextStyle(fontSize: isMobile ? fontSize : AppFonts.md),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: spacing * 2),

            // Sections List
            if (_sections.isNotEmpty)
              Column(
                children: _sections.asMap().entries.map((entry) {
                  final index = entry.key;
                  final section = entry.value;
                  return Card(
                    margin: EdgeInsets.only(bottom: spacing),
                    child: ListTile(
                      title: Text(
                        section['title']!,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: isMobile ? fontSize : AppFonts.md,
                        ),
                      ),
                      subtitle: Text(
                        section['content']!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: isMobile ? fontSize : AppFonts.md),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () => _editSection(index),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _removeSection(index),
                          ),
                        ],
                      ),
                      isThreeLine: true,
                    ),
                  );
                }).toList(),
              ),

            SizedBox(height: spacing * 3),

            // Save Button
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveTerms,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF173B69),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.save, size: 22),
                          SizedBox(width: spacing),
                          Text(
                            _termsId.isNotEmpty ? 'Update Terms & Conditions' : 'Save Terms & Conditions',
                            style: TextStyle(
                              fontSize: isMobile ? fontSize : AppFonts.md,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            SizedBox(height: spacing * 2),

            // Preview Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton(
                onPressed: () {
                  // Preview terms before saving
                  if (_titleController.text.trim().isEmpty) {
                    _showSnackBar('Please enter a title first', Colors.orange);
                    return;
                  }
                  if (_sections.isEmpty) {
                    _showSnackBar('Please add at least one section', Colors.orange);
                    return;
                  }
                  _showPreviewDialog();
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF173B69),
                  side: const BorderSide(color: Color(0xFF173B69)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Preview Terms',
                  style: TextStyle(
                    fontSize: isMobile ? fontSize : AppFonts.md,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            SizedBox(height: spacing * 2),
          ],
        ),
      ),
    );
  }

  void _showPreviewDialog() {
    final title = _titleController.text.trim();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: _sections.map((section) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      section['title'] ?? '',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      section['content'] ?? '',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}