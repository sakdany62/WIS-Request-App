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
  
  // ⏰ Report Type & Date (Same as Admin Report)
  String _selectedReportType = 'daily';
  DateTime _selectedDate = DateTime.now();
  
  String _managerDepartment = '';
  bool _isManager = false;

  @override
  void initState() {
    super.initState();
    _checkManagerDepartment();
  }

  // ============================================================
  // ⏰ Format submit time to Cambodia time (UTC+7)
  // ============================================================
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

  // ⏰ Format time to Cambodia time (UTC+7) with AM/PM - Same as Admin Report
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
      
      // Convert to Cambodia time (UTC+7) if it's UTC
      DateTime cambodiaTime;
      if (isUTC) {
        cambodiaTime = parsedDateTime.toUtc().add(const Duration(hours: 7));
      } else {
        cambodiaTime = parsedDateTime;
      }
      
      // Format: dd/MM/yyyy hh:mm AM/PM
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

  // ==================== LOAD ALL REQUESTS ====================
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
  }) {
    return Container(
      width: 70,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
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
              fontSize: AppFonts.md,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
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
            fontSize: AppFonts.md,
          ),
        ),
        backgroundColor: const Color(0xFF173B69),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.file_download),
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
                  // Filter Section (Same as Admin Report)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                    color: Colors.grey[100],
                    child: Column(
                      children: [
                        // Row 1: Report Type & Date (Same as Admin Report)
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _selectedReportType,
                                decoration: InputDecoration(
                                  labelText: 'Report Type',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                                items: const [
                                  DropdownMenuItem(value: 'daily', child: Text(' Daily')),
                                  DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                                  DropdownMenuItem(value: 'yearly', child: Text('Yearly')),
                                ],
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() {
                                      _selectedReportType = value;
                                    });
                                    _loadAllRequests();
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              height: 50,
                              child: ElevatedButton.icon(
                                onPressed: _selectDate,
                                icon: const Icon(Icons.calendar_today, size: 18),
                                label: Text(
                                  _getDateLabel(),
                                  style: const TextStyle(fontSize: 13),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF173B69),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Row 2: Status Filter
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _filterStatus,
                                decoration: InputDecoration(
                                  labelText: 'Status Filter',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                                items: const [
                                  DropdownMenuItem(value: 'all', child: Text('All')),
                                  DropdownMenuItem(value: 'pending', child: Text(' Pending')),
                                  DropdownMenuItem(value: 'approved', child: Text(' Approved')),
                                  DropdownMenuItem(value: 'auto_approved', child: Text(' Auto Approved')),
                                  DropdownMenuItem(value: 'rejected', child: Text(' Rejected')),
                                ],
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() {
                                      _filterStatus = value;
                                    });
                                    _applyFilters();
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Clear Filters Button (next to status filter)
                            SizedBox(
                              height: 50,
                              child: _filterStatus != 'all'
                                  ? ElevatedButton(
                                      onPressed: _clearFilter,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red.shade50,
                                        foregroundColor: Colors.red.shade700,
                                        padding: const EdgeInsets.symmetric(horizontal: 12),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                          side: BorderSide(color: Colors.red.shade200),
                                        ),
                                      ),
                                      child: const Text(
                                        'Clear',
                                        style: TextStyle(fontSize: 13),
                                      ),
                                    )
                                  : null,
                            ),
                          ],
                        ),

                        // Row 3: Department Display (if manager)
                        if (departmentDisplay.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.business, size: 18, color: Colors.green),
                                      const SizedBox(width: 8),
                                      Text(
                                        ' $departmentDisplay',
                                        style: TextStyle(
                                          fontSize: AppFonts.md,
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

                  // Summary Cards (Same as Admin Report)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    child: SizedBox(
                      height: 70,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          _buildSummaryCard(
                            label: 'Total',
                            value: summary['total'].toString(),
                            color: const Color(0xFF173B69),
                          ),
                          const SizedBox(width: 6),
                          _buildSummaryCard(
                            label: 'Pending',
                            value: summary['pending'].toString(),
                            color: Colors.orange,
                          ),
                          const SizedBox(width: 6),
                          _buildSummaryCard(
                            label: 'Approved',
                            value: summary['approved'].toString(),
                            color: Colors.green,
                          ),
                          const SizedBox(width: 6),
                          _buildSummaryCard(
                            label: 'Rejected',
                            value: summary['rejected'].toString(),
                            color: Colors.red,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Total Days Card (Same as Admin Report)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.purple.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.calendar_today, color: Colors.purple, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          'Total Days: ${summary['totalDays']}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.purple,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.purple.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${summary['autoApproved']} Auto',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.purple,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  // List of Requests
                  filtered.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(40),
                          child: Column(
                            children: [
                              const Icon(
                                Icons.inbox,
                                size: 64,
                                color: Colors.grey,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                ' No requests found',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: AppFonts.md,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (_isManager && _managerDepartment.isNotEmpty)
                                Text(
                                  'Department: $_managerDepartment',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: AppFonts.md,
                                  ),
                                ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: _refresh,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Refresh'),
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
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final r = filtered[index];
                            return _RequestCard(request: r);
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

  const _RequestCard({required this.request});

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

  // ⏰ Format time to Cambodia time (UTC+7) with AM/PM - Same as Admin Report
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
      
      // Convert to Cambodia time (UTC+7) if it's UTC
      DateTime cambodiaTime;
      if (isUTC) {
        cambodiaTime = parsedDateTime.toUtc().add(const Duration(hours: 7));
      } else {
        cambodiaTime = parsedDateTime;
      }
      
      // Format: dd/MM/yyyy hh:mm AM/PM
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
      margin: const EdgeInsets.only(bottom: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: _statusColor.withOpacity(0.2),
                  child: Icon(
                    _statusIcon,
                    color: _statusColor,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.staffName,
                        style: TextStyle(
                          fontSize: AppFonts.md,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        request.userEmail,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    request.status.toUpperCase(),
                    style: TextStyle(
                      color: _statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 12, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  '${request.startDate} → ${request.endDate}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Row(
              children: [
                Icon(Icons.note, size: 12, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    request.reason,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[700],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${request.totalDays} days',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: request.autoApproved
                        ? Colors.purple.withOpacity(0.1)
                        : Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    request.autoApproved ? ' Auto' : ' Manual',
                    style: TextStyle(
                      fontSize: 11,
                      color: request.autoApproved ? Colors.purple : Colors.orange,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '#${request.requestNumber}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[500],
                  ),
                ),
                const SizedBox(width: 6),
                // Show Cambodia time with AM/PM
                Text(
                  createdAtDisplay,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.blue[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            if (request.status == 'rejected' && request.rejectionReason != null)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(
                  '⚠️ ${request.rejectionReason}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.red[700],
                  ),
                ),
              ),
            if (request.approvedByName != null && request.approvedByName!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  ' Approved by: ${request.approvedByName}',
                  style: TextStyle(
                    fontSize: 12,
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