import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/request_service.dart';
import '../../services/telegram_service.dart';
import '../../utils/responsive.dart'; 
import '../staff/notifications_screen.dart';
import 'manager_profile_screen.dart';  // ✅ Manager Profile
import '../../app_fonts.dart';

class ManagerHomeScreen extends StatefulWidget {
  const ManagerHomeScreen({super.key});

  @override
  State<ManagerHomeScreen> createState() => _ManagerHomeScreenState();
}

class _ManagerHomeScreenState extends State<ManagerHomeScreen> {
  final RequestService _requestService = RequestService();
  String managerName = 'Manager User';
  String managerDepartment = '';
  bool isLoading = true;
  String managerId = '';
  String? errorMessage;
  int _staffCount = 0;
  
  // Statistics
  int _totalRequests = 0;
  int _pendingRequests = 0;
  int _approvedRequests = 0;
  int _rejectedRequests = 0;
  int _autoApprovedRequests = 0;
  int _totalDays = 0;

  @override
  void initState() {
    super.initState();
    _checkAuthAndLoad();
  }

  Future<void> _checkAuthAndLoad() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
      return;
    }

    if (mounted) {
      setState(() {
        managerId = user.uid;
      });
    }

    await _loadManagerData();
    await _loadStaffCount();
    await _loadStatistics();
  }

  Future<void> _loadManagerData() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      try {
        final docSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (docSnapshot.exists) {
          final data = docSnapshot.data()!;
          if (mounted) {
            setState(() {
              managerName = data['fullName'] ?? data['username'] ?? 'Manager User';
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
              errorMessage = 'User profile not found in database';
            });
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            isLoading = false;
            errorMessage = 'Failed to load user data: $e';
          });
        }
      }
    } else {
      if (mounted) {
        setState(() {
          isLoading = false;
          errorMessage = 'No user logged in';
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

      if (mounted) {
        setState(() {
          _staffCount = snapshot.docs.length;
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
      
      int total = 0;
      int pending = 0;
      int approved = 0;
      int rejected = 0;
      int autoApproved = 0;
      int totalDays = 0;
      
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        total++;
        
        final status = data['status'] ?? 'pending';
        final autoApprovedValue = data['autoApproved'] ?? false;
        
        // 🔥 អាន totalDays ដោយសុវត្ថិភាព
        int days = 0;
        final daysValue = data['totalDays'];
        if (daysValue != null) {
          if (daysValue is int) {
            days = daysValue;
          } else if (daysValue is double) {
            days = daysValue.toInt();
          } else if (daysValue is String) {
            days = int.tryParse(daysValue) ?? 0;
          } else if (daysValue is num) {
            days = daysValue.toInt();
          }
        }
        
        if (status == 'pending') {
          pending++;
        } else if (status == 'approved') {
          approved++;
          if (autoApprovedValue) {
            autoApproved++;
          }
        } else if (status == 'rejected') {
          rejected++;
        }
        
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
      
      print('📊 Statistics loaded: Total=$total, Pending=$pending, Approved=$approved, Rejected=$rejected');
    } catch (e) {
      print('❌ Error loading statistics: $e');
      if (mounted) {
        setState(() {
          // Keep existing values or set to 0
        });
      }
    }
  }

  Future<void> _approveRequest(
      String requestId, String userName, int totalDays) async {
    try {
      final requestDoc = await FirebaseFirestore.instance
          .collection('leave_requests')
          .doc(requestId)
          .get();
      
      final requestData = requestDoc.data() as Map<String, dynamic>;
      final permissionType = requestData['permissionType'] ?? 'Leave';
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
✅ REQUEST APPROVED

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
      
      print('📨 Telegram notifications sent for approval');

      await _loadStatistics();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ Request approved successfully',
              style: TextStyle(fontSize: AppFonts.md),
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } on FirebaseException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '❌ ${e.message}',
              style: TextStyle(fontSize: AppFonts.md),
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '❌ ${e.toString().replaceFirst('Exception: ', '')}',
              style: TextStyle(fontSize: AppFonts.md),
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _showRejectDialog(
      String requestId, String userName, int totalDays) async {
    final reasonController = TextEditingController();
    
    final bool isMobile = Responsive.isMobile(context);
    final double fontSize = Responsive.fontSize(context, 14);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Reject Request',
          style: TextStyle(
            fontSize: isMobile ? fontSize : fontSize + 2,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Please provide a reason for rejection:',
              style: TextStyle(fontSize: fontSize),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                hintText: 'Reason...',
                hintStyle: TextStyle(fontSize: fontSize),
                border: const OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: isMobile ? 10 : 14,
                ),
              ),
              maxLines: isMobile ? 2 : 3,
              style: TextStyle(fontSize: fontSize),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(fontSize: fontSize),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                final requestDoc = await FirebaseFirestore.instance
                    .collection('leave_requests')
                    .doc(requestId)
                    .get();
                
                final requestData = requestDoc.data() as Map<String, dynamic>;
                final permissionType = requestData['permissionType'] ?? 'Leave';
                final reason = requestData['reason'] ?? 'No reason provided';
                final startDate = requestData['startDate'] ?? 'N/A';
                final endDate = requestData['endDate'] ?? 'N/A';
                final rejectionReason = reasonController.text.isNotEmpty
                    ? reasonController.text
                    : 'No reason provided';

                await _requestService.rejectRequestAsManager(
                  requestId,
                  managerId,
                  managerName,
                  managerDepartment,
                  reason: rejectionReason,
                );

                final rejectionMessage = '''
❌ REQUEST REJECTED

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
                
                print('📨 Telegram notifications sent for rejection');

                await _loadStatistics();

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '❌ Request rejected',
                        style: TextStyle(fontSize: AppFonts.md),
                      ),
                      backgroundColor: Colors.red,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '❌ ${e.toString().replaceFirst('Exception: ', '')}',
                        style: TextStyle(fontSize: AppFonts.md),
                      ),
                      backgroundColor: Colors.red,
                      duration: const Duration(seconds: 3),
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(
              'Reject',
              style: TextStyle(fontSize: fontSize),
            ),
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
    final double iconSize = Responsive.iconSize(context, 24);

    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
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
                Text(
                  'Error',
                  style: TextStyle(
                    fontSize: fontSize + 2,
                    fontWeight: FontWeight.bold,
                    color: Colors.red[700],
                  ),
                ),
                SizedBox(height: spacing),
                Text(
                  errorMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: fontSize),
                ),
                SizedBox(height: spacing * 2.5),
                ElevatedButton(
                  onPressed: () {
                    if (mounted) {
                      setState(() {
                        errorMessage = null;
                        isLoading = true;
                      });
                    }
                    _checkAuthAndLoad();
                  },
                  child: Text(
                    'Retry',
                    style: TextStyle(fontSize: fontSize),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    String departmentDisplay = managerDepartment.isNotEmpty
        ? ' $managerDepartment'
        : ' No department assigned';

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                vertical: isMobile ? 12 : 16,
                horizontal: spacing,
              ),
              decoration: const BoxDecoration(
                color: Color(0xFF173B69),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: _ManagerUserHeader(
                managerName: managerName,
                isLoading: isLoading,
                userId: managerId,
                useWhiteTheme: true,
                isMobile: isMobile,
                fontSize: fontSize,
                spacing: spacing,
                iconSize: iconSize,
              ),
            ),
            // Scrollable content
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  await _loadManagerData();
                  await _loadStaffCount();
                  await _loadStatistics();
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.all(spacing * 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Department & staff count row
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: spacing * 1.5,
                              vertical: spacing / 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.business,
                                  size: iconSize - 8,
                                  color: Colors.blue[700],
                                ),
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
                          const Spacer(),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: spacing * 1.5,
                              vertical: spacing / 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.people,
                                  size: iconSize - 8,
                                  color: Colors.green[700],
                                ),
                                SizedBox(width: spacing / 3),
                                Text(
                                  '$_staffCount Staff',
                                  style: TextStyle(
                                    fontSize: isMobile ? fontSize * 0.85 : fontSize,
                                    color: Colors.green[700],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: spacing * 2),
                      
                      // Statistics Cards
                      Row(
                        children: [
                          _buildStatCard(
                            label: 'Total',
                            value: '$_totalRequests',
                            color: const Color(0xFF173B69),
                            isMobile: isMobile,
                            fontSize: fontSize,
                          ),
                          _buildStatCard(
                            label: 'Pending',
                            value: '$_pendingRequests',
                            color: Colors.orange,
                            isMobile: isMobile,
                            fontSize: fontSize,
                          ),
                          _buildStatCard(
                            label: 'Approved',
                            value: '$_approvedRequests',
                            color: Colors.green,
                            isMobile: isMobile,
                            fontSize: fontSize,
                          ),
                          _buildStatCard(
                            label: 'Rejected',
                            value: '$_rejectedRequests',
                            color: Colors.red,
                            isMobile: isMobile,
                            fontSize: fontSize,
                          ),
                        ],
                      ),
                      
                      SizedBox(height: spacing),
                      
                      // Auto Approved and Total Days
                      Row(
                        children: [
                          _buildStatCard(
                            label: 'Auto Approved',
                            value: '$_autoApprovedRequests',
                            color: Colors.purple,
                            isMobile: isMobile,
                            fontSize: fontSize,
                          ),
                          _buildStatCard(
                            label: 'Total Days',
                            value: '$_totalDays',
                            color: Colors.teal,
                            isMobile: isMobile,
                            fontSize: fontSize,
                          ),
                          const Expanded(
                            child: SizedBox(),
                          ),
                        ],
                      ),
                      
                      SizedBox(height: spacing * 3),
                      
                      // Pending Approvals Title
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Pending Approvals',
                            style: TextStyle(
                              fontSize: isMobile ? fontSize + 2 : fontSize + 4,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (managerDepartment.isNotEmpty)
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: spacing,
                                vertical: spacing / 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                managerDepartment,
                                style: TextStyle(
                                  fontSize: isMobile ? fontSize * 0.8 : fontSize,
                                  color: Colors.green[700],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                        ],
                      ),
                      SizedBox(height: spacing * 1.5),
                      
                      // Pending Requests List
                      StreamBuilder<QuerySnapshot>(
                        stream: _requestService
                            .getPendingRequestsForManager(managerDepartment),
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return Center(
                              child: Column(
                                children: [
                                  const Icon(Icons.error_outline,
                                      size: 48, color: Colors.red),
                                  SizedBox(height: spacing),
                                  Text(
                                    'Error: ${snapshot.error}',
                                    style: TextStyle(fontSize: fontSize),
                                  ),
                                  SizedBox(height: spacing),
                                  ElevatedButton(
                                    onPressed: () {
                                      setState(() {});
                                    },
                                    child: Text(
                                      'Retry',
                                      style: TextStyle(fontSize: fontSize),
                                    ),
                                  ),
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
                                padding: EdgeInsets.all(spacing * 5),
                                child: Column(
                                  children: [
                                    Icon(Icons.inbox, size: 48, color: Colors.grey),
                                    SizedBox(height: spacing),
                                    Text(
                                      'No pending requests',
                                      style: TextStyle(
                                        fontSize: fontSize,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    Text(
                                      'All requests in your department have been processed',
                                      style: TextStyle(
                                        fontSize: fontSize * 0.85,
                                        color: Colors.grey,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }

                          return Column(
                            children: requests.map((doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              final requestDepartment =
                                  data['department'] ?? 'No Department';

                              return _PendingCard(
                                requestId: doc.id,
                                employeeName: data['userName'] ?? 'Unknown',
                                month: _getMonthFromDate(data['startDate']),
                                date: _getDateFromDate(data['startDate']),
                                reason: data['reason'] ?? 'No reason',
                                totalDays: data['totalDays'] ?? 0,
                                department: requestDepartment,
                                permissionType: data['permissionType'] ?? 'Leave',
                                startDate: data['startDate'] ?? 'N/A',
                                endDate: data['endDate'] ?? 'N/A',
                                isMobile: isMobile,
                                fontSize: fontSize,
                                spacing: spacing,
                                onApprove: () => _approveRequest(
                                  doc.id,
                                  data['userName'] ?? 'Unknown',
                                  data['totalDays'] ?? 0,
                                ),
                                onReject: () => _showRejectDialog(
                                  doc.id,
                                  data['userName'] ?? 'Unknown',
                                  data['totalDays'] ?? 0,
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),
                      SizedBox(height: isMobile ? 60 : 80),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String label,
    required String value,
    required Color color,
    required bool isMobile,
    required double fontSize,
  }) {
    return Expanded(
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 2),
        padding: EdgeInsets.symmetric(
          vertical: isMobile ? 6 : 8,
          horizontal: 2,
        ),
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
                fontSize: isMobile ? fontSize : fontSize + 2,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: isMobile ? fontSize * 0.7 : fontSize,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getMonthFromDate(String? dateStr) {
    if (dateStr == null) return 'N/A';
    final parts = dateStr.split(' ');
    if (parts.length >= 2) {
      return parts[1].toUpperCase();
    }
    return 'N/A';
  }

  String _getDateFromDate(String? dateStr) {
    if (dateStr == null) return 'N/A';
    final parts = dateStr.split(' ');
    return parts[0];
  }
}

// ================= MANAGER USER HEADER =================
class _ManagerUserHeader extends StatelessWidget {
  final String managerName;
  final bool isLoading;
  final String userId;
  final bool useWhiteTheme;
  final bool isMobile;
  final double fontSize;
  final double spacing;
  final double iconSize;

  const _ManagerUserHeader({
    required this.managerName,
    required this.isLoading,
    required this.userId,
    this.useWhiteTheme = false,
    required this.isMobile,
    required this.fontSize,
    required this.spacing,
    required this.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = useWhiteTheme ? Colors.white : const Color(0xFF173B69);
    final subTextColor = useWhiteTheme ? Colors.white70 : Colors.grey;
    final iconColor = useWhiteTheme ? Colors.white : const Color(0xFF173B69);
    final avatarBg = useWhiteTheme ? Colors.white : const Color(0xFF173B69);
    final avatarIcon = useWhiteTheme ? const Color(0xFF173B69) : Colors.white;

    return Row(
      children: [
        // ✅ Avatar - Click to Manager Profile
        GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ManagerProfileScreen()),
          ),
          child: CircleAvatar(
            radius: isMobile ? 30 : 40,
            backgroundColor: avatarBg,
            child: Icon(
              Icons.manage_accounts,
              size: isMobile ? 30 : 40,
              color: avatarIcon,
            ),
          ),
        ),
        SizedBox(width: spacing * 1.5),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isLoading)
                SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: useWhiteTheme ? Colors.white : const Color(0xFF173B69),
                  ),
                )
              else
                Text(
                  managerName,
                  style: TextStyle(
                    color: textColor,
                    fontSize: isMobile ? fontSize : fontSize + 2,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              SizedBox(height: spacing / 4),
              Text(
                'Manager',
                style: TextStyle(
                  color: subTextColor,
                  fontSize: isMobile ? fontSize * 0.85 : fontSize,
                ),
              ),
            ],
          ),
        ),
        _NotificationIconWithBadgeManager(
          userId: userId,
          iconColor: iconColor,
          isMobile: isMobile,
          iconSize: iconSize,
        ),
      ],
    );
  }
}

// ================= NOTIFICATION ICON WITH BADGE (Manager) =================
class _NotificationIconWithBadgeManager extends StatelessWidget {
  final String userId;
  final Color iconColor;
  final bool isMobile;
  final double iconSize;

  const _NotificationIconWithBadgeManager({
    required this.userId,
    this.iconColor = const Color(0xFF173B69),
    required this.isMobile,
    required this.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .snapshots(),
      builder: (context, snapshot) {
        int unreadCount = 0;

        if (snapshot.hasData) {
          unreadCount = snapshot.data!.docs.length;
        }

        return Stack(
          children: [
            IconButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationsScreen(),
                ),
              ),
              icon: Icon(
                Icons.notifications_none,
                color: iconColor,
                size: isMobile ? iconSize - 4 : iconSize,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            if (unreadCount > 0)
              Positioned(
                top: 2,
                right: 2,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  constraints: BoxConstraints(
                    minWidth: isMobile ? 14 : 18,
                    minHeight: isMobile ? 14 : 18,
                  ),
                  child: Text(
                    unreadCount > 99 ? '99+' : '$unreadCount',
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
      },
    );
  }
}

// ================= PENDING CARD =================
class _PendingCard extends StatelessWidget {
  final String requestId;
  final String employeeName;
  final String month;
  final String date;
  final String reason;
  final int totalDays;
  final String department;
  final String permissionType;
  final String startDate;
  final String endDate;
  final bool isMobile;
  final double fontSize;
  final double spacing;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _PendingCard({
    required this.requestId,
    required this.employeeName,
    required this.month,
    required this.date,
    required this.reason,
    required this.totalDays,
    required this.department,
    required this.permissionType,
    required this.startDate,
    required this.endDate,
    required this.isMobile,
    required this.fontSize,
    required this.spacing,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: spacing * 1.5),
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade300,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: isMobile ? 50 : 60,
                padding: EdgeInsets.symmetric(
                  horizontal: spacing / 2,
                  vertical: spacing,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF173B69).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Text(
                      month,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: isMobile ? fontSize * 0.85 : fontSize,
                        color: const Color(0xFF173B69),
                      ),
                    ),
                    Text(
                      date,
                      style: TextStyle(
                        fontSize: isMobile ? fontSize * 0.85 : fontSize,
                        color: const Color(0xFF173B69),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: spacing * 1.5),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      employeeName,
                      style: TextStyle(
                        fontSize: isMobile ? fontSize : fontSize + 2,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: spacing / 2),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: spacing / 2,
                        vertical: spacing / 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        ' $department',
                        style: TextStyle(
                          fontSize: isMobile ? fontSize * 0.75 : fontSize,
                          color: Colors.blue[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    SizedBox(height: spacing / 2),
                    Text(
                      reason,
                      style: TextStyle(
                        fontSize: isMobile ? fontSize * 0.85 : fontSize,
                        color: Colors.grey,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: spacing / 2),
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: spacing / 2,
                            vertical: spacing / 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$totalDays day${totalDays > 1 ? 's' : ''}',
                            style: TextStyle(
                              fontSize: isMobile ? fontSize * 0.75 : fontSize,
                              color: Colors.orange,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        SizedBox(width: spacing / 2),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: spacing / 2,
                            vertical: spacing / 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.purple.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            permissionType,
                            style: TextStyle(
                              fontSize: isMobile ? fontSize * 0.75 : fontSize,
                              color: Colors.purple,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: spacing),
          const Divider(),
          SizedBox(height: spacing / 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              SizedBox(
                width: isMobile ? 60 : 80,
                height: isMobile ? 32 : 36,
                child: OutlinedButton(
                  onPressed: onReject,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: EdgeInsets.zero,
                  ),
                  child: Text(
                    'Reject',
                    style: TextStyle(
                      fontSize: isMobile ? fontSize * 0.75 : fontSize,
                    ),
                  ),
                ),
              ),
              SizedBox(width: spacing),
              SizedBox(
                width: isMobile ? 60 : 80,
                height: isMobile ? 32 : 36,
                child: ElevatedButton(
                  onPressed: onApprove,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: EdgeInsets.zero,
                  ),
                  child: Text(
                    'Approve',
                    style: TextStyle(
                      fontSize: isMobile ? fontSize * 0.75 : fontSize,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}