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
  final String? department;  // added department field

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
  
  List<TodayRequest> _requests = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _filterStatus = 'all';
  
  String _managerDepartment = '';
  bool _isManager = false;

  @override
  void initState() {
    super.initState();
    _checkManagerDepartment();
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
        
        if (roleId == '3') {
          _isManager = true;
          _managerDepartment = data['department'] ?? '';
          print('✅ Manager department: $_managerDepartment');
        } else {
          _isManager = false;
          _managerDepartment = '';
        }
      }
    } catch (e) {
      print('❌ Error checking manager department: $e');
    }

    _loadTodayRequests();
  }

  // ==================== LOAD TODAY'S REQUESTS ====================
  Future<void> _loadTodayRequests() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day, 0, 0, 0);
      final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

      final startTimestamp = Timestamp.fromDate(startOfDay);
      final endTimestamp = Timestamp.fromDate(endOfDay);

      // ============ QUERY (no department, no orderBy) ============
      Query query = _firestore
          .collection('leave_requests')
          .where('createdAt', isGreaterThanOrEqualTo: startTimestamp)
          .where('createdAt', isLessThanOrEqualTo: endTimestamp);

      final querySnapshot = await query.get();
      
      print('📊 Total requests today: ${querySnapshot.docs.length}');
      
      // ============ Convert to TodayRequest ============
      List<TodayRequest> allRequests = querySnapshot.docs
          .map((doc) => TodayRequest.fromFirestore(doc))
          .toList();
      
      // ============ Filter by Department (if Manager) ============
      if (_isManager && _managerDepartment.isNotEmpty) {
        allRequests = allRequests.where((r) {
          return r.department == _managerDepartment;
        }).toList();
        
        print('🔍 Filtered by department: $_managerDepartment');
        print('📊 After filter: ${allRequests.length} requests');
      }
      
      // ============ Sort by date ============
      allRequests.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      setState(() {
        _requests = allRequests;
        _isLoading = false;
      });
      
      print('✅ Loaded ${_requests.length} requests for today');
    } catch (e) {
      print('❌ Error loading requests: $e');
      setState(() {
        _requests = [];
        _isLoading = false;
      });
    }
  }

  Future<void> _refresh() async {
    await _loadTodayRequests();
  }

  List<TodayRequest> get _filteredRequests {
    var filtered = _requests;

    if (_filterStatus != 'all') {
      filtered = filtered.where((r) {
        if (_filterStatus == 'auto_approved') {
          return r.autoApproved;
        }
        return r.status == _filterStatus;
      }).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((r) {
        return r.staffName.toLowerCase().contains(query) ||
            r.userEmail.toLowerCase().contains(query) ||
            r.reason.toLowerCase().contains(query) ||
            r.requestId.toLowerCase().contains(query) ||
            (r.department?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    return filtered;
  }

  Map<String, int> get _stats {
    final stats = {
      'total': _requests.length,
      'pending': 0,
      'approved': 0,
      'rejected': 0,
      'autoApproved': 0,
      'totalDays': 0,
    };

    for (var r in _requests) {
      if (r.status == 'pending') {
        stats['pending'] = (stats['pending'] ?? 0) + 1;
      } else if (r.status == 'approved') {
        stats['approved'] = (stats['approved'] ?? 0) + 1;
        if (r.autoApproved) {
          stats['autoApproved'] = (stats['autoApproved'] ?? 0) + 1;
        }
      } else if (r.status == 'rejected') {
        stats['rejected'] = (stats['rejected'] ?? 0) + 1;
      }
      stats['totalDays'] = (stats['totalDays'] ?? 0) + r.totalDays;
    }

    return stats;
  }

  Future<void> _exportToExcel() async {
    final filtered = _filteredRequests;
    if (filtered.isEmpty) {
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
      excel.Sheet sheet = excelFile['Permission Today'];

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
        'Department',  // added Department column
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

      for (int i = 0; i < filtered.length; i++) {
        final r = filtered[i];
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
          r.department ?? '',
        ]);
      }

      final colWidths = [6, 12, 20, 25, 15, 15, 12, 25, 14, 14, 16, 20, 20];
      for (int i = 0; i < colWidths.length; i++) {
        sheet.setColWidth(i, colWidths[i].toDouble());
      }

      final dir = await getTemporaryDirectory();
      final fileName = 'permission_today_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';
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

  @override
  Widget build(BuildContext context) {
    final stats = _stats;
    final filtered = _filteredRequests;

    String departmentDisplay = _isManager && _managerDepartment.isNotEmpty
        ? '📁 $_managerDepartment'
        : '';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Permission Today',
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
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(90),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.calendar_today, size: 16, color: Colors.white70),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('EEEE, dd MMMM yyyy').format(DateTime.now()),
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
                      child: TextField(
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value;
                          });
                        },
                        style: TextStyle(fontSize: AppFonts.md),
                        decoration: InputDecoration(
                          hintText: '🔍 Search...',
                          hintStyle: TextStyle(fontSize: AppFonts.md, color: Colors.grey),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.9),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 0,
                          ),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    setState(() {
                                      _searchQuery = '';
                                    });
                                  },
                                )
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: DropdownButton<String>(
                        value: _filterStatus,
                        icon: const Icon(Icons.filter_list),
                        underline: const SizedBox(),
                        style: TextStyle(fontSize: AppFonts.md, color: Colors.black),
                        items: [
                          const DropdownMenuItem(value: 'all', child: Text('All')),
                          const DropdownMenuItem(value: 'pending', child: Text('⏳ Pending')),
                          const DropdownMenuItem(value: 'approved', child: Text('✅ Approved')),
                          const DropdownMenuItem(value: 'auto_approved', child: Text('🤖 Auto')),
                          const DropdownMenuItem(value: 'rejected', child: Text('❌ Rejected')),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _filterStatus = value!;
                          });
                        },
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
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      _StatCard(
                        label: 'Total',
                        value: stats['total']?.toString() ?? '0',
                        color: const Color(0xFF173B69),
                      ),
                      _StatCard(
                        label: 'Pending',
                        value: stats['pending']?.toString() ?? '0',
                        color: Colors.orange,
                      ),
                      _StatCard(
                        label: 'Approved',
                        value: stats['approved']?.toString() ?? '0',
                        color: Colors.green,
                      ),
                      _StatCard(
                        label: 'Rejected',
                        value: stats['rejected']?.toString() ?? '0',
                        color: Colors.red,
                      ),
                      _StatCard(
                        label: 'Total Days',
                        value: stats['totalDays']?.toString() ?? '0',
                        color: Colors.purple,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.inbox, size: 64, color: Colors.grey),
                              const SizedBox(height: 16),
                              Text(
                                'No requests found for today',
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
                              const SizedBox(height: 8),
                              Text(
                                'Check back later',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: AppFonts.md,
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
                ),
              ],
            ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
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
                fontSize: AppFonts.md,
                color: Colors.grey[600],
              ),
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

  @override
  Widget build(BuildContext context) {
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
                    request.autoApproved ? '🤖 Auto' : '👤 Manual',
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