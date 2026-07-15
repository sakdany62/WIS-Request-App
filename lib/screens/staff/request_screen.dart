import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../services/request_service.dart';
import '../../services/telegram_service.dart';
import 'package:permission_system/app_fonts.dart';
import 'staff_home_screen.dart';

class RequestScreen extends StatefulWidget {
  const RequestScreen({super.key});

  @override
  State<RequestScreen> createState() => _RequestScreenState();
}

class _RequestScreenState extends State<RequestScreen> {
  String selectedReason = 'Sick';
  final TextEditingController otherController = TextEditingController();
  DateTime? startDate;
  DateTime? endDate;
  int totalDays = 0;
  bool _isSubmitting = false;
  final RequestService _requestService = RequestService();

  File? _selectedImage;
  String? _imageName;

  String _staffName = '';
  String _staffPosition = '';
  String _managerName = '';
  String _managerId = '';

  OverlayEntry? _overlayEntry;

  // ⏰ Submit time variables
  DateTime? _submitTime;
  String _submitTimeString = '';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .where('userId', isEqualTo: user.uid)
          .get();

      if (doc.docs.isNotEmpty) {
        final data = doc.docs.first.data() as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            _staffName = data['fullName'] ?? data['name'] ?? user.displayName ?? user.email ?? 'Staff';
            _staffPosition = data['position'] ?? data['department'] ?? 'Employee';
            _managerName = data['managerName'] ?? 'Manager';
            _managerId = data['managerId'] ?? '';
          });
        }
        print('👤 Staff: $_staffName, Position: $_staffPosition');
        print('👤 Manager: $_managerName');
      }
    } catch (e) {
      print('❌ Error loading user data: $e');
    }
  }

  String formatDate(DateTime? date) {
    if (date == null) return "Select Date";
    return DateFormat('dd MMM yyyy').format(date);
  }

  // ⏰ មុខងារបំប្លែងពេលវេលាទៅជា AM/PM (ម៉ោងកម្ពុជា UTC+7)
  String _formatTimeWithAMPM(DateTime time) {
    final cambodiaTime = time;
    
    int hour = cambodiaTime.hour;
    final int minute = cambodiaTime.minute;
    final String period = hour >= 12 ? 'PM' : 'AM';
    
    if (hour == 0) {
      hour = 12;
    } else if (hour > 12) {
      hour = hour - 12;
    }
    
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
  }

  // ⏰ មុខងារយកពេលបច្ចុប្បន្នតាមម៉ោងកម្ពុជា
  DateTime _getCurrentCambodiaTime() {
    return DateTime.now().toUtc().add(const Duration(hours: 7));
  }

  Future<void> pickStartDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
    );

    if (picked != null) {
      setState(() {
        startDate = picked;
        endDate = picked;
        totalDays = 1;
      });
    }
  }

  Future<void> pickEndDate() async {
    _showError('Request can only be for 1 day');
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );

      if (image != null) {
        final file = File(image.path);
        final fileName = image.name;

        setState(() {
          _selectedImage = file;
          _imageName = fileName;
        });

        _showSuccess('✅ Image selected: $fileName');
      }
    } catch (e) {
      print('❌ Error picking image: $e');
      _showError('Failed to pick image: $e');
    }
  }

  void _removeImage() {
    setState(() {
      _selectedImage = null;
      _imageName = null;
    });
    _showSuccess('Image removed');
  }

  Future<void> _submitRequest() async {
    if (startDate == null) {
      _showError('Please select a start date');
      return;
    }
    if (endDate == null) {
      _showError('Please select an end date');
      return;
    }
    if (totalDays <= 0) {
      _showError('Invalid date range');
      return;
    }
    if (totalDays > 1) {
      _showError('Request can only be for 1 day');
      return;
    }

    // ⏰ កត់ត្រាពេលចុច Submit (ម៉ោងកម្ពុជា UTC+7)
    final now = _getCurrentCambodiaTime();
    _submitTime = now;
    _submitTimeString = _formatTimeWithAMPM(now);

    setState(() {
      _isSubmitting = true;
    });

    try {
      String reasonToSend = selectedReason;
      String otherReasonToSend = '';
      
      if (selectedReason == 'Other') {
        otherReasonToSend = otherController.text.trim();
        if (otherReasonToSend.isEmpty) {
          _showError('Please specify a reason');
          setState(() {
            _isSubmitting = false;
          });
          return;
        }
        reasonToSend = 'Other';
      }

      String? imageUrl;
      
      final result = await _requestService.submitRequestWithAutoApprove(
        startDate: formatDate(startDate),
        endDate: formatDate(endDate),
        totalDays: totalDays,
        reason: reasonToSend,
        otherReason: otherReasonToSend,
        fileUrl: null,
        imageUrl: imageUrl,
        submitTime: _submitTime,
      );

      await _sendTelegramNotification(
        requestId: result['requestId'] ?? 'N/A',
        status: result['status'] ?? 'pending',
      );

      if (mounted) {
        final status = result['status'];
        final message = result['message'];

        final timeDisplay = _submitTimeString.isNotEmpty 
            ? '\nSubmitted at: $_submitTimeString' 
            : '';

        if (status == 'approved') {
          _showSuccess('Request automatically approved!$timeDisplay');
        } else if (message?.contains('contact') == true) {
          _showWarning('${message ?? 'You must contact your manager directly'}$timeDisplay');
        } else {
          _showWarning('${message ?? 'Request is pending manager approval'}$timeDisplay');
        }

        if (mounted) {
          setState(() {
            startDate = null;
            endDate = null;
            totalDays = 0;
            selectedReason = 'Sick';
            otherController.clear();
            _selectedImage = null;
            _imageName = null;
            _isSubmitting = false;
            _submitTime = null;
            _submitTimeString = '';
          });
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            // StaffHomeScreenStateManager.refreshData();
          }
        });
      }
    } on FirebaseException catch (e) {
      print('❌ Firebase Error: ${e.code} - ${e.message}');
      if (mounted) {
        if (e.code == 'permission-denied') {
          _showError(
              'You do not have permission to submit requests. Please contact Admin');
        } else {
          _showError('System error: ${e.message}');
        }
        setState(() {
          _isSubmitting = false;
        });
      }
    } catch (e) {
      print('❌ Submit error: $e');
      if (mounted) {
        _showError('Error: ${e.toString().replaceFirst('Exception: ', '')}');
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _sendTelegramNotification({
    required String requestId,
    required String status,
  }) async {
    try {
      String reasonText = selectedReason;
      if (selectedReason == 'Other') {
        reasonText = otherController.text.trim();
      }

      final details = {
        'reason': reasonText,
        'startDate': formatDate(startDate),
        'endDate': formatDate(endDate),
        'duration': totalDays,
        'submitTime': _submitTimeString,
      };

      final message = TelegramService.formatPermissionRequestWithInfo(
        staffName: _staffName.isNotEmpty ? _staffName : 'Staff',
        staffPosition: _staffPosition.isNotEmpty ? _staffPosition : 'Employee',
        permissionType: selectedReason,
        details: details,
        requestId: requestId,
        status: status,
      );

      final bool sent = await TelegramService.sendToAll(message);

      if (sent) {
        print('✅ Telegram notification sent successfully');
      } else {
        print('⚠️ Failed to send Telegram notification');
      }
    } catch (e) {
      print('⚠️ Telegram error (non-critical): $e');
    }
  }

  String _mapReasonToType(String reason) {
    final Map<String, String> mapping = {
      'Sick': 'sick',
      'Personal issue': 'personal',
      'Vacation': 'leave',
      'Emergency': 'emergency',
      'Other': 'other',
    };
    return mapping[reason] ?? 'other';
  }

  void _showError(String message) {
    _showOverlayMessage(message, Colors.red, Icons.error_outline);
  }

  void _showSuccess(String message) {
    _showOverlayMessage(message, Colors.green, Icons.check_circle_outline);
  }

  void _showWarning(String message) {
    _showOverlayMessage(message, Colors.orange, Icons.warning_amber_rounded);
  }

  void _showOverlayMessage(String message, Color backgroundColor, IconData icon) {
    _hideOverlayMessage();

    if (!mounted) return;

    final overlay = Overlay.of(context);
    if (overlay == null) return;

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 10,
        left: 20,
        right: 20,
        child: Material(
          color: Colors.transparent,
          child: GestureDetector(
            onTap: _hideOverlayMessage,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    icon,
                    color: Colors.white,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      message,
                      style: TextStyle(
                        fontSize: AppFonts.md,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _hideOverlayMessage,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(_overlayEntry!);

    Future.delayed(const Duration(seconds: 4), () {
      _hideOverlayMessage();
    });
  }

  void _hideOverlayMessage() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  void dispose() {
    _hideOverlayMessage();
    otherController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color primary = Color(0xFF1A3B68);
    
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 16, top: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.assignment_outlined,
                    color: primary,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    "Leave Request",
                    style: TextStyle(
                      color: primary,
                      fontWeight: FontWeight.bold,
                      fontSize: AppFonts.md + 5,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 24),

            // ============ CARD 1: SELECT DATE ============
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Select Date",
                      style: TextStyle(
                        fontSize: AppFonts.md,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    GestureDetector(
                      onTap: pickStartDate,
                      child: _box(formatDate(startDate)),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today, color: Colors.green),
                          const SizedBox(width: 8),
                          Text(
                            "Total Days: 1 day",
                            style: TextStyle(
                              fontSize: AppFonts.md,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ============ CARD 2: DOCUMENT REFERENCE ============
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Document Reference (Optional)",
                      style: TextStyle(
                        fontSize: AppFonts.md,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _pickImage,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: _selectedImage != null ? Colors.green : Colors.grey.shade300,
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            color: _selectedImage != null ? Colors.green.shade50 : Colors.white,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.image,
                                color: _selectedImage != null ? Colors.green : Colors.grey.shade600,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _selectedImage != null 
                                      ? _imageName ?? 'Image selected' 
                                      : 'Select Image',
                                  style: TextStyle(
                                    fontSize: AppFonts.md,
                                    color: _selectedImage != null ? Colors.black : Colors.grey.shade600,
                                    fontWeight: _selectedImage != null ? FontWeight.w500 : FontWeight.normal,
                                  ),
                                ),
                              ),
                              if (_selectedImage != null)
                                IconButton(
                                  icon: const Icon(Icons.close, color: Colors.red),
                                  onPressed: _removeImage,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  iconSize: 20,
                                )
                              else
                                Icon(
                                  Icons.arrow_forward_ios,
                                  size: 16,
                                  color: Colors.grey.shade400,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ============ CARD 3: REASON FOR LEAVE ============
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Reason for Leave",
                      style: TextStyle(
                        fontSize: AppFonts.md,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildRadio("Sick"),
                    _buildRadio("Personal issue"),
                    _buildRadio("Vacation"),
                    _buildRadio("Emergency"),
                    _buildRadio("Other"),
                    const SizedBox(height: 10),
                    
                    // ✅ បង្ហាញ TextField តែពេលជ្រើសរើស "Other" ប៉ុណ្ណោះ (មាន border)
                    Visibility(
                      visible: selectedReason == "Other",
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Please specify your reason:",
                            style: TextStyle(
                              fontSize: AppFonts.md,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Colors.blue.shade400,
                                width: 1.5,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: TextField(
                              controller: otherController,
                              style: TextStyle(fontSize: AppFonts.md),
                              decoration: InputDecoration(
                                hintText: "Enter other reason...",
                                hintStyle: TextStyle(fontSize: AppFonts.md),
                                border: InputBorder.none,
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                              ),
                              maxLines: 3,
                              autofocus: false,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 30),

            // ============ SUBMIT BUTTON ============
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitRequest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSubmitting
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
                          const Icon(Icons.send, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            "Submit Request",
                            style: TextStyle(fontSize: AppFonts.md),
                          ),
                        ],
                      ),
              ),
            ),
            
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  // ============ HELPER WIDGETS ============
  
  Widget _box(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.blue.shade200),
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
      ),
      child: Row(
        children: [
          Icon(
            text == "Select Date" ? Icons.calendar_today : Icons.check_circle,
            size: 18,
            color: text == "Select Date" ? Colors.grey : Colors.green,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: AppFonts.md,
              color: text == "Select Date" ? Colors.grey : Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRadio(String title) {
    return InkWell(
      onTap: () {
        setState(() {
          selectedReason = title;
          if (title != "Other") {
            otherController.clear();
          }
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Radio<String>(
              value: title,
              groupValue: selectedReason,
              onChanged: (value) {
                setState(() {
                  selectedReason = value!;
                  if (value != "Other") {
                    otherController.clear();
                  }
                });
              },
              activeColor: const Color(0xFF1A3B68),
            ),
            Text(
              title,
              style: TextStyle(fontSize: AppFonts.md),
            ),
          ],
        ),
      ),
    );
  }
}