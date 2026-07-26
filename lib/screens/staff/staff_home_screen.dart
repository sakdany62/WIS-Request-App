// lib/screens/staff/staff_home_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';
import 'package:permission_system/app_fonts.dart';
import '../../utils/responsive.dart';
import '../../widgets/profile_avatar.dart';

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
  String? profileImageUrl;
  bool isLoading = true;
  String userId = '';
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

  Future<void> _refreshProfileImage() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final docSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (docSnapshot.exists) {
        final data = docSnapshot.data()!;
        if (mounted) {
          setState(() {
            profileImageUrl = data['profileImageUrl'] ?? '';
            userName = data['fullName'] ?? data['username'] ?? 'Staff User';
          });
        }
      }
    } catch (e) {
      print('❌ Error refreshing profile image: $e');
    }
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    
    if (user != null) {
      userId = user.uid;
      try {
        final docSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        
        if (docSnapshot.exists) {
          final data = docSnapshot.data()!;
          if (mounted) {
            setState(() {
              userName = data['fullName'] ?? data['username'] ?? 'Staff User';
              profileImageUrl = data['profileImageUrl'] ?? '';
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
    final bool isMobile = Responsive.isMobile(context);
    final double fontSize = Responsive.fontSize(context, 14);
    final double spacing = Responsive.spacing(context);
    final double iconSize = Responsive.iconSize(context, 24);

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
                userId: userId,
                profileImageUrl: profileImageUrl,
                isLoading: isLoading,
                leaveStats: leaveStats,
                isMobile: isMobile,
                fontSize: fontSize,
                spacing: spacing,
                iconSize: iconSize,
                onProfileUpdated: _refreshProfileImage,
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
  final String userId;
  final String? profileImageUrl;
  final bool isLoading;
  final Map<String, int> leaveStats;
  final bool isMobile;
  final double fontSize;
  final double spacing;
  final double iconSize;
  final VoidCallback? onProfileUpdated;

  const _HeaderSection({
    required this.userName,
    required this.userId,
    this.profileImageUrl,
    required this.isLoading,
    required this.leaveStats,
    required this.isMobile,
    required this.fontSize,
    required this.spacing,
    required this.iconSize,
    this.onProfileUpdated,
  });

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final headerHeight = screenHeight * 0.45;

    return SizedBox(
      height: headerHeight,
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          color: Color(0xFF173B69),
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(28),
            bottomRight: Radius.circular(28),
          ),
        ),
        padding: EdgeInsets.fromLTRB(
          isMobile ? 16 : 24,
          isMobile ? 18 : 28,
          isMobile ? 16 : 24,
          isMobile ? 16 : 22,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Header with more top padding to push profile down
            _UserHeader(
              userName: userName,
              userId: userId,
              profileImageUrl: profileImageUrl,
              isLoading: isLoading,
              isMobile: isMobile,
              fontSize: fontSize,
              spacing: spacing,
              iconSize: iconSize,
              onProfileUpdated: onProfileUpdated,
            ),
            
            // Increased space between user header and "Your Leave Balance"
            SizedBox(height: isMobile ? 28 : 40),
            
            // Row with "Your Leave Balance" on the left
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Your Leave Balance',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isMobile ? fontSize + 2 : fontSize + 4,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
            SizedBox(height: isMobile ? 6 : 10),
            
            // Grid of balance cards
            Expanded(
              child: GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 3,
                crossAxisSpacing: isMobile ? 4 : 8,
                mainAxisSpacing: isMobile ? 4 : 8,
                childAspectRatio: 1.78,
                children: [
                  _BalanceCard(
                    count: '${leaveStats['used'] ?? 0}',
                    type: 'USED',
                    total: '${leaveStats['total'] ?? 24}',
                    isMobile: isMobile,
                    fontSize: fontSize,
                    color: Colors.blue.shade400,
                    icon: Icons.check_circle_outline,
                  ),
                  _BalanceCard(
                    count: '${leaveStats['remaining'] ?? 0}',
                    type: 'REMAINING',
                    total: '${leaveStats['total'] ?? 24}',
                    isMobile: isMobile,
                    fontSize: fontSize,
                    color: Colors.green.shade400,
                    icon: Icons.assignment_turned_in,
                  ),
                  _BalanceCard(
                    count: '${leaveStats['autoApproved'] ?? 0}',
                    type: 'AUTO-APPROVED',
                    total: '',
                    isMobile: isMobile,
                    fontSize: fontSize,
                    color: Colors.purple.shade400,
                    icon: Icons.autorenew,
                  ),
                  _BalanceCard(
                    count: '${leaveStats['pending'] ?? 0}',
                    type: 'PENDING',
                    total: '',
                    isMobile: isMobile,
                    fontSize: fontSize,
                    color: Colors.orange.shade400,
                    icon: Icons.hourglass_empty,
                  ),
                  _BalanceCard(
                    count: '${leaveStats['approved'] ?? 0}',
                    type: 'APPROVED',
                    total: '',
                    isMobile: isMobile,
                    fontSize: fontSize,
                    color: Colors.teal.shade400,
                    icon: Icons.thumb_up_alt_outlined,
                  ),
                  _BalanceCard(
                    count: '${leaveStats['rejected'] ?? 0}',
                    type: 'REJECTED',
                    total: '',
                    isMobile: isMobile,
                    fontSize: fontSize,
                    color: Colors.red.shade400,
                    icon: Icons.cancel_outlined,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================= BALANCE CARD =================
class _BalanceCard extends StatelessWidget {
  final String count;
  final String type;
  final String total;
  final bool isMobile;
  final double fontSize;
  final Color color;
  final IconData icon;

  const _BalanceCard({
    required this.count,
    required this.type,
    required this.total,
    required this.isMobile,
    required this.fontSize,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final double baseFontSize = isMobile ? fontSize * 0.75 : fontSize * 0.75;
    final double increasedFontSize = baseFontSize * 1.1;
    final double reducedPadding = isMobile ? 2 : 4;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isMobile ? 8 : 12),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Container(
        padding: EdgeInsets.symmetric(
          vertical: reducedPadding,
          horizontal: reducedPadding,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withOpacity(0.12),
              ),
              padding: EdgeInsets.all(isMobile ? 3 : 5),
              child: Icon(
                icon,
                color: color.withOpacity(0.85),
                size: isMobile ? 17 : 23,
              ),
            ),
            SizedBox(height: isMobile ? 3 : 5),
            Text(
              count,
              style: TextStyle(
                color: color.withOpacity(0.9),
                fontSize: isMobile ? increasedFontSize + 8 : increasedFontSize + 12,
                fontWeight: FontWeight.bold,
                height: 1.0,
              ),
            ),
            Text(
              type,
              style: TextStyle(
                color: color.withOpacity(0.7),
                fontSize: isMobile ? increasedFontSize * 0.65 : increasedFontSize * 0.7,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
                height: 1.0,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            if (total.isNotEmpty)
              Container(
                margin: EdgeInsets.only(top: isMobile ? 1 : 2),
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 4 : 6,
                  vertical: isMobile ? 0.5 : 1,
                ),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'of $total',
                  style: TextStyle(
                    color: color.withOpacity(0.5),
                    fontSize: isMobile ? increasedFontSize * 0.4 : increasedFontSize * 0.45,
                    fontWeight: FontWeight.w500,
                    height: 1.0,
                  ),
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
  final String userId;
  final String? profileImageUrl;
  final bool isLoading;
  final bool isMobile;
  final double fontSize;
  final double spacing;
  final double iconSize;
  final VoidCallback? onProfileUpdated;

  const _UserHeader({
    required this.userName,
    required this.userId,
    this.profileImageUrl,
    required this.isLoading,
    required this.isMobile,
    required this.fontSize,
    required this.spacing,
    required this.iconSize,
    this.onProfileUpdated,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Profile avatar with increased top padding to push it down more
        Padding(
          padding: EdgeInsets.only(top: isMobile ? 20 : 28),
          child: ProfileAvatar(
            userId: userId,
            imageUrl: profileImageUrl,
            name: userName,
            radius: isMobile ? 30 : 40,
            backgroundColor: Colors.white24,
            textColor: Colors.white,
            onTap: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => StaffProfileScreen()),
              );
              if (result == true && onProfileUpdated != null) {
                onProfileUpdated!();
              }
            },
          ),
        ),
        SizedBox(width: isMobile ? 12 : 16),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(top: isMobile ? 20 : 28),
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
        ),
        Padding(
          padding: EdgeInsets.only(top: isMobile ? 20 : 28),
          child: _NotificationIconWithBadge(
            userId: userId,
            isMobile: isMobile,
            iconSize: iconSize,
          ),
        ),
      ],
    );
  }
}

// ================= NOTIFICATION ICON WITH BADGE =================
class _NotificationIconWithBadge extends StatelessWidget {
  final String userId;
  final bool isMobile;
  final double iconSize;

  const _NotificationIconWithBadge({
    required this.userId,
    required this.isMobile,
    required this.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    final double notificationSize = isMobile ? iconSize * 1.3 : 28 * 1.3;
    final double badgeSize = isMobile ? 18 : 24;
    final double fontSize = isMobile ? 10 : 12;

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
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const NotificationsScreen()),
                );
              },
              icon: Icon(
                Icons.notifications_none,
                color: Colors.white,
                size: notificationSize,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            if (unreadCount > 0)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.all(isMobile ? 3 : 5),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  constraints: BoxConstraints(
                    minWidth: badgeSize,
                    minHeight: badgeSize,
                  ),
                  child: Text(
                    unreadCount > 99 ? '99+' : '$unreadCount',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: fontSize,
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