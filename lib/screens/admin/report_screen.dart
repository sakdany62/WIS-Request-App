// lib/screens/admin/report_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart' as excel;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:open_file/open_file.dart';
import '../../app_fonts.dart';
import '../../utils/responsive.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  String _selectedReportType = 'daily';
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  List<Map<String, dynamic>> _reportData = [];
  List<Map<String, dynamic>> _allReportData = [];
  Map<String, dynamic> _summary = {};
  String _filterDepartment = 'all';
  int _currentSegment = 0;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final List<Map<String, String>> _departments = [
    {'id': 'dept_it', 'name': 'IT Department'},
    {'id': 'dept_education', 'name': 'Education Department'},
    {'id': 'dept_administration', 'name': 'Administration Department'},
    {'id': 'dept_service', 'name': 'Service Department'},
  ];

  final List<String> _segmentLabels = [
    'All',
    'Pending',
    'Approved',
    'Rejected',
  ];

  DateTime _getStartOfWeek(DateTime date) {
    int weekday = date.weekday;
    int daysToSubtract = weekday - 1;
    return DateTime(date.year, date.month, date.day - daysToSubtract);
  }

  DateTime _getEndOfWeek(DateTime date) {
    DateTime startOfWeek = _getStartOfWeek(date);
    return DateTime(
      startOfWeek.year,
      startOfWeek.month,
      startOfWeek.day + 6,
      23,
      59,
      59,
      999,
    );
  }

  String _getWeekLabel(DateTime date) {
    DateTime startOfWeek = _getStartOfWeek(date);
    DateTime endOfWeek = _getEndOfWeek(date);
    return '${DateFormat('dd MMM').format(startOfWeek)} - ${DateFormat('dd MMM yyyy').format(endOfWeek)}';
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
      DateTime cambodiaTime;
      if (isUTC) {
        cambodiaTime = parsedDateTime.toUtc().add(const Duration(hours: 7));
      } else {
        cambodiaTime = parsedDateTime;
      }
      return DateFormat('dd/MM/yyyy hh:mm a').format(cambodiaTime);
    } catch (e) {
      return 'N/A';
    }
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

  final Map<String, String> _userNameCache = {};

  Future<String> _getUserFullNameCached(String userId) async {
    if (userId.isEmpty) return 'Unknown';
    if (_userNameCache.containsKey(userId)) {
      return _userNameCache[userId]!;
    }
    final name = await _getUserFullName(userId);
    _userNameCache[userId] = name;
    return name;
  }

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() {
      _isLoading = true;
    });

    try {
      DateTime startDate;
      DateTime endDate;

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

      final startTimestamp = Timestamp.fromDate(startDate);
      final endTimestamp = Timestamp.fromDate(endDate);

      Query query = _firestore
          .collection('leave_requests')
          .where('createdAt', isGreaterThanOrEqualTo: startTimestamp)
          .where('createdAt', isLessThan: endTimestamp)
          .orderBy('createdAt', descending: true);

      final querySnapshot = await query.get();

      final data = querySnapshot.docs.map((doc) {
        final d = doc.data() as Map<String, dynamic>;
        String department = d['department'] ?? '';
        String departmentId = d['departmentId'] ?? '';

        if (departmentId.isEmpty && d['deptId'] != null) {
          departmentId = d['deptId'].toString();
        }

        if (department.isEmpty && departmentId.isNotEmpty) {
          final dept = _departments.firstWhere(
            (d) => d['id'] == departmentId,
            orElse: () => {},
          );
          department = dept['name'] ?? '';
        }

        return {
          'id': doc.id,
          'userId': d['userId'] ?? '',
          'userName': d['userName'] ?? d['fullName'] ?? 'Unknown',
          'userEmail': d['userEmail'] ?? '',
          'department': department,
          'departmentId': departmentId,
          'startDate': d['startDate'] ?? '',
          'endDate': d['endDate'] ?? '',
          'totalDays': d['totalDays'] ?? 0,
          'reason': d['reason'] ?? '',
          'status': d['status'] ?? 'pending',
          'autoApproved': d['autoApproved'] ?? false,
          'createdAt': (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          'approvedByName': d['approvedByName'] ?? '',
          'rejectionReason': d['rejectionReason'] ?? '',
          'requestNumber': d['requestNumber'] ?? 0,
        };
      }).toList();

      List<Map<String, dynamic>> filteredData = data;
      if (_filterDepartment != 'all') {
        filteredData = data.where((d) {
          final deptId = d['departmentId'] ?? '';
          final deptName = d['department'] ?? '';
          final selectedDept = _departments.firstWhere(
            (dept) => dept['id'] == _filterDepartment,
            orElse: () => {},
          );
          final selectedDeptName = selectedDept['name'] ?? '';
          return deptId == _filterDepartment ||
              deptName == selectedDeptName ||
              deptName.contains(selectedDeptName.replaceAll(' Department', ''));
        }).toList();
      }

      setState(() {
        _allReportData = data;
        _reportData = filteredData;
        _summary = _calculateSummary(filteredData);
        _isLoading = false;
        _userNameCache.clear();
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _reportData = [];
        _allReportData = [];
        _summary = {};
      });
    }
  }

  Map<String, dynamic> _calculateSummary(List<Map<String, dynamic>> data) {
    int total = data.length;
    int pending = data.where((d) => d['status'] == 'pending').length;
    int approved = data.where((d) => d['status'] == 'approved').length;
    int rejected = data.where((d) => d['status'] == 'rejected').length;
    int autoApproved = data.where((d) => d['autoApproved'] == true).length;
    int totalDays = data.fold(0, (sum, d) => sum + (d['totalDays'] as int));

    return {
      'total': total,
      'pending': pending,
      'approved': approved,
      'rejected': rejected,
      'autoApproved': autoApproved,
      'totalDays': totalDays,
    };
  }

  List<Map<String, dynamic>> get _filteredData {
    if (_currentSegment == 0) return _reportData;
    String targetStatus;
    switch (_currentSegment) {
      case 1:
        targetStatus = 'pending';
        break;
      case 2:
        targetStatus = 'approved';
        break;
      case 3:
        targetStatus = 'rejected';
        break;
      default:
        return _reportData;
    }
    return _reportData.where((item) => item['status'] == targetStatus).toList();
  }

  Future<void> _exportToExcel() async {
    if (_reportData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No data to export'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      var excelFile = excel.Excel.createExcel();
      excel.Sheet sheet = excelFile['Report'];

      final headers = [
        'No.',
        'Staff Name',
        'Email',
        'Department',
        'Start Date',
        'End Date',
        'Total Days',
        'Reason',
        'Status',
        'Type',
        'Request #',
        'Created At (Cambodia Time)',
        'Approved By',
        'Rejection Reason',
      ];

      sheet.appendRow(headers);
      for (int col = 0; col < headers.length; col++) {
        var cell = sheet.cell(
          excel.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0),
        );
        cell.cellStyle = excel.CellStyle(
          bold: true,
          backgroundColorHex: '#173B69',
          fontColorHex: '#FFFFFF',
        );
      }

      for (int i = 0; i < _reportData.length; i++) {
        final r = _reportData[i];
        final String cambodiaTime = _formatToCambodiaTime(r['createdAt']);
        String fullName = r['userName'] ?? 'Unknown';
        if (r['userId'] != null && r['userId'].isNotEmpty) {
          final cachedName = _userNameCache[r['userId']];
          if (cachedName != null) {
            fullName = cachedName;
          } else {
            final fetchedName = await _getUserFullName(r['userId']);
            _userNameCache[r['userId']] = fetchedName;
            fullName = fetchedName;
          }
        }

        sheet.appendRow([
          (i + 1),
          fullName,
          r['userEmail'],
          r['department'] ?? 'N/A',
          r['startDate'],
          r['endDate'],
          r['totalDays'],
          r['reason'],
          r['status'].toUpperCase(),
          r['autoApproved'] ? 'Auto' : 'Manual',
          r['requestNumber'],
          cambodiaTime,
          r['approvedByName'] ?? '',
          r['rejectionReason'] ?? '',
        ]);
      }

      final colWidths = [6, 20, 25, 20, 15, 15, 12, 25, 14, 10, 12, 25, 18, 25];
      for (int i = 0; i < colWidths.length; i++) {
        sheet.setColWidth(i, colWidths[i].toDouble());
      }

      final dir = await getTemporaryDirectory();
      final fileName = 'report_${_selectedReportType}_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';
      final filePath = '${dir.path}/$fileName';

      final fileBytes = excelFile.encode();
      if (fileBytes != null) {
        File(filePath)
          ..createSync(recursive: true)
          ..writeAsBytesSync(fileBytes);

        final result = await OpenFile.open(filePath);
        if (result.type != ResultType.done) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not open file: ${result.message}'),
              backgroundColor: Colors.red,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(' Exported: $fileName'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export error: $e'),
          backgroundColor: Colors.red,
        ),
      );
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
      setState(() {
        _selectedDate = picked;
      });
      _loadReport();
    }
  }

  String _getDateLabel() {
    switch (_selectedReportType) {
      case 'daily':
        return DateFormat('dd MMM yyyy').format(_selectedDate);
      case 'weekly':
        return _getWeekLabel(_selectedDate);
      case 'monthly':
        return DateFormat('MMMM yyyy').format(_selectedDate);
      case 'yearly':
        return DateFormat('yyyy').format(_selectedDate);
      default:
        return '';
    }
  }

  String _getCurrentDepartmentName() {
    if (_filterDepartment == 'all') {
      return 'All Departments';
    }
    final dept = _departments.firstWhere(
      (d) => d['id'] == _filterDepartment,
      orElse: () => {},
    );
    return dept['name'] ?? 'Unknown Department';
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      case 'pending':
        return 'Pending';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = Responsive.isMobile(context);
    final double fontSize = Responsive.fontSize(context, 14);
    final double spacing = Responsive.spacing(context);
    final double iconSize = Responsive.iconSize(context, 20);
    double bottomPadding = MediaQuery.of(context).padding.bottom + 24;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF173B69),
        elevation: 2,
        title: const Text(
          'Reports',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        centerTitle: false,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            onPressed: _exportToExcel,
            icon: const Icon(Icons.file_download),
            tooltip: 'Export to Excel',
          ),
        ],
        // ===== SEGMENT IN APPBAR (BOTTOM) =====
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
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  )
                                ]
                              : null,
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
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF173B69)),
                ),
              )
            : Column(
                children: [
                  // ===== FILTER ROW =====
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        // Report Type
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
                                icon: const Icon(
                                  Icons.arrow_drop_down,
                                  color: Color(0xFF173B69),
                                ),
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
                                    _loadReport();
                                  }
                                },
                                style: TextStyle(
                                  fontSize: fontSize,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF173B69),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Date Picker
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
                                  const Icon(
                                    Icons.calendar_today,
                                    size: 16,
                                    color: Color(0xFF173B69),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _getDateLabel(),
                                      style: TextStyle(
                                        fontSize: fontSize,
                                        fontWeight: FontWeight.w500,
                                        color: const Color(0xFF173B69),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Department Filter
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
                                value: _filterDepartment,
                                icon: const Icon(
                                  Icons.arrow_drop_down,
                                  color: Color(0xFF173B69),
                                ),
                                isExpanded: true,
                                items: [
                                  const DropdownMenuItem(
                                    value: 'all',
                                    child: Text('All Dept'),
                                  ),
                                  ..._departments.map((dept) {
                                    return DropdownMenuItem(
                                      value: dept['id'],
                                      child: Text(dept['name']!),
                                    );
                                  }),
                                ],
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() => _filterDepartment = value);
                                    _loadReport();
                                  }
                                },
                                style: TextStyle(
                                  fontSize: fontSize * 0.85,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF173B69),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // ===== LIST =====
                  Expanded(
                    child: _filteredData.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.inbox_outlined,
                                  size: 64,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _filterDepartment == 'all'
                                      ? 'No data found'
                                      : 'No data found for ${_getCurrentDepartmentName()}',
                                  style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: fontSize,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: EdgeInsets.only(
                              left: 16,
                              right: 16,
                              top: 8,
                              bottom: bottomPadding,
                            ),
                            itemCount: _filteredData.length,
                            itemBuilder: (context, index) {
                              final r = _filteredData[index];
                              return _buildReportCard(r, isMobile, fontSize, spacing);
                            },
                          ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildReportCard(Map<String, dynamic> r, bool isMobile, double fontSize, double spacing) {
    final Color statusColor = _getStatusColor(r['status'] ?? 'pending');
    final String statusLabel = _getStatusLabel(r['status'] ?? 'pending');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          // Navigate to detail if needed
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1: Name + Status
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r['userName'] ?? 'Unknown',
                          style: TextStyle(
                            fontSize: isMobile ? fontSize : fontSize + 2,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        if (r['department'] != null && r['department'].isNotEmpty)
                          Text(
                            r['department'],
                            style: TextStyle(
                              fontSize: isMobile ? fontSize * 0.7 : fontSize * 0.85,
                              color: Colors.grey.shade600,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      statusLabel.toUpperCase(),
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: isMobile ? fontSize * 0.7 : fontSize * 0.85,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Row 2: Date Range
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${r['startDate'] ?? 'N/A'} → ${r['endDate'] ?? 'N/A'}',
                      style: TextStyle(
                        fontSize: isMobile ? fontSize * 0.75 : fontSize * 0.9,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // Row 3: Reason + Days
              Row(
                children: [
                  Icon(Icons.note, size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      r['reason'] ?? 'No reason',
                      style: TextStyle(
                        fontSize: isMobile ? fontSize * 0.75 : fontSize * 0.9,
                        color: Colors.grey.shade700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${r['totalDays'] ?? 0}d',
                      style: TextStyle(
                        fontSize: isMobile ? fontSize * 0.7 : fontSize * 0.85,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // Row 4: Time + Type + Request #
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: r['autoApproved'] == true
                          ? Colors.purple.withValues(alpha: 0.1)
                          : Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      r['autoApproved'] == true ? 'Auto' : 'Manual',
                      style: TextStyle(
                        fontSize: isMobile ? fontSize * 0.65 : fontSize * 0.8,
                        color: r['autoApproved'] == true ? Colors.purple : Colors.orange,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Text(
                    '#${r['requestNumber'] ?? 0}',
                    style: TextStyle(
                      fontSize: isMobile ? fontSize * 0.65 : fontSize * 0.8,
                      color: Colors.grey.shade500,
                    ),
                  ),
                  Text(
                    _formatToCambodiaTime(r['createdAt']),
                    style: TextStyle(
                      fontSize: isMobile ? fontSize * 0.65 : fontSize * 0.8,
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              // Rejection Reason / Approved By
              if (r['rejectionReason'] != null && r['rejectionReason'].isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Rejected: ${r['rejectionReason']}',
                    style: TextStyle(
                      fontSize: isMobile ? fontSize * 0.7 : fontSize * 0.85,
                      color: Colors.red.shade700,
                    ),
                  ),
                ),
              if (r['approvedByName'] != null && r['approvedByName'].isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Approved by: ${r['approvedByName']}',
                    style: TextStyle(
                      fontSize: isMobile ? fontSize * 0.7 : fontSize * 0.85,
                      color: Colors.green.shade700,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}