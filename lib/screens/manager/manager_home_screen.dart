// lib/screens/manager/manager_home_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/request_service.dart';
import '../../services/telegram_service.dart';
import '../../utils/responsive.dart';
import '../../widgets/profile_avatar.dart';
import '../staff/notifications_screen.dart';
import 'manager_profile_screen.dart';
import '../../app_fonts.dart';

class ManagerHomeScreen extends StatefulWidget {
  const ManagerHomeScreen({super.key});

  @override
  State<ManagerHomeScreen> createState() => _ManagerHomeScreenState();
}

class _ManagerHomeScreenState extends State<ManagerHomeScreen> {
  final RequestService _requestService = RequestService();
  String managerName = 'Manager User';
  String? profileImageUrl;
  String managerDepartment = '';
  bool isLoading = true;
  String managerId = '';
  String? errorMessage;
  int _staffCount = 0;
  List<Map<String, dynamic>> _staffList = [];

  int _totalRequests = 0;
  int _pendingRequests = 0;
  int _approvedRequests = 0;
  int _rejectedRequests = 0;
  int _autoApprovedRequests = 0;
  int _totalDays = 0;

  int _unreadCount = 0;
  Stream<QuerySnapshot>? _notificationStream;

  @override
  void initState() {
    super.initState();
    _checkAuthAndLoad();
  }

  Future<void> _checkAuthAndLoad() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
      return;
    }
    setState(() => managerId = user.uid);
    await _loadManagerData();
    await _loadStaffCount();
    await _loadStatistics();
    _loadNotificationStream();
  }

  void _loadNotificationStream() {
    if (managerId.isEmpty) return;
    _notificationStream = FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: managerId)
        .where('isRead', isEqualTo: false)
        .snapshots();
    _notificationStream?.listen((snapshot) {
      if (mounted) setState(() => _unreadCount = snapshot.docs.length);
    });
  }

  Future<void> _refreshUnreadCount() async {
    if (managerId.isEmpty) return;
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: managerId)
          .where('isRead', isEqualTo: false)
          .get();
      if (mounted) setState(() => _unreadCount = snapshot.docs.length);
    } catch (e) {
      print('Error refreshing unread count: $e');
    }
  }

  Future<void> _refreshProfileImage() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final docSnapshot = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (docSnapshot.exists) {
        final data = docSnapshot.data() as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            profileImageUrl = data['profileImageUrl'] ?? '';
            managerName = data['fullName'] ?? data['username'] ?? 'Manager User';
          });
        }
      }
    } catch (e) {
      print('Error refreshing profile image: $e');
    }
  }

  Future<void> _loadManagerData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final docSnapshot = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (docSnapshot.exists) {
        final data = docSnapshot.data() as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            managerName = data['fullName'] ?? data['username'] ?? 'Manager User';
            profileImageUrl = data['profileImageUrl'] ?? '';
            managerDepartment = data['department'] ?? '';
            isLoading = false;
            errorMessage = null;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            managerName = user.email?.split('@').first ?? 'Manager User';
            isLoading = false;
            errorMessage = 'User profile not found';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
          errorMessage = 'Failed to load user data';
        });
      }
    }
  }

  Future<void> _loadStaffCount() async {
    if (managerDepartment.isEmpty) return;
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('roleId', isEqualTo: '2')
          .where('department', isEqualTo: managerDepartment)
          .where('status', isEqualTo: 'Active')
          .get();

      List<Map<String, dynamic>> staffList = [];
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        staffList.add({
          'id': doc.id,
          'name': data['fullName'] ?? data['username'] ?? 'Unknown',
          'email': data['email'] ?? 'No email',
          'profileImageUrl': data['profileImageUrl'] ?? '',
          'status': data['status'] ?? 'Active',
        });
      }

      if (mounted) {
        setState(() {
          _staffCount = snapshot.docs.length;
          _staffList = staffList;
        });
      }
    } catch (e) {
      print('Error loading staff count: $e');
    }
  }

  Future<void> _loadStatistics() async {
    try {
      Query query = FirebaseFirestore.instance.collection('leave_requests');
      if (managerDepartment.isNotEmpty) {
        query = query.where('department', isEqualTo: managerDepartment);
      }

      final snapshot = await query.get();

      int total = 0, pending = 0, approved = 0, rejected = 0, autoApproved = 0, totalDays = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        total++;
        final status = data['status'] ?? 'pending';
        final autoApprovedValue = data['autoApproved'] ?? false;
        int days = 0;
        final daysValue = data['totalDays'];
        if (daysValue != null) {
          if (daysValue is int) days = daysValue;
          else if (daysValue is double) days = daysValue.toInt();
          else if (daysValue is String) days = int.tryParse(daysValue) ?? 0;
          else if (daysValue is num) days = daysValue.toInt();
        }

        if (status == 'pending') pending++;
        else if (status == 'approved') {
          approved++;
          if (autoApprovedValue) autoApproved++;
        } else if (status == 'rejected') rejected++;
        totalDays += days;
      }

      if (mounted) {
        setState(() {
          _totalRequests = total;
          _pendingRequests = pending;
          _approvedRequests = approved;
          _rejectedRequests = rejected;
          _autoApprovedRequests = autoApproved;
          _totalDays = totalDays;
        });
      }
    } catch (e) {
      print('Error loading statistics: $e');
    }
  }

  void _showStaffListDialog() {
    if (_staffList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No staff members found in your department'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final bool isMobile = Responsive.isMobile(context);
    final double fontSize = Responsive.fontSize(context, 14);
    final double spacing = Responsive.spacing(context);

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: isMobile ? double.infinity : 400,
          padding: EdgeInsets.all(spacing * 1.5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Staff Members', style: TextStyle(fontSize: isMobile ? fontSize + 2 : fontSize + 4, fontWeight: FontWeight.bold)),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: spacing, vertical: spacing / 2),
                    decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                    child: Text('$_staffCount Staff', style: TextStyle(fontSize: isMobile ? fontSize * 0.8 : fontSize, color: Colors.green[700], fontWeight: FontWeight.w500)),
                  ),
                ],
              ),
              SizedBox(height: spacing),
              Container(
                padding: EdgeInsets.symmetric(horizontal: spacing, vertical: spacing / 2),
                decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    Icon(Icons.business, size: 16, color: Colors.blue[700]),
                    SizedBox(width: spacing / 2),
                    Text('Department: $managerDepartment', style: TextStyle(fontSize: isMobile ? fontSize * 0.8 : fontSize, color: Colors.blue[700], fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              SizedBox(height: spacing * 1.5),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _staffList.length,
                  separatorBuilder: (context, index) => Divider(height: spacing, color: Colors.grey.shade200),
                  itemBuilder: (context, index) {
                    final staff = _staffList[index];
                    return Container(
                      padding: EdgeInsets.symmetric(vertical: spacing / 1.5, horizontal: spacing / 2),
                      child: Row(
                        children: [
                          ProfileAvatar(
                            userId: staff['id'],
                            imageUrl: staff['profileImageUrl'],
                            name: staff['name'],
                            radius: isMobile ? 20 : 25,
                            backgroundColor: Colors.grey.shade200,
                            textColor: const Color(0xFF173B69),
                          ),
                          SizedBox(width: spacing),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(staff['name'], style: TextStyle(fontSize: isMobile ? fontSize : fontSize + 1, fontWeight: FontWeight.w600)),
                                Text(staff['email'], style: TextStyle(fontSize: isMobile ? fontSize * 0.75 : fontSize * 0.8, color: Colors.grey[600])),
                              ],
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: spacing / 1.5, vertical: spacing / 3),
                            decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                            child: Text('Active', style: TextStyle(fontSize: isMobile ? fontSize * 0.65 : fontSize * 0.7, color: Colors.green[700], fontWeight: FontWeight.w500)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              SizedBox(height: spacing),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Close', style: TextStyle(fontSize: isMobile ? fontSize : fontSize + 1)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===== OPEN TELEGRAM APP =====
  Future<void> _openTelegram() async {
    try {
      final Uri telegramUri = Uri.parse('tg://resolve?domain=telegram');
      if (await canLaunchUrl(telegramUri)) {
        await launchUrl(telegramUri);
      } else {
        final Uri fallbackUri = Uri.parse('https://t.me/telegram');
        if (await canLaunchUrl(fallbackUri)) {
          await launchUrl(fallbackUri);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Please install Telegram app to view attachment'),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 3),
              ),
            );
          }
        }
      }
    } catch (e) {
      print('❌ Error opening Telegram: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening Telegram: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ==================== SHOW REQUEST DETAIL DIALOG ====================
  void _showRequestDetailDialog({
    required String requestId,
    required String employeeName,
    required String reason,
    required String startDate,
    required String endDate,
    required int totalDays,
    required String department,
    required String permissionType,
    String? imageUrl,
  }) {
    final bool isMobile = Responsive.isMobile(context);
    final double fontSize = Responsive.fontSize(context, 14);
    final double spacing = Responsive.spacing(context);

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: isMobile ? double.infinity : 420,
          padding: EdgeInsets.all(spacing * 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: spacing, horizontal: spacing * 1.5),
                decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                child: Text(
                  'REQUEST DETAIL',
                  style: TextStyle(
                    fontSize: isMobile ? fontSize + 2 : fontSize + 4,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange[700],
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              SizedBox(height: spacing * 2),
              _buildDetailRow(label: 'Staff Name', value: employeeName, isMobile: isMobile, fontSize: fontSize, spacing: spacing, isBold: true),
              SizedBox(height: spacing * 1.5),
              _buildDetailRow(label: 'Department', value: department, isMobile: isMobile, fontSize: fontSize, spacing: spacing),
              SizedBox(height: spacing * 1.5),
              _buildDetailRow(label: 'Reason', value: reason, isMobile: isMobile, fontSize: fontSize, spacing: spacing, isMultiline: true),
              SizedBox(height: spacing * 1.5),
              _buildDetailRow(label: 'Date Range', value: '$startDate - $endDate', isMobile: isMobile, fontSize: fontSize, spacing: spacing),
              SizedBox(height: spacing * 1.5),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: spacing * 1.5, vertical: spacing),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Total Days', style: TextStyle(fontSize: isMobile ? fontSize * 0.7 : fontSize * 0.75, color: Colors.grey[600], fontWeight: FontWeight.w500)),
                          SizedBox(height: 2),
                          Text('$totalDays day${totalDays > 1 ? 's' : ''}', style: TextStyle(fontSize: isMobile ? fontSize + 2 : fontSize + 4, fontWeight: FontWeight.bold, color: Colors.orange[700])),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              
              SizedBox(height: spacing * 2.5),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: isMobile ? 44 : 48,
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _showRejectDialog(requestId, employeeName, totalDays);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red, width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: Text('Reject', style: TextStyle(fontSize: isMobile ? fontSize : fontSize + 1, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                  SizedBox(width: spacing),
                  Expanded(
                    child: SizedBox(
                      height: isMobile ? 44 : 48,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _approveRequest(requestId, employeeName, totalDays);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 2,
                        ),
                        child: Text('Approve', style: TextStyle(fontSize: isMobile ? fontSize : fontSize + 1, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: spacing),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Close', style: TextStyle(fontSize: isMobile ? fontSize * 0.85 : fontSize, color: Colors.grey[600], fontWeight: FontWeight.w500)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required String label,
    required String value,
    required bool isMobile,
    required double fontSize,
    required double spacing,
    bool isBold = false,
    bool isMultiline = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: isMobile ? fontSize * 0.75 : fontSize * 0.8, color: Colors.grey[600], fontWeight: FontWeight.w500, letterSpacing: 0.3)),
        SizedBox(height: 4),
        Container(
          padding: EdgeInsets.symmetric(horizontal: spacing * 1.5, vertical: isMultiline ? spacing : spacing * 0.6),
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: isMobile ? (isBold ? fontSize + 1 : fontSize) : (isBold ? fontSize + 3 : fontSize + 1),
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: isBold ? const Color(0xFF173B69) : Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  // ==================== SHOW REJECT DIALOG WITH CONFIRM ====================
  Future<void> _showRejectDialog(String requestId, String userName, int totalDays) async {
    final reasonController = TextEditingController();
    final bool isMobile = Responsive.isMobile(context);
    final double fontSize = Responsive.fontSize(context, 14);
    final double spacing = Responsive.spacing(context);

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
                SizedBox(width: spacing),
                Text(
                  'Reject Request',
                  style: TextStyle(
                    fontSize: isMobile ? fontSize + 2 : fontSize + 4,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Are you sure you want to reject this request?',
                  style: TextStyle(
                    fontSize: fontSize,
                    color: Colors.grey[700],
                  ),
                ),
                SizedBox(height: spacing * 1.5),
                Container(
                  padding: EdgeInsets.all(spacing),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Staff: $userName',
                        style: TextStyle(
                          fontSize: isMobile ? fontSize * 0.9 : fontSize,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Total Days: $totalDays day${totalDays > 1 ? 's' : ''}',
                        style: TextStyle(
                          fontSize: isMobile ? fontSize * 0.9 : fontSize,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: spacing * 1.5),
                Text(
                  'Reason for rejection:',
                  style: TextStyle(
                    fontSize: isMobile ? fontSize * 0.9 : fontSize,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: spacing / 2),
                TextField(
                  controller: reasonController,
                  decoration: InputDecoration(
                    hintText: 'Enter reason for rejection...',
                    hintStyle: TextStyle(fontSize: fontSize, color: Colors.grey[400]),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Colors.red, width: 2),
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: spacing,
                      vertical: isMobile ? 10 : 14,
                    ),
                  ),
                  maxLines: isMobile ? 2 : 3,
                  style: TextStyle(fontSize: fontSize),
                  autofocus: true,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey[600],
                ),
                child: Text(
                  'Cancel',
                  style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w500),
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  final rejectionReason = reasonController.text.trim().isNotEmpty
                      ? reasonController.text.trim()
                      : 'No reason provided';

                  await _rejectRequest(
                    requestId: requestId,
                    userName: userName,
                    totalDays: totalDays,
                    rejectionReason: rejectionReason,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: spacing * 2, vertical: spacing),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cancel_outlined, size: 18),
                    SizedBox(width: spacing / 2),
                    Text(
                      'Confirm Reject',
                      style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ==================== REJECT REQUEST ====================
  Future<void> _rejectRequest({
    required String requestId,
    required String userName,
    required int totalDays,
    required String rejectionReason,
  }) async {
    try {
      final requestDoc = await FirebaseFirestore.instance.collection('leave_requests').doc(requestId).get();
      final requestData = requestDoc.data() as Map<String, dynamic>;
      final reason = requestData['reason'] ?? 'No reason provided';
      final startDate = requestData['startDate'] ?? 'N/A';
      final endDate = requestData['endDate'] ?? 'N/A';

      await _requestService.rejectRequestAsManager(
        requestId,
        managerId,
        managerName,
        managerDepartment,
        reason: rejectionReason,
      );

      final rejectionMessage = '''
REQUEST REJECTED

Staff: $userName
Reason: $reason
Date: $startDate - $endDate
Total Days: $totalDays

Rejected By: $managerName (Manager)
Department: $managerDepartment
Time: ${TelegramService.formatTimeOnlyAMPM()}
Rejection Reason: $rejectionReason

Status: REJECTED
      ''';

      await TelegramService.sendToAll(rejectionMessage);
      await _loadStatistics();
      await _refreshUnreadCount();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Request rejected: $rejectionReason', style: TextStyle(fontSize: AppFonts.md)),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString().replaceFirst('Exception: ', '')}', style: TextStyle(fontSize: AppFonts.md)),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // ==================== APPROVE REQUEST ====================
  Future<void> _approveRequest(String requestId, String userName, int totalDays) async {
    try {
      final requestDoc = await FirebaseFirestore.instance.collection('leave_requests').doc(requestId).get();
      final requestData = requestDoc.data() as Map<String, dynamic>;
      final reason = requestData['reason'] ?? 'No reason provided';
      final startDate = requestData['startDate'] ?? 'N/A';
      final endDate = requestData['endDate'] ?? 'N/A';

      await _requestService.approveRequestAsManager(
        requestId,
        managerId,
        managerName,
        managerDepartment,
      );

      final approvalMessage = '''
REQUEST APPROVED

Staff: $userName
Reason: $reason
Date: $startDate - $endDate
Total Days: $totalDays

Approved By: $managerName (Manager)
Department: $managerDepartment
Time: ${TelegramService.formatTimeOnlyAMPM()}

Status: APPROVED
      ''';

      await TelegramService.sendToAll(approvalMessage);
      await _loadStatistics();
      await _refreshUnreadCount();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Request approved successfully', style: TextStyle(fontSize: AppFonts.md)),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString().replaceFirst('Exception: ', '')}', style: TextStyle(fontSize: AppFonts.md)),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = Responsive.isMobile(context);
    final double fontSize = Responsive.fontSize(context, 14);
    final double spacing = Responsive.spacing(context);
    final double iconSize = Responsive.iconSize(context, 24);
    double bottomPadding = MediaQuery.of(context).padding.bottom + 24;

    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (errorMessage != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(spacing * 2.5),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                SizedBox(height: spacing * 2),
                Text('Error', style: TextStyle(fontSize: fontSize + 2, fontWeight: FontWeight.bold, color: Colors.red[700])),
                SizedBox(height: spacing),
                Text(errorMessage!, textAlign: TextAlign.center, style: TextStyle(fontSize: fontSize)),
                SizedBox(height: spacing * 2.5),
                ElevatedButton(
                  onPressed: () {
                    setState(() { errorMessage = null; isLoading = true; });
                    _checkAuthAndLoad();
                  },
                  child: Text('Retry', style: TextStyle(fontSize: fontSize)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await _loadManagerData();
            await _loadStaffCount();
            await _loadStatistics();
            await _refreshProfileImage();
            await _refreshUnreadCount();
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ===== TOP SECTION (Fixed, not scrollable) =====
              Padding(
                padding: EdgeInsets.all(isMobile ? 12 : 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile Section
                    _buildProfileSection(isMobile, spacing, iconSize),
                    const SizedBox(height: 14),
                    
                    // Bar Chart
                    _buildBarChart(isMobile, spacing, fontSize),
                    const SizedBox(height: 16),
                    
                    // Department & Staff Count
                    _buildDepartmentSection(isMobile, spacing, iconSize, fontSize),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
              
              // ===== PENDING APPROVALS (Scrollable) =====
              Expanded(
                child: _buildPendingApprovals(isMobile, spacing, fontSize),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileSection(bool isMobile, double spacing, double iconSize) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final isTablet = screenWidth >= 600;

    final avatarRadius = isSmallScreen ? 30 : (isTablet ? 48 : 36);
    final nameSize = isSmallScreen ? 16 : (isTablet ? 24 : 20);
    final roleSize = isSmallScreen ? 11 : (isTablet ? 16 : 13);

    return Container(
      padding: EdgeInsets.all(isMobile ? 14 : 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A3B68), Color(0xFF2C5F8A)],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          ProfileAvatar(
            userId: managerId,
            imageUrl: profileImageUrl,
            name: managerName,
            radius: avatarRadius.toDouble(),
            backgroundColor: Colors.white.withValues(alpha: 0.15),
            textColor: Colors.white,
            onTap: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ManagerProfileScreen()),
              );
              if (result == true) await _refreshProfileImage();
            },
          ),
          SizedBox(width: isMobile ? 10 : 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  managerName,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: nameSize.toDouble(),
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: isMobile ? 2 : 4),
                Row(
                  children: [
                    Icon(Icons.manage_accounts, size: isMobile ? 14 : 16, color: Colors.white70),
                    const SizedBox(width: 4),
                    Text(
                      'Manager',
                      style: TextStyle(color: Colors.white70, fontSize: roleSize.toDouble()),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _buildNotificationBadge(isMobile, iconSize),
        ],
      ),
    );
  }

  Widget _buildNotificationBadge(bool isMobile, double iconSize) {
    final notificationSize = isMobile ? iconSize * 0.8 : iconSize * 1.2;

    return Stack(
      children: [
        IconButton(
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const NotificationsScreen()),
            );
            _refreshUnreadCount();
          },
          icon: Icon(Icons.notifications_none, color: Colors.white),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        if (_unreadCount > 0)
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
              constraints: BoxConstraints(
                minWidth: isMobile ? 14 : 18,
                minHeight: isMobile ? 14 : 18,
              ),
              child: Text(
                _unreadCount > 99 ? '99+' : _unreadCount.toString(),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isMobile ? 8 : 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  // ==================== BAR CHART ====================
  Widget _buildBarChart(bool isMobile, double spacing, double fontSize) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final isTablet = screenWidth >= 600;

    final List<BarChartGroupData> barGroups = [
      BarChartGroupData(
        x: 0,
        barRods: [
          BarChartRodData(
            toY: _pendingRequests.toDouble(),
            color: const Color(0xFFF59E0B),
            width: isSmallScreen ? 18 : (isTablet ? 32 : 24),
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ),
      BarChartGroupData(
        x: 1,
        barRods: [
          BarChartRodData(
            toY: _approvedRequests.toDouble(),
            color: const Color(0xFF10B981),
            width: isSmallScreen ? 18 : (isTablet ? 32 : 24),
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ),
      BarChartGroupData(
        x: 2,
        barRods: [
          BarChartRodData(
            toY: _rejectedRequests.toDouble(),
            color: const Color(0xFFEF4444),
            width: isSmallScreen ? 18 : (isTablet ? 32 : 24),
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ),
      BarChartGroupData(
        x: 3,
        barRods: [
          BarChartRodData(
            toY: _autoApprovedRequests.toDouble(),
            color: const Color(0xFF8B5CF6),
            width: isSmallScreen ? 18 : (isTablet ? 32 : 24),
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ),
    ];

    final maxY = [_pendingRequests, _approvedRequests, _rejectedRequests, _autoApprovedRequests]
        .reduce((a, b) => a > b ? a : b)
        .toDouble();
    final double maxValue = maxY > 0 ? maxY * 1.4 : 10.0;

    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 18,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Requests Overview',
                style: TextStyle(
                  fontSize: isMobile ? 15 : 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1A3B68),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_totalRequests == 0)
            SizedBox(
              height: 160,
              child: Center(
                child: Text(
                  'No data available',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                ),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  flex: 7,
                  child: SizedBox(
                    height: isSmallScreen ? 140 : (isTablet ? 190 : 160),
                    child: BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: maxValue,
                        barTouchData: BarTouchData(
                          enabled: true,
                          touchTooltipData: BarTouchTooltipData(
                            getTooltipItem: (group, groupIndex, rod, rodIndex) {
                              return BarTooltipItem(
                                '${rod.toY.round()}',
                                const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              );
                            },
                          ),
                        ),
                        titlesData: FlTitlesData(
                          show: true,
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                final labels = ['Pending', 'Approved', 'Rejected', 'Auto-App'];
                                final index = value.toInt();
                                if (index >= 0 && index < labels.length) {
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      labels[index],
                                      style: TextStyle(
                                        fontSize: isSmallScreen ? 8 : (isTablet ? 12 : 10),
                                        fontWeight: FontWeight.w500,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                              reservedSize: isSmallScreen ? 30 : 40,
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          topTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                        ),
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: maxValue / 4,
                          getDrawingHorizontalLine: (value) {
                            return FlLine(
                              color: Colors.grey.shade300,
                              strokeWidth: 0.5,
                              dashArray: [4, 4],
                            );
                          },
                        ),
                        borderData: FlBorderData(show: false),
                        barGroups: barGroups,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Padding(
                    padding: EdgeInsets.only(left: isMobile ? 8 : 16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLegendItem('Pending', _pendingRequests, const Color(0xFFF59E0B), isSmallScreen, isTablet),
                        const SizedBox(height: 6),
                        _buildLegendItem('Approved', _approvedRequests, const Color(0xFF10B981), isSmallScreen, isTablet),
                        const SizedBox(height: 6),
                        _buildLegendItem('Rejected', _rejectedRequests, const Color(0xFFEF4444), isSmallScreen, isTablet),
                        const SizedBox(height: 6),
                        _buildLegendItem('Auto-App', _autoApprovedRequests, const Color(0xFF8B5CF6), isSmallScreen, isTablet),
                      ],
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String title, int count, Color color, bool isSmallScreen, bool isTablet) {
    return Row(
      children: [
        Container(
          width: isSmallScreen ? 10 : 14,
          height: isSmallScreen ? 10 : 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '$title: $count',
          style: TextStyle(
            fontSize: isSmallScreen ? 9 : (isTablet ? 13 : 11),
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade700,
          ),
        ),
      ],
    );
  }

  Widget _buildDepartmentSection(bool isMobile, double spacing, double iconSize, double fontSize) {
    String departmentDisplay = managerDepartment.isNotEmpty ? managerDepartment : 'No department assigned';

    return Container(
      padding: EdgeInsets.all(isMobile ? 10 : 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: spacing / 1.5, vertical: spacing / 1.5),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.business, size: iconSize - 8, color: Colors.blue[700]),
                    SizedBox(width: spacing / 2),
                    Text(
                      departmentDisplay,
                      style: TextStyle(
                        fontSize: isMobile ? fontSize * 0.85 : fontSize,
                        color: Colors.blue[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Spacer(),
          GestureDetector(
            onTap: _showStaffListDialog,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: spacing * 1.5, vertical: spacing / 1.5),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.green.withValues(alpha: 0.3), width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.people, size: iconSize - 8, color: Colors.green[700]),
                  SizedBox(width: spacing / 3),
                  Text(
                    '$_staffCount Staff',
                    style: TextStyle(
                      fontSize: isMobile ? fontSize * 0.85 : fontSize,
                      color: Colors.green[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Icon(Icons.arrow_drop_down, size: 16, color: Colors.green[700]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== PENDING APPROVALS LIST WITH BUTTONS ====================
  Widget _buildPendingApprovals(bool isMobile, double spacing, double fontSize) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 10 : 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 18,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Pending Approvals',
                style: TextStyle(
                  fontSize: isMobile ? 15 : 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1A3B68),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // ===== SCROLLABLE PENDING REQUESTS =====
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _requestService.getPendingRequestsForManager(managerDepartment),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.red),
                        SizedBox(height: spacing),
                        Text('Error: ${snapshot.error}', style: TextStyle(fontSize: fontSize)),
                      ],
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final requests = snapshot.data?.docs ?? [];

                if (requests.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: EdgeInsets.all(spacing * 3),
                      child: Column(
                        children: [
                          Icon(Icons.inbox_outlined, size: 48, color: Colors.grey.shade400),
                          SizedBox(height: spacing),
                          Text(
                            'No pending requests',
                            style: TextStyle(fontSize: fontSize, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                          ),
                          Text(
                            'All requests have been processed',
                            style: TextStyle(fontSize: fontSize * 0.85, color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.only(bottom: 24),
                  itemCount: requests.length,
                  itemBuilder: (context, index) {
                    final doc = requests[index];
                    final data = doc.data() as Map<String, dynamic>;
                    return Padding(
                      padding: EdgeInsets.only(bottom: spacing),
                      child: _buildPendingCardWithButtons(
                        requestId: doc.id,
                        data: data,
                        isMobile: isMobile,
                        fontSize: fontSize,
                        spacing: spacing,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ==================== PENDING CARD WITH APPROVE/REJECT BUTTONS ====================
  Widget _buildPendingCardWithButtons({
    required String requestId,
    required Map<String, dynamic> data,
    required bool isMobile,
    required double fontSize,
    required double spacing,
  }) {
    final String employeeName = data['userName'] ?? 'Unknown';
    final String reason = data['reason'] ?? 'No reason';
    final int totalDays = data['totalDays'] ?? 0;
    final String startDate = data['startDate'] ?? 'N/A';
    final String endDate = data['endDate'] ?? 'N/A';
    final String month = _getMonthFromDate(startDate);
    final String date = _getDateFromDate(startDate);
    final String imageUrl = data['imageUrl'] ?? '';

    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 14),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.15), width: 1),
      ),
      child: Column(
        children: [
          // Top Row: Info (Clickable to see detail)
          GestureDetector(
            onTap: () => _showRequestDetailDialog(
              requestId: requestId,
              employeeName: employeeName,
              reason: reason,
              startDate: startDate,
              endDate: endDate,
              totalDays: totalDays,
              department: data['department'] ?? 'N/A',
              permissionType: data['permissionType'] ?? 'Leave',
              imageUrl: imageUrl,
            ),
            child: Row(
              children: [
                Container(
                  width: isMobile ? 44 : 52,
                  padding: EdgeInsets.symmetric(vertical: spacing / 1.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF173B69).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Text(
                        month,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: isMobile ? fontSize * 0.8 : fontSize,
                          color: const Color(0xFF173B69),
                        ),
                      ),
                      Text(
                        date,
                        style: TextStyle(
                          fontSize: isMobile ? fontSize * 0.8 : fontSize,
                          color: const Color(0xFF173B69),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: spacing),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        employeeName,
                        style: TextStyle(
                          fontSize: isMobile ? fontSize : fontSize + 1,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 2),
                      Text(
                        reason,
                        style: TextStyle(
                          fontSize: isMobile ? fontSize * 0.75 : fontSize * 0.85,
                          color: Colors.grey.shade700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: spacing / 2, vertical: spacing / 4),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$totalDays day${totalDays > 1 ? 's' : ''}',
                              style: TextStyle(
                                fontSize: isMobile ? fontSize * 0.65 : fontSize * 0.75,
                                color: Colors.orange,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          SizedBox(width: spacing / 2),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: spacing / 2, vertical: spacing / 4),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.access_time, size: isMobile ? 10 : 12, color: Colors.orange[700]),
                                SizedBox(width: 2),
                                Text(
                                  'Pending',
                                  style: TextStyle(
                                    fontSize: isMobile ? fontSize * 0.6 : fontSize * 0.7,
                                    color: Colors.orange[700],
                                    fontWeight: FontWeight.w600,
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
                Icon(Icons.arrow_forward_ios, size: isMobile ? 14 : 18, color: Colors.grey.shade400),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getMonthFromDate(String? dateStr) {
    if (dateStr == null) return 'N/A';
    final parts = dateStr.split(' ');
    if (parts.length >= 2) return parts[1].toUpperCase();
    return 'N/A';
  }

  String _getDateFromDate(String? dateStr) {
    if (dateStr == null) return 'N/A';
    final parts = dateStr.split(' ');
    return parts.isNotEmpty ? parts[0] : 'N/A';
  }
}