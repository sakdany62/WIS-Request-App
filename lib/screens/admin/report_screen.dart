// lib/screens/admin/report_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart' as excel;
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show rootBundle;
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/translation_service.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../app_fonts.dart';
import '../../utils/responsive.dart';
import '../../widgets/profile_avatar.dart';
import 'package:permission_system/utils/web_utils.dart';

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
  String _searchQuery = '';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Map<String, String> _userNameCache = {};

  // Departments loaded from Firestore
  List<Map<String, String>> _departments = [];

  // Admin data for avatar
  String _adminId = '';
  String _adminName = '';
  String? _adminProfileImageUrl;

  final List<String> _segmentLabels = [
    'All',
    'Pending',
    'Approved',
    'Rejected',
  ];

  // ===== CHECK PLATFORM =====
  bool get _isWeb => kIsWeb;
  bool get _isDesktop {
    if (_isWeb) return false;
    return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
  }
  bool get _isMobile {
    if (_isWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }
  bool get _isWindows {
    if (_isWeb) return false;
    return Platform.isWindows;
  }
  bool get _isAndroid {
    if (_isWeb) return false;
    return Platform.isAndroid;
  }

  // ===== LOAD ADMIN DATA =====
  Future<void> _loadAdminData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final docSnapshot = await _firestore.collection('users').doc(user.uid).get();
        if (docSnapshot.exists) {
          final data = docSnapshot.data() as Map<String, dynamic>;
          setState(() {
            _adminId = user.uid;
            _adminName = data['fullName'] ?? data['username'] ?? 'Admin';
            _adminProfileImageUrl = data['profileImageUrl'];
          });
        }
      } catch (e) {
        print('Error loading admin data: $e');
      }
    }
  }

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

  // ===== LOAD DEPARTMENTS FROM FIRESTORE =====
  Future<void> _loadDepartments() async {
    try {
      final snapshot = await _firestore.collection('departments').orderBy('name').get();

      final List<Map<String, String>> loadedDepartments = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        loadedDepartments.add({
          'id': doc.id,
          'name': data['name']?.toString() ?? 'Unnamed',
        });
      }

      if (loadedDepartments.isEmpty) {
        setState(() {
          _departments = _getDefaultDepartments();
        });
        return;
      }

      setState(() {
        _departments = loadedDepartments;
      });

      print('✅ Loaded ${_departments.length} departments from Firestore');
    } catch (e) {
      print('❌ Error loading departments: $e');
      setState(() {
        _departments = _getDefaultDepartments();
      });
    }
  }

  List<Map<String, String>> _getDefaultDepartments() {
    return [
      {'id': 'dept_it', 'name': 'IT Department'},
      {'id': 'dept_education', 'name': 'Education Department'},
      {'id': 'dept_administration', 'name': 'Administration Department'},
      {'id': 'dept_service', 'name': 'Service Department'},
    ];
  }

  @override
  void initState() {
    super.initState();
    _loadAdminData();
    _loadDepartments();
    _loadReport();
    if (_isAndroid) {
      _requestPermissions();
    }
  }

  Future<void> _requestPermissions() async {
    if (_isAndroid) {
      final status = await Permission.storage.status;
      if (!status.isGranted) {
        await Permission.storage.request();
      }
    }
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

  // ===== FILTERED DATA WITH SEARCH =====
  List<Map<String, dynamic>> get _filteredData {
    List<Map<String, dynamic>> result = [];

    if (_currentSegment == 0) {
      result = _reportData;
    } else {
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
      result = _reportData.where((item) => item['status'] == targetStatus).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase().trim();
      result = result.where((item) {
        final name = (item['userName'] ?? '').toLowerCase();
        final email = (item['userEmail'] ?? '').toLowerCase();
        return name.contains(query) || email.contains(query);
      }).toList();
    }

    return result;
  }

  // ================================================================
  // ===== GET DATE LABEL =====
  // ================================================================
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

  // ================================================================
  // ===== EXPORT TO PDF =====
  // ================================================================
  Future<void> _exportToPDF() async {
    final dataToExport = _filteredData;
    
    if (dataToExport.isEmpty) {
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
                Text('Generating PDF file...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      // ===== TRANSLATE DATA =====
      List<Map<String, dynamic>> translatedData = [];
      
      for (var request in dataToExport) {
        final translatedName = await TranslationService.translateToEnglish(
          request['userName'] ?? 'Unknown'
        );
        final translatedReason = await TranslationService.translateToEnglish(
          request['reason'] ?? ''
        );
        final translatedDepartment = request['department'] != null && request['department'].toString().isNotEmpty
            ? await TranslationService.translateToEnglish(request['department'].toString())
            : 'N/A';
        final translatedStatus = await TranslationService.translateToEnglish(
          request['status'] ?? 'pending'
        );
        final translatedApprovedBy = request['approvedByName'] != null && request['approvedByName'].toString().isNotEmpty
            ? await TranslationService.translateToEnglish(request['approvedByName'].toString())
            : '';
        final translatedRejectionReason = request['rejectionReason'] != null && request['rejectionReason'].toString().isNotEmpty
            ? await TranslationService.translateToEnglish(request['rejectionReason'].toString())
            : '';
        
        translatedData.add({
          'id': request['id'],
          'userId': request['userId'],
          'userName': translatedName,
          'userEmail': request['userEmail'] ?? '',
          'department': translatedDepartment,
          'departmentId': request['departmentId'] ?? '',
          'startDate': request['startDate'] ?? '',
          'endDate': request['endDate'] ?? '',
          'totalDays': request['totalDays'] ?? 0,
          'reason': translatedReason,
          'status': translatedStatus,
          'autoApproved': request['autoApproved'] ?? false,
          'createdAt': request['createdAt'],
          'approvedByName': translatedApprovedBy,
          'rejectionReason': translatedRejectionReason,
          'requestNumber': request['requestNumber'] ?? 0,
        });
      }

      // ===== LOAD LOGO =====
      pw.ImageProvider? logoImage;
      try {
        final ByteData imageData = await rootBundle.load('assets/img/logo1.png');
        final Uint8List imageBytes = imageData.buffer.asUint8List();
        logoImage = pw.MemoryImage(imageBytes);
        print(' Logo loaded successfully');
      } catch (e) {
        print(' Logo image not found: $e');
        logoImage = null;
      }

      // ===== GENERATE PDF =====
      final pdf = pw.Document();
      final pageFormat = PdfPageFormat.a4.landscape;

      pdf.addPage(
        pw.MultiPage(
          pageFormat: pageFormat,
          margin: pw.EdgeInsets.all(20),
          build: (pw.Context context) {
            return [
              // ===== HEADER =====
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(
                    width: 100,
                    height: 100,
                    child: pw.Center(
                      child: logoImage != null
                          ? pw.Image(
                              logoImage!,
                              width: 90,
                              height: 90,
                              fit: pw.BoxFit.contain,
                            )
                          : pw.Text(
                              '🏫',
                              style: pw.TextStyle(
                                fontSize: 40,
                              ),
                            ),
                    ),
                  ),
                  pw.SizedBox(width: 16),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text(
                          'KINGDOM OF CAMBODIA',
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue900,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'Nation  Religion  King',
                          style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue900,
                          ),
                        ),
                        pw.SizedBox(height: 35),
                        pw.Text(
                          'PERMISSION REQUEST REPORT',
                          style: pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.grey800,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'Period: ${_getDateLabel()}',
                          style: pw.TextStyle(
                            fontSize: 9,
                            color: PdfColors.grey600,
                          ),
                        ),
                        pw.Text(
                          'Department: ${_getCurrentDepartmentName()}',
                          style: pw.TextStyle(
                            fontSize: 9,
                            color: PdfColors.grey600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.SizedBox(height: 10),

           

              // ===== TABLE =====
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
                    decoration: pw.BoxDecoration(
                      color: PdfColors.blue900,
                    ),
                    children: [
                      _buildHeaderCell('No.'),
                      _buildHeaderCell('Name'),
                      _buildHeaderCell('Email'),
                      _buildHeaderCell('Dept'),
                      _buildHeaderCell('Date'),
                      _buildHeaderCell('Days'),
                      _buildHeaderCell('Reason'),
                      _buildHeaderCell('Status'),
                      _buildHeaderCell('Type'),
                      _buildHeaderCell('Req #'),
                      _buildHeaderCell('Created'),
                      _buildHeaderCell('Approved By'),
                      _buildHeaderCell('Rejection'),
                    ],
                  ),
                  ...translatedData.asMap().entries.map((entry) {
                    final index = entry.key;
                    final r = entry.value;
                    final color = index % 2 == 0 
                        ? PdfColors.grey100 
                        : PdfColors.white;
                    
                    final status = r['status'] ?? 'pending';
                    PdfColor statusColor;
                    if (status == 'approved') {
                      statusColor = PdfColors.green;
                    } else if (status == 'rejected') {
                      statusColor = PdfColors.red;
                    } else {
                      statusColor = PdfColors.orange;
                    }
                    
                    return pw.TableRow(
                      decoration: pw.BoxDecoration(
                        color: color,
                      ),
                      children: [
                        _buildDataCell('${index + 1}'),
                        _buildDataCell(r['userName'] ?? 'Unknown'),
                        _buildDataCell(r['userEmail'] ?? ''),
                        _buildDataCell(r['department'] ?? 'N/A'),
                        _buildDataCell(r['startDate'] ?? ''),
                        _buildDataCell('${r['totalDays'] ?? 0}'),
                        _buildDataCell(r['reason'] ?? ''),
                        _buildDataCell(
                          (r['status'] ?? 'pending').toString().toUpperCase(),
                          color: statusColor,
                        ),
                        _buildDataCell(r['autoApproved'] == true ? 'Auto' : 'Manual'),
                        _buildDataCell('${r['requestNumber'] ?? 0}'),
                        _buildDataCell(_formatToCambodiaTime(r['createdAt'])),
                        _buildDataCell(r['approvedByName'] ?? ''),
                        _buildDataCell(r['rejectionReason'] ?? ''),
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
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue900,
                    ),
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Date: ${DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now())}',
                        style: pw.TextStyle(
                          fontSize: 9,
                          color: PdfColors.grey600,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Prepared by: $_adminName',
                        style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue900,
                        ),
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

      if (_isWeb) {
        _downloadPDFOnWeb(pdfBytes);
      } else {
        await _savePDFToFile(pdfBytes);
      }

      // Clear translation cache after export
      TranslationService.clearCache();

    } catch (e, stackTrace) {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      print('PDF Export error: $e');
      print('StackTrace: $stackTrace');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PDF Export error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ================================================================
  // ===== PDF HELPER FUNCTIONS =====
  // ================================================================

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

  pw.Widget _buildSummaryItem(String label, int value, PdfColor color) {
    return pw.Column(
      children: [
        pw.Text(
          value.toString(),
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
            color: color,
          ),
        ),
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 8,
            color: PdfColors.grey600,
          ),
        ),
      ],
    );
  }

  // ================================================================
  // ===== WEB DOWNLOAD PDF =====
  // ================================================================

  void _downloadPDFOnWeb(List<int> pdfBytes) {
    if (!kIsWeb) return;
    
    final fileName =
        'report_${_selectedReportType}_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';

    try {
      downloadFileWeb(
        pdfBytes, 
        fileName, 
        'application/pdf'
      );
      _showWebSuccessDialog(fileName);
    } catch (e) {
      print('Web PDF download error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Download failed. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ================================================================
  // ===== SAVE PDF TO FILE =====
  // ================================================================

  Future<void> _savePDFToFile(List<int> pdfBytes) async {
    try {
      final dir = await getTemporaryDirectory();
      final fileName =
          'report_${_selectedReportType}_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';
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
              content: Text(' Exported PDF: $fileName'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        _showMobileSuccessDialog(filePath, fileName);
      }
    } catch (e) {
      print('Save PDF error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Save failed: ${e.toString()}'),
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
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Export Successful'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('PDF saved: $fileName'),
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
                  const Text(
                    'Location:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
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
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showWebSuccessDialog(String fileName) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Download Succeeded'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('File: $fileName'),
            const SizedBox(height: 12),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // ================================================================
  // ===== EXPORT TO EXCEL =====
  // ================================================================
  Future<void> _exportToExcel() async {
    final dataToExport = _filteredData;
    
    if (dataToExport.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No data to export'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // ===== PERMISSION FOR ANDROID =====
    if (_isAndroid) {
      if (await Permission.manageExternalStorage.isPermanentlyDenied) {
        _showPermissionDialog();
        return;
      }
      
      var status = await Permission.manageExternalStorage.status;
      if (!status.isGranted) {
        status = await Permission.manageExternalStorage.request();
      }
      
      if (!status.isGranted) {
        final storageStatus = await Permission.storage.request();
        if (!storageStatus.isGranted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Storage permission is required to export'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
          return;
        }
      }
    }

    // ===== SHOW LOADING =====
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
                Text('Generating Excel file...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      var excelFile = excel.Excel.createExcel();
      var sheet = excelFile['Sheet1'];
      if (sheet == null) {
        throw Exception('No sheet available');
      }

      final headers = [
        'No.',
        'Staff Name',
        'Email',
        'Department',
        'Date',
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

      for (int i = 0; i < dataToExport.length; i++) {
        final r = dataToExport[i];
        final String cambodiaTime = _formatToCambodiaTime(r['createdAt']);

        String fullName = r['userName'] ?? 'Unknown';
        if (r['userId'] != null && r['userId'].isNotEmpty) {
          if (_userNameCache.containsKey(r['userId'])) {
            fullName = _userNameCache[r['userId']]!;
          } else {
            final fetchedName = await _getUserFullName(r['userId']);
            _userNameCache[r['userId']] = fetchedName;
            fullName = fetchedName;
          }
        }

        sheet.appendRow([
          (i + 1),
          fullName,
          r['userEmail'] ?? '',
          r['department'] ?? 'N/A',
          r['startDate'] ?? '',
          r['totalDays'] ?? 0,
          r['reason'] ?? '',
          (r['status'] ?? 'pending').toString().toUpperCase(),
          (r['autoApproved'] == true) ? 'Auto' : 'Manual',
          r['requestNumber'] ?? 0,
          cambodiaTime,
          r['approvedByName'] ?? '',
          r['rejectionReason'] ?? '',
        ]);
      }

      final colWidths = [6, 20, 25, 20, 15, 12, 25, 14, 10, 12, 25, 18, 25];
      for (int i = 0; i < colWidths.length; i++) {
        sheet.setColWidth(i, colWidths[i].toDouble());
      }

      final fileBytes = excelFile.encode();
      if (fileBytes == null || fileBytes.isEmpty) {
        throw Exception('Failed to encode Excel file');
      }

      Navigator.pop(context);

      if (_isWeb) {
        _downloadExcelOnWeb(fileBytes);
      } else if (_isWindows) {
        await _saveExcelOnWindows(fileBytes);
      } else if (_isMobile) {
        await _saveExcelOnMobile(fileBytes);
      } else {
        await _saveExcelGeneric(fileBytes);
      }
    } catch (e, stackTrace) {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      print('Export error: $e');
      print('StackTrace: $stackTrace');
      _showExportError(e.toString());
    }
  }

  // ================================================================
  // ===== EXCEL EXPORT HELPERS =====
  // ================================================================
  void _downloadExcelOnWeb(List<int> fileBytes) {
    if (!kIsWeb) return;
    
    final fileName =
        'report_${_selectedReportType}_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';

    try {
      downloadFileWeb(
        fileBytes, 
        fileName, 
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
      );
      _showWebSuccessDialog(fileName);
    } catch (e) {
      print('Web download error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Download failed. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _saveExcelOnWindows(List<int> fileBytes) async {
    String fileName =
        'report_${_selectedReportType}_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';
    String desktopPath = '${Platform.environment['USERPROFILE']}\\Desktop';
    final desktopDir = Directory(desktopPath);
    if (!await desktopDir.exists()) {
      await desktopDir.create(recursive: true);
    }
    String filePath = '$desktopPath\\$fileName';

    final file = File(filePath);
    await file.writeAsBytes(fileBytes, flush: true);

    _showWindowsSuccessDialog(filePath, fileName);
  }

  Future<void> _saveExcelOnMobile(List<int> fileBytes) async {
    String fileName =
        'report_${_selectedReportType}_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';
    
    Directory? directory;
    
    if (_isAndroid) {
      try {
        final downloadsDir = await getExternalStorageDirectory();
        if (downloadsDir != null) {
          directory = downloadsDir;
        } else {
          directory = await getApplicationDocumentsDirectory();
        }
      } catch (e) {
        directory = await getApplicationDocumentsDirectory();
      }
    } else {
      directory = await getApplicationDocumentsDirectory();
    }

    final String filePath = '${directory!.path}/$fileName';
    final file = File(filePath);
    await file.writeAsBytes(fileBytes, flush: true);

    _showMobileExcelSuccessDialog(filePath, fileName);
  }

  Future<void> _saveExcelGeneric(List<int> fileBytes) async {
    String fileName =
        'report_${_selectedReportType}_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';
    final directory = await getApplicationDocumentsDirectory();
    String filePath = '${directory.path}/$fileName';

    final file = File(filePath);
    await file.writeAsBytes(fileBytes, flush: true);

    _showGenericSuccessDialog(filePath, fileName);
  }

  // ================================================================
  // ===== SUCCESS DIALOGS =====
  // ================================================================
  void _showWindowsSuccessDialog(String filePath, String fileName) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Export Successful'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Excel file has been created successfully!'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    ' File saved to Desktop:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    fileName,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    ' Double-click the file on your Desktop to open it.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _openWindowsFolder();
            },
            icon: const Icon(Icons.folder_open),
            label: const Text('Open Desktop'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _showMobileExcelSuccessDialog(String filePath, String fileName) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Export Successful'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('File saved: $fileName'),
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
                  const Text(
                    'Location:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
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
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              try {
                final result = await OpenFile.open(
                  filePath,
                  type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
                );
                if (result.type != ResultType.done) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please open the file manually'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please open the file manually'),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            },
            icon: const Icon(Icons.open_in_new),
            label: const Text('Open File'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _showGenericSuccessDialog(String filePath, String fileName) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Export Successful'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('File saved: $fileName'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                filePath,
                style: const TextStyle(fontSize: 11),
                maxLines: 2,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Storage Permission Required'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Please allow storage permission to export Excel files.'),
            SizedBox(height: 12),
            Text(
              'Go to Settings > Apps > Permission System > Permissions > '
              'Enable "Files and Media" or "Manage External Storage".',
              style: TextStyle(fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  void _showExportError(String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error, color: Colors.red),
            SizedBox(width: 8),
            Text('Export Failed'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('An error occurred while exporting:'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                error,
                style: TextStyle(
                  color: Colors.red[800],
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please try again or check storage permissions.',
              style: TextStyle(fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _exportToExcel();
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _openWindowsFolder() {
    try {
      String desktopPath = Platform.environment['USERPROFILE']! + '\\Desktop';
      Process.run('explorer', [desktopPath], runInShell: true);
    } catch (e) {
      // Silent fail
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
    double bottomPadding = MediaQuery.of(context).padding.bottom + 24;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF173B69),
        elevation: 2,
        automaticallyImplyLeading: false,
        title: const Text(
          'Reports',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // Export PDF button
          IconButton(
            onPressed: _exportToPDF,
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Export to PDF',
          ),
          // Export Excel button
          IconButton(
            onPressed: _exportToExcel,
            icon: const Icon(Icons.table_chart),
            tooltip: 'Export to Excel',
          ),
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
                                      value: dept['id']!,
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
                  
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: TextField(
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                        });
                      },
                      style: TextStyle(fontSize: fontSize),
                      decoration: InputDecoration(
                        hintText: ' Search by name or email...',
                        hintStyle: TextStyle(fontSize: fontSize, color: Colors.grey.shade500),
                        prefixIcon: Icon(Icons.search, color: Colors.grey.shade500, size: 20),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.clear, color: Colors.grey.shade500, size: 18),
                                onPressed: () {
                                  setState(() {
                                    _searchQuery = '';
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
                                  _searchQuery.isNotEmpty
                                      ? 'No results found for "$_searchQuery"'
                                      : _filterDepartment == 'all'
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
        onTap: () {},
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ProfileAvatar(
                    userId: r['userId'] ?? '',
                    name: r['userName'] ?? 'Unknown',
                    radius: isMobile ? 14 : 18,
                    backgroundColor: statusColor.withValues(alpha: 0.1),
                    textColor: statusColor,
                  ),
                  const SizedBox(width: 8),
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
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (r['department'] != null && r['department'].isNotEmpty)
                          Text(
                            r['department'],
                            style: TextStyle(
                              fontSize: isMobile ? fontSize * 0.7 : fontSize * 0.85,
                              color: Colors.grey.shade600,
                            ),
                            overflow: TextOverflow.ellipsis,
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