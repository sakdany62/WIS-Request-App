// lib/screens/staff/request_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/request_service.dart';
import '../../services/telegram_service.dart';
import '../../services/manager_telegram_service.dart';
import '../../services/policy_service.dart';
import 'package:permission_system/app_fonts.dart';
import '../../utils/responsive.dart';

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
  final PolicyService _policyService = PolicyService();

  File? _selectedImage;
  String? _imageName;

  String _staffName = '';
  String _staffPosition = '';
  String _staffDepartment = '';
  String _staffDepartmentId = '';
  String _staffEmail = '';
  String _managerName = '';
  String _managerId = '';

  OverlayEntry? _overlayEntry;

  DateTime? _submitTime;
  String _submitTimeString = '';

  List<String> _allowedReasons = ['Sick', 'Personal issue', 'Vacation', 'Emergency', 'Other'];
  bool _isLoadingReasons = true;
  StreamSubscription<List<String>>? _reasonsSubscription;

  static const Color appBarColor = Color(0xFF1A3B68);

  String _getDepartmentId(String deptName) {
    if (deptName.contains('IT')) return 'dept_it';
    if (deptName.contains('Education')) return 'dept_education';
    if (deptName.contains('Administration')) return 'dept_administration';
    if (deptName.contains('Service')) return 'dept_service';
    return 'dept_unknown';
  }

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _listenToPolicyChanges();
  }

  void _listenToPolicyChanges() {
    _reasonsSubscription = _policyService.streamAllowedReasons().listen(
      (reasons) {
        if (mounted) {
          setState(() {
            _allowedReasons = reasons;
            if (_allowedReasons.isNotEmpty && !_allowedReasons.contains(selectedReason)) {
              selectedReason = _allowedReasons.first;
            } else if (_allowedReasons.isEmpty) {
              selectedReason = 'Sick';
            }
            _isLoadingReasons = false;
          });
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() {
            _isLoadingReasons = false;
          });
        }
      },
    );
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      QuerySnapshot? querySnapshot;
      
      try {
        querySnapshot = await FirebaseFirestore.instance
            .collection('users')
            .where('userId', isEqualTo: user.uid)
            .get();
      } catch (e) {
        // ignore
      }
      
      if (querySnapshot == null || querySnapshot.docs.isEmpty) {
        if (user.email != null && user.email!.isNotEmpty) {
          querySnapshot = await FirebaseFirestore.instance
              .collection('users')
              .where('email', isEqualTo: user.email)
              .get();
        }
      }

      if (querySnapshot != null && querySnapshot.docs.isNotEmpty) {
        final data = querySnapshot.docs.first.data() as Map<String, dynamic>;
        
        String name = data['fullName'] ?? data['name'] ?? data['displayName'] ?? data['username'] ?? user.displayName ?? user.email ?? 'Staff';
        String position = data['position'] ?? data['jobTitle'] ?? data['role'] ?? 'Employee';
        String department = data['department'] ?? data['dept'] ?? data['division'] ?? 'N/A';
        String email = data['email'] ?? user.email ?? '';
        String departmentId = data['departmentId'] ?? data['deptId'] ?? _getDepartmentId(department);
        
        if (mounted) {
          setState(() {
            _staffName = name;
            _staffPosition = position;
            _staffDepartment = department;
            _staffDepartmentId = departmentId;
            _staffEmail = email;
            _managerName = data['managerName'] ?? data['supervisor'] ?? 'Manager';
            _managerId = data['managerId'] ?? data['supervisorId'] ?? '';
          });
        }
      } else {
        String name = user.displayName ?? (user.email != null ? user.email!.split('@').first : 'Staff');
        
        if (mounted) {
          setState(() {
            _staffName = name;
            _staffPosition = 'Employee';
            _staffDepartment = 'N/A';
            _staffDepartmentId = 'dept_unknown';
            _staffEmail = user.email ?? '';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _staffName = user.displayName ?? (user.email != null ? user.email!.split('@').first : 'Staff');
          _staffPosition = 'Employee';
          _staffDepartment = 'N/A';
          _staffDepartmentId = 'dept_unknown';
          _staffEmail = user.email ?? '';
        });
      }
    }
  }

  String formatDate(DateTime? date) {
    if (date == null) return "Select Date";
    return DateFormat('dd MMM yyyy').format(date);
  }

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

        _showSuccess('Image selected: $fileName');
      }
    } catch (e) {
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

    final now = _getCurrentCambodiaTime();
    _submitTime = now;
    _submitTimeString = _formatTimeWithAMPM(now);

    final String selectedReasonAtSubmit = selectedReason;
    final String otherReasonAtSubmit = otherController.text.trim();

    if (mounted) {
      setState(() {
        _isSubmitting = true;
      });
    }

    try {
      String reasonToSend = selectedReasonAtSubmit;
      String otherReasonToSend = '';
      
      if (selectedReasonAtSubmit == 'Other') {
        otherReasonToSend = otherReasonAtSubmit;
        if (otherReasonToSend.isEmpty) {
          _showError('Please specify a reason');
          if (mounted) {
            setState(() {
              _isSubmitting = false;
            });
          }
          return;
        }
        reasonToSend = 'Other';
      }

      final String reasonTextForNotification = selectedReasonAtSubmit == 'Other' 
          ? otherReasonAtSubmit 
          : selectedReasonAtSubmit;

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
        department: _staffDepartment,
        departmentId: _staffDepartmentId,
        userName: _staffName,
        userEmail: _staffEmail.isNotEmpty ? _staffEmail : FirebaseAuth.instance.currentUser?.email ?? '',
      );

      await _sendTelegramNotification(
        requestId: result['requestId'] ?? 'N/A',
        status: result['status'] ?? 'pending',
        reasonText: reasonTextForNotification,
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
            selectedReason = _allowedReasons.isNotEmpty ? _allowedReasons.first : 'Sick';
            otherController.clear();
            _selectedImage = null;
            _imageName = null;
            _isSubmitting = false;
            _submitTime = null;
            _submitTimeString = '';
          });
        }
      }
    } on FirebaseException catch (e) {
      if (mounted) {
        if (e.code == 'permission-denied') {
          _showError('You do not have permission to submit requests. Please contact Admin');
        } else {
          _showError('System error: ${e.message}');
        }
        setState(() {
          _isSubmitting = false;
        });
      }
    } catch (e) {
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
    required String reasonText,
  }) async {
    try {
      final details = {
        'reason': reasonText,
        'startDate': formatDate(startDate),
        'endDate': formatDate(endDate),
        'duration': totalDays,
        'submitTime': _submitTimeString,
      };

      final String displayName = _staffName.isNotEmpty && !_staffName.contains('@')
          ? _staffName
          : (FirebaseAuth.instance.currentUser?.displayName ?? 
             FirebaseAuth.instance.currentUser?.email?.split('@').first ?? 
             'Staff');

      final bool isViewing = await _checkViewMode();
      final bool isManager = await _checkIsManager();
      
      if (isViewing && isManager) {
        final String message = await ManagerTelegramService.formatManagerViewRequest(
          staffName: displayName,
          staffDepartment: _staffDepartment.isNotEmpty ? _staffDepartment : 'N/A',
          permissionType: reasonText,
          details: details,
          requestId: requestId,
          status: status,
        );
        
        if (message.isNotEmpty) {
          await ManagerTelegramService.sendToAll(message);
        }
      } else {
        final String message = await TelegramService.formatPermissionRequestWithInfo(
          staffName: displayName,
          staffPosition: _staffPosition.isNotEmpty ? _staffPosition : 'Employee',
          staffDepartment: _staffDepartment.isNotEmpty ? _staffDepartment : 'N/A',
          permissionType: reasonText,
          details: details,
          requestId: requestId,
          status: status,
        );
        
        await TelegramService.sendToAll(message);
      }
    } catch (e) {
      // ignore
    }
  }

  Future<bool> _checkViewMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('view_as_staff') ?? false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _checkIsManager() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('userId', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final data = querySnapshot.docs.first.data();
        final roleId = data['roleId']?.toString() ?? '';
        return roleId == '3';
      }
      return false;
    } catch (e) {
      return false;
    }
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
                  Icon(icon, color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      message,
                      style: TextStyle(
                        fontSize: Responsive.fontSize(context, AppFonts.md),
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
                      child: const Icon(Icons.close, color: Colors.white, size: 18),
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
    _reasonsSubscription?.cancel();
    _hideOverlayMessage();
    otherController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = Responsive.isMobile(context);
    final double fontSize = Responsive.fontSize(context, 14);
    final double spacing = Responsive.spacing(context);
    final double iconSize = Responsive.iconSize(context, 40);
    final EdgeInsets padding = Responsive.padding(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                vertical: isMobile ? 14 : 20,
                horizontal: isMobile ? 12 : 24,
              ),
              decoration: const BoxDecoration(
                color: Color(0xFF1A3B68),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(height: isMobile ? 4 : 8),
                  Icon(
                    Icons.assignment_outlined,
                    color: Colors.white.withOpacity(0.9),
                    size: isMobile ? iconSize * 0.8 : iconSize,
                  ),
                  SizedBox(height: isMobile ? 4 : 8),
                  Text(
                    "Leave Request",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: isMobile ? fontSize + 2 : fontSize + 6,
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: padding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(spacing * 2),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Select Date",
                              style: TextStyle(
                                fontSize: Responsive.fontSize(context, AppFonts.md),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: spacing * 2),
                            
                            GestureDetector(
                              onTap: pickStartDate,
                              child: _buildDateBox(context, formatDate(startDate), spacing),
                            ),
                            SizedBox(height: spacing * 1.5),
                            Container(
                              padding: EdgeInsets.all(spacing * 1.5),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.calendar_today, color: Colors.green, size: Responsive.iconSize(context, 20)),
                                  SizedBox(width: spacing),
                                  Text(
                                    "Total Days: 1 day",
                                    style: TextStyle(
                                      fontSize: Responsive.fontSize(context, AppFonts.md),
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
                    SizedBox(height: spacing * 2.5),

                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(spacing * 2),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Document Reference (Optional)",
                              style: TextStyle(
                                fontSize: Responsive.fontSize(context, AppFonts.md),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: spacing * 1.5),
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: _pickImage,
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: EdgeInsets.symmetric(horizontal: spacing * 2, vertical: spacing * 1.5),
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
                                        size: Responsive.iconSize(context, 24),
                                      ),
                                      SizedBox(width: spacing * 1.5),
                                      Expanded(
                                        child: Text(
                                          _selectedImage != null 
                                              ? _imageName ?? 'Image selected' 
                                              : 'Select Image',
                                          style: TextStyle(
                                            fontSize: Responsive.fontSize(context, AppFonts.md),
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
                                          size: Responsive.iconSize(context, 16),
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
                    SizedBox(height: spacing * 2.5),

                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(spacing * 2),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Reason for Leave",
                              style: TextStyle(
                                fontSize: Responsive.fontSize(context, AppFonts.md),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: spacing),
                            
                            _isLoadingReasons
                                ? Padding(
                                    padding: EdgeInsets.symmetric(vertical: spacing * 2),
                                    child: const Center(
                                      child: SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      ),
                                    ),
                                  )
                                : Column(
                                    children: [
                                      ..._allowedReasons.map((reason) => 
                                        _buildRadio(context, reason, spacing)
                                      ).toList(),
                                    ],
                                  ),
                            
                            SizedBox(height: spacing * 1.5),
                            
                            Visibility(
                              visible: selectedReason == "Other",
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Please specify your reason:",
                                    style: TextStyle(
                                      fontSize: Responsive.fontSize(context, AppFonts.md),
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  SizedBox(height: spacing),
                                  Container(
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.blue.shade400, width: 1.5),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: TextField(
                                      controller: otherController,
                                      style: TextStyle(fontSize: Responsive.fontSize(context, AppFonts.md)),
                                      decoration: InputDecoration(
                                        hintText: "Enter other reason...",
                                        hintStyle: TextStyle(fontSize: Responsive.fontSize(context, AppFonts.md)),
                                        border: InputBorder.none,
                                        filled: true,
                                        fillColor: Colors.white,
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: spacing * 2,
                                          vertical: spacing * 1.8,
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
                    
                    SizedBox(height: spacing * 4),

                    SizedBox(
                      width: double.infinity,
                      height: Responsive.buttonHeight(context),
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submitRequest,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: appBarColor,
                          foregroundColor: Colors.white,
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isSubmitting
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
                                  Icon(Icons.send, size: Responsive.iconSize(context, 20)),
                                  SizedBox(width: spacing),
                                  Text(
                                    "Submit Request",
                                    style: TextStyle(fontSize: Responsive.fontSize(context, AppFonts.md)),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    
                    SizedBox(height: isMobile ? 80 : 100),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateBox(BuildContext context, String text, double spacing) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(spacing * 1.8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.blue.shade200),
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
      ),
      child: Row(
        children: [
          Icon(
            text == "Select Date" ? Icons.calendar_today : Icons.check_circle,
            size: Responsive.iconSize(context, 18),
            color: text == "Select Date" ? Colors.grey : Colors.green,
          ),
          SizedBox(width: spacing),
          Text(
            text,
            style: TextStyle(
              fontSize: Responsive.fontSize(context, AppFonts.md),
              color: text == "Select Date" ? Colors.grey : Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRadio(BuildContext context, String title, double spacing) {
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
        padding: EdgeInsets.symmetric(vertical: spacing * 0.5),
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
              activeColor: appBarColor,
            ),
            Text(
              title,
              style: TextStyle(fontSize: Responsive.fontSize(context, AppFonts.md)),
            ),
          ],
        ),
      ),
    );
  }
}