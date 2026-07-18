// lib/screens/staff/staff_home_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';
import 'package:permission_system/app_fonts.dart';
import '../../utils/responsive.dart'; 

// ✅ State Manager សម្រាប់គ្រប់គ្រង Refresh
class StaffHomeScreenStateManager {
  static _StaffHomeScreenState? _instance;
  
  static void setInstance(_StaffHomeScreenState instance) {
    _instance = instance;
  }
  
  static void clearInstance() {
    _instance = null;
  }
  
  static Future<void> refreshData() async {
    if (_instance != null && _instance!.mounted) {
      await _instance!.refreshData();
    }
  }
}

class StaffHomeScreen extends StatefulWidget {
  const StaffHomeScreen({super.key});

  @override
  State<StaffHomeScreen> createState() => _StaffHomeScreenState();
}

class _StaffHomeScreenState extends State<StaffHomeScreen> {
  String userName = 'Staff User';
  bool isLoading = true;
  List<Map<String, dynamic>> leaveStatusList = [];
  List<Map<String, dynamic>> allLeaveStatusList = [];
  bool showAll = false;
  Map<String, int> leaveStats = {
    'total': 24,
    'used': 0,
    'remaining': 24,
    'pending': 0,
    'approved': 0,
    'rejected': 0,
    'autoApproved': 0,
  };

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    StaffHomeScreenStateManager.setInstance(this);
    _loadUserData();
    _loadLeaveStatus();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    StaffHomeScreenStateManager.clearInstance();
    super.dispose();
  }

  Future<void> refreshData() async {
    await _loadLeaveStatus();
    await _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    
    if (user != null) {
      try {
        final querySnapshot = await FirebaseFirestore.instance
            .collection('users')
            .where('userId', isEqualTo: user.uid)
            .limit(1)
            .get();
        
        if (querySnapshot.docs.isNotEmpty) {
          final data = querySnapshot.docs.first.data();
          if (mounted) {
            setState(() {
              userName = data['fullName'] ?? data['username'] ?? 'Staff User';
              isLoading = false;
            });
          }
        } else {
          if (mounted) {
            setState(() {
              userName = user.email?.split('@').first ?? 'Staff User';
              isLoading = false;
            });
          }
        }
      } catch (e) {
        print('Error loading user name: $e');
        if (mounted) {
          setState(() {
            isLoading = false;
          });
        }
      }
    } else {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _loadLeaveStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('leave_requests')
          .where('userId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .get();

      List<Map<String, dynamic>> requests = [];
      int totalDays = 0;
      int pending = 0;
      int approved = 0;
      int rejected = 0;
      int autoApproved = 0;

      for (var doc in querySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final status = data['status'] ?? 'pending';
        final days = (data['totalDays'] as num?)?.toInt() ?? 0;
        final isAutoApproved = data['autoApproved'] ?? false;

        requests.add({
          'id': doc.id,
          'month': _getMonthFromDate(data['startDate']),
          'date': _getDateRange(data['startDate'], data['endDate']),
          'title': data['reason'] ?? 'Leave Request',
          'status': status.toUpperCase(),
          'statusColor': _getStatusColor(status),
          'totalDays': days,
          'startDate': data['startDate'],
          'endDate': data['endDate'],
        });

        if (status == 'approved') {
          approved++;
          totalDays += days;
          if (isAutoApproved) autoApproved++;
        } else if (status == 'pending') {
          pending++;
        } else if (status == 'rejected') {
          rejected++;
        }
      }

      final remaining = 24 - totalDays;

      if (mounted) {
        setState(() {
          allLeaveStatusList = requests;
          if (requests.length > 3) {
            leaveStatusList = requests.sublist(0, 3);
          } else {
            leaveStatusList = requests;
          }
          leaveStats = {
            'total': 24,
            'used': totalDays,
            'remaining': remaining < 0 ? 0 : remaining,
            'pending': pending,
            'approved': approved,
            'rejected': rejected,
            'autoApproved': autoApproved,
          };
        });
      }
    } catch (e) {
      print('Error loading leave status: $e');
    }
  }

  String _getMonthFromDate(String? dateStr) {
    if (dateStr == null) return 'N/A';
    final parts = dateStr.split(' ');
    if (parts.length >= 2) {
      return parts[1].toUpperCase();
    }
    return 'N/A';
  }

  String _getDateRange(String? start, String? end) {
    if (start == null) return 'N/A';
    if (end == null) return start;
    
    final startParts = start.split(' ');
    final endParts = end.split(' ');
    
    final startDay = startParts.isNotEmpty ? startParts[0] : '';
    final endDay = endParts.isNotEmpty ? endParts[0] : '';
    
    if (startDay == endDay) return startDay;
    return '$startDay-$endDay';
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
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

  void _toggleShowAll() {
    setState(() {
      showAll = !showAll;
      if (showAll) {
        leaveStatusList = allLeaveStatusList;
      } else {
        if (allLeaveStatusList.length > 3) {
          leaveStatusList = allLeaveStatusList.sublist(0, 3);
        } else {
          leaveStatusList = allLeaveStatusList;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // ✅ ប្រើ Responsive
    final bool isMobile = Responsive.isMobile(context);
    final double fontSize = Responsive.fontSize(context, 14);
    final double spacing = Responsive.spacing(context);
    final double iconSize = Responsive.iconSize(context, 24);
    final EdgeInsets padding = Responsive.padding(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadLeaveStatus();
          await _loadUserData();
        },
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: _HeaderSection(
                userName: userName, 
                isLoading: isLoading,
                leaveStats: leaveStats,
                isMobile: isMobile,
                fontSize: fontSize,
                spacing: spacing,
                iconSize: iconSize,
              ),
            ),
            SliverToBoxAdapter(
              child: _LeaveStatusSection(
                leaveStatusList: leaveStatusList,
                allLeaveStatusList: allLeaveStatusList,
                showAll: showAll,
                onToggleShowAll: _toggleShowAll,
                isMobile: isMobile,
                fontSize: fontSize,
                spacing: spacing,
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(height: isMobile ? 60 : 100),
            ),
          ],
        ),
      ),
    );
  }
}

// ================= HEADER SECTION =================
class _HeaderSection extends StatelessWidget {
  final String userName;
  final bool isLoading;
  final Map<String, int> leaveStats;
  final bool isMobile;
  final double fontSize;
  final double spacing;
  final double iconSize;

  const _HeaderSection({
    required this.userName, 
    required this.isLoading,
    required this.leaveStats,
    required this.isMobile,
    required this.fontSize,
    required this.spacing,
    required this.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final userId = user?.uid;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFF173B69),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        isMobile ? 16 : 24,
        isMobile ? 40 : 60,
        isMobile ? 16 : 24,
        isMobile ? 24 : 40,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _UserHeader(
            userName: userName, 
            isLoading: isLoading,
            userId: userId,
            isMobile: isMobile,
            fontSize: fontSize,
            spacing: spacing,
            iconSize: iconSize,
          ),
          SizedBox(height: isMobile ? 16 : 20),
          Text(
            'Your Leave Balance',
            style: TextStyle(
              color: Colors.white,
              fontSize: isMobile ? fontSize : fontSize + 2,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: isMobile ? 8 : 12),
          Row(
            children: [
              _BalanceCard(
                count: '${leaveStats['used'] ?? 0}',
                type: 'USED',
                total: '/${leaveStats['total'] ?? 24}',
                isMobile: isMobile,
                fontSize: fontSize,
              ),
              SizedBox(width: isMobile ? 6 : 12),
              _BalanceCard(
                count: '${leaveStats['remaining'] ?? 0}',
                type: 'REMAINING',
                total: '/${leaveStats['total'] ?? 24}',
                isMobile: isMobile,
                fontSize: fontSize,
              ),
              SizedBox(width: isMobile ? 6 : 12),
              _BalanceCard(
                count: '${leaveStats['autoApproved'] ?? 0}',
                type: 'AUTO-APPROVED',
                total: '',
                isMobile: isMobile,
                fontSize: fontSize,
              ),
            ],
          ),
          SizedBox(height: isMobile ? 8 : 12),
          Row(
            children: [
              _BalanceCardSmall(
                count: '${leaveStats['pending'] ?? 0}',
                type: 'PENDING',
                isMobile: isMobile,
                fontSize: fontSize,
              ),
              SizedBox(width: isMobile ? 4 : 8),
              _BalanceCardSmall(
                count: '${leaveStats['approved'] ?? 0}',
                type: 'APPROVED',
                isMobile: isMobile,
                fontSize: fontSize,
              ),
              SizedBox(width: isMobile ? 4 : 8),
              _BalanceCardSmall(
                count: '${leaveStats['rejected'] ?? 0}',
                type: 'REJECTED',
                isMobile: isMobile,
                fontSize: fontSize,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  final String count;
  final String type;
  final String total;
  final bool isMobile;
  final double fontSize;

  const _BalanceCard({
    required this.count,
    required this.type,
    required this.total,
    required this.isMobile,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(isMobile ? 8 : 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(isMobile ? 10 : 12),
        ),
        child: Column(
          children: [
            Text(
              count,
              style: TextStyle(
                color: Colors.white,
                fontSize: isMobile ? fontSize : fontSize + 2,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: isMobile ? 2 : 4),
            Text(
              type,
              style: TextStyle(
                color: Colors.white70,
                fontSize: isMobile ? fontSize * 0.7 : fontSize,
              ),
            ),
            if (total.isNotEmpty)
              Text(
                total,
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: isMobile ? fontSize * 0.6 : fontSize,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BalanceCardSmall extends StatelessWidget {
  final String count;
  final String type;
  final bool isMobile;
  final double fontSize;

  const _BalanceCardSmall({
    required this.count,
    required this.type,
    required this.isMobile,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: isMobile ? 6 : 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(isMobile ? 6 : 8),
        ),
        child: Column(
          children: [
            Text(
              count,
              style: TextStyle(
                color: Colors.white,
                fontSize: isMobile ? fontSize : fontSize + 2,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              type,
              style: TextStyle(
                color: Colors.white70,
                fontSize: isMobile ? fontSize * 0.6 : fontSize,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================= USER HEADER =================
class _UserHeader extends StatelessWidget {
  final String userName;
  final bool isLoading;
  final String? userId;
  final bool isMobile;
  final double fontSize;
  final double spacing;
  final double iconSize;

  const _UserHeader({
    required this.userName,
    required this.isLoading,
    this.userId,
    required this.isMobile,
    required this.fontSize,
    required this.spacing,
    required this.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ProfileScreen()),
          ),
          child: CircleAvatar(
            radius: isMobile ? 30 : 40,
            backgroundColor: Colors.white24,
            child: Icon(
              Icons.person,
              size: isMobile ? 30 : 40,
              color: Colors.white,
            ),
          ),
        ),
        SizedBox(width: isMobile ? 12 : 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isLoading)
                SizedBox(
                  height: isMobile ? 16 : 20,
                  width: isMobile ? 16 : 20,
                  child: const CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              else
                Text(
                  userName,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isMobile ? fontSize : fontSize + 2,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              SizedBox(height: isMobile ? 2 : 4),
              Text(
                'Staff',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: isMobile ? fontSize * 0.8 : fontSize,
                ),
              ),
            ],
          ),
        ),
        _NotificationIconWithBadge(
          userId: userId,
          isMobile: isMobile,
          iconSize: iconSize,
        ),
      ],
    );
  }
}

// ================= NOTIFICATION ICON WITH BADGE =================
class _NotificationIconWithBadge extends StatelessWidget {
  final String? userId;
  final bool isMobile;
  final double iconSize;

  const _NotificationIconWithBadge({
    this.userId,
    required this.isMobile,
    required this.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    if (userId == null) {
      return IconButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const NotificationsScreen()),
        ),
        icon: Icon(
          Icons.notifications_none,
          color: Colors.white,
          size: isMobile ? iconSize : 28,
        ),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
      );
    }

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
                MaterialPageRoute(builder: (context) => const NotificationsScreen()),
              ),
              icon: Icon(
                Icons.notifications_none,
                color: Colors.white,
                size: isMobile ? iconSize : 28,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            if (unreadCount > 0)
              Positioned(
                top: 2,
                right: 2,
                child: Container(
                  padding: EdgeInsets.all(isMobile ? 2 : 4),
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

// ================= LEAVE STATUS SECTION =================
class _LeaveStatusSection extends StatelessWidget {
  final List<Map<String, dynamic>> leaveStatusList;
  final List<Map<String, dynamic>> allLeaveStatusList;
  final bool showAll;
  final VoidCallback onToggleShowAll;
  final bool isMobile;
  final double fontSize;
  final double spacing;

  const _LeaveStatusSection({
    required this.leaveStatusList,
    required this.allLeaveStatusList,
    required this.showAll,
    required this.onToggleShowAll,
    required this.isMobile,
    required this.fontSize,
    required this.spacing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: isMobile ? 12 : 20),
          Center(
            child: Text(
              'Leave Status',
              style: TextStyle(
                fontSize: isMobile ? fontSize + 2 : fontSize + 4,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(height: isMobile ? 12 : 16),
          if (leaveStatusList.isEmpty)
            Center(
              child: Padding(
                padding: EdgeInsets.all(isMobile ? 20 : 32),
                child: Text(
                  'No leave requests yet',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: isMobile ? fontSize * 0.85 : fontSize,
                  ),
                ),
              ),
            )
          else
            ...leaveStatusList.map((request) => LeaveStatusCard(
              key: ValueKey(request['id']),
              month: request['month'],
              date: request['date'],
              title: request['title'],
              status: request['status'],
              statusColor: request['statusColor'],
              isMobile: isMobile,
              fontSize: fontSize,
              spacing: spacing,
            )),
          SizedBox(height: isMobile ? 8 : 12),
          if (allLeaveStatusList.length > 3)
            Center(
              child: TextButton(
                onPressed: onToggleShowAll,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF173B69),
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 16 : 24,
                    vertical: isMobile ? 8 : 12,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      showAll ? 'Show Less' : 'See More',
                      style: TextStyle(
                        fontSize: isMobile ? fontSize : fontSize + 2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(width: isMobile ? 2 : 4),
                    Icon(
                      showAll ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      size: isMobile ? 16 : 20,
                    ),
                  ],
                ),
              ),
            ),
          SizedBox(height: isMobile ? 12 : 20),
        ],
      ),
    );
  }
}

class LeaveStatusCard extends StatelessWidget {
  final String month;
  final String date;
  final String title;
  final String status;
  final Color statusColor;
  final bool isMobile;
  final double fontSize;
  final double spacing;

  const LeaveStatusCard({
    super.key,
    required this.month,
    required this.date,
    required this.title,
    required this.status,
    required this.statusColor,
    required this.isMobile,
    required this.fontSize,
    required this.spacing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: isMobile ? 8 : 12),
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 8 : 12,
              vertical: isMobile ? 6 : 8,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF173B69).withOpacity(0.1),
              borderRadius: BorderRadius.circular(isMobile ? 6 : 8),
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
          SizedBox(width: isMobile ? 10 : 16),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: isMobile ? fontSize * 0.85 : fontSize,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 6 : 8,
              vertical: isMobile ? 2 : 4,
            ),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(isMobile ? 8 : 12),
            ),
            child: Text(
              status,
              style: TextStyle(
                color: statusColor,
                fontWeight: FontWeight.bold,
                fontSize: isMobile ? fontSize * 0.7 : fontSize,
              ),
            ),
          ),
        ],
      ),
    );
  }
}