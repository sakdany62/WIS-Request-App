// lib/screens/staff/list_staff_screen.dart
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
    return TodayRequest(
      requestId: doc.id,
      userId: data['userId'] ?? '',
      staffName: data['userName'] ?? data['userEmail'] ?? 'Unknown',
      userEmail: data['userEmail'] ?? '',
      reason: data['reason'] ?? 'No reason',
      startDate: data['startDate'] ?? '',
      endDate: data['endDate'] ?? '',
      totalDays: (data['totalDays'] as num?)?.toInt() ?? 0,
      status: data['status'] ?? 'pending',
      approvalType: data['autoApproved'] == true ? 'Auto' : 'Manual',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      autoApproved: data['autoApproved'] ?? false,
      requestNumber: (data['requestNumber'] as num?)?.toInt() ?? 0,
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
  String _filterStatus = 'all';
  
  String _selectedReportType = 'daily';
  DateTime _selectedDate = DateTime.now();
  
  String _managerDepartment = '';
  bool _isManager = false;

  @override
  void initState() {
    super.initState();
    _checkManagerDepartment();
  }

  String _formatSubmitTime(dynamic submitTime) {
    if (submitTime == null) return 'N/A';
    
    try {
      if (submitTime is String) {
        String cleaned = submitTime.trim();
        if (cleaned.contains('AM') || cleaned.contains('PM')) {
          return cleaned;
        }
      }
      
      DateTime? parsedDateTime;
      bool isUTC = false;
      
      if (submitTime is String) {
        String cleaned = submitTime.trim();
        
        if (cleaned.contains('T') && cleaned.endsWith('Z')) {
          try {
            parsedDateTime = DateTime.parse(cleaned);
            isUTC = true;
          } catch (e) {}
        } else if (cleaned.contains('T')) {
          try {
            parsedDateTime = DateTime.parse(cleaned);
            isUTC = false;
          } catch (e) {}
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
              isUTC = false;
            }
          }
        }
      }
      else if (submitTime is Timestamp) {
        parsedDateTime = submitTime.toDate();
        isUTC = true;
      }
      else if (submitTime is DateTime) {
        parsedDateTime = submitTime;
        isUTC = submitTime.isUtc;
      }
      
      if (parsedDateTime == null) {
        return submitTime.toString();
      }
      
      DateTime cambodiaTime;
      if (isUTC) {
        cambodiaTime = parsedDateTime.toUtc().add(const Duration(hours: 7));
      } else {
        cambodiaTime = parsedDateTime;
      }
      
      int hour = cambodiaTime.hour;
      final int minute = cambodiaTime.minute;
      final String period = hour >= 12 ? 'PM' : 'AM';
      
      if (hour == 0) {
        hour = 12;
      } else if (hour > 12) {
        hour = hour - 12;
      }
      
      return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
      
    } catch (e) {
      return 'N/A';
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
      
      DateTime cambodiaTime;
      if (isUTC) {
        cambodiaTime = parsedDateTime.toUtc().add(const Duration(hours: 7));
      } else {
        cambodiaTime = parsedDateTime;
      }
      
      return DateFormat('dd/MM/yyyy hh:mm a').format(cambodiaTime);
      
    } catch (e) {
      print('❌ Error formatting timestamp: $e');
      return 'N/A';
    }
  }

  String _getDateLabel() {
    switch (_selectedReportType) {
      case 'daily':
        return DateFormat('dd MMM yyyy').format(_selectedDate);
      case 'monthly':
        return DateFormat('MMMM yyyy').format(_selectedDate);
      case 'yearly':
        return DateFormat('yyyy').format(_selectedDate);
      default:
        return '';
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
      _loadAllRequests();
    }
  }

  Future<void> _checkManagerDepartment() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
      return;
    }

    try {
      final querySnapshot = await _firestore
          .collection('users')
          .where('userId', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final data = querySnapshot.docs.first.data() as Map<String, dynamic>;
        final roleId = data['roleId']?.toString() ?? '2';
        
        if (roleId == '3' || roleId == '4') {
          _isManager = true;
          _managerDepartment = data['department'] ?? '';
          print('Manager department: $_managerDepartment');
        } else {
          _isManager = false;
          _managerDepartment = '';
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
    });

    try {
      DateTime startDate;
      DateTime endDate;

      switch (_selectedReportType) {
        case 'daily':
          startDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
          endDate = startDate.add(const Duration(days: 1));
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
          .where('createdAt', isLessThan: endTimestamp);

      final querySnapshot = await query.get();
      
      print('📊 Total requests: ${querySnapshot.docs.length}');
      
      List<TodayRequest> allRequests = querySnapshot.docs
          .map((doc) => TodayRequest.fromFirestore(doc))
          .toList();
      
      if (_isManager && _managerDepartment.isNotEmpty) {
        allRequests = allRequests.where((r) {
          return r.department == _managerDepartment;
        }).toList();
        
        print('🔍 Filtered by department: $_managerDepartment');
        print('📊 After filter: ${allRequests.length} requests');
      }
      
      allRequests.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      setState(() {
        _allRequests = allRequests;
        _applyFilters();
        _isLoading = false;
      });
      
      print('✅ Loaded ${_allRequests.length} requests');
    } catch (e) {
      print('❌ Error loading requests: $e');
      setState(() {
        _allRequests = [];
        _filteredRequests = [];
        _isLoading = false;
      });
    }
  }

  void _applyFilters() {
    var filtered = _allRequests;

    if (_filterStatus != 'all') {
      filtered = filtered.where((r) {
        if (_filterStatus == 'auto_approved') {
          return r.autoApproved;
        }
        return r.status == _filterStatus;
      }).toList();
    }

    setState(() {
      _filteredRequests = filtered;
    });
  }

  Future<void> _refresh() async {
    await _loadAllRequests();
  }

  void _clearFilter() {
    setState(() {
      _filterStatus = 'all';
    });
    _applyFilters();
  }

  Future<void> _exportToExcel() async {
    if (_filteredRequests.isEmpty) {
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
      excel.Sheet sheet = excelFile['Permission List'];

      final headers = [
        'No.',
        'Request ID',
        'Staff Name',
        'Email',
        'Start Date',
        'End Date',
        'Total Days',
        'Reason',
        'Status',
        'Approval Type',
        'Request Number',
        'Created At (Cambodia Time)',
        'Submit Time',
        'Department',
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

      for (int i = 0; i < _filteredRequests.length; i++) {
        final r = _filteredRequests[i];
        final submitTimeDisplay = _formatSubmitTime(r.submitTime);
        final createdAtDisplay = _formatToCambodiaTime(r.createdAt);
        
        sheet.appendRow([
          (i + 1),
          r.requestId.substring(0, 8),
          r.staffName,
          r.userEmail,
          r.startDate,
          r.endDate,
          r.totalDays,
          r.reason,
          r.status.toUpperCase(),
          r.approvalType,
          r.requestNumber,
          createdAtDisplay,
          submitTimeDisplay,
          r.department ?? '',
        ]);
      }

      final colWidths = [6, 12, 20, 25, 15, 15, 12, 25, 14, 14, 16, 25, 18, 20];
      for (int i = 0; i < colWidths.length; i++) {
        sheet.setColWidth(i, colWidths[i].toDouble());
      }

      final dir = await getTemporaryDirectory();
      final fileName = 'permission_list_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';
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
              content: Text('✅ Exported: $fileName'),
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

  Map<String, dynamic> _calculateSummary(List<TodayRequest> data) {
    int total = data.length;
    int pending = data.where((r) => r.status == 'pending').length;
    int approved = data.where((r) => r.status == 'approved').length;
    int rejected = data.where((r) => r.status == 'rejected').length;
    int autoApproved = data.where((r) => r.autoApproved == true).length;
    int totalDays = data.fold(0, (sum, r) => sum + r.totalDays);

    return {
      'total': total,
      'pending': pending,
      'approved': approved,
      'rejected': rejected,
      'autoApproved': autoApproved,
      'totalDays': totalDays,
    };
  }

  Widget _buildSummaryCard({
    required String label,
    required String value,
    required Color color,
    required bool isMobile,
    required double fontSize,
  }) {
    return Container(
      width: isMobile ? 60 : 70,
      padding: EdgeInsets.symmetric(
        vertical: isMobile ? 4 : 6,
        horizontal: isMobile ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: isMobile ? fontSize : fontSize + 2,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: isMobile ? 10 : 12,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = Responsive.isMobile(context);
    final double fontSize = Responsive.fontSize(context, 14);
    final double spacing = Responsive.spacing(context);
    final double iconSize = Responsive.iconSize(context, 20);

    final filtered = _filteredRequests;
    final summary = _calculateSummary(filtered);
    final String departmentDisplay = _isManager && _managerDepartment.isNotEmpty
        ? '$_managerDepartment'
        : '';

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(
          'Permission List',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: isMobile ? 16 : 18,
          ),
        ),
        backgroundColor: const Color(0xFF173B69),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, size: iconSize),
            onPressed: _refresh,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: Icon(Icons.file_download, size: iconSize),
            onPressed: _exportToExcel,
            tooltip: 'Export to Excel',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  // Filter Section
                  Container(
                    padding: EdgeInsets.symmetric(
                      vertical: spacing * 2,
                      horizontal: spacing,
                    ),
                    color: Colors.grey[100],
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _selectedReportType,
                                decoration: InputDecoration(
                                  labelText: 'Report Type',
                                  labelStyle: TextStyle(
                                    fontSize: fontSize,
                                    color: Colors.grey[700],
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(color: Colors.grey, width: 1.0),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(color: Colors.grey, width: 1.0),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(color: Color(0xFF173B69), width: 2.0),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white, // ✅ Background ពណ៌ស
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: spacing,
                                    vertical: isMobile ? 6 : 8,
                                  ),
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'daily',
                                    child: Text(' Daily'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'monthly',
                                    child: Text('Monthly'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'yearly',
                                    child: Text('Yearly'),
                                  ),
                                ],
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() {
                                      _selectedReportType = value;
                                    });
                                    _loadAllRequests();
                                  }
                                },
                                style: TextStyle(
                                  fontSize: fontSize,
                                  color: Colors.black, // ✅ អក្សរពណ៌ខ្មៅ
                                ),
                                dropdownColor: Colors.white, // ✅ Dropdown menu background ពណ៌ស
                                icon: const Icon(
                                  Icons.arrow_drop_down,
                                  color: Color(0xFF173B69),
                                ),
                              ),
                            ),
                            SizedBox(width: spacing),
                            SizedBox(
                              height: isMobile ? 44 : 50,
                              child: ElevatedButton.icon(
                                onPressed: _selectDate,
                                icon: Icon(Icons.calendar_today, size: iconSize - 2),
                                label: Text(
                                  _getDateLabel(),
                                  style: TextStyle(fontSize: isMobile ? 11 : 13),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF173B69),
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(horizontal: spacing),
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: spacing),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _filterStatus,
                                decoration: InputDecoration(
                                  labelText: 'Status Filter',
                                  labelStyle: TextStyle(
                                    fontSize: fontSize,
                                    color: Colors.grey[700],
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(color: Colors.grey, width: 1.0),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(color: Colors.grey, width: 1.0),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(color: Color(0xFF173B69), width: 2.0),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white, // ✅ Background ពណ៌ស
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: spacing,
                                    vertical: isMobile ? 6 : 8,
                                  ),
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'all',
                                    child: Text('All'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'pending',
                                    child: Text(' Pending'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'approved',
                                    child: Text(' Approved'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'auto_approved',
                                    child: Text(' Auto Approved'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'rejected',
                                    child: Text(' Rejected'),
                                  ),
                                ],
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() {
                                      _filterStatus = value;
                                    });
                                    _applyFilters();
                                  }
                                },
                                style: TextStyle(
                                  fontSize: fontSize,
                                  color: Colors.black, // ✅ អក្សរពណ៌ខ្មៅ
                                ),
                                dropdownColor: Colors.white, // ✅ Dropdown menu background ពណ៌ស
                                icon: const Icon(
                                  Icons.arrow_drop_down,
                                  color: Color(0xFF173B69),
                                ),
                              ),
                            ),
                            if (_filterStatus != 'all') ...[
                              SizedBox(width: spacing),
                              SizedBox(
                                height: isMobile ? 44 : 50,
                                child: ElevatedButton(
                                  onPressed: _clearFilter,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red.shade50,
                                    foregroundColor: Colors.red.shade700,
                                    padding: EdgeInsets.symmetric(horizontal: spacing),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      side: BorderSide(color: Colors.red.shade200),
                                    ),
                                  ),
                                  child: Text(
                                    'Clear',
                                    style: TextStyle(
                                      fontSize: isMobile ? 11 : 13,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (departmentDisplay.isNotEmpty)
                          Padding(
                            padding: EdgeInsets.only(top: spacing),
                            child: Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: spacing * 1.5,
                                    vertical: spacing,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.business,
                                        size: iconSize - 2,
                                        color: Colors.green,
                                      ),
                                      SizedBox(width: spacing / 2),
                                      Text(
                                        ' $departmentDisplay',
                                        style: TextStyle(
                                          fontSize: isMobile ? fontSize * 0.85 : fontSize,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.green,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Summary Cards
                  Container(
                    padding: EdgeInsets.symmetric(
                      vertical: spacing,
                      horizontal: spacing * 1.5,
                    ),
                    child: SizedBox(
                      height: isMobile ? 60 : 70,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          _buildSummaryCard(
                            label: 'Total',
                            value: summary['total'].toString(),
                            color: const Color(0xFF173B69),
                            isMobile: isMobile,
                            fontSize: fontSize,
                          ),
                          SizedBox(width: spacing / 2),
                          _buildSummaryCard(
                            label: 'Pending',
                            value: summary['pending'].toString(),
                            color: Colors.orange,
                            isMobile: isMobile,
                            fontSize: fontSize,
                          ),
                          SizedBox(width: spacing / 2),
                          _buildSummaryCard(
                            label: 'Approved',
                            value: summary['approved'].toString(),
                            color: Colors.green,
                            isMobile: isMobile,
                            fontSize: fontSize,
                          ),
                          SizedBox(width: spacing / 2),
                          _buildSummaryCard(
                            label: 'Rejected',
                            value: summary['rejected'].toString(),
                            color: Colors.red,
                            isMobile: isMobile,
                            fontSize: fontSize,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Total Days Card
                  Container(
                    margin: EdgeInsets.symmetric(horizontal: spacing * 1.5),
                    padding: EdgeInsets.symmetric(
                      vertical: spacing,
                      horizontal: spacing * 1.5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.purple.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.calendar_today,
                          color: Colors.purple,
                          size: iconSize - 2,
                        ),
                        SizedBox(width: spacing / 2),
                        Text(
                          'Total Days: ${summary['totalDays']}',
                          style: TextStyle(
                            fontSize: isMobile ? fontSize * 0.85 : fontSize,
                            fontWeight: FontWeight.bold,
                            color: Colors.purple,
                          ),
                        ),
                        SizedBox(width: spacing),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: spacing / 2,
                            vertical: spacing / 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.purple.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${summary['autoApproved']} Auto',
                            style: TextStyle(
                              fontSize: isMobile ? fontSize * 0.85 : fontSize,
                              color: Colors.purple,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: spacing),

                  // List of Requests
                  filtered.isEmpty
                      ? Padding(
                          padding: EdgeInsets.all(spacing * 5),
                          child: Column(
                            children: [
                              Icon(
                                Icons.inbox,
                                size: iconSize * 3,
                                color: Colors.grey,
                              ),
                              SizedBox(height: spacing * 2),
                              Text(
                                ' No requests found',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: fontSize,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (_isManager && _managerDepartment.isNotEmpty)
                                Text(
                                  'Department: $_managerDepartment',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: fontSize * 0.85,
                                  ),
                                ),
                              SizedBox(height: spacing * 2),
                              ElevatedButton.icon(
                                onPressed: _refresh,
                                icon: Icon(Icons.refresh, size: iconSize),
                                label: Text(
                                  'Refresh',
                                  style: TextStyle(fontSize: fontSize),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF173B69),
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: EdgeInsets.symmetric(
                            horizontal: spacing * 1.5,
                            vertical: spacing / 1.5,
                          ),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final r = filtered[index];
                            return _RequestCard(
                              request: r,
                              isMobile: isMobile,
                              fontSize: fontSize,
                              spacing: spacing,
                              iconSize: iconSize,
                            );
                          },
                        ),
                ],
              ),
            ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final TodayRequest request;
  final bool isMobile;
  final double fontSize;
  final double spacing;
  final double iconSize;

  const _RequestCard({
    required this.request,
    required this.isMobile,
    required this.fontSize,
    required this.spacing,
    required this.iconSize,
  });

  Color get _statusColor {
    switch (request.status) {
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

  IconData get _statusIcon {
    switch (request.status) {
      case 'approved':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      case 'pending':
        return Icons.hourglass_empty;
      default:
        return Icons.help_outline;
    }
  }

  String _formatSubmitTime(dynamic submitTime) {
    if (submitTime == null) return 'N/A';
    
    try {
      if (submitTime is String) {
        String cleaned = submitTime.trim();
        if (cleaned.contains('AM') || cleaned.contains('PM')) {
          return cleaned;
        }
      }
      
      DateTime? parsedDateTime;
      bool isUTC = false;
      
      if (submitTime is String) {
        String cleaned = submitTime.trim();
        
        if (cleaned.contains('T') && cleaned.endsWith('Z')) {
          try {
            parsedDateTime = DateTime.parse(cleaned);
            isUTC = true;
          } catch (e) {}
        } else if (cleaned.contains('T')) {
          try {
            parsedDateTime = DateTime.parse(cleaned);
            isUTC = false;
          } catch (e) {}
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
              isUTC = false;
            }
          }
        }
      }
      else if (submitTime is Timestamp) {
        parsedDateTime = submitTime.toDate();
        isUTC = true;
      }
      else if (submitTime is DateTime) {
        parsedDateTime = submitTime;
        isUTC = submitTime.isUtc;
      }
      
      if (parsedDateTime == null) {
        return submitTime.toString();
      }
      
      DateTime cambodiaTime;
      if (isUTC) {
        cambodiaTime = parsedDateTime.toUtc().add(const Duration(hours: 7));
      } else {
        cambodiaTime = parsedDateTime;
      }
      
      int hour = cambodiaTime.hour;
      final int minute = cambodiaTime.minute;
      final String period = hour >= 12 ? 'PM' : 'AM';
      
      if (hour == 0) {
        hour = 12;
      } else if (hour > 12) {
        hour = hour - 12;
      }
      
      return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
      
    } catch (e) {
      return 'N/A';
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
      
      DateTime cambodiaTime;
      if (isUTC) {
        cambodiaTime = parsedDateTime.toUtc().add(const Duration(hours: 7));
      } else {
        cambodiaTime = parsedDateTime;
      }
      
      return DateFormat('dd/MM/yyyy hh:mm a').format(cambodiaTime);
      
    } catch (e) {
      print('❌ Error formatting timestamp: $e');
      return 'N/A';
    }
  }

  @override
  Widget build(BuildContext context) {
    final submitTimeDisplay = _formatSubmitTime(request.submitTime);
    final createdAtDisplay = _formatToCambodiaTime(request.createdAt);

    return Card(
      margin: EdgeInsets.only(bottom: spacing / 2),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 8 : 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: isMobile ? 14 : 16,
                  backgroundColor: _statusColor.withOpacity(0.2),
                  child: Icon(
                    _statusIcon,
                    color: _statusColor,
                    size: isMobile ? 14 : 16,
                  ),
                ),
                SizedBox(width: spacing),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.staffName,
                        style: TextStyle(
                          fontSize: isMobile ? fontSize * 0.85 : fontSize,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        request.userEmail,
                        style: TextStyle(
                          fontSize: isMobile ? fontSize * 0.7 : 12,
                          color: Colors.grey[600],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: spacing / 2,
                    vertical: spacing / 4,
                  ),
                  decoration: BoxDecoration(
                    color: _statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    request.status.toUpperCase(),
                    style: TextStyle(
                      color: _statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: isMobile ? fontSize * 0.6 : 11,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: spacing / 2),
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: isMobile ? 10 : 12,
                  color: Colors.grey[600],
                ),
                SizedBox(width: spacing / 3),
                Expanded(
                  child: Text(
                    '${request.startDate} → ${request.endDate}',
                    style: TextStyle(
                      fontSize: isMobile ? fontSize * 0.7 : 12,
                      color: Colors.grey[700],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            SizedBox(height: spacing / 4),
            Row(
              children: [
                Icon(
                  Icons.note,
                  size: isMobile ? 10 : 12,
                  color: Colors.grey[600],
                ),
                SizedBox(width: spacing / 3),
                Expanded(
                  child: Text(
                    request.reason,
                    style: TextStyle(
                      fontSize: isMobile ? fontSize * 0.7 : 12,
                      color: Colors.grey[700],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: spacing / 2,
                    vertical: spacing / 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${request.totalDays} days',
                    style: TextStyle(
                      fontSize: isMobile ? fontSize * 0.65 : 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: spacing / 4),
            Wrap(
              spacing: spacing / 2,
              runSpacing: spacing / 4,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: spacing / 2,
                    vertical: spacing / 4,
                  ),
                  decoration: BoxDecoration(
                    color: request.autoApproved
                        ? Colors.purple.withOpacity(0.1)
                        : Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    request.autoApproved ? ' Auto' : ' Manual',
                    style: TextStyle(
                      fontSize: isMobile ? fontSize * 0.6 : 11,
                      color: request.autoApproved ? Colors.purple : Colors.orange,
                    ),
                  ),
                ),
                Text(
                  '#${request.requestNumber}',
                  style: TextStyle(
                    fontSize: isMobile ? fontSize * 0.6 : 11,
                    color: Colors.grey[500],
                  ),
                ),
                Text(
                  createdAtDisplay,
                  style: TextStyle(
                    fontSize: isMobile ? fontSize * 0.6 : 11,
                    color: Colors.blue[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            if (request.status == 'rejected' && request.rejectionReason != null)
              Padding(
                padding: EdgeInsets.only(top: spacing / 2),
                child: Text(
                  '⚠️ ${request.rejectionReason}',
                  style: TextStyle(
                    fontSize: isMobile ? fontSize * 0.7 : 12,
                    color: Colors.red[700],
                  ),
                ),
              ),
            if (request.approvedByName != null && request.approvedByName!.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(top: spacing / 4),
                child: Text(
                  ' Approved by: ${request.approvedByName}',
                  style: TextStyle(
                    fontSize: isMobile ? fontSize * 0.7 : 12,
                    color: Colors.green[700],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}