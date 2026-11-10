// lib/screens/manager/all_permission_today.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:convert';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart' as excel;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:open_file/open_file.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:permission_system/app_fonts.dart';
import '../../services/request_service.dart';
import '../../utils/responsive.dart';
import '../../widgets/profile_avatar.dart';
import '../../services/translation_service.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:permission_system/utils/web_utils.dart';

// ============================================================
// MODEL
// ============================================================
class TodayRequest {
  final String requestId;
  final String userId;
  final String staffName;
  final String userEmail;
  final String reason;
  final String startDate;
  final String endDate;
  final int totalDays;
  final String status;
  final String approvalType;
  final DateTime createdAt;
  final bool autoApproved;
  final int requestNumber;
  final String? fileUrl;
  final String? imageUrl;
  final String? rejectionReason;
  final String? approvedBy;
  final String? approvedByName;
  final String? department;
  final String? departmentId;
  final String? submitTime;

  TodayRequest({
    required this.requestId,
    required this.userId,
    required this.staffName,
    required this.userEmail,
    required this.reason,
    required this.startDate,
    required this.endDate,
    required this.totalDays,
    required this.status,
    required this.approvalType,
    required this.createdAt,
    this.autoApproved = false,
    required this.requestNumber,
    this.fileUrl,
    this.imageUrl,
    this.rejectionReason,
    this.approvedBy,
    this.approvedByName,
    this.department,
    this.departmentId,
    this.submitTime,
  });

  factory TodayRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    int requestNumber = 0;
    final rn = data['requestNumber'];
    if (rn != null) {
      if (rn is int) requestNumber = rn;
      else if (rn is String) requestNumber = int.tryParse(rn) ?? 0;
      else if (rn is num) requestNumber = rn.toInt();
    }

    int totalDays = 0;
    final td = data['totalDays'];
    if (td != null) {
      if (td is int) totalDays = td;
      else if (td is String) totalDays = int.tryParse(td) ?? 0;
      else if (td is num) totalDays = td.toInt();
    }

    return TodayRequest(
      requestId: doc.id,
      userId: data['userId'] ?? '',
      staffName: data['userName'] ?? data['userEmail'] ?? 'unknown'.tr(),
      userEmail: data['userEmail'] ?? '',
      reason: data['reason'] ?? 'no_reason'.tr(),
      startDate: data['startDate'] ?? '',
      endDate: data['endDate'] ?? '',
      totalDays: totalDays,
      status: data['status'] ?? 'pending',
      approvalType: data['autoApproved'] == true ? 'Auto' : 'Manual',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      autoApproved: data['autoApproved'] ?? false,
      requestNumber: requestNumber,
      fileUrl: data['fileUrl'],
      imageUrl: data['imageUrl'],
      rejectionReason: data['rejectionReason'],
      approvedBy: data['approvedBy'],
      approvedByName: data['approvedByName'],
      department: data['department'] ?? '',
      departmentId: data['departmentId']?.toString(),
      submitTime: data['submitTime'],
    );
  }
}

// ============================================================
// SCREEN
// ============================================================
class ListStaffScreen extends StatefulWidget {
  const ListStaffScreen({super.key});

  @override
  State<ListStaffScreen> createState() => _ListStaffScreenState();
}

class _ListStaffScreenState extends State<ListStaffScreen> {
  final RequestService _requestService = RequestService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<TodayRequest> _allRequests = [];
  List<TodayRequest> _filteredRequests = [];
  bool _isLoading = true;
  int _currentSegment = 0;

  String _selectedReportType = 'daily';
  DateTime _selectedDate = DateTime.now();

  String _managerDepartment = '';
  String _managerDepartmentId = '';
  String _managerName = '';
  bool _isManager = false;

  int _visibleCount = 3;
  bool _showAll = false;

  final Map<String, String> _userNameCache = {};

  String _searchQuery = '';

  // ✅ Dropdown សម្រាប់ជ្រើសរើសបុគ្គលិក
  String? _selectedStaffId;
  String? _selectedStaffName;
  List<Map<String, String>> _staffList = [];

  final List<String> _segmentLabels = [
    'all',
    'pending',
    'approved',
    'rejected',
    'auto_app',
  ];

  @override
  void initState() {
    super.initState();
    _checkManagerDepartment();
  }

  // ✅ Data ដែលត្រូវបង្ហាញ (filter តាម staff ដែលបានជ្រើសរើស)
  List<TodayRequest> get _displayRequests {
    var base = _filteredRequests;
    if (_selectedStaffId != null) {
      base = base.where((r) => r.userId == _selectedStaffId).toList();
    }
    return base;
  }

  String _normalizeDept(String dept) {
    return dept
        .toLowerCase()
        .trim()
        .replaceAll(' department', '')
        .replaceAll('dept', '')
        .replaceAll(' ', '');
  }

  Future<String> _getUserFullName(String userId) async {
    if (userId.isEmpty) return 'unknown'.tr();
    try {
      final docSnapshot = await _firestore.collection('users').doc(userId).get();
      if (docSnapshot.exists) {
        final data = docSnapshot.data();
        return data?['fullName'] ?? data?['username'] ?? 'unknown'.tr();
      }
      return 'unknown'.tr();
    } catch (e) {
      return 'unknown'.tr();
    }
  }

  String _formatToCambodiaTime(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    try {
      DateTime? parsedDateTime;
      bool isUTC = false;
      if (timestamp is Timestamp) {
        parsedDateTime = timestamp.toDate();
        isUTC = true;
      } else if (timestamp is DateTime) {
        parsedDateTime = timestamp;
        isUTC = timestamp.isUtc;
      } else {
        return 'N/A';
      }
      DateTime cambodiaTime = isUTC ? parsedDateTime.toUtc().add(const Duration(hours: 7)) : parsedDateTime;
      return DateFormat('dd/MM/yyyy hh:mm a').format(cambodiaTime);
    } catch (_) { return 'N/A'; }
  }

  DateTime _getStartOfWeek(DateTime date) {
    int weekday = date.weekday;
    return DateTime(date.year, date.month, date.day - (weekday - 1));
  }

  DateTime _getEndOfWeek(DateTime date) {
    DateTime startOfWeek = _getStartOfWeek(date);
    return DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day + 6, 23, 59, 59, 999);
  }

  String _getWeekLabel(DateTime date) {
    DateTime startOfWeek = _getStartOfWeek(date);
    DateTime endOfWeek = _getEndOfWeek(date);
    return '${DateFormat('dd MMM').format(startOfWeek)} - ${DateFormat('dd MMM yyyy').format(endOfWeek)}';
  }

  String _getDateLabel() {
    switch (_selectedReportType) {
      case 'daily': return DateFormat('dd MMM yyyy').format(_selectedDate);
      case 'weekly': return _getWeekLabel(_selectedDate);
      case 'monthly': return DateFormat('MMMM yyyy').format(_selectedDate);
      case 'yearly': return DateFormat('yyyy').format(_selectedDate);
      default: return '';
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _loadAllRequests();
    }
  }

  Future<void> _checkManagerDepartment() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    try {
      DocumentSnapshot? userDoc;

      try {
        final doc = await _firestore.collection('users').doc(user.uid).get();
        if (doc.exists) userDoc = doc;
      } catch (_) {}

      if (userDoc == null) {
        try {
          final q = await _firestore
              .collection('users')
              .where('userId', isEqualTo: user.uid)
              .limit(1)
              .get();
          if (q.docs.isNotEmpty) userDoc = q.docs.first;
        } catch (_) {}
      }

      if (userDoc == null) {
        try {
          final q = await _firestore
              .collection('users')
              .where('uid', isEqualTo: user.uid)
              .limit(1)
              .get();
          if (q.docs.isNotEmpty) userDoc = q.docs.first;
        } catch (_) {}
      }

      if (userDoc == null && user.email != null) {
        try {
          final q = await _firestore
              .collection('users')
              .where('email', isEqualTo: user.email)
              .limit(1)
              .get();
          if (q.docs.isNotEmpty) userDoc = q.docs.first;
        } catch (_) {}
      }

      if (userDoc == null) {
        _loadAllRequests();
        return;
      }

      final data = userDoc.data() as Map<String, dynamic>?;
      if (data == null) {
        _loadAllRequests();
        return;
      }

      final roleId = data['roleId']?.toString() ?? '2';
      final roleInt = int.tryParse(roleId.replaceAll('.0', '')) ?? 2;
      final isManagerRole = roleInt == 3 || roleInt == 4;

      if (isManagerRole) {
        _isManager = true;
        _managerDepartment = data['department']?.toString() ?? '';
        _managerDepartmentId = data['departmentId']?.toString() ?? '';
        _managerName = data['fullName'] ?? data['username'] ?? 'manager'.tr();

        if (_managerDepartmentId.isEmpty && _managerDepartment.isNotEmpty) {
          try {
            final deptSnapshot = await _firestore
                .collection('departments')
                .where('name', isEqualTo: _managerDepartment)
                .limit(1)
                .get();
            if (deptSnapshot.docs.isNotEmpty) {
              _managerDepartmentId = deptSnapshot.docs.first.id;
            }
          } catch (_) {}
        }
      }
    } catch (e) {
      print('Error checking manager department: $e');
    }

    await _loadStaffList();
    _loadAllRequests();
  }

  // ============================================================
  // ✅ ទាញបញ្ជីបុគ្គលិកក្នុង department របស់ Manager
  //    (បន្ថែម profileImageUrl)
  // ============================================================
  Future<void> _loadStaffList() async {
    if (_managerDepartmentId.isEmpty && _managerDepartment.isEmpty) return;

    print('🔍 Loading staff list for dept: "$_managerDepartment" (id: "$_managerDepartmentId")');

    try {
      final snapshot = await _firestore
          .collection('users')
          .where('roleId', isEqualTo: '2')
          .get();

      final staffList = <Map<String, String>>[];
      final managerKey = _normalizeDept(_managerDepartment);
      final mDeptId = _managerDepartmentId.trim();

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final staffDeptId = data['departmentId']?.toString() ?? '';
        final staffDeptName = data['department']?.toString() ?? '';
        final staffStatus = data['status']?.toString() ?? 'Active';

        if (staffStatus != 'Active') continue;

        bool match = false;
        if (mDeptId.isNotEmpty && staffDeptId.isNotEmpty) {
          match = staffDeptId == mDeptId;
        } else {
          match = _normalizeDept(staffDeptName) == managerKey;
        }

        if (match) {
          staffList.add({
            'id': doc.id,
            'name': data['fullName'] ?? data['username'] ?? 'Unknown',
            'email': data['email'] ?? '',
            'profileImageUrl': data['profileImageUrl'] ?? '', // ✅ បន្ថែម
          });
        }
      }

      staffList.sort((a, b) => (a['name'] ?? '').compareTo(b['name'] ?? ''));

      print('✅ Loaded ${staffList.length} staff for manager dept');

      if (mounted) {
        setState(() => _staffList = staffList);
      }
    } catch (e) {
      print('❌ Error loading staff list: $e');
    }
  }

  Future<void> _loadAllRequests() async {
    setState(() {
      _isLoading = true;
      _showAll = false;
      _visibleCount = 3;
      _searchQuery = '';
      _selectedStaffId = null;
      _selectedStaffName = null;
    });
    try {
      DateTime startDate, endDate;
      switch (_selectedReportType) {
        case 'daily':
          startDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
          endDate = startDate.add(const Duration(days: 1));
          break;
        case 'weekly':
          startDate = _getStartOfWeek(_selectedDate);
          endDate = _getEndOfWeek(_selectedDate).add(const Duration(milliseconds: 1));
          break;
        case 'monthly':
          startDate = DateTime(_selectedDate.year, _selectedDate.month, 1);
          endDate = DateTime(_selectedDate.year, _selectedDate.month + 1, 1);
          break;
        case 'yearly':
          startDate = DateTime(_selectedDate.year, 1, 1);
          endDate = DateTime(_selectedDate.year + 1, 1, 1);
          break;
        default:
          startDate = DateTime.now();
          endDate = DateTime.now().add(const Duration(days: 1));
      }

      final querySnapshot = await _firestore
          .collection('leave_requests')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('createdAt', isLessThan: Timestamp.fromDate(endDate))
          .get();

      List<TodayRequest> allRequests =
          querySnapshot.docs.map((doc) => TodayRequest.fromFirestore(doc)).toList();

      if (_isManager && (_managerDepartmentId.isNotEmpty || _managerDepartment.isNotEmpty)) {
        final managerKey = _normalizeDept(_managerDepartment);
        final mDeptId = _managerDepartmentId.trim();

        allRequests = allRequests.where((r) {
          final rDeptId = (r.departmentId ?? '').trim();
          final rDeptKey = _normalizeDept(r.department ?? '');

          if (mDeptId.isNotEmpty && rDeptId.isNotEmpty) {
            return rDeptId == mDeptId;
          }
          return rDeptKey == managerKey;
        }).toList();
      }

      allRequests.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      setState(() {
        _allRequests = allRequests;
        _applyFilters();
        _isLoading = false;
        _userNameCache.clear();
      });
    } catch (e) {
      print('Error loading requests: $e');
      setState(() {
        _allRequests = [];
        _filteredRequests = [];
        _isLoading = false;
      });
    }
  }

  void _applyFilters() {
    var filtered = _allRequests;

    if (_currentSegment != 0) {
      switch (_currentSegment) {
        case 1: filtered = filtered.where((r) => r.status == 'pending').toList(); break;
        case 2: filtered = filtered.where((r) => r.status == 'approved').toList(); break;
        case 3: filtered = filtered.where((r) => r.status == 'rejected').toList(); break;
        case 4: filtered = filtered.where((r) => r.autoApproved == true).toList(); break;
      }
    }

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase().trim();
      filtered = filtered.where((item) {
        final name = item.staffName.toLowerCase();
        final email = item.userEmail.toLowerCase();
        return name.contains(query) || email.contains(query);
      }).toList();
    }

    setState(() {
      _filteredRequests = filtered;
      _visibleCount = 3;
      _showAll = false;
    });
  }

  void _showMore() => setState(() { _showAll = true; _visibleCount = _displayRequests.length; });
  void _showLess() => setState(() { _showAll = false; _visibleCount = 3; });

  Map<String, dynamic> _calculateSummary(List<TodayRequest> data) {
    return {
      'total': data.length,
      'pending': data.where((r) => r.status == 'pending').length,
      'approved': data.where((r) => r.status == 'approved').length,
      'rejected': data.where((r) => r.status == 'rejected').length,
      'autoApproved': data.where((r) => r.autoApproved == true).length,
      'totalDays': data.fold(0, (sum, r) => sum + r.totalDays),
    };
  }

  // ============================================================
  // ✅ Summary Banner ពេលជ្រើសរើសបុគ្គលិក
  // ============================================================
  Widget _buildSelectedStaffSummary(bool isMobile, double fontSize, double spacing) {
    if (_selectedStaffId == null) return const SizedBox.shrink();

    final staffReqs = _allRequests.where((r) => r.userId == _selectedStaffId).toList();
    final summary = _calculateSummary(staffReqs);

    final selectedStaff = _staffList.firstWhere(
      (s) => s['id'] == _selectedStaffId,
      orElse: () => {'name': '', 'profileImageUrl': '', 'email': ''},
    );

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: EdgeInsets.all(spacing * 1.2),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF173B69), Color(0xFF2C5F8A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ProfileAvatar(
                userId: _selectedStaffId!,
                imageUrl: selectedStaff['profileImageUrl'], // ✅ បន្ថែម
                name: _selectedStaffName ?? '',
                radius: isMobile ? 18 : 22,
                backgroundColor: Colors.white.withValues(alpha: 0.15),
                textColor: Colors.white,
              ),
              SizedBox(width: spacing),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedStaffName ?? '',
                      style: TextStyle(
                        fontSize: isMobile ? fontSize + 1 : fontSize + 3,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '📊 ${staffReqs.length} request(s) · ${summary['totalDays']} day(s)',
                      style: TextStyle(
                        fontSize: isMobile ? fontSize * 0.75 : fontSize * 0.85,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    _selectedStaffId = null;
                    _selectedStaffName = null;
                  });
                },
                icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                tooltip: 'Clear selection',
              ),
            ],
          ),
          SizedBox(height: spacing),
          Row(
            children: [
              _buildMiniStat('Total', '${summary['total']}', Colors.white, isMobile, fontSize),
              _buildMiniStat('Pending', '${summary['pending']}', Colors.orangeAccent, isMobile, fontSize),
              _buildMiniStat('Approved', '${summary['approved']}', Colors.greenAccent, isMobile, fontSize),
              _buildMiniStat('Rejected', '${summary['rejected']}', Colors.redAccent, isMobile, fontSize),
              _buildMiniStat('Auto', '${summary['autoApproved']}', Colors.purpleAccent, isMobile, fontSize),
            ],
          ),
          SizedBox(height: spacing),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                _exportStaffSummaryToPDF(
                  _selectedStaffId!,
                  _selectedStaffName ?? '',
                  staffReqs,
                  summary,
                );
              },
              icon: const Icon(Icons.picture_as_pdf, size: 18),
              label: const Text('Export PDF for this staff'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF173B69),
                padding: EdgeInsets.symmetric(vertical: spacing),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, Color color, bool isMobile, double fontSize) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: isMobile ? 16 : 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: isMobile ? 9 : 11,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportStaffSummaryToPDF(
    String userId,
    String staffName,
    List<TodayRequest> requests,
    Map<String, dynamic> summary,
  ) async {
    if (requests.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No data to export'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Generating PDF...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      List<TodayRequest> translatedData = [];
      for (var request in requests) {
        final translatedName = await TranslationService.translateToEnglish(request.staffName);
        final translatedReason = await TranslationService.translateToEnglish(request.reason);
        final translatedDepartment = request.department != null
            ? await TranslationService.translateToEnglish(request.department!)
            : '';
        final translatedStatus = await TranslationService.translateToEnglish(request.status);
        final translatedApprovedBy = request.approvedByName != null
            ? await TranslationService.translateToEnglish(request.approvedByName!)
            : '';
        final translatedRejectionReason = request.rejectionReason != null
            ? await TranslationService.translateToEnglish(request.rejectionReason!)
            : '';

        translatedData.add(TodayRequest(
          requestId: request.requestId,
          userId: request.userId,
          staffName: translatedName,
          userEmail: request.userEmail,
          reason: translatedReason,
          startDate: request.startDate,
          endDate: request.endDate,
          totalDays: request.totalDays,
          status: translatedStatus,
          approvalType: request.approvalType,
          createdAt: request.createdAt,
          autoApproved: request.autoApproved,
          requestNumber: request.requestNumber,
          fileUrl: request.fileUrl,
          imageUrl: request.imageUrl,
          rejectionReason: translatedRejectionReason,
          approvedBy: request.approvedBy,
          approvedByName: translatedApprovedBy,
          department: translatedDepartment,
          departmentId: request.departmentId,
          submitTime: request.submitTime,
        ));
      }

      pw.ImageProvider? logoImage;
      try {
        final ByteData imageData = await rootBundle.load('assets/img/logo1.png');
        final Uint8List imageBytes = imageData.buffer.asUint8List();
        logoImage = pw.MemoryImage(imageBytes);
      } catch (_) {}

      final pdf = pw.Document();
      final pageFormat = PdfPageFormat.a4.landscape;

      pdf.addPage(
        pw.MultiPage(
          pageFormat: pageFormat,
          margin: pw.EdgeInsets.all(20),
          build: (pw.Context context) {
            return [
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(
                    width: 80,
                    height: 80,
                    child: pw.Center(
                      child: logoImage != null
                          ? pw.Image(logoImage!, width: 70, height: 70, fit: pw.BoxFit.contain)
                          : pw.Text('🏫', style: pw.TextStyle(fontSize: 30)),
                    ),
                  ),
                  pw.SizedBox(width: 16),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text(
                          'KINGDOM OF CAMBODIA',
                          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'Nation  Religion  King',
                          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
                        ),
                        pw.SizedBox(height: 20),
                        pw.Text(
                          'STAFF SUMMARY REPORT',
                          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'Staff: $staffName',
                          style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                        ),
                        pw.Text(
                          'Period: ${_getDateLabel()}',
                          style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                        ),
                        pw.Text(
                          'Department: $_managerDepartment',
                          style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 15),
              pw.Container(
                padding: pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(8),
                  border: pw.Border.all(color: PdfColors.grey300),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                  children: [
                    _buildPdfSummaryItem('Total', '${summary['total']}', PdfColors.blue900),
                    _buildPdfSummaryItem('Pending', '${summary['pending']}', PdfColors.orange),
                    _buildPdfSummaryItem('Approved', '${summary['approved']}', PdfColors.green),
                    _buildPdfSummaryItem('Rejected', '${summary['rejected']}', PdfColors.red),
                    _buildPdfSummaryItem('Auto', '${summary['autoApproved']}', PdfColors.purple),
                    _buildPdfSummaryItem('Days', '${summary['totalDays']}', PdfColors.blue),
                  ],
                ),
              ),
              pw.SizedBox(height: 15),
              pw.Table(
                border: pw.TableBorder.all(),
                columnWidths: {
                  0: pw.FixedColumnWidth(25),
                  1: pw.FixedColumnWidth(50),
                  2: pw.FixedColumnWidth(60),
                  3: pw.FixedColumnWidth(75),
                  4: pw.FixedColumnWidth(60),
                  5: pw.FixedColumnWidth(35),
                  6: pw.FixedColumnWidth(100),
                  7: pw.FixedColumnWidth(55),
                  8: pw.FixedColumnWidth(40),
                  9: pw.FixedColumnWidth(40),
                  10: pw.FixedColumnWidth(80),
                },
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: PdfColors.blue900),
                    children: [
                      _buildPdfHeaderCell('No.'),
                      _buildPdfHeaderCell('Date'),
                      _buildPdfHeaderCell('End Date'),
                      _buildPdfHeaderCell('Reason'),
                      _buildPdfHeaderCell('Department'),
                      _buildPdfHeaderCell('Days'),
                      _buildPdfHeaderCell('Status'),
                      _buildPdfHeaderCell('Type'),
                      _buildPdfHeaderCell('Req #'),
                      _buildPdfHeaderCell('Created'),
                      _buildPdfHeaderCell('Approved/Rejection'),
                    ],
                  ),
                  ...translatedData.asMap().entries.map((entry) {
                    final index = entry.key;
                    final r = entry.value;
                    final color = index % 2 == 0 ? PdfColors.grey100 : PdfColors.white;

                    return pw.TableRow(
                      decoration: pw.BoxDecoration(color: color),
                      children: [
                        _buildPdfDataCell('${index + 1}'),
                        _buildPdfDataCell(r.startDate),
                        _buildPdfDataCell(r.endDate),
                        _buildPdfDataCell(r.reason),
                        _buildPdfDataCell(r.department ?? 'N/A'),
                        _buildPdfDataCell('${r.totalDays}'),
                        _buildPdfDataCell(
                          r.status.toUpperCase(),
                          color: r.status == 'approved'
                              ? PdfColors.green
                              : r.status == 'rejected'
                                  ? PdfColors.red
                                  : PdfColors.orange,
                        ),
                        _buildPdfDataCell(r.autoApproved ? 'Auto' : 'Manual'),
                        _buildPdfDataCell('${r.requestNumber}'),
                        _buildPdfDataCell(_formatToCambodiaTime(r.createdAt)),
                        _buildPdfDataCell(
                          r.approvedByName?.isNotEmpty == true
                              ? 'By: ${r.approvedByName}'
                              : r.rejectionReason?.isNotEmpty == true
                                  ? 'Rej: ${r.rejectionReason}'
                                  : '',
                        ),
                      ],
                    );
                  }).toList(),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Total: ${translatedData.length} request(s)',
                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Date: ${DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now())}',
                        style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Prepared by: $_managerName',
                        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
                      ),
                    ],
                  ),
                ],
              ),
            ];
          },
        ),
      );

      final pdfBytes = await pdf.save();
      if (Navigator.canPop(context)) Navigator.pop(context);

      final fileName = 'staff_${staffName.replaceAll(' ', '_')}_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';

      if (kIsWeb) {
        downloadFileWeb(pdfBytes, fileName, 'application/pdf');
        _showWebSuccessDialog(fileName);
      } else {
        final dir = await getTemporaryDirectory();
        final filePath = '${dir.path}/$fileName';
        final file = File(filePath);
        await file.writeAsBytes(pdfBytes, flush: true);
        try {
          final result = await OpenFile.open(filePath);
          if (result.type != ResultType.done) {
            _showMobileSuccessDialog(filePath, fileName);
          }
        } catch (_) {
          _showMobileSuccessDialog(filePath, fileName);
        }
      }

      TranslationService.clearCache();
    } catch (e) {
      if (Navigator.canPop(context)) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PDF Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  pw.Widget _buildPdfSummaryItem(String label, String value, PdfColor color) {
    return pw.Column(
      children: [
        pw.Text(
          value,
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: color),
        ),
        pw.Text(
          label,
          style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
        ),
      ],
    );
  }

  pw.Widget _buildPdfHeaderCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(
        text,
        style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 8),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  pw.Widget _buildPdfDataCell(String text, {PdfColor? color}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(3),
      child: pw.Text(
        text,
        style: pw.TextStyle(color: color ?? PdfColors.black, fontSize: 7),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  // ============================================================
  // ✅ Dropdown បង្ហាញរូបថត + ឈ្មោះ + អ៊ីមែល
  // ============================================================
  Widget _buildStaffDropdown(bool isMobile, double fontSize, double spacing) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: _selectedStaffId,
          icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
          isExpanded: true,
          dropdownColor: const Color(0xFF173B69),
          menuMaxHeight: 400,

          // ✅ បង្ហាញក្នុងប្រអប់បិទ
          selectedItemBuilder: (context) {
            return [
              // All Staff
              Row(
                children: [
                  Container(
                    width: isMobile ? 24 : 28,
                    height: isMobile ? 24 : 28,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.people, color: Colors.white, size: isMobile ? 14 : 16),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'All Staff (${_staffList.length})',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: fontSize,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              // Individual staff
              ..._staffList.map((staff) {
                final isSelected = staff['id'] == _selectedStaffId;
                if (!isSelected) return const SizedBox.shrink();
                return Row(
                  children: [
                    ProfileAvatar(
                      userId: staff['id'] ?? '',
                      imageUrl: staff['profileImageUrl'],
                      name: staff['name'] ?? '',
                      radius: isMobile ? 12 : 14,
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      textColor: Colors.white,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        staff['name'] ?? '',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: fontSize,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                );
              }),
            ];
          },

          // ✅ បង្ហាញក្នុងប្រអប់បើក (dropdown list)
          items: [
            // All Staff
            DropdownMenuItem<String?>(
              value: null,
              child: Row(
                children: [
                  Container(
                    width: isMobile ? 28 : 32,
                    height: isMobile ? 28 : 32,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.people, color: Colors.white, size: isMobile ? 16 : 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'All Staff (${_staffList.length})',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: fontSize,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            // Individual staff (រូបថត + ឈ្មោះ + អ៊ីមែល)
            ..._staffList.map((staff) {
              return DropdownMenuItem<String?>(
                value: staff['id'],
                child: Row(
                  children: [
                    ProfileAvatar(
                      userId: staff['id'] ?? '',
                      imageUrl: staff['profileImageUrl'],
                      name: staff['name'] ?? '',
                      radius: isMobile ? 14 : 16,
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      textColor: Colors.white,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            staff['name'] ?? '',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: fontSize,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          if ((staff['email'] ?? '').isNotEmpty)
                            Text(
                              staff['email'] ?? '',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: fontSize * 0.7,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],

          onChanged: (value) {
            setState(() {
              _selectedStaffId = value;
              _selectedStaffName = value == null
                  ? null
                  : _staffList.firstWhere(
                      (s) => s['id'] == value,
                      orElse: () => {'name': ''},
                    )['name'];
              _showAll = false;
              _visibleCount = 3;
            });
          },
          style: TextStyle(fontSize: fontSize),
        ),
      ),
    );
  }

  Future<void> _exportToPDF() async {
    final dataToExport = _displayRequests;

    if (dataToExport.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('no_data_to_export'.tr()),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text('generating_pdf'.tr()),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      List<TodayRequest> translatedData = [];

      for (var request in dataToExport) {
        final translatedName = await TranslationService.translateToEnglish(request.staffName);
        final translatedReason = await TranslationService.translateToEnglish(request.reason);
        final translatedDepartment = request.department != null
            ? await TranslationService.translateToEnglish(request.department!)
            : '';
        final translatedStatus = await TranslationService.translateToEnglish(request.status);
        final translatedApprovedBy = request.approvedByName != null
            ? await TranslationService.translateToEnglish(request.approvedByName!)
            : '';
        final translatedRejectionReason = request.rejectionReason != null
            ? await TranslationService.translateToEnglish(request.rejectionReason!)
            : '';

        translatedData.add(TodayRequest(
          requestId: request.requestId,
          userId: request.userId,
          staffName: translatedName,
          userEmail: request.userEmail,
          reason: translatedReason,
          startDate: request.startDate,
          endDate: request.endDate,
          totalDays: request.totalDays,
          status: translatedStatus,
          approvalType: request.approvalType,
          createdAt: request.createdAt,
          autoApproved: request.autoApproved,
          requestNumber: request.requestNumber,
          fileUrl: request.fileUrl,
          imageUrl: request.imageUrl,
          rejectionReason: translatedRejectionReason,
          approvedBy: request.approvedBy,
          approvedByName: translatedApprovedBy,
          department: translatedDepartment,
          departmentId: request.departmentId,
          submitTime: request.submitTime,
        ));
      }

      pw.ImageProvider? logoImage;
      try {
        final ByteData imageData = await rootBundle.load('assets/img/logo1.png');
        final Uint8List imageBytes = imageData.buffer.asUint8List();
        logoImage = pw.MemoryImage(imageBytes);
      } catch (_) {}

      final pdf = pw.Document();
      final pageFormat = PdfPageFormat.a4.landscape;

      pdf.addPage(
        pw.MultiPage(
          pageFormat: pageFormat,
          margin: pw.EdgeInsets.all(20),
          build: (pw.Context context) {
            return [
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(
                    width: 100,
                    height: 100,
                    child: pw.Center(
                      child: logoImage != null
                          ? pw.Image(logoImage!, width: 90, height: 90, fit: pw.BoxFit.contain)
                          : pw.Text('🏫', style: pw.TextStyle(fontSize: 40)),
                    ),
                  ),
                  pw.SizedBox(width: 16),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text(
                          'KINGDOM OF CAMBODIA',
                          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'Nation  Religion  King',
                          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
                        ),
                        pw.SizedBox(height: 35),
                        pw.Text(
                          'permission_request_report'.tr(),
                          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          '${'period'.tr()}: ${_getDateLabel()}',
                          style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                        ),
                        if (_isManager && _managerDepartment.isNotEmpty)
                          pw.Text(
                            '${'department'.tr()}: $_managerDepartment',
                            style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
                          ),
                        if (_selectedStaffName != null)
                          pw.Text(
                            'Staff: $_selectedStaffName',
                            style: pw.TextStyle(fontSize: 10, color: PdfColors.blue900, fontWeight: pw.FontWeight.bold),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Table(
                border: pw.TableBorder.all(),
                columnWidths: {
                  0: pw.FixedColumnWidth(25),
                  1: pw.FixedColumnWidth(70),
                  2: pw.FixedColumnWidth(80),
                  3: pw.FixedColumnWidth(70),
                  4: pw.FixedColumnWidth(60),
                  5: pw.FixedColumnWidth(35),
                  6: pw.FixedColumnWidth(70),
                  7: pw.FixedColumnWidth(50),
                  8: pw.FixedColumnWidth(40),
                  9: pw.FixedColumnWidth(45),
                  10: pw.FixedColumnWidth(75),
                  11: pw.FixedColumnWidth(60),
                  12: pw.FixedColumnWidth(60),
                },
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: PdfColors.blue900),
                    children: [
                      _buildHeaderCell('no'.tr()),
                      _buildHeaderCell('staff_name'.tr()),
                      _buildHeaderCell('email'.tr()),
                      _buildHeaderCell('dept'.tr()),
                      _buildHeaderCell('date'.tr()),
                      _buildHeaderCell('days'.tr()),
                      _buildHeaderCell('reason'.tr()),
                      _buildHeaderCell('status'.tr()),
                      _buildHeaderCell('type'.tr()),
                      _buildHeaderCell('req_no'.tr()),
                      _buildHeaderCell('created'.tr()),
                      _buildHeaderCell('approved_by'.tr()),
                      _buildHeaderCell('rejection'.tr()),
                    ],
                  ),
                  ...translatedData.asMap().entries.map((entry) {
                    final index = entry.key;
                    final r = entry.value;
                    final color = index % 2 == 0 ? PdfColors.grey100 : PdfColors.white;

                    return pw.TableRow(
                      decoration: pw.BoxDecoration(color: color),
                      children: [
                        _buildDataCell('${index + 1}'),
                        _buildDataCell(r.staffName),
                        _buildDataCell(r.userEmail),
                        _buildDataCell(r.department ?? 'N/A'),
                        _buildDataCell(r.startDate),
                        _buildDataCell('${r.totalDays}'),
                        _buildDataCell(r.reason),
                        _buildDataCell(
                          r.status.toUpperCase(),
                          color: r.status == 'approved'
                              ? PdfColors.green
                              : r.status == 'rejected'
                                  ? PdfColors.red
                                  : PdfColors.orange,
                        ),
                        _buildDataCell(r.autoApproved ? 'Auto' : 'Manual'),
                        _buildDataCell('${r.requestNumber}'),
                        _buildDataCell(_formatToCambodiaTime(r.createdAt)),
                        _buildDataCell(r.approvedByName ?? ''),
                        _buildDataCell(r.rejectionReason ?? ''),
                      ],
                    );
                  }).toList(),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    '${'total'.tr()}: ${translatedData.length} ${'requests'.tr()}',
                    style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        '${'date'.tr()}: ${DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now())}',
                        style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        '${'prepared_by'.tr()}: $_managerName',
                        style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
                      ),
                    ],
                  ),
                ],
              ),
            ];
          },
        ),
      );

      final pdfBytes = await pdf.save();

      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      if (kIsWeb) {
        _downloadPDFOnWeb(pdfBytes);
      } else {
        await _savePDFToFile(pdfBytes);
      }

      TranslationService.clearCache();
    } catch (e, stackTrace) {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      print('PDF Export error: $e');
      print('StackTrace: $stackTrace');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${'pdf_export_error'.tr()}: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  pw.Widget _buildHeaderCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          color: PdfColors.white,
          fontWeight: pw.FontWeight.bold,
          fontSize: 8,
        ),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  pw.Widget _buildDataCell(String text, {PdfColor? color}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(3),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          color: color ?? PdfColors.black,
          fontSize: 7,
        ),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  void _downloadPDFOnWeb(List<int> pdfBytes) {
    if (!kIsWeb) return;
    final fileName = 'permission_list_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';
    try {
      downloadFileWeb(pdfBytes, fileName, 'application/pdf');
      _showWebSuccessDialog(fileName);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Download failed. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showWebSuccessDialog(String fileName) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green),
            const SizedBox(width: 8),
            Text('download_succeeded'.tr()),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${'file'.tr()}: $fileName'),
            const SizedBox(height: 12),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('ok'.tr()),
          ),
        ],
      ),
    );
  }

  Future<void> _savePDFToFile(List<int> pdfBytes) async {
    try {
      final dir = await getTemporaryDirectory();
      final fileName = 'permission_list_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';
      final filePath = '${dir.path}/$fileName';

      final file = File(filePath);
      await file.writeAsBytes(pdfBytes, flush: true);

      try {
        final result = await OpenFile.open(filePath);
        if (result.type != ResultType.done) {
          _showMobileSuccessDialog(filePath, fileName);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ ${'exported_pdf'.tr()}: $fileName'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (_) {
        _showMobileSuccessDialog(filePath, fileName);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${'save_failed'.tr()}: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showMobileSuccessDialog(String filePath, String fileName) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green),
            const SizedBox(width: 8),
            Text('export_successful'.tr()),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${'pdf_saved'.tr()}: $fileName'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'location'.tr(),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  Text(
                    filePath,
                    style: const TextStyle(fontSize: 11),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('close'.tr()),
          ),
        ],
      ),
    );
  }

  Future<void> _exportToExcel() async {
    final dataToExport = _displayRequests;

    if (dataToExport.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('no_data_to_export'.tr()),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text('generating_excel'.tr()),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      var excelFile = excel.Excel.createExcel();
      var sheet = excelFile['Sheet1'];
      if (sheet == null) throw Exception('No sheet available');

      int currentRow = 0;

      sheet.merge(
        excel.CellIndex.indexByString('A1'),
        excel.CellIndex.indexByString('M1'),
      );
      var titleCell = sheet.cell(excel.CellIndex.indexByString('A1'));
      titleCell.value = 'PERMISSION REQUEST REPORT';
      titleCell.cellStyle = excel.CellStyle(
        bold: true,
        fontSize: 16,
        fontColorHex: '#173B69',
        horizontalAlign: excel.HorizontalAlign.Center,
        verticalAlign: excel.VerticalAlign.Center,
      );
      currentRow++;

      sheet.merge(
        excel.CellIndex.indexByString('A2'),
        excel.CellIndex.indexByString('M2'),
      );
      var periodCell = sheet.cell(excel.CellIndex.indexByString('A2'));
      periodCell.value = '${'period'.tr()}: ${_getDateLabel()}';
      periodCell.cellStyle = excel.CellStyle(
        bold: true,
        fontSize: 14,
        fontColorHex: '#173B69',
        horizontalAlign: excel.HorizontalAlign.Center,
        verticalAlign: excel.VerticalAlign.Center,
      );
      currentRow++;

      if (_isManager && _managerDepartment.isNotEmpty) {
        sheet.merge(
          excel.CellIndex.indexByString('A3'),
          excel.CellIndex.indexByString('M3'),
        );
        var deptCell = sheet.cell(excel.CellIndex.indexByString('A3'));
        deptCell.value = '${'department'.tr()}: $_managerDepartment';
        deptCell.cellStyle = excel.CellStyle(
          italic: true,
          fontSize: 10,
          fontColorHex: '#666666',
          horizontalAlign: excel.HorizontalAlign.Center,
          verticalAlign: excel.VerticalAlign.Center,
        );
        currentRow++;
      }

      currentRow++;

      final headers = [
        'no'.tr(),
        'staff_name'.tr(),
        'email'.tr(),
        'department'.tr(),
        'date'.tr(),
        'total_days'.tr(),
        'reason'.tr(),
        'status'.tr(),
        'approval_type'.tr(),
        'request_no'.tr(),
        'created_at'.tr(),
        'approved_by'.tr(),
        'rejection_reason'.tr(),
      ];

      for (int col = 0; col < headers.length; col++) {
        var cell = sheet.cell(
          excel.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: currentRow),
        );
        cell.value = headers[col];
        cell.cellStyle = excel.CellStyle(
          bold: true,
          backgroundColorHex: '#173B69',
          fontColorHex: '#FFFFFF',
          horizontalAlign: excel.HorizontalAlign.Center,
          verticalAlign: excel.VerticalAlign.Center,
          fontSize: 11,
        );
      }
      currentRow++;

      for (int i = 0; i < dataToExport.length; i++) {
        final r = dataToExport[i];
        final String cambodiaTime = _formatToCambodiaTime(r.createdAt);

        String fullName = r.staffName;
        if (r.userId.isNotEmpty && _userNameCache.containsKey(r.userId)) {
          fullName = _userNameCache[r.userId]!;
        }

        final rowIndex = currentRow;

        var cell0 = sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex));
        cell0.value = i + 1;
        cell0.cellStyle = excel.CellStyle(horizontalAlign: excel.HorizontalAlign.Center, verticalAlign: excel.VerticalAlign.Center, fontSize: 10);

        var cell1 = sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex));
        cell1.value = fullName;
        cell1.cellStyle = excel.CellStyle(horizontalAlign: excel.HorizontalAlign.Left, verticalAlign: excel.VerticalAlign.Center, fontSize: 10);

        var cell2 = sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex));
        cell2.value = r.userEmail;
        cell2.cellStyle = excel.CellStyle(horizontalAlign: excel.HorizontalAlign.Left, verticalAlign: excel.VerticalAlign.Center, fontSize: 10);

        var cell3 = sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex));
        cell3.value = r.department ?? 'N/A';
        cell3.cellStyle = excel.CellStyle(horizontalAlign: excel.HorizontalAlign.Left, verticalAlign: excel.VerticalAlign.Center, fontSize: 10);

        var cell4 = sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex));
        cell4.value = r.startDate;
        cell4.cellStyle = excel.CellStyle(horizontalAlign: excel.HorizontalAlign.Center, verticalAlign: excel.VerticalAlign.Center, fontSize: 10);

        var cell5 = sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex));
        cell5.value = r.totalDays;
        cell5.cellStyle = excel.CellStyle(horizontalAlign: excel.HorizontalAlign.Center, verticalAlign: excel.VerticalAlign.Center, fontSize: 10);

        var cell6 = sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rowIndex));
        cell6.value = r.reason;
        cell6.cellStyle = excel.CellStyle(horizontalAlign: excel.HorizontalAlign.Left, verticalAlign: excel.VerticalAlign.Center, fontSize: 10);

        var cell7 = sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: rowIndex));
        cell7.value = r.status.toUpperCase();
        String statusColor = '';
        switch (r.status.toLowerCase()) {
          case 'pending': statusColor = '#FFA500'; break;
          case 'approved': statusColor = '#28A745'; break;
          case 'rejected': statusColor = '#DC3545'; break;
          default: statusColor = '#000000';
        }
        cell7.cellStyle = excel.CellStyle(
          horizontalAlign: excel.HorizontalAlign.Center,
          verticalAlign: excel.VerticalAlign.Center,
          fontColorHex: statusColor,
          bold: true,
          fontSize: 10,
        );

        var cell8 = sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: rowIndex));
        cell8.value = r.autoApproved ? 'Auto' : 'Manual';
        cell8.cellStyle = excel.CellStyle(horizontalAlign: excel.HorizontalAlign.Center, verticalAlign: excel.VerticalAlign.Center, fontSize: 10);

        var cell9 = sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: rowIndex));
        cell9.value = r.requestNumber;
        cell9.cellStyle = excel.CellStyle(horizontalAlign: excel.HorizontalAlign.Center, verticalAlign: excel.VerticalAlign.Center, fontSize: 10);

        var cell10 = sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: rowIndex));
        cell10.value = cambodiaTime;
        cell10.cellStyle = excel.CellStyle(horizontalAlign: excel.HorizontalAlign.Center, verticalAlign: excel.VerticalAlign.Center, fontSize: 10);

        var cell11 = sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 11, rowIndex: rowIndex));
        cell11.value = r.approvedByName ?? '';
        cell11.cellStyle = excel.CellStyle(horizontalAlign: excel.HorizontalAlign.Left, verticalAlign: excel.VerticalAlign.Center, fontSize: 10);

        var cell12 = sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 12, rowIndex: rowIndex));
        cell12.value = r.rejectionReason ?? '';
        cell12.cellStyle = excel.CellStyle(horizontalAlign: excel.HorizontalAlign.Left, verticalAlign: excel.VerticalAlign.Center, fontSize: 10);

        currentRow++;
      }

      int footerStartRow = currentRow + 1;

      sheet.merge(
        excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: footerStartRow),
        excel.CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: footerStartRow),
      );
      var summaryCell = sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: footerStartRow));
      summaryCell.value = '${'total'.tr()}: ${dataToExport.length} ${'requests'.tr()}';
      summaryCell.cellStyle = excel.CellStyle(bold: true, fontSize: 11, fontColorHex: '#173B69', horizontalAlign: excel.HorizontalAlign.Left);

      footerStartRow++;

      sheet.merge(
        excel.CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: footerStartRow),
        excel.CellIndex.indexByColumnRow(columnIndex: 12, rowIndex: footerStartRow),
      );
      var exportDateCell = sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: footerStartRow));
      exportDateCell.value = '${'date'.tr()}: ${DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now())}';
      exportDateCell.cellStyle = excel.CellStyle(italic: true, fontSize: 9, fontColorHex: '#666666', horizontalAlign: excel.HorizontalAlign.Right);

      footerStartRow++;

      sheet.merge(
        excel.CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: footerStartRow),
        excel.CellIndex.indexByColumnRow(columnIndex: 12, rowIndex: footerStartRow),
      );
      var preparedCell = sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: footerStartRow));
      preparedCell.value = '${'prepared_by'.tr()}: $_managerName';
      preparedCell.cellStyle = excel.CellStyle(bold: true, fontSize: 11, fontColorHex: '#173B69', horizontalAlign: excel.HorizontalAlign.Right);

      final colWidths = [6, 22, 28, 20, 18, 14, 28, 16, 14, 14, 28, 20, 28];
      for (int i = 0; i < colWidths.length; i++) {
        sheet.setColWidth(i, colWidths[i].toDouble());
      }

      final fileBytes = excelFile.encode();
      if (fileBytes == null || fileBytes.isEmpty) {
        throw Exception('Failed to encode Excel file');
      }

      Navigator.pop(context);

      if (kIsWeb) {
        _downloadExcelOnWeb(fileBytes);
      } else {
        await _saveExcelToFile(fileBytes);
      }
    } catch (e, stackTrace) {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      print('Export error: $e');
      print('StackTrace: $stackTrace');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${'export_error'.tr()}: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _downloadExcelOnWeb(List<int> fileBytes) {
    if (!kIsWeb) return;
    final fileName = 'permission_list_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';
    try {
      downloadFileWeb(
        fileBytes,
        fileName,
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
      );
      _showWebSuccessDialog(fileName);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Download failed. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _saveExcelToFile(List<int> fileBytes) async {
    final dir = await getTemporaryDirectory();
    final fileName = 'permission_list_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';
    final filePath = '${dir.path}/$fileName';

    final file = File(filePath);
    await file.writeAsBytes(fileBytes, flush: true);

    final result = await OpenFile.open(filePath);
    if (result.type != ResultType.done) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${'could_not_open'.tr()}: ${result.message}'),
          backgroundColor: Colors.red,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ ${'exported_excel'.tr()}: $fileName'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    EasyLocalization.of(context);

    final bool isMobile = Responsive.isMobile(context);
    final double fontSize = Responsive.fontSize(context, 14);
    final double spacing = Responsive.spacing(context);
    final double iconSize = Responsive.iconSize(context, 20);
    double bottomPadding = MediaQuery.of(context).padding.bottom + 24;

    final displayList = _displayRequests;
    final List<TodayRequest> visibleItems = _showAll ? displayList : displayList.take(_visibleCount).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF173B69),
        elevation: 2,
        automaticallyImplyLeading: false,
        title: Text(
          'permission_list'.tr(),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          PopupMenuWidget(
            iconSize: iconSize,
            onExportExcel: _exportToExcel,
            onExportPDF: _exportToPDF,
            fontSize: fontSize,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(110),
          child: Column(
            children: [
              _buildStaffDropdown(isMobile, fontSize, spacing),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    children: List.generate(_segmentLabels.length, (index) {
                      final isSelected = _currentSegment == index;
                      final label = _segmentLabels[index];
                      return Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() => _currentSegment = index);
                            _applyFilters();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.white : Colors.transparent,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: isSelected ? [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, 2))] : null,
                            ),
                            child: Center(
                              child: Text(
                                label.tr(),
                                style: TextStyle(
                                  color: isSelected ? const Color(0xFF173B69) : Colors.white,
                                  fontSize: 13,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF173B69))))
            : Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF173B69).withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedReportType,
                                icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF173B69)),
                                isExpanded: true,
                                items: const [
                                  DropdownMenuItem(value: 'daily', child: Text(' Daily')),
                                  DropdownMenuItem(value: 'weekly', child: Text(' Weekly')),
                                  DropdownMenuItem(value: 'monthly', child: Text(' Monthly')),
                                  DropdownMenuItem(value: 'yearly', child: Text(' Yearly')),
                                ],
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() => _selectedReportType = value);
                                    _loadAllRequests();
                                  }
                                },
                                style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w500, color: const Color(0xFF173B69)),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 3,
                          child: GestureDetector(
                            onTap: _selectDate,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF173B69).withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_today, size: 16, color: Color(0xFF173B69)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _getDateLabel(),
                                      style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w500, color: const Color(0xFF173B69)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: TextField(
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                          _applyFilters();
                        });
                      },
                      style: TextStyle(fontSize: fontSize),
                      decoration: InputDecoration(
                        hintText: 'search_by_name_email'.tr(),
                        hintStyle: TextStyle(fontSize: fontSize, color: Colors.grey.shade500),
                        prefixIcon: Icon(Icons.search, color: Colors.grey.shade500, size: 20),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.clear, color: Colors.grey.shade500, size: 18),
                                onPressed: () {
                                  setState(() {
                                    _searchQuery = '';
                                    _applyFilters();
                                  });
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: spacing,
                          vertical: isMobile ? 10 : 14,
                        ),
                      ),
                    ),
                  ),

                  _buildSelectedStaffSummary(isMobile, fontSize, spacing),

                  Expanded(
                    child: displayList.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade400),
                                const SizedBox(height: 12),
                                Text(
                                  _selectedStaffId != null
                                      ? 'No requests for ${_selectedStaffName ?? ''}'
                                      : _searchQuery.isNotEmpty
                                          ? '${'no_results'.tr()} "$_searchQuery"'
                                          : 'no_data_found'.tr(),
                                  style: TextStyle(color: Colors.grey.shade500, fontSize: fontSize),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: EdgeInsets.only(left: 16, right: 16, top: 8, bottom: bottomPadding),
                            itemCount: visibleItems.length + (displayList.length > 3 ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == visibleItems.length && displayList.length > 3) {
                                return Padding(
                                  padding: EdgeInsets.symmetric(vertical: spacing),
                                  child: Center(
                                    child: TextButton(
                                      onPressed: _showAll ? _showLess : _showMore,
                                      style: TextButton.styleFrom(
                                        foregroundColor: const Color(0xFF173B69),
                                        padding: EdgeInsets.symmetric(horizontal: spacing * 3, vertical: spacing),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                          side: const BorderSide(color: Color(0xFF173B69), width: 1.5),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(_showAll ? 'show_less'.tr() : 'see_more'.tr(), style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600, color: const Color(0xFF173B69))),
                                          const SizedBox(width: 4),
                                          Icon(_showAll ? Icons.expand_less : Icons.expand_more, color: const Color(0xFF173B69), size: iconSize),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }
                              final r = visibleItems[index];
                              return _RequestCard(
                                request: r,
                                isMobile: isMobile,
                                fontSize: fontSize,
                                spacing: spacing,
                              );
                            },
                          ),
                  ),
                ],
              ),
      ),
    );
  }
}

// ===== POPUP MENU WIDGET =====
class PopupMenuWidget extends StatelessWidget {
  final VoidCallback onExportExcel;
  final VoidCallback onExportPDF;
  final double iconSize;
  final double fontSize;

  const PopupMenuWidget({
    super.key,
    required this.onExportExcel,
    required this.onExportPDF,
    required this.iconSize,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.file_download, size: iconSize),
      onSelected: (value) {
        if (value == 'excel') {
          onExportExcel();
        } else if (value == 'pdf') {
          onExportPDF();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'pdf',
          child: Row(
            children: [
              const Icon(Icons.picture_as_pdf, color: Colors.red),
              const SizedBox(width: 8),
              Text('export_pdf'.tr()),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'excel',
          child: Row(
            children: [
              const Icon(Icons.table_chart, color: Colors.green),
              const SizedBox(width: 8),
              Text('export_excel'.tr()),
            ],
          ),
        ),
      ],
    );
  }
}

// ===== REQUEST CARD =====
class _RequestCard extends StatelessWidget {
  final TodayRequest request;
  final bool isMobile;
  final double fontSize;
  final double spacing;

  const _RequestCard({
    required this.request,
    required this.isMobile,
    required this.fontSize,
    required this.spacing,
  });

  Color get _statusColor {
    if (request.status == 'approved') return Colors.green;
    if (request.status == 'rejected') return Colors.red;
    return Colors.orange;
  }

  String _formatToCambodiaTime(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    try {
      DateTime? parsedDateTime;
      if (timestamp is Timestamp) parsedDateTime = timestamp.toDate();
      else if (timestamp is DateTime) parsedDateTime = timestamp;
      else return 'N/A';
      DateTime cambodiaTime = parsedDateTime.toUtc().add(const Duration(hours: 7));
      return DateFormat('dd/MM/yyyy hh:mm a').format(cambodiaTime);
    } catch (_) { return 'N/A'; }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          ProfileAvatar(
                            userId: request.userId,
                            name: request.staffName,
                            radius: isMobile ? 14 : 18,
                            backgroundColor: _statusColor.withValues(alpha: 0.1),
                            textColor: _statusColor,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  request.staffName,
                                  style: TextStyle(fontSize: isMobile ? fontSize : fontSize + 2, fontWeight: FontWeight.bold, color: Colors.black87),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (request.department != null && request.department!.isNotEmpty)
                                  Text(
                                    request.department!,
                                    style: TextStyle(fontSize: isMobile ? fontSize * 0.7 : fontSize * 0.85, color: Colors.grey.shade600),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${'reason'.tr()}: ${request.reason}',
                        style: TextStyle(fontSize: isMobile ? fontSize * 0.75 : fontSize * 0.9),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade500),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${request.startDate} → ${request.endDate}',
                              style: TextStyle(fontSize: isMobile ? fontSize * 0.75 : fontSize * 0.9, color: Colors.grey.shade700),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${request.totalDays}d',
                              style: TextStyle(fontSize: isMobile ? fontSize * 0.7 : fontSize * 0.85, fontWeight: FontWeight.bold, color: Colors.blue),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: request.autoApproved ? Colors.purple.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              request.autoApproved ? 'auto'.tr() : 'manual'.tr(),
                              style: TextStyle(
                                fontSize: isMobile ? fontSize * 0.65 : fontSize * 0.8,
                                color: request.autoApproved ? Colors.purple : Colors.orange,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Text(
                            '#${request.requestNumber}',
                            style: TextStyle(fontSize: isMobile ? fontSize * 0.65 : fontSize * 0.8, color: Colors.grey.shade500),
                          ),
                          Text(
                            _formatToCambodiaTime(request.createdAt),
                            style: TextStyle(fontSize: isMobile ? fontSize * 0.65 : fontSize * 0.8, color: Colors.blue.shade700, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    request.status.toUpperCase(),
                    style: TextStyle(color: _statusColor, fontWeight: FontWeight.bold, fontSize: isMobile ? fontSize * 0.7 : fontSize * 0.85),
                  ),
                ),
              ],
            ),
            if (request.rejectionReason != null && request.rejectionReason!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '${'rejected'.tr()}: ${request.rejectionReason}',
                  style: TextStyle(fontSize: isMobile ? fontSize * 0.7 : fontSize * 0.85, color: Colors.red.shade700),
                ),
              ),
            if (request.approvedByName != null && request.approvedByName!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '${'approved_by'.tr()}: ${request.approvedByName}',
                  style: TextStyle(fontSize: isMobile ? fontSize * 0.7 : fontSize * 0.85, color: Colors.green.shade700),
                ),
              ),
          ],
        ),
      ),
    );
  }
}