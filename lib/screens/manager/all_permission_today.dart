// lib/screens/manager/list_staff_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';
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
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

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
  String _managerName = '';
  bool _isManager = false;

  int _visibleCount = 3;
  bool _showAll = false;

  final Map<String, String> _userNameCache = {};

  String _searchQuery = '';

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
          _managerName = data['fullName'] ?? data['username'] ?? 'Manager';
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
      _searchQuery = '';
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

  // ================================================================
  // ===== EXPORT PDF =====
  // ================================================================
  Future<void> _exportToPDF() async {
    final dataToExport = _filteredRequests;
    
    if (dataToExport.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No data to export'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Show loading dialog
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
      // ===== LOAD IMAGE FROM ASSETS =====
      pw.ImageProvider? logoImage;
      try {
        final ByteData imageData = await rootBundle.load('assets/img/logo1.png');
        final Uint8List imageBytes = imageData.buffer.asUint8List();
        logoImage = pw.MemoryImage(imageBytes);
        print('✅ Logo loaded successfully');
      } catch (e) {
        print('⚠️ Logo image not found: $e');
        logoImage = null;
      }

      final pdf = pw.Document();

      // ===== LANDSCAPE PAGE FORMAT =====
      final pageFormat = PdfPageFormat.a4.landscape;

      pdf.addPage(
        pw.MultiPage(
          pageFormat: pageFormat,
          margin: pw.EdgeInsets.all(20),
          build: (pw.Context context) {
            return [
              // ===== HEADER: LOGO (LEFT) + TITLE (CENTER) =====
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Left: School Logo (No Border)
                  pw.Container(
                    width: 70,
                    height: 70,
                    child: pw.Center(
                      child: logoImage != null
                          ? pw.Image(
                              logoImage!,
                              width: 60,
                              height: 60,
                              fit: pw.BoxFit.contain,
                            )
                          : pw.Text(
                              '🏫',
                              style: pw.TextStyle(
                                fontSize: 30,
                              ),
                            ),
                    ),
                  ),
                  pw.SizedBox(width: 16),
                  
                  // Center: Country Name + Motto + Report Title
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text(
                          'KINGDOM OF CAMBODIA',
                          style: pw.TextStyle(
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue900,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'Nation Religion King',
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue900,
                          ),
                        ),
                        pw.Divider(thickness: 1, color: PdfColors.blue900),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'PERMISSION REQUEST REPORT',
                          style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.grey800,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'Period: ${_getDateLabel()}',
                          style: pw.TextStyle(
                            fontSize: 10,
                            color: PdfColors.grey600,
                          ),
                        ),
                        if (_isManager && _managerDepartment.isNotEmpty)
                          pw.Text(
                            'Department: $_managerDepartment',
                            style: pw.TextStyle(
                              fontSize: 10,
                              color: PdfColors.grey600,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Divider(thickness: 2, color: PdfColors.blue900),
              pw.SizedBox(height: 10),

              // ===== DATA TABLE =====
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
                  // Table Header
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
                  // Data Rows
                  ...dataToExport.asMap().entries.map((entry) {
                    final index = entry.key;
                    final r = entry.value;
                    final color = index % 2 == 0 
                        ? PdfColors.grey100 
                        : PdfColors.white;
                    
                    return pw.TableRow(
                      decoration: pw.BoxDecoration(
                        color: color,
                      ),
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

              // ===== FOOTER =====
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Total: ${dataToExport.length} request(s)',
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
                        'Prepared by: $_managerName',
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

      // Generate PDF bytes
      final pdfBytes = await pdf.save();

      // Close loading dialog
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      // ===== HANDLE BASED ON PLATFORM =====
      if (kIsWeb) {
        _downloadPDFOnWeb(pdfBytes);
      } else {
        await _savePDFToFile(pdfBytes);
      }

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

  // ===== WEB DOWNLOAD PDF =====
  void _downloadPDFOnWeb(List<int> pdfBytes) {
    if (!kIsWeb) return;
    
    final fileName = 'permission_list_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';

    try {
      final base64 = base64Encode(pdfBytes);
      final anchor = html.AnchorElement(
        href: 'data:application/pdf;base64,$base64'
      )
        ..setAttribute('download', fileName)
        ..style.display = 'none'
        ..click();

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

  // ===== SAVE PDF TO FILE (Mobile/Desktop) =====
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
              content: Text('✅ Exported PDF: $fileName'),
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

/// ================================================================
// ===== EXPORT EXCEL WITH ENGLISH HEADERS (NO LOGO, ONLY START DATE) =====
// ================================================================
Future<void> _exportToExcel() async {
  final dataToExport = _filteredRequests;
  
  if (dataToExport.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No data to export'),
        backgroundColor: Colors.orange,
      ),
    );
    return;
  }

  // Show loading dialog
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
    // ===== CREATE EXCEL =====
    var excelFile = excel.Excel.createExcel();

    // Get Sheet1
    var sheet = excelFile['Sheet1'];
    if (sheet == null) {
      throw Exception('No sheet available');
    }

    // ================================================================
    // ===== HEADER: PERIOD ONLY =====
    // ================================================================
    
    // Row 0: Period
    sheet.merge(
      excel.CellIndex.indexByString('A1'),
      excel.CellIndex.indexByString('M1'),
    );
    var periodCell = sheet.cell(excel.CellIndex.indexByString('A1'));
    periodCell.value = 'Period: ${_getDateLabel()}';
    periodCell.cellStyle = excel.CellStyle(
      bold: true,
      fontSize: 14,
      fontColorHex: '#173B69',
      horizontalAlign: excel.HorizontalAlign.Center,
      verticalAlign: excel.VerticalAlign.Center,
    );

    // Row 1: Department (if manager)
    if (_isManager && _managerDepartment.isNotEmpty) {
      sheet.merge(
        excel.CellIndex.indexByString('A2'),
        excel.CellIndex.indexByString('M2'),
      );
      var deptCell = sheet.cell(excel.CellIndex.indexByString('A2'));
      deptCell.value = 'Department: $_managerDepartment';
      deptCell.cellStyle = excel.CellStyle(
        italic: true,
        fontSize: 10,
        fontColorHex: '#666666',
        horizontalAlign: excel.HorizontalAlign.Center,
        verticalAlign: excel.VerticalAlign.Center,
      );
    }

    // Empty row for spacing
    int headerRowCount = _isManager && _managerDepartment.isNotEmpty ? 3 : 2;
    int currentRow = headerRowCount;

    // ================================================================
    // ===== DATA TABLE HEADERS (ENGLISH) =====
    // ================================================================
    final headers = [
      'No.',
      'Staff Name',
      'Email',
      'Department',
      'Date',            // Only Start Date
      'Total Days',
      'Reason',
      'Status',
      'Approval Type',
      'Request #',
      'Created At',
      'Approved By',
      'Rejection Reason',
    ];

    // Add headers row with styling
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

    // ===== ADD DATA ROWS =====
    for (int i = 0; i < dataToExport.length; i++) {
      final r = dataToExport[i];
      final String cambodiaTime = _formatToCambodiaTime(r.createdAt);

      // Get full name from cache or use staffName
      String fullName = r.staffName;
      if (r.userId.isNotEmpty && _userNameCache.containsKey(r.userId)) {
        fullName = _userNameCache[r.userId]!;
      }

      final rowIndex = currentRow;
      
      // 1. No.
      var cell0 = sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex));
      cell0.value = i + 1;
      cell0.cellStyle = excel.CellStyle(
        horizontalAlign: excel.HorizontalAlign.Center,
        verticalAlign: excel.VerticalAlign.Center,
        fontSize: 10,
      );

      // 2. Staff Name
      var cell1 = sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex));
      cell1.value = fullName;
      cell1.cellStyle = excel.CellStyle(
        horizontalAlign: excel.HorizontalAlign.Left,
        verticalAlign: excel.VerticalAlign.Center,
        fontSize: 10,
      );

      // 3. Email
      var cell2 = sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex));
      cell2.value = r.userEmail;
      cell2.cellStyle = excel.CellStyle(
        horizontalAlign: excel.HorizontalAlign.Left,
        verticalAlign: excel.VerticalAlign.Center,
        fontSize: 10,
      );

      // 4. Department
      var cell3 = sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex));
      cell3.value = r.department ?? 'N/A';
      cell3.cellStyle = excel.CellStyle(
        horizontalAlign: excel.HorizontalAlign.Left,
        verticalAlign: excel.VerticalAlign.Center,
        fontSize: 10,
      );

      // 5. Date (Start Date only)
      var cell4 = sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex));
      cell4.value = r.startDate;
      cell4.cellStyle = excel.CellStyle(
        horizontalAlign: excel.HorizontalAlign.Center,
        verticalAlign: excel.VerticalAlign.Center,
        fontSize: 10,
      );

      // 6. Total Days
      var cell5 = sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex));
      cell5.value = r.totalDays;
      cell5.cellStyle = excel.CellStyle(
        horizontalAlign: excel.HorizontalAlign.Center,
        verticalAlign: excel.VerticalAlign.Center,
        fontSize: 10,
      );

      // 7. Reason
      var cell6 = sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rowIndex));
      cell6.value = r.reason;
      cell6.cellStyle = excel.CellStyle(
        horizontalAlign: excel.HorizontalAlign.Left,
        verticalAlign: excel.VerticalAlign.Center,
        fontSize: 10,
      );

      // 8. Status (with color)
      var cell7 = sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: rowIndex));
      String statusText = r.status.toUpperCase();
      cell7.value = statusText;
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

      // 9. Approval Type
      var cell8 = sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: rowIndex));
      cell8.value = r.autoApproved ? 'Auto' : 'Manual';
      cell8.cellStyle = excel.CellStyle(
        horizontalAlign: excel.HorizontalAlign.Center,
        verticalAlign: excel.VerticalAlign.Center,
        fontSize: 10,
      );

      // 10. Request #
      var cell9 = sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: rowIndex));
      cell9.value = r.requestNumber;
      cell9.cellStyle = excel.CellStyle(
        horizontalAlign: excel.HorizontalAlign.Center,
        verticalAlign: excel.VerticalAlign.Center,
        fontSize: 10,
      );

      // 11. Created At
      var cell10 = sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: rowIndex));
      cell10.value = cambodiaTime;
      cell10.cellStyle = excel.CellStyle(
        horizontalAlign: excel.HorizontalAlign.Center,
        verticalAlign: excel.VerticalAlign.Center,
        fontSize: 10,
      );

      // 12. Approved By
      var cell11 = sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 11, rowIndex: rowIndex));
      cell11.value = r.approvedByName ?? '';
      cell11.cellStyle = excel.CellStyle(
        horizontalAlign: excel.HorizontalAlign.Left,
        verticalAlign: excel.VerticalAlign.Center,
        fontSize: 10,
      );

      // 13. Rejection Reason
      var cell12 = sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 12, rowIndex: rowIndex));
      cell12.value = r.rejectionReason ?? '';
      cell12.cellStyle = excel.CellStyle(
        horizontalAlign: excel.HorizontalAlign.Left,
        verticalAlign: excel.VerticalAlign.Center,
        fontSize: 10,
      );

      currentRow++;
    }

    // ================================================================
    // ===== FOOTER =====
    // ================================================================
    int footerStartRow = currentRow + 1;

    // Total summary
    sheet.merge(
      excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: footerStartRow),
      excel.CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: footerStartRow),
    );
    var summaryCell = sheet.cell(
      excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: footerStartRow),
    );
    summaryCell.value = 'Total: ${dataToExport.length} request(s)';
    summaryCell.cellStyle = excel.CellStyle(
      bold: true,
      fontSize: 11,
      fontColorHex: '#173B69',
      horizontalAlign: excel.HorizontalAlign.Left,
    );

    footerStartRow++;

    // Export date and prepared by (Right side)
    sheet.merge(
      excel.CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: footerStartRow),
      excel.CellIndex.indexByColumnRow(columnIndex: 12, rowIndex: footerStartRow),
    );
    var exportDateCell = sheet.cell(
      excel.CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: footerStartRow),
    );
    exportDateCell.value = 'Date: ${DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now())}';
    exportDateCell.cellStyle = excel.CellStyle(
      italic: true,
      fontSize: 9,
      fontColorHex: '#666666',
      horizontalAlign: excel.HorizontalAlign.Right,
    );

    footerStartRow++;

    sheet.merge(
      excel.CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: footerStartRow),
      excel.CellIndex.indexByColumnRow(columnIndex: 12, rowIndex: footerStartRow),
    );
    var preparedCell = sheet.cell(
      excel.CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: footerStartRow),
    );
    preparedCell.value = 'Prepared by: $_managerName';
    preparedCell.cellStyle = excel.CellStyle(
      bold: true,
      fontSize: 11,
      fontColorHex: '#173B69',
      horizontalAlign: excel.HorizontalAlign.Right,
    );

    // ===== SET COLUMN WIDTHS =====
    final colWidths = [6, 22, 28, 20, 18, 14, 28, 16, 14, 14, 28, 20, 28];
    for (int i = 0; i < colWidths.length; i++) {
      sheet.setColWidth(i, colWidths[i].toDouble());
    }

    final fileBytes = excelFile.encode();
    if (fileBytes == null || fileBytes.isEmpty) {
      throw Exception('Failed to encode Excel file');
    }

    // Close loading dialog
    Navigator.pop(context);

    // ===== HANDLE BASED ON PLATFORM =====
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
        content: Text('Export error: $e'),
        backgroundColor: Colors.red,
      ),
    );
  }
}

  // ===== WEB DOWNLOAD EXCEL =====
  void _downloadExcelOnWeb(List<int> fileBytes) {
    if (!kIsWeb) return;
    
    final fileName = 'permission_list_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';

    try {
      final base64 = base64Encode(fileBytes);
      final anchor = html.AnchorElement(
        href: 'data:application/vnd.openxmlformats-officedocument.spreadsheetml.sheet;base64,$base64'
      )
        ..setAttribute('download', fileName)
        ..style.display = 'none'
        ..click();

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

  // ===== SAVE EXCEL TO FILE (Mobile/Desktop) =====
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
        automaticallyImplyLeading: false,
        title: const Text(
          'Permission List',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.file_download, size: iconSize),
            onSelected: (value) {
              if (value == 'excel') {
                _exportToExcel();
              } else if (value == 'pdf') {
                _exportToPDF();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'pdf',
                child: Row(
                  children: [
                    Icon(Icons.picture_as_pdf, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Export PDF'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'excel',
                child: Row(
                  children: [
                    Icon(Icons.table_chart, color: Colors.green),
                    SizedBox(width: 8),
                    Text('Export Excel'),
                  ],
                ),
              ),
            ],
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
                  
                  // ===== SEARCH FIELD =====
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
                        hintText: ' Search by name or email...',
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
                  
                  // ===== LIST =====
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade400),
                                const SizedBox(height: 12),
                                Text(
                                  _searchQuery.isNotEmpty
                                      ? 'No results found for "$_searchQuery"'
                                      : 'No data found',
                                  style: TextStyle(color: Colors.grey.shade500, fontSize: fontSize),
                                ),
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