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

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final List<Map<String, String>> _departments = [
    {'id': 'dept_it', 'name': 'IT Department'},
    {'id': 'dept_education', 'name': 'Education Department'},
    {'id': 'dept_administration', 'name': 'Administration Department'},
    {'id': 'dept_service', 'name': 'Service Department'},
  ];

  // 📅 បន្ថែមមុខងារគណនាថ្ងៃដំបូង និងថ្ងៃចុងក្រោយនៃសប្តាហ៍
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
      23, 59, 59, 999,
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
      print('❌ Error formatting timestamp: $e');
      return 'N/A';
    }
  }

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  // ==================== LOAD REPORT (កែប្រែ) ====================
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

      // ✅ យក where('departmentId') ចេញ ដើម្បីកុំឲ្យត្រូវការ Composite Index
      Query query = _firestore
          .collection('leave_requests')
          .where('createdAt', isGreaterThanOrEqualTo: startTimestamp)
          .where('createdAt', isLessThan: endTimestamp)
          .orderBy('createdAt', descending: true);

      final querySnapshot = await query.get();

      print('📊 Total documents: ${querySnapshot.docs.length}');
      print('🔍 Filter department: $_filterDepartment');

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

      // ✅ Filter by department ក្នុងកម្មវិធី (Client-side filtering)
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

      print('📊 Filtered data count: ${filteredData.length}');

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
        'No.', 'Staff Name', 'Email', 'Department', 'Start Date', 'End Date',
        'Total Days', 'Reason', 'Status', 'Type', 'Request #',
        'Created At (Cambodia Time)', 'Approved By', 'Rejection Reason',
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

  // ✅ Get current department name for display
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

  @override
  Widget build(BuildContext context) {
    final bool isMobile = Responsive.isMobile(context);
    final double fontSize = Responsive.fontSize(context, 14);
    final double spacing = Responsive.spacing(context);
    final EdgeInsets padding = Responsive.padding(context);
    final double iconSize = Responsive.iconSize(context, 20);
    final double buttonHeight = Responsive.buttonHeight(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                vertical: isMobile ? 14 : 20,
                horizontal: spacing,
              ),
              decoration: const BoxDecoration(
                color: Color(0xFF173B69),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  SizedBox(width: isMobile ? 36 : 48),
                  Expanded(
                    child: Center(
                      child: Text(
                        "Reports",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: isMobile ? 16 : 18,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _exportToExcel,
                    icon: Icon(
                      Icons.file_download,
                      color: Colors.white,
                      size: iconSize + 4,
                    ),
                    tooltip: 'Export to Excel',
                    padding: EdgeInsets.all(spacing),
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
                          // ✅ Filter Section
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
                                      flex: isMobile ? 2 : 3,
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
                                          fillColor: Colors.white,
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
                                            value: 'weekly',
                                            child: Text(' Weekly'), 
                                          ),
                                          DropdownMenuItem(
                                            value: 'monthly',
                                            child: Text(' Monthly'),
                                          ),
                                          DropdownMenuItem(
                                            value: 'yearly',
                                            child: Text(' Yearly'),
                                          ),
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
                                          fontSize: fontSize,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.black,
                                        ),
                                        dropdownColor: Colors.white,
                                        icon: const Icon(
                                          Icons.arrow_drop_down,
                                          color: Color(0xFF173B69),
                                        ),
                                        isExpanded: true,
                                      ),
                                    ),
                                    SizedBox(width: spacing),
                                    SizedBox(
                                      height: buttonHeight,
                                      child: ElevatedButton.icon(
                                        onPressed: _selectDate,
                                        icon: Icon(Icons.calendar_today, size: iconSize - 4),
                                        label: Text(
                                          _getDateLabel(),
                                          style: TextStyle(fontSize: isMobile ? 11 : 13),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF173B69),
                                          foregroundColor: Colors.white,
                                          padding: EdgeInsets.symmetric(horizontal: spacing),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: spacing),
                                Row(
                                  children: [
                                    Expanded(
                                      flex: isMobile ? 2 : 3,
                                      child: DropdownButtonFormField<String>(
                                        value: _filterDepartment,
                                        decoration: InputDecoration(
                                          labelText: 'Department',
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
                                          fillColor: Colors.white,
                                          contentPadding: EdgeInsets.symmetric(
                                            horizontal: spacing,
                                            vertical: isMobile ? 6 : 8,
                                          ),
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
                                          fontSize: fontSize,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.black,
                                        ),
                                        dropdownColor: Colors.white,
                                        icon: const Icon(
                                          Icons.arrow_drop_down,
                                          color: Color(0xFF173B69),
                                        ),
                                        isExpanded: true,
                                      ),
                                    ),
                                    if (_filterDepartment != 'all') ...[
                                      SizedBox(width: spacing),
                                      SizedBox(
                                        height: buttonHeight,
                                        child: ElevatedButton(
                                          onPressed: () {
                                            setState(() {
                                              _filterDepartment = 'all';
                                            });
                                            _loadReport();
                                          },
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
                                            style: TextStyle(fontSize: isMobile ? 11 : 13),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // ✅ Department Filter Info
                          Container(
                            margin: EdgeInsets.symmetric(
                              horizontal: spacing,
                              vertical: spacing / 2,
                            ),
                            padding: EdgeInsets.symmetric(
                              horizontal: spacing,
                              vertical: spacing / 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF173B69).withOpacity(0.08),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFF173B69).withOpacity(0.2),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.filter_alt,
                                      size: iconSize - 4,
                                      color: const Color(0xFF173B69),
                                    ),
                                    SizedBox(width: spacing / 2),
                                    Text(
                                      'Filter: ${_getCurrentDepartmentName()}',
                                      style: TextStyle(
                                        fontSize: fontSize * 0.9,
                                        fontWeight: FontWeight.w500,
                                        color: const Color(0xFF173B69),
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: spacing / 2,
                                    vertical: spacing / 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF173B69),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${_reportData.length} records',
                                    style: TextStyle(
                                      fontSize: fontSize * 0.85,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Summary Cards
                          Container(
                            padding: EdgeInsets.symmetric(
                              vertical: spacing,
                              horizontal: spacing,
                            ),
                            child: SizedBox(
                              height: isMobile ? 60 : 70,
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                children: [
                                  _buildSummaryCard(
                                    label: 'Total',
                                    value: _summary['total']?.toString() ?? '0',
                                    color: const Color(0xFF173B69),
                                    isMobile: isMobile,
                                  ),
                                  SizedBox(width: spacing / 2),
                                  _buildSummaryCard(
                                    label: 'Pending',
                                    value: _summary['pending']?.toString() ?? '0',
                                    color: Colors.orange,
                                    isMobile: isMobile,
                                  ),
                                  SizedBox(width: spacing / 2),
                                  _buildSummaryCard(
                                    label: 'Approved',
                                    value: _summary['approved']?.toString() ?? '0',
                                    color: Colors.green,
                                    isMobile: isMobile,
                                  ),
                                  SizedBox(width: spacing / 2),
                                  _buildSummaryCard(
                                    label: 'Rejected',
                                    value: _summary['rejected']?.toString() ?? '0',
                                    color: Colors.red,
                                    isMobile: isMobile,
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Total Days Summary
                          Container(
                            margin: EdgeInsets.symmetric(horizontal: spacing),
                            padding: EdgeInsets.symmetric(
                              vertical: spacing,
                              horizontal: spacing,
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
                                  'Total Days: ${_summary['totalDays'] ?? 0}',
                                  style: TextStyle(
                                    fontSize: fontSize,
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
                                    '${_summary['autoApproved'] ?? 0} Auto',
                                    style: TextStyle(
                                      fontSize: fontSize * 0.9,
                                      color: Colors.purple,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          SizedBox(height: spacing),

                          // Report List
                          _reportData.isEmpty
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
                                        _filterDepartment == 'all' 
                                            ? 'No data found' 
                                            : 'No data found for ${_getCurrentDepartmentName()}',
                                        style: TextStyle(
                                          color: Colors.grey,
                                          fontSize: fontSize,
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
                                          child: Text(
                                            'View all departments',
                                            style: TextStyle(fontSize: fontSize),
                                          ),
                                        ),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: spacing,
                                    vertical: spacing / 2,
                                  ),
                                  itemCount: _reportData.length,
                                  itemBuilder: (context, index) {
                                    final r = _reportData[index];
                                    return _ReportCard(
                                      data: r,
                                      isMobile: isMobile,
                                      fontSize: fontSize,
                                      spacing: spacing,
                                    );
                                  },
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

  Widget _buildSummaryCard({
    required String label,
    required String value,
    required Color color,
    required bool isMobile,
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
              fontSize: isMobile ? 14 : 16,
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
}

// ==================== Report Card ====================
class _ReportCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isMobile;
  final double fontSize;
  final double spacing;

  const _ReportCard({
    required this.data,
    required this.isMobile,
    required this.fontSize,
    required this.spacing,
  });

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
    final double cardFontSize = isMobile ? fontSize * 0.85 : fontSize;

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
            // Row 1: Name + Department + Status
            Row(
              children: [
                Expanded(
                  child: Text(
                    data['userName'],
                    style: TextStyle(
                      fontSize: cardFontSize,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (hasDepartment && !isMobile)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    margin: EdgeInsets.only(right: 4),
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
                          size: 10,
                          color: _departmentColor,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          department,
                          style: TextStyle(
                            fontSize: cardFontSize * 0.8,
                            color: _departmentColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 4 : 8,
                    vertical: isMobile ? 2 : 3,
                  ),
                  decoration: BoxDecoration(
                    color: _statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    data['status'].toUpperCase(),
                    style: TextStyle(
                      color: _statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: cardFontSize * 0.85,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: spacing / 4),

            // Row 2: Email
            Text(
              data['userEmail'],
              style: TextStyle(
                fontSize: cardFontSize * 0.85,
                color: Colors.grey[600],
              ),
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: spacing / 2),

            // Row 3: Date Range
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
                    '${data['startDate']} → ${data['endDate']}',
                    style: TextStyle(
                      fontSize: cardFontSize * 0.85,
                      color: Colors.grey[700],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            SizedBox(height: spacing / 4),

            // Row 4: Reason + Days
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
                    data['reason'],
                    style: TextStyle(
                      fontSize: cardFontSize * 0.85,
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
                    '${data['totalDays']} days',
                    style: TextStyle(
                      fontSize: cardFontSize * 0.85,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: spacing / 4),

            // Row 5: Type + Request # + Time
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
                    color: data['autoApproved']
                        ? Colors.purple.withOpacity(0.1)
                        : Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    data['autoApproved'] ? ' Auto' : ' Manual',
                    style: TextStyle(
                      fontSize: cardFontSize * 0.8,
                      color: data['autoApproved'] ? Colors.purple : Colors.orange,
                    ),
                  ),
                ),
                Text(
                  '#${data['requestNumber']}',
                  style: TextStyle(
                    fontSize: cardFontSize * 0.8,
                    color: Colors.grey[500],
                  ),
                ),
                Text(
                  cambodiaTime,
                  style: TextStyle(
                    fontSize: cardFontSize * 0.8,
                    color: Colors.blue[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),

            // Rejection Reason
            if (data['rejectionReason'] != null && data['rejectionReason'].isNotEmpty)
              Padding(
                padding: EdgeInsets.only(top: spacing / 4),
                child: Text(
                  ' ${data['rejectionReason']}',
                  style: TextStyle(
                    fontSize: cardFontSize * 0.85,
                    color: Colors.red[700],
                  ),
                ),
              ),

            // Approved By
            if (data['approvedByName'] != null && data['approvedByName'].isNotEmpty)
              Padding(
                padding: EdgeInsets.only(top: spacing / 4),
                child: Text(
                  ' Approved by: ${data['approvedByName']}',
                  style: TextStyle(
                    fontSize: cardFontSize * 0.85,
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