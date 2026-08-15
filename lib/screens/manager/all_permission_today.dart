// lib/screens/manager/list_staff_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart' as excel;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:open_file/open_file.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:permission_system/app_fonts.dart';
import '../../services/request_service.dart';
import '../../utils/responsive.dart';
import '../../widgets/profile_avatar.dart';

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
    this.submitTime,
  });

  factory TodayRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    int requestNumber = 0;
    final requestNumberValue = data['requestNumber'];
    if (requestNumberValue != null) {
      if (requestNumberValue is int) {
        requestNumber = requestNumberValue;
      } else if (requestNumberValue is String) {
        requestNumber = int.tryParse(requestNumberValue) ?? 0;
      } else if (requestNumberValue is num) {
        requestNumber = requestNumberValue.toInt();
      }
    }

    int totalDays = 0;
    final totalDaysValue = data['totalDays'];
    if (totalDaysValue != null) {
      if (totalDaysValue is int) {
        totalDays = totalDaysValue;
      } else if (totalDaysValue is String) {
        totalDays = int.tryParse(totalDaysValue) ?? 0;
      } else if (totalDaysValue is num) {
        totalDays = totalDaysValue.toInt();
      }
    }

    return TodayRequest(
      requestId: doc.id,
      userId: data['userId'] ?? '',
      staffName: data['userName'] ?? data['userEmail'] ?? 'Unknown',
      userEmail: data['userEmail'] ?? '',
      reason: data['reason'] ?? 'No reason',
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
      submitTime: data['submitTime'],
    );
  }
}

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
  bool _isManager = false;

  int _visibleCount = 3;
  bool _showAll = false;

  final Map<String, String> _userNameCache = {};

  final List<String> _segmentLabels = [
    'All',
    'Pending',
    'Approved',
    'Rejected',
    'Auto-App',
  ];

  @override
  void initState() {
    super.initState();
    _checkManagerDepartment();
  }

  Future<String> _getUserFullName(String userId) async {
    if (userId.isEmpty) return 'Unknown';
    try {
      final docSnapshot = await _firestore.collection('users').doc(userId).get();
      if (docSnapshot.exists) {
        final data = docSnapshot.data();
        return data?['fullName'] ?? data?['username'] ?? 'Unknown';
      }
      return 'Unknown';
    } catch (e) {
      return 'Unknown';
    }
  }

  Future<String> _getUserFullNameCached(String userId) async {
    if (userId.isEmpty) return 'Unknown';
    if (_userNameCache.containsKey(userId)) {
      return _userNameCache[userId]!;
    }
    final name = await _getUserFullName(userId);
    _userNameCache[userId] = name;
    return name;
  }

  String _formatSubmitTime(dynamic submitTime) {
    if (submitTime == null) return 'N/A';
    try {
      if (submitTime is String && (submitTime.contains('AM') || submitTime.contains('PM'))) {
        return submitTime;
      }
      DateTime? parsedDateTime;
      bool isUTC = false;
      if (submitTime is String) {
        String cleaned = submitTime.trim();
        if (cleaned.contains('T') && cleaned.endsWith('Z')) {
          try { parsedDateTime = DateTime.parse(cleaned); isUTC = true; } catch (_) {}
        } else if (cleaned.contains('T')) {
          try { parsedDateTime = DateTime.parse(cleaned); } catch (_) {}
        } else if (cleaned.contains(' ') && cleaned.contains('-')) {
          final parts = cleaned.split(' ');
          if (parts.length == 2) {
            final dateParts = parts[0].split('-');
            final timeParts = parts[1].split(':');
            if (dateParts.length == 3 && timeParts.length >= 2) {
              parsedDateTime = DateTime(
                int.parse(dateParts[0]),
                int.parse(dateParts[1]),
                int.parse(dateParts[2]),
                int.parse(timeParts[0]),
                int.parse(timeParts[1]),
              );
            }
          }
        }
      } else if (submitTime is Timestamp) {
        parsedDateTime = submitTime.toDate();
        isUTC = true;
      } else if (submitTime is DateTime) {
        parsedDateTime = submitTime;
        isUTC = submitTime.isUtc;
      }
      if (parsedDateTime == null) return submitTime.toString();
      DateTime cambodiaTime = isUTC ? parsedDateTime.toUtc().add(const Duration(hours: 7)) : parsedDateTime;
      int hour = cambodiaTime.hour;
      final int minute = cambodiaTime.minute;
      final String period = hour >= 12 ? 'PM' : 'AM';
      if (hour == 0) hour = 12;
      else if (hour > 12) hour -= 12;
      return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
    } catch (_) { return 'N/A'; }
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
      final querySnapshot = await _firestore.collection('users').where('userId', isEqualTo: user.uid).limit(1).get();
      if (querySnapshot.docs.isNotEmpty) {
        final data = querySnapshot.docs.first.data();
        final roleId = data['roleId']?.toString() ?? '2';
        if (roleId == '3' || roleId == '4') {
          _isManager = true;
          _managerDepartment = data['department'] ?? '';
        }
      }
    } catch (e) {
      print('Error checking manager department: $e');
    }
    _loadAllRequests();
  }

  Future<void> _loadAllRequests() async {
    setState(() {
      _isLoading = true;
      _showAll = false;
      _visibleCount = 3;
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

      List<TodayRequest> allRequests = querySnapshot.docs.map((doc) => TodayRequest.fromFirestore(doc)).toList();

      if (_isManager && _managerDepartment.isNotEmpty) {
        allRequests = allRequests.where((r) => r.department == _managerDepartment).toList();
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
    setState(() {
      _filteredRequests = filtered;
      _visibleCount = 3;
      _showAll = false;
    });
  }

  Future<void> _refresh() async => _loadAllRequests();

  void _showMore() => setState(() { _showAll = true; _visibleCount = _filteredRequests.length; });
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

  @override
  Widget build(BuildContext context) {
    final bool isMobile = Responsive.isMobile(context);
    final double fontSize = Responsive.fontSize(context, 14);
    final double spacing = Responsive.spacing(context);
    final double iconSize = Responsive.iconSize(context, 20);
    double bottomPadding = MediaQuery.of(context).padding.bottom + 24;

    final filtered = _filteredRequests;
    final summary = _calculateSummary(filtered);
    final List<TodayRequest> visibleItems = _showAll ? filtered : filtered.take(_visibleCount).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF173B69),
        elevation: 2,
        automaticallyImplyLeading: false, // Remove back button
        title: const Text(
          'Permission List',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
        ),
        centerTitle: true, // Center the title
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(icon: Icon(Icons.refresh, size: iconSize), onPressed: _refresh, tooltip: 'Refresh'),
          IconButton(icon: Icon(Icons.file_download, size: iconSize), onPressed: () => _exportToExcel(), tooltip: 'Export'),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Container(
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
                            _segmentLabels[index],
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
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF173B69))))
            : Column(
                children: [
                  // Filter Row
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
                  // Total Only - No summary chips
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF173B69).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF173B69).withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.assignment_rounded, size: 14, color: const Color(0xFF173B69)),
                              const SizedBox(width: 6),
                              Text(
                                'Total: ${summary['total']}',
                                style: TextStyle(
                                  fontSize: fontSize,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF173B69),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_isManager && _managerDepartment.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.business, size: 14, color: Colors.green[700]),
                            const SizedBox(width: 4),
                            Text(
                              _managerDepartment,
                              style: TextStyle(fontSize: fontSize * 0.85, color: Colors.green[700], fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                    ),
                  // List
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade400),
                                const SizedBox(height: 12),
                                Text('No data found', style: TextStyle(color: Colors.grey.shade500, fontSize: fontSize)),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: EdgeInsets.only(left: 16, right: 16, top: 8, bottom: bottomPadding),
                            itemCount: visibleItems.length + (filtered.length > 3 ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == visibleItems.length && filtered.length > 3) {
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
                                          Text(_showAll ? 'Show Less' : 'See More', style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600, color: const Color(0xFF173B69))),
                                          const SizedBox(width: 4),
                                          Icon(_showAll ? Icons.expand_less : Icons.expand_more, color: const Color(0xFF173B69), size: iconSize),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }
                              final r = visibleItems[index];
                              return _RequestCard(request: r, isMobile: isMobile, fontSize: fontSize, spacing: spacing);
                            },
                          ),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _exportToExcel() async {
    if (_filteredRequests.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No data to export'), backgroundColor: Colors.orange),
      );
      return;
    }
    try {
      var excelFile = excel.Excel.createExcel();
      excel.Sheet sheet = excelFile['Permission List'];
      final headers = ['No.', 'Request ID', 'Staff Name', 'Email', 'Start Date', 'End Date', 'Total Days', 'Reason', 'Status', 'Approval Type', 'Request #', 'Created At', 'Submit Time', 'Department'];
      sheet.appendRow(headers);
      for (int i = 0; i < headers.length; i++) {
        var cell = sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
        cell.cellStyle = excel.CellStyle(bold: true, backgroundColorHex: '#173B69', fontColorHex: '#FFFFFF');
      }
      for (int i = 0; i < _filteredRequests.length; i++) {
        final r = _filteredRequests[i];
        String fullName = r.staffName;
        if (r.userId.isNotEmpty && _userNameCache.containsKey(r.userId)) {
          fullName = _userNameCache[r.userId]!;
        }
        sheet.appendRow([
          (i + 1), r.requestId.substring(0, 8), fullName, r.userEmail, r.startDate, r.endDate,
          r.totalDays, r.reason, r.status.toUpperCase(), r.approvalType, r.requestNumber,
          _formatToCambodiaTime(r.createdAt), _formatSubmitTime(r.submitTime), r.department ?? ''
        ]);
      }
      final dir = await getTemporaryDirectory();
      final fileName = 'permission_list_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';
      final filePath = '${dir.path}/$fileName';
      final fileBytes = excelFile.encode();
      if (fileBytes != null) {
        File(filePath)..createSync(recursive: true)..writeAsBytesSync(fileBytes);
        await OpenFile.open(filePath);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(' Exported: $fileName'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export error: $e'), backgroundColor: Colors.red),
      );
    }
  }
}

class _RequestCard extends StatelessWidget {
  final TodayRequest request;
  final bool isMobile;
  final double fontSize;
  final double spacing;

  const _RequestCard({required this.request, required this.isMobile, required this.fontSize, required this.spacing});

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
                        'Reason: ${request.reason}',
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
                              request.autoApproved ? 'Auto' : 'Manual',
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
                  'Rejected: ${request.rejectionReason}',
                  style: TextStyle(fontSize: isMobile ? fontSize * 0.7 : fontSize * 0.85, color: Colors.red.shade700),
                ),
              ),
            if (request.approvedByName != null && request.approvedByName!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Approved by: ${request.approvedByName}',
                  style: TextStyle(fontSize: isMobile ? fontSize * 0.7 : fontSize * 0.85, color: Colors.green.shade700),
                ),
              ),
          ],
        ),
      ),
    );
  }
}