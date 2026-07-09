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
  
  // ⏰ Custom Filter
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isCustomFilter = false;
  
  // ⏰ Available dates with data
  List<DateTime> _availableDates = [];
  bool _isLoadingDates = false;
  
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

  // ============================================================
  // ⏰ Get available dates with data
  // ============================================================
  Future<List<DateTime>> _getAvailableDates() async {
    setState(() {
      _isLoadingDates = true;
    });
    
    try {
      Query query = _firestore.collection('leave_requests');
      
      if (_isManager && _managerDepartment.isNotEmpty) {
        query = query.where('department', isEqualTo: _managerDepartment);
      }
      
      final snapshot = await query.get();
      
      Set<DateTime> uniqueDates = {};
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        if (createdAt != null) {
          final dateOnly = DateTime(createdAt.year, createdAt.month, createdAt.day);
          uniqueDates.add(dateOnly);
        }
      }
      
      final sortedDates = uniqueDates.toList()..sort((a, b) => a.compareTo(b));
      
      setState(() {
        _availableDates = sortedDates;
        _isLoadingDates = false;
      });
      
      return sortedDates;
    } catch (e) {
      print('❌ Error getting available dates: $e');
      setState(() {
        _isLoadingDates = false;
      });
      return [];
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

    await _getAvailableDates();
    _loadAllRequests();
  }

  // ==================== LOAD ALL REQUESTS ====================
  Future<void> _loadAllRequests() async {
    setState(() {
      _isLoading = true;
    });

    try {
      Query query = _firestore.collection('leave_requests');

      if (_isCustomFilter && _startDate != null && _endDate != null) {
        final startTimestamp = Timestamp.fromDate(_startDate!);
        final endTimestamp = Timestamp.fromDate(_endDate!);
        query = query
            .where('createdAt', isGreaterThanOrEqualTo: startTimestamp)
            .where('createdAt', isLessThanOrEqualTo: endTimestamp);
      }

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
    await _getAvailableDates();
    await _loadAllRequests();
  }

  // ============================================================
  // ⏰ Show Custom Filter Dialog - Simple Version
  // ============================================================
  Future<void> _showCustomFilterDialog() async {
    await _getAvailableDates();
    
    if (_availableDates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('📭 No data available to filter'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    // Determine current filter
    String selectedFilter = 'all';
    if (_isCustomFilter && _startDate != null && _endDate != null) {
      final now = DateTime.now();
      final sevenDaysAgo = now.subtract(const Duration(days: 7));
      final firstDayOfMonth = DateTime(now.year, now.month, 1);
      final lastDayOfMonth = DateTime(now.year, now.month + 1, 0);
      
      if (_startDate!.isAtSameMomentAs(_availableDates.first) && 
          _endDate!.isAtSameMomentAs(_availableDates.last)) {
        selectedFilter = 'all';
      }
      else if (_startDate!.isAfter(sevenDaysAgo) || _startDate!.isAtSameMomentAs(sevenDaysAgo)) {
        selectedFilter = 'last7days';
      }
      else if (_startDate!.isAfter(firstDayOfMonth.subtract(const Duration(days: 1))) &&
               _endDate!.isBefore(lastDayOfMonth.add(const Duration(days: 1)))) {
        selectedFilter = 'thismonth';
      }
      else {
        selectedFilter = 'custom';
      }
    }

    String tempFilter = selectedFilter;
    DateTime? tempStartDate = _startDate;
    DateTime? tempEndDate = _endDate;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.filter_alt, color: const Color(0xFF173B69)),
                const SizedBox(width: 8),
                const Text('Filter by Date'),
              ],
            ),
            content: SizedBox(
              width: 300,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '📅 ${_availableDates.length} days with data',
                                style: TextStyle(
                                  fontSize: AppFonts.md,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                              Text(
                                '${DateFormat('dd MMM yyyy').format(_availableDates.first)} - ${DateFormat('dd MMM yyyy').format(_availableDates.last)}',
                                style: TextStyle(
                                  fontSize: AppFonts.md,
                                  color: Colors.blue.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  _buildFilterOption(
                    context: context,
                    label: 'All Data',
                    icon: Icons.view_list,
                    isSelected: tempFilter == 'all',
                    onTap: () {
                      setStateDialog(() {
                        tempFilter = 'all';
                        tempStartDate = _availableDates.first;
                        tempEndDate = _availableDates.last;
                      });
                    },
                  ),
                  
                  const SizedBox(height: 8),
                  
                  _buildFilterOption(
                    context: context,
                    label: 'Last 7 Days',
                    icon: Icons.today,
                    isSelected: tempFilter == 'last7days',
                    onTap: () {
                      setStateDialog(() {
                        tempFilter = 'last7days';
                        final now = DateTime.now();
                        final sevenDaysAgo = now.subtract(const Duration(days: 7));
                        tempStartDate = _availableDates.firstWhere(
                          (d) => d.isAfter(sevenDaysAgo) || d.isAtSameMomentAs(sevenDaysAgo),
                          orElse: () => _availableDates.first,
                        );
                        tempEndDate = _availableDates.lastWhere(
                          (d) => d.isBefore(now) || d.isAtSameMomentAs(now),
                          orElse: () => _availableDates.last,
                        );
                      });
                    },
                  ),
                  
                  const SizedBox(height: 8),
                  
                  _buildFilterOption(
                    context: context,
                    label: 'This Month',
                    icon: Icons.calendar_month,
                    isSelected: tempFilter == 'thismonth',
                    onTap: () {
                      setStateDialog(() {
                        tempFilter = 'thismonth';
                        final now = DateTime.now();
                        final firstDay = DateTime(now.year, now.month, 1);
                        final lastDay = DateTime(now.year, now.month + 1, 0);
                        tempStartDate = _availableDates.firstWhere(
                          (d) => d.isAfter(firstDay.subtract(const Duration(days: 1))),
                          orElse: () => _availableDates.first,
                        );
                        tempEndDate = _availableDates.lastWhere(
                          (d) => d.isBefore(lastDay.add(const Duration(days: 1))),
                          orElse: () => _availableDates.last,
                        );
                      });
                    },
                  ),
                  
                  const SizedBox(height: 8),
                  
                  _buildFilterOption(
                    context: context,
                    label: 'Custom Range',
                    icon: Icons.calendar_today,
                    isSelected: tempFilter == 'custom',
                    onTap: () {
                      setStateDialog(() {
                        tempFilter = 'custom';
                        if (tempStartDate == null) tempStartDate = _availableDates.first;
                        if (tempEndDate == null) tempEndDate = _availableDates.last;
                      });
                    },
                  ),
                  
                  if (tempFilter == 'custom') ...[
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 12),
                    
                    _buildSimpleDatePicker(
                      context: context,
                      label: 'Start Date',
                      date: tempStartDate ?? _availableDates.first,
                      availableDates: _availableDates,
                      onChanged: (date) {
                        setStateDialog(() {
                          tempStartDate = date;
                        });
                      },
                    ),
                    
                    const SizedBox(height: 8),
                    
                    _buildSimpleDatePicker(
                      context: context,
                      label: 'End Date',
                      date: tempEndDate ?? _availableDates.last,
                      availableDates: _availableDates,
                      onChanged: (date) {
                        setStateDialog(() {
                          tempEndDate = date;
                        });
                      },
                    ),
                    
                    if (tempStartDate != null && tempEndDate != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.green.shade700, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${DateFormat('dd MMM yyyy').format(tempStartDate!)} - ${DateFormat('dd MMM yyyy').format(tempEndDate!)}',
                                style: TextStyle(
                                  fontSize: AppFonts.md,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.green.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                  
                  if (tempFilter != 'custom' && tempStartDate != null && tempEndDate != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.blue.shade700, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${DateFormat('dd MMM yyyy').format(tempStartDate!)} - ${DateFormat('dd MMM yyyy').format(tempEndDate!)}',
                              style: TextStyle(
                                fontSize: AppFonts.md,
                                fontWeight: FontWeight.w500,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (tempStartDate != null && tempEndDate != null) {
                    setState(() {
                      _startDate = tempStartDate;
                      _endDate = tempEndDate;
                      _isCustomFilter = true;
                    });
                    Navigator.pop(context);
                    _loadAllRequests();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please select a date range'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF173B69),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Apply'),
              ),
            ],
          );
        },
      ),
    );
  }

  // ============================================================
  // ⏰ Filter Option Widget
  // ============================================================
  Widget _buildFilterOption({
    required BuildContext context,
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF173B69).withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFF173B69) : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFF173B69) : Colors.grey.shade600,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: AppFonts.md,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? const Color(0xFF173B69) : Colors.black87,
                ),
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: const Color(0xFF173B69),
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // ⏰ Simple Date Picker Widget
  // ============================================================
  Widget _buildSimpleDatePicker({
    required BuildContext context,
    required String label,
    required DateTime? date,
    required List<DateTime> availableDates,
    required Function(DateTime) onChanged,
  }) {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date ?? availableDates.first,
          firstDate: availableDates.first,
          lastDate: availableDates.last,
        );
        if (picked != null) {
          if (availableDates.any((d) =>
              d.year == picked.year &&
              d.month == picked.month &&
              d.day == picked.day)) {
            onChanged(picked);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('❌ No data on ${DateFormat('dd MMM yyyy').format(picked)}'),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(10),
          color: Colors.white,
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today, color: const Color(0xFF173B69), size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: AppFonts.md,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  Text(
                    date != null
                        ? DateFormat('dd MMM yyyy').format(date!)
                        : 'Select date',
                    style: TextStyle(
                      fontSize: AppFonts.md,
                      fontWeight: FontWeight.w500,
                      color: date != null ? Colors.black : Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: Colors.grey.shade400, size: 14),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // ⏰ Clear Custom Filter
  // ============================================================
  void _clearFilter() {
    setState(() {
      _startDate = null;
      _endDate = null;
      _isCustomFilter = false;
      _filterStatus = 'all';
    });
    _loadAllRequests();
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
        'Created At',
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
          DateFormat('dd/MM/yyyy HH:mm').format(r.createdAt),
          submitTimeDisplay,
          r.department ?? '',
        ]);
      }

      final colWidths = [6, 12, 20, 25, 15, 15, 12, 25, 14, 14, 16, 20, 18, 20];
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

  String _getFilterLabel() {
    if (_isCustomFilter && _startDate != null && _endDate != null) {
      return '${DateFormat('dd MMM').format(_startDate!)} - ${DateFormat('dd MMM yyyy').format(_endDate!)}';
    }
    if (_availableDates.isNotEmpty) {
      return 'All Data (${DateFormat('dd MMM').format(_availableDates.first)} - ${DateFormat('dd MMM yyyy').format(_availableDates.last)})';
    }
    return 'All Time';
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredRequests;
    final String departmentDisplay = _isManager && _managerDepartment.isNotEmpty
        ? '$_managerDepartment'
        : '';

    return Scaffold(
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
          IconButton(
            icon: const Icon(Icons.filter_alt),
            onPressed: _showCustomFilterDialog,
            tooltip: 'Custom Filter',
          ),
          if (_isCustomFilter || _filterStatus != 'all')
            IconButton(
              icon: const Icon(Icons.clear_all),
              onPressed: _clearFilter,
              tooltip: 'Clear Filter',
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(110),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.filter_alt, size: 16, color: Colors.white70),
                    const SizedBox(width: 8),
                    Text(
                      'Filter: ${_getFilterLabel()}',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: AppFonts.md,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (departmentDisplay.isNotEmpty) ...[
                      const SizedBox(width: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          departmentDisplay,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: AppFonts.md,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: DropdownButton<String>(
                          value: _filterStatus,
                          icon: const Icon(Icons.filter_list),
                          underline: const SizedBox(),
                          isExpanded: true,
                          style: TextStyle(fontSize: AppFonts.md, color: Colors.black),
                          items: [
                            const DropdownMenuItem(value: 'all', child: Text('All Status')),
                            const DropdownMenuItem(value: 'pending', child: Text(' Pending')),
                            const DropdownMenuItem(value: 'approved', child: Text(' Approved')),
                            const DropdownMenuItem(value: 'auto_approved', child: Text(' Auto Approved')),
                            const DropdownMenuItem(value: 'rejected', child: Text(' Rejected')),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _filterStatus = value!;
                              _applyFilters();
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, size: 16, color: Colors.grey[700]),
                          const SizedBox(width: 4),
                          Text(
                            '${filtered.length}',
                            style: TextStyle(
                              fontSize: AppFonts.md,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF173B69),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inbox, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        '📭 No requests found',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: AppFonts.md,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (_availableDates.isNotEmpty)
                        Text(
                          'Available data: ${DateFormat('dd MMM yyyy').format(_availableDates.first)} - ${DateFormat('dd MMM yyyy').format(_availableDates.last)}',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: AppFonts.md,
                          ),
                        ),
                      Text(
                        _getFilterLabel(),
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: AppFonts.md,
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
                        onPressed: _showCustomFilterDialog,
                        icon: const Icon(Icons.filter_alt),
                        label: const Text('Change Filter'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF173B69),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final r = filtered[index];
                    return _RequestCard(request: r);
                  },
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

  @override
  Widget build(BuildContext context) {
    final submitTimeDisplay = _formatSubmitTime(request.submitTime);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: _statusColor.withOpacity(0.2),
                  child: Icon(
                    _statusIcon,
                    color: _statusColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
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
                          fontSize: AppFonts.md,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _statusColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    request.status.toUpperCase(),
                    style: TextStyle(
                      color: _statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: AppFonts.md,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '📅 ${request.startDate} → ${request.endDate}',
                        style: TextStyle(
                          fontSize: AppFonts.md,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '📝 ${request.reason}',
                        style: TextStyle(
                          fontSize: AppFonts.md,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '🕐 Submitted: $submitTimeDisplay',
                        style: TextStyle(
                          fontSize: AppFonts.md,
                          color: Colors.blue[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${request.totalDays} day${request.totalDays > 1 ? 's' : ''}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                          fontSize: AppFonts.md,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ID #${request.requestNumber}',
                      style: TextStyle(
                        fontSize: AppFonts.md,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: request.autoApproved
                        ? Colors.purple.withOpacity(0.1)
                        : Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    request.autoApproved ? ' Auto' : ' Manual',
                    style: TextStyle(
                      fontSize: AppFonts.md,
                      color: request.autoApproved ? Colors.purple : Colors.orange,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (request.approvedByName != null)
                  Text(
                    'by ${request.approvedByName}',
                    style: TextStyle(
                      fontSize: AppFonts.md,
                      color: Colors.grey[500],
                    ),
                  ),
                const Spacer(),
                Text(
                  DateFormat('HH:mm').format(request.createdAt),
                  style: TextStyle(
                    fontSize: AppFonts.md,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
            if (request.status == 'rejected' && request.rejectionReason != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.red[300], size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Rejected: ${request.rejectionReason}',
                          style: TextStyle(
                            fontSize: AppFonts.md,
                            color: Colors.red[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}