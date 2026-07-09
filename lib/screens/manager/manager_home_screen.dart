import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/request_service.dart';
import '../staff/notifications_screen.dart';
import '../staff/profile_screen.dart';
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

    setState(() {
      managerId = user.uid;
    });

    await _loadManagerData();
    await _loadStaffCount();
    await _loadStatistics();
  }

  Future<void> _loadManagerData() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      try {
        final querySnapshot = await FirebaseFirestore.instance
            .collection('users')
            .where('userId', isEqualTo: user.uid)
            .limit(1)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          final data = querySnapshot.docs.first.data() as Map<String, dynamic>;
          setState(() {
            managerName =
                data['fullName'] ?? data['username'] ?? 'Manager User';
            managerDepartment = data['department'] ?? '';
            isLoading = false;
            errorMessage = null;
          });
        } else {
          setState(() {
            managerName = user.email?.split('@').first ?? 'Manager User';
            isLoading = false;
            errorMessage = 'User profile not found in database';
          });
        }
      } catch (e) {
        setState(() {
          isLoading = false;
          errorMessage = 'Failed to load user data: $e';
        });
      }
    } else {
      setState(() {
        isLoading = false;
        errorMessage = 'No user logged in';
      });
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

      setState(() {
        _staffCount = snapshot.docs.length;
      });
    } catch (e) {
      print('Error loading staff count: $e');
    }
  }

  // ============================================================
  // ⏰ Load Statistics from Firestore
  // ============================================================
  Future<void> _loadStatistics() async {
    try {
      Query query = FirebaseFirestore.instance.collection('leave_requests');
      
      // Filter by department if manager has department
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
        final days = (data['totalDays'] as num?)?.toInt() ?? 0;
        
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
      
      setState(() {
        _totalRequests = total;
        _pendingRequests = pending;
        _approvedRequests = approved;
        _rejectedRequests = rejected;
        _autoApprovedRequests = autoApproved;
        _totalDays = totalDays;
      });
      
      print('📊 Statistics loaded: Total=$total, Pending=$pending, Approved=$approved, Rejected=$rejected');
    } catch (e) {
      print('❌ Error loading statistics: $e');
    }
  }

  Future<void> _approveRequest(
      String requestId, String userName, int totalDays) async {
    try {
      await _requestService.approveRequestAsManager(
        requestId,
        managerId,
        managerName,
        managerDepartment,
      );

      // Refresh statistics after approval
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

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Reject Request',
          style: TextStyle(fontSize: AppFonts.md, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Please provide a reason for rejection:',
              style: TextStyle(fontSize: AppFonts.md),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                hintText: 'Reason...',
                hintStyle: TextStyle(fontSize: AppFonts.md),
                border: const OutlineInputBorder(),
              ),
              maxLines: 3,
              style: TextStyle(fontSize: AppFonts.md),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(fontSize: AppFonts.md),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _requestService.rejectRequestAsManager(
                  requestId,
                  managerId,
                  managerName,
                  managerDepartment,
                  reason: reasonController.text.isNotEmpty
                      ? reasonController.text
                      : null,
                );

                // Refresh statistics after rejection
                await _loadStatistics();

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '✅ Request rejected',
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
              style: TextStyle(fontSize: AppFonts.md),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (errorMessage != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  'Error',
                  style: TextStyle(
                    fontSize: AppFonts.md,
                    fontWeight: FontWeight.bold,
                    color: Colors.red[700],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  errorMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: AppFonts.md),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      errorMessage = null;
                      isLoading = true;
                    });
                    _checkAuthAndLoad();
                  },
                  child: Text(
                    'Retry',
                    style: TextStyle(fontSize: AppFonts.md),
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
            // ---------- Fixed header with background ----------
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
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
              ),
            ),
            // ---------- Scrollable content ----------
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  await _loadManagerData();
                  await _loadStaffCount();
                  await _loadStatistics();
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Department & staff count row
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.business,
                                    size: 16, color: Colors.blue[700]),
                                const SizedBox(width: 8),
                                Text(
                                  departmentDisplay,
                                  style: TextStyle(
                                    fontSize: AppFonts.md,
                                    color: Colors.blue[700],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.people,
                                    size: 16, color: Colors.green[700]),
                                const SizedBox(width: 4),
                                Text(
                                  '$_staffCount Staff',
                                  style: TextStyle(
                                    fontSize: AppFonts.md,
                                    color: Colors.green[700],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      // ============================================================
                      // ⏰ Statistics Cards - Total, Pending, Approved, Rejected
                      // ============================================================
                      Row(
                        children: [
                          _buildStatCard(
                            label: 'Total',
                            value: '$_totalRequests',
                            color: const Color(0xFF173B69),
                          ),
                          _buildStatCard(
                            label: 'Pending',
                            value: '$_pendingRequests',
                            color: Colors.orange,
                          ),
                          _buildStatCard(
                            label: 'Approved',
                            value: '$_approvedRequests',
                            color: Colors.green,
                          ),
                          _buildStatCard(
                            label: 'Rejected',
                            value: '$_rejectedRequests',
                            color: Colors.red,
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 8),
                      
                      // Auto Approved and Total Days
                      Row(
                        children: [
                          _buildStatCard(
                            label: 'Auto Approved',
                            value: '$_autoApprovedRequests',
                            color: Colors.purple,
                          ),
                          _buildStatCard(
                            label: 'Total Days',
                            value: '$_totalDays',
                            color: Colors.teal,
                          ),
                          const Expanded(
                            child: SizedBox(),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Pending Approvals Title
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Pending Approvals',
                            style: TextStyle(
                              fontSize: AppFonts.md,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (managerDepartment.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                managerDepartment,
                                style: TextStyle(
                                  fontSize: AppFonts.md,
                                  color: Colors.green[700],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      
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
                                  const SizedBox(height: 8),
                                  Text(
                                    'Error: ${snapshot.error}',
                                    style: TextStyle(fontSize: AppFonts.md),
                                  ),
                                  const SizedBox(height: 8),
                                  ElevatedButton(
                                    onPressed: () {
                                      setState(() {});
                                    },
                                    child: Text(
                                      'Retry',
                                      style: TextStyle(fontSize: AppFonts.md),
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
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(40),
                                child: Column(
                                  children: [
                                    Icon(Icons.inbox, size: 48, color: Colors.grey),
                                    SizedBox(height: 8),
                                    Text(
                                      'No pending requests',
                                      style: TextStyle(
                                          fontSize: AppFonts.md, color: Colors.grey),
                                    ),
                                    Text(
                                      'All requests in your department have been processed',
                                      style: TextStyle(
                                          fontSize: AppFonts.md, color: Colors.grey),
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
                                employeeName: data['userName'] ?? 'Unknown',
                                month: _getMonthFromDate(data['startDate']),
                                date: _getDateFromDate(data['startDate']),
                                reason: data['reason'] ?? 'No reason',
                                totalDays: data['totalDays'] ?? 0,
                                department: requestDepartment,
                                onApprove: () => _approveRequest(doc.id,
                                    data['userName'] ?? '', data['totalDays'] ?? 0),
                                onReject: () => _showRejectDialog(doc.id,
                                    data['userName'] ?? '', data['totalDays'] ?? 0),
                              );
                            }).toList(),
                          );
                        },
                      ),
                      const SizedBox(height: 20),
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

  // ============================================================
  // ⏰ Build Stat Card
  // ============================================================
  Widget _buildStatCard({
    required String label,
    required String value,
    required Color color,
  }) {
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

// ================= MANAGER USER HEADER WITH NOTIFICATION BADGE =================
class _ManagerUserHeader extends StatelessWidget {
  final String managerName;
  final bool isLoading;
  final String userId;
  final bool useWhiteTheme;

  const _ManagerUserHeader({
    required this.managerName,
    required this.isLoading,
    required this.userId,
    this.useWhiteTheme = false,
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
        GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ProfileScreen()),
          ),
          child: CircleAvatar(
            radius: 40,
            backgroundColor: avatarBg,
            child: Icon(Icons.manage_accounts, size: 40, color: avatarIcon),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isLoading)
                const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              else
                Text(
                  managerName,
                  style: TextStyle(
                    color: textColor,
                    fontSize: AppFonts.md,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              const SizedBox(height: 4),
              Text(
                'Manager',
                style: TextStyle(
                  color: subTextColor,
                  fontSize: AppFonts.md,
                ),
              ),
            ],
          ),
        ),
        _NotificationIconWithBadge(
          userId: userId,
          iconColor: iconColor,
        ),
      ],
    );
  }
}

// ================= NOTIFICATION ICON WITH BADGE =================
class _NotificationIconWithBadge extends StatelessWidget {
  final String userId;
  final Color iconColor;

  const _NotificationIconWithBadge({
    required this.userId,
    this.iconColor = const Color(0xFF173B69),
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
                size: 28,
              ),
            ),
            if (unreadCount > 0)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 20,
                    minHeight: 20,
                  ),
                  child: Text(
                    unreadCount > 99 ? '99+' : '$unreadCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
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

class _PendingCard extends StatelessWidget {
  final String employeeName;
  final String month;
  final String date;
  final String reason;
  final int totalDays;
  final String department;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _PendingCard({
    required this.employeeName,
    required this.month,
    required this.date,
    required this.reason,
    required this.totalDays,
    required this.department,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
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
                width: 60,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
                        fontSize: AppFonts.md,
                        color: const Color(0xFF173B69),
                      ),
                    ),
                    Text(
                      date,
                      style: TextStyle(
                        fontSize: AppFonts.md,
                        color: const Color(0xFF173B69),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      employeeName,
                      style: TextStyle(
                        fontSize: AppFonts.md,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        ' $department',
                        style: TextStyle(
                          fontSize: AppFonts.md,
                          color: Colors.blue[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      reason,
                      style: TextStyle(
                        fontSize: AppFonts.md,
                        color: Colors.grey,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$totalDays day${totalDays > 1 ? 's' : ''}',
                        style: TextStyle(
                          fontSize: AppFonts.md,
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              SizedBox(
                width: 80,
                height: 36,
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
                    style: TextStyle(fontSize: AppFonts.md),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 80,
                height: 36,
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
                    style: TextStyle(fontSize: AppFonts.md),
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