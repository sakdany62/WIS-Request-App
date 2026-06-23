// lib/screens/admin/report_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart' as excel;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:open_file/open_file.dart';

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
  List<Map<String, dynamic>> _allReportData = []; // រក្សាទុកទិន្នន័យទាំងអស់
  Map<String, dynamic> _summary = {};
  String _filterStatus = 'all';
  String _searchName = ''; // ← បន្ថែមសម្រាប់ Search by Name
  final TextEditingController _searchController = TextEditingController();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

      if (_filterStatus != 'all') {
        if (_filterStatus == 'auto_approved') {
          query = query.where('autoApproved', isEqualTo: true);
        } else {
          query = query.where('status', isEqualTo: _filterStatus);
        }
      }

      final querySnapshot = await query.get();

      final data = querySnapshot.docs.map((doc) {
        final d = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'userName': d['userName'] ?? 'Unknown',
          'userEmail': d['userEmail'] ?? '',
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

      setState(() {
        _allReportData = data;
        _applyFilters(); // ← អនុវត្តតម្រង
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

  // ============ អនុវត្តតម្រង ============
  void _applyFilters() {
    List<Map<String, dynamic>> filtered = List.from(_allReportData);

    // ============ Filter តាមឈ្មោះ ============
    if (_searchName.isNotEmpty) {
      final query = _searchName.toLowerCase().trim();
      filtered = filtered.where((item) {
        final userName = (item['userName'] ?? '').toLowerCase();
        final userEmail = (item['userEmail'] ?? '').toLowerCase();
        return userName.contains(query) || userEmail.contains(query);
      }).toList();
    }

    setState(() {
      _reportData = filtered;
      _summary = _calculateSummary(filtered);
    });
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
        'Start Date',
        'End Date',
        'Total Days',
        'Reason',
        'Status',
        'Type',
        'Request #',
        'Created At',
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
        sheet.appendRow([
          (i + 1),
          r['userName'],
          r['userEmail'],
          r['startDate'],
          r['endDate'],
          r['totalDays'],
          r['reason'],
          r['status'].toUpperCase(),
          r['autoApproved'] ? 'Auto' : 'Manual',
          r['requestNumber'],
          DateFormat('dd/MM/yyyy HH:mm').format(r['createdAt']),
          r['approvedByName'] ?? '',
          r['rejectionReason'] ?? '',
        ]);
      }

      final colWidths = [6, 20, 25, 15, 15, 12, 25, 14, 10, 12, 18, 18, 25];
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
      appBar: AppBar(
        title: const Text('Reports'),
        backgroundColor: const Color(0xFF173B69),
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        actions: [
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
                  // ============ Filter Section ============
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: Colors.grey[100],
                    child: Column(
                      children: [
                        // ============ Row 1: Report Type & Date ============
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
                                ),
                                items: const [
                                  DropdownMenuItem(value: 'daily', child: Text('📅 Daily')),
                                  DropdownMenuItem(value: 'monthly', child: Text('📆 Monthly')),
                                  DropdownMenuItem(value: 'yearly', child: Text('📊 Yearly')),
                                ],
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() {
                                      _selectedReportType = value;
                                    });
                                    _loadReport();
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              height: 56,
                              child: ElevatedButton.icon(
                                onPressed: _selectDate,
                                icon: const Icon(Icons.calendar_today),
                                label: Text(_getDateLabel()),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF173B69),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        
                        // ============ Row 2: Status Filter ============
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
                                ),
                                items: const [
                                  DropdownMenuItem(value: 'all', child: Text('All')),
                                  DropdownMenuItem(value: 'pending', child: Text('⏳ Pending')),
                                  DropdownMenuItem(value: 'approved', child: Text('✅ Approved')),
                                  DropdownMenuItem(value: 'auto_approved', child: Text('🤖 Auto Approved')),
                                  DropdownMenuItem(value: 'rejected', child: Text('❌ Rejected')),
                                ],
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() {
                                      _filterStatus = value;
                                    });
                                    _loadReport();
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        
                        // ============ Row 3: Search by Name ============
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                onChanged: (value) {
                                  setState(() {
                                    _searchName = value;
                                  });
                                  _applyFilters(); // ← អនុវត្តតម្រងពេលវាយបញ្ចូល
                                },
                                decoration: InputDecoration(
                                  hintText: '🔍 Search by name or email...',
                                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                  suffixIcon: _searchName.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(Icons.clear, size: 18),
                                          onPressed: () {
                                            setState(() {
                                              _searchName = '';
                                              _searchController.clear();
                                            });
                                            _applyFilters();
                                          },
                                        )
                                      : null,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // ============ ប៊ូតុង Clear Filter ============
                            if (_searchName.isNotEmpty || _filterStatus != 'all')
                              Container(
                                height: 56,
                                child: ElevatedButton(
                                  onPressed: () {
                                    setState(() {
                                      _searchName = '';
                                      _searchController.clear();
                                      _filterStatus = 'all';
                                    });
                                    _loadReport();
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red.shade50,
                                    foregroundColor: Colors.red.shade700,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      side: BorderSide(color: Colors.red.shade200),
                                    ),
                                  ),
                                  child: const Text('Clear Filters'),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // ============ Summary Cards ============
                  Container(
                    padding: const EdgeInsets.all(12),
                    child: SizedBox(
                      height: 80,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          _buildSummaryCard(
                            label: 'Total',
                            value: _summary['total']?.toString() ?? '0',
                            color: const Color(0xFF173B69),
                          ),
                          const SizedBox(width: 8),
                          _buildSummaryCard(
                            label: 'Pending',
                            value: _summary['pending']?.toString() ?? '0',
                            color: Colors.orange,
                          ),
                          const SizedBox(width: 8),
                          _buildSummaryCard(
                            label: 'Approved',
                            value: _summary['approved']?.toString() ?? '0',
                            color: Colors.green,
                          ),
                          const SizedBox(width: 8),
                          _buildSummaryCard(
                            label: 'Rejected',
                            value: _summary['rejected']?.toString() ?? '0',
                            color: Colors.red,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ============ Total Days Card ============
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.purple.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.calendar_today, color: Colors.purple),
                        const SizedBox(width: 8),
                        Text(
                          'Total Days: ${_summary['totalDays'] ?? 0}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.purple,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.purple.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${_summary['autoApproved'] ?? 0} Auto',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.purple,
                            ),
                          ),
                        ),
                        if (_searchName.isNotEmpty)
                          const SizedBox(width: 16),
                        if (_searchName.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '🔍 $_searchName',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.blue,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ============ List of Reports ============
                  _reportData.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(40),
                          child: Column(
                            children: [
                              Icon(
                                _searchName.isNotEmpty 
                                    ? Icons.search_off 
                                    : Icons.inbox,
                                size: 64,
                                color: Colors.grey,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _searchName.isNotEmpty
                                    ? 'No results found for "$_searchName"'
                                    : 'No data found',
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 16,
                                ),
                              ),
                              if (_searchName.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Try searching with a different name',
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          itemCount: _reportData.length,
                          itemBuilder: (context, index) {
                            final r = _reportData[index];
                            return _ReportCard(data: r);
                          },
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
      width: 80,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
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
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
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
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
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
                Expanded(
                  child: Text(
                    data['userName'],
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
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
            const SizedBox(height: 4),
            Text(
              data['userEmail'],
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  '${data['startDate']} → ${data['endDate']}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.note, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    data['reason'],
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[700],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
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
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: data['autoApproved'] 
                        ? Colors.purple.withOpacity(0.1) 
                        : Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    data['autoApproved'] ? '🤖 Auto' : '👤 Manual',
                    style: TextStyle(
                      fontSize: 11,
                      color: data['autoApproved'] ? Colors.purple : Colors.orange,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '#${data['requestNumber']}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[500],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  DateFormat('dd/MM/yyyy HH:mm').format(data['createdAt']),
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
            if (data['rejectionReason'] != null && data['rejectionReason'].isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
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
                  '✅ Approved by: ${data['approvedByName']}',
                  style: TextStyle(
                    fontSize: 11,
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