// lib/screens/admin/report_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart' as excel;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:open_file/open_file.dart';
import '../../app_fonts.dart';

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

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ============ List of Departments ============
  final List<Map<String, String>> _departments = [
    {'id': 'dept_it', 'name': 'IT Department'},
    {'id': 'dept_education', 'name': 'Education Department'},
    {'id': 'dept_administration', 'name': 'Administration Department'},
    {'id': 'dept_service', 'name': 'Service Department'},
  ];

  // ⏰ Format time to Cambodia time (UTC+7) with AM/PM
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

      print('📊 Total leave requests found: ${querySnapshot.docs.length}');

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
          'userName': d['userName'] ?? 'Unknown',
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

      print('📊 Total data processed: ${data.length}');

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
        
        print('📊 Filtered by department: ${filteredData.length}');
      }

      setState(() {
        _allReportData = data;
        _reportData = filteredData;
        _summary = _calculateSummary(filteredData);
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Error loading report: $e');
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
        
        sheet.appendRow([
          (i + 1),
          r['userName'],
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
      case 'monthly':
        return DateFormat('MMMM yyyy').format(_selectedDate);
      case 'yearly':
        return DateFormat('yyyy').format(_selectedDate);
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
              decoration: const BoxDecoration(
                color: Color(0xFF173B69),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 48),
                  const Expanded(
                    child: Center(
                      child: Text(
                        "Reports",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: AppFonts.md,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _exportToExcel,
                    icon: const Icon(Icons.file_download, color: Colors.white),
                    tooltip: 'Export to Excel',
                  ),
                ],
              ),
            ),

            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
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
                                          labelStyle: TextStyle(fontSize: AppFonts.md),
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
                                          errorBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(10),
                                            borderSide: const BorderSide(color: Colors.red, width: 1.5),
                                          ),
                                          focusedErrorBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(10),
                                            borderSide: const BorderSide(color: Colors.red, width: 2.0),
                                          ),
                                          filled: true,
                                          fillColor: Colors.white,
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
                                            _loadReport();
                                          }
                                        },
                                        style: TextStyle(
                                          fontSize: AppFonts.md,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        dropdownColor: Colors.white,
                                        icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF173B69)),
                                        isExpanded: true,
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
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: DropdownButtonFormField<String>(
                                        value: _filterDepartment,
                                        decoration: InputDecoration(
                                          labelText: 'Department Filter',
                                          labelStyle: TextStyle(fontSize: AppFonts.md),
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
                                          errorBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(10),
                                            borderSide: const BorderSide(color: Colors.red, width: 1.5),
                                          ),
                                          focusedErrorBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(10),
                                            borderSide: const BorderSide(color: Colors.red, width: 2.0),
                                          ),
                                          filled: true,
                                          fillColor: Colors.white,
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                        ),
                                        items: [
                                          const DropdownMenuItem(
                                            value: 'all',
                                            child: Text('All Departments'),
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
                                            setState(() {
                                              _filterDepartment = value;
                                            });
                                            _loadReport();
                                          }
                                        },
                                        style: TextStyle(
                                          fontSize: AppFonts.md,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        dropdownColor: Colors.white,
                                        icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF173B69)),
                                        isExpanded: true,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    SizedBox(
                                      height: 50,
                                      child: _filterDepartment != 'all'
                                          ? ElevatedButton(
                                              onPressed: () {
                                                setState(() {
                                                  _filterDepartment = 'all';
                                                });
                                                _loadReport();
                                              },
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
                              ],
                            ),
                          ),

                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                            child: SizedBox(
                              height: 70,
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                children: [
                                  _buildSummaryCard(
                                    label: 'Total',
                                    value: _summary['total']?.toString() ?? '0',
                                    color: const Color(0xFF173B69),
                                  ),
                                  const SizedBox(width: 6),
                                  _buildSummaryCard(
                                    label: 'Pending',
                                    value: _summary['pending']?.toString() ?? '0',
                                    color: Colors.orange,
                                  ),
                                  const SizedBox(width: 6),
                                  _buildSummaryCard(
                                    label: 'Approved',
                                    value: _summary['approved']?.toString() ?? '0',
                                    color: Colors.green,
                                  ),
                                  const SizedBox(width: 6),
                                  _buildSummaryCard(
                                    label: 'Rejected',
                                    value: _summary['rejected']?.toString() ?? '0',
                                    color: Colors.red,
                                  ),
                                ],
                              ),
                            ),
                          ),

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
                                  'Total Days: ${_summary['totalDays'] ?? 0}',
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
                                    '${_summary['autoApproved'] ?? 0} Auto',
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

                          _reportData.isEmpty
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
                                        _filterDepartment == 'all' 
                                            ? 'No data found' 
                                            : 'No data found for this department',
                                        style: const TextStyle(
                                          color: Colors.grey,
                                          fontSize: AppFonts.md,
                                        ),
                                      ),
                                      if (_filterDepartment != 'all')
                                        TextButton(
                                          onPressed: () {
                                            setState(() {
                                              _filterDepartment = 'all';
                                            });
                                            _loadReport();
                                          },
                                          child: const Text('View all departments'),
                                        ),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  itemCount: _reportData.length,
                                  itemBuilder: (context, index) {
                                    final r = _reportData[index];
                                    return _ReportCard(data: r);
                                  },
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
}

// ==================== Report Card ====================
class _ReportCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const _ReportCard({required this.data});

  Color get _statusColor {
    switch (data['status']) {
      case 'approved': return Colors.green;
      case 'rejected': return Colors.red;
      case 'pending': return Colors.orange;
      default: return Colors.grey;
    }
  }

  Color get _departmentColor {
    final dept = data['department'] ?? '';
    if (dept.contains('IT')) return Colors.blue;
    if (dept.contains('Education')) return Colors.green;
    if (dept.contains('Administration')) return Colors.purple;
    if (dept.contains('Service')) return Colors.orange;
    return Colors.grey;
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
    final String cambodiaTime = _formatToCambodiaTime(data['createdAt']);
    final String department = data['department'] ?? '';
    final bool hasDepartment = department.isNotEmpty;

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
                Expanded(
                  child: Text(
                    data['userName'],
                    style: const TextStyle(
                      fontSize: AppFonts.md,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (hasDepartment)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: _departmentColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _departmentColor.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.business,
                          size: 12,
                          color: _departmentColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          department,
                          style: TextStyle(
                            fontSize: 10,
                            color: _departmentColor,
                            fontWeight: FontWeight.w500,
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
                    data['status'].toUpperCase(),
                    style: TextStyle(
                      color: _statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Row(
              children: [
                Expanded(
                  child: Text(
                    data['userEmail'],
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
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
                  '${data['startDate']} → ${data['endDate']}',
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
                    data['reason'],
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
                    '${data['totalDays']} days',
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
                    color: data['autoApproved']
                        ? Colors.purple.withOpacity(0.1)
                        : Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    data['autoApproved'] ? ' Auto' : ' Manual',
                    style: TextStyle(
                      fontSize: 11,
                      color: data['autoApproved'] ? Colors.purple : Colors.orange,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '#${data['requestNumber']}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[500],
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  cambodiaTime,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.blue[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            if (data['rejectionReason'] != null && data['rejectionReason'].isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(
                  '⚠️ ${data['rejectionReason']}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.red[700],
                  ),
                ),
              ),
            if (data['approvedByName'] != null && data['approvedByName'].isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  ' Approved by: ${data['approvedByName']}',
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