// lib/screens/staff/staff_home_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:permission_system/screens/staff/staff_detail_screen.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';
import '../../models/leave_stats.dart';
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
  LeaveStats leaveStats = LeaveStats();

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
      print('Error refreshing profile image: $e');
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

      for (var doc in querySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        requests.add({
          'id': doc.id,
          'month': _getMonthFromDate(data['startDate']),
          'date': _getDateRange(data['startDate'], data['endDate']),
          'title': data['reason'] ?? 'Leave Request',
          'status': data['status'] ?? 'pending',
          'statusColor': _getStatusColor(data['status'] ?? 'pending'),
          'totalDays': (data['totalDays'] as num?)?.toInt() ?? 0,
          'startDate': data['startDate'],
          'endDate': data['endDate'],
          'autoApproved': data['autoApproved'] ?? false,
        });
      }

      if (mounted) {
        setState(() {
          allLeaveStatusList = requests;
          if (requests.length > 3) {
            leaveStatusList = requests.sublist(0, 3);
          } else {
            leaveStatusList = requests;
          }
          leaveStats = LeaveStats.calculate(requests);
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
              ),
            ),
            SliverToBoxAdapter(
              child: _LeaveStatusSection(
                leaveStatusList: leaveStatusList,
                allLeaveStatusList: allLeaveStatusList,
                showAll: showAll,
                onToggleShowAll: _toggleShowAll,
              ),
            ),
            SliverToBoxAdapter(
              child: const SizedBox(height: 60),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderSection extends StatelessWidget {
  final String userName;
  final String userId;
  final String? profileImageUrl;
  final bool isLoading;
  final LeaveStats leaveStats;

  const _HeaderSection({
    required this.userName,
    required this.userId,
    this.profileImageUrl,
    required this.isLoading,
    required this.leaveStats,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenWidth < 360;
    final isTablet = screenWidth >= 600;
    
    double paddingHorizontal = isSmallScreen ? 12 : (isTablet ? 24 : 16);
    double paddingVertical = isSmallScreen ? 12 : (isTablet ? 28 : 18);
    double headerHeight = screenHeight * (isSmallScreen ? 0.45 : (isTablet ? 0.38 : 0.43));
    double fontSize = isSmallScreen ? 12 : (isTablet ? 18 : 14);
    double cardSpacing = isSmallScreen ? 3 : (isTablet ? 8 : 4);

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
          paddingHorizontal,
          paddingVertical,
          paddingHorizontal,
          isSmallScreen ? 12 : 16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _UserHeader(
              userName: userName,
              userId: userId,
              profileImageUrl: profileImageUrl,
              isLoading: isLoading,
              fontSize: fontSize,
              isSmallScreen: isSmallScreen,
              isTablet: isTablet,
            ),
            
            SizedBox(height: isSmallScreen ? 16 : (isTablet ? 36 : 24)),
            
            Text(
              'Your Leave Balance',
              style: TextStyle(
                color: Colors.white,
                fontSize: isSmallScreen ? fontSize + 2 : (isTablet ? fontSize + 6 : fontSize + 4),
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
            SizedBox(height: isSmallScreen ? 2 : (isTablet ? 8 : 4)),
            
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final availableWidth = constraints.maxWidth;
                  final cardWidth = (availableWidth - (cardSpacing * 2)) / 3;
                  
                  return Wrap(
                    spacing: cardSpacing,
                    runSpacing: cardSpacing,
                    children: [
                      _BalanceCard(
                        count: '${leaveStats.total}',
                        type: 'TOTAL',
                        total: '',
                        color: Colors.blue.shade400,
                        icon: Icons.calendar_today,
                        cardWidth: cardWidth,
                        isSmallScreen: isSmallScreen,
                        isTablet: isTablet,
                        statType: 'total',
                        userId: userId,
                      ),
                      _BalanceCard(
                        count: '${leaveStats.used}',
                        type: 'USED',
                        total: '${leaveStats.total}',
                        color: Colors.green.shade400,
                        icon: Icons.check_circle_outline,
                        cardWidth: cardWidth,
                        isSmallScreen: isSmallScreen,
                        isTablet: isTablet,
                        statType: 'used',
                        userId: userId,
                      ),
                      _BalanceCard(
                        count: '${leaveStats.remaining}',
                        type: 'REMAINING',
                        total: '${leaveStats.total}',
                        color: Colors.purple.shade400,
                        icon: Icons.assignment_turned_in,
                        cardWidth: cardWidth,
                        isSmallScreen: isSmallScreen,
                        isTablet: isTablet,
                        statType: 'remaining',
                        userId: userId,
                      ),
                      _BalanceCard(
                        count: '${leaveStats.autoApproved}',
                        type: 'AUTO-APPROVED',
                        total: '',
                        color: Colors.teal.shade400,
                        icon: Icons.autorenew,
                        cardWidth: cardWidth,
                        isSmallScreen: isSmallScreen,
                        isTablet: isTablet,
                        statType: 'autoApproved',
                        userId: userId,
                      ),
                      _BalanceCard(
                        count: '${leaveStats.pending}',
                        type: 'PENDING',
                        total: '',
                        color: Colors.orange.shade400,
                        icon: Icons.hourglass_empty,
                        cardWidth: cardWidth,
                        isSmallScreen: isSmallScreen,
                        isTablet: isTablet,
                        statType: 'pending',
                        userId: userId,
                      ),
                      _BalanceCard(
                        count: '${leaveStats.approved}',
                        type: 'APPROVED',
                        total: '',
                        color: Colors.blue.shade700,
                        icon: Icons.thumb_up_alt_outlined,
                        cardWidth: cardWidth,
                        isSmallScreen: isSmallScreen,
                        isTablet: isTablet,
                        statType: 'approved',
                        userId: userId,
                      ),
                      _BalanceCard(
                        count: '${leaveStats.rejected}',
                        type: 'REJECTED',
                        total: '',
                        color: Colors.red.shade400,
                        icon: Icons.cancel_outlined,
                        cardWidth: cardWidth,
                        isSmallScreen: isSmallScreen,
                        isTablet: isTablet,
                        statType: 'rejected',
                        userId: userId,
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  final String count;
  final String type;
  final String total;
  final Color color;
  final IconData icon;
  final double cardWidth;
  final bool isSmallScreen;
  final bool isTablet;
  final String statType;
  final String userId;

  const _BalanceCard({
    required this.count,
    required this.type,
    required this.total,
    required this.color,
    required this.icon,
    required this.cardWidth,
    required this.isSmallScreen,
    required this.isTablet,
    required this.statType,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    double fontSize = isSmallScreen ? 10 : (isTablet ? 16 : 12);
    double iconSize = isSmallScreen ? 14 : (isTablet ? 22 : 18);
    double paddingSize = isSmallScreen ? 2 : (isTablet ? 6 : 4);
    double borderRadius = isSmallScreen ? 6 : (isTablet ? 12 : 8);

    return SizedBox(
      width: cardWidth,
      child: InkWell(
        onTap: () {
          String title = '';
          switch (statType) {
            case 'total':
              title = 'Total Leave Requests';
              break;
            case 'used':
              title = 'Used Leave Requests';
              break;
            case 'remaining':
              title = 'Remaining Leave Balance';
              break;
            case 'pending':
              title = 'Pending Leave Requests';
              break;
            case 'approved':
              title = 'Approved Leave Requests';
              break;
            case 'rejected':
              title = 'Rejected Leave Requests';
              break;
            case 'autoApproved':
              title = 'Auto-Approved Leave Requests';
              break;
          }
          
          Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => StatDetailScreen(
      title: title,
      statType: statType,
      userId: userId,
    ),
  ),
);
        },
        borderRadius: BorderRadius.circular(borderRadius),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(borderRadius),
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
          padding: EdgeInsets.symmetric(
            vertical: paddingSize,
            horizontal: paddingSize,
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
                padding: EdgeInsets.all(isSmallScreen ? 2 : (isTablet ? 6 : 4)),
                child: Icon(
                  icon,
                  color: color.withOpacity(0.85),
                  size: iconSize,
                ),
              ),
              SizedBox(height: isSmallScreen ? 1 : (isTablet ? 6 : 3)),
              Text(
                count,
                style: TextStyle(
                  color: color.withOpacity(0.9),
                  fontSize: isSmallScreen ? fontSize + 4 : (isTablet ? fontSize + 14 : fontSize + 8),
                  fontWeight: FontWeight.bold,
                  height: 1.0,
                ),
              ),
              Text(
                type,
                style: TextStyle(
                  color: color.withOpacity(0.7),
                  fontSize: isSmallScreen ? fontSize * 0.5 : (isTablet ? fontSize * 0.7 : fontSize * 0.6),
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                  height: 1.0,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              if (total.isNotEmpty)
                Container(
                  margin: EdgeInsets.only(top: isSmallScreen ? 0.5 : (isTablet ? 3 : 1)),
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 2 : (isTablet ? 6 : 4),
                    vertical: isSmallScreen ? 0.5 : (isTablet ? 2 : 1),
                  ),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'of $total',
                    style: TextStyle(
                      color: color.withOpacity(0.5),
                      fontSize: isSmallScreen ? fontSize * 0.35 : (isTablet ? fontSize * 0.5 : fontSize * 0.4),
                      fontWeight: FontWeight.w500,
                      height: 1.0,
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

class _UserHeader extends StatelessWidget {
  final String userName;
  final String userId;
  final String? profileImageUrl;
  final bool isLoading;
  final double fontSize;
  final bool isSmallScreen;
  final bool isTablet;

  const _UserHeader({
    required this.userName,
    required this.userId,
    this.profileImageUrl,
    required this.isLoading,
    required this.fontSize,
    required this.isSmallScreen,
    required this.isTablet,
  });

  @override
  Widget build(BuildContext context) {
    double avatarRadius = isSmallScreen ? 24 : (isTablet ? 44 : 30);
    double topPadding = isSmallScreen ? 12 : (isTablet ? 28 : 20);
    
    return Row(
      children: [
        Padding(
          padding: EdgeInsets.only(top: topPadding),
          child: ProfileAvatar(
            userId: userId,
            imageUrl: profileImageUrl,
            name: userName,
            radius: avatarRadius,
            backgroundColor: Colors.white24,
            textColor: Colors.white,
            onTap: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => StaffProfileScreen()),
              );
              if (result == true) {
                // Refresh will be handled
              }
            },
          ),
        ),
        SizedBox(width: isSmallScreen ? 8 : (isTablet ? 20 : 12)),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(top: topPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isLoading)
                  SizedBox(
                    height: isSmallScreen ? 14 : (isTablet ? 22 : 16),
                    width: isSmallScreen ? 14 : (isTablet ? 22 : 16),
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
                      fontSize: isSmallScreen ? fontSize : (isTablet ? fontSize + 4 : fontSize + 2),
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                SizedBox(height: isSmallScreen ? 1 : (isTablet ? 6 : 2)),
                Text(
                  'Staff',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: isSmallScreen ? fontSize * 0.7 : (isTablet ? fontSize + 2 : fontSize * 0.8),
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.only(top: topPadding),
          child: _NotificationIconWithBadge(
            userId: userId,
            isSmallScreen: isSmallScreen,
            isTablet: isTablet,
          ),
        ),
      ],
    );
  }
}

class _NotificationIconWithBadge extends StatelessWidget {
  final String userId;
  final bool isSmallScreen;
  final bool isTablet;

  const _NotificationIconWithBadge({
    required this.userId,
    required this.isSmallScreen,
    required this.isTablet,
  });

  @override
  Widget build(BuildContext context) {
    double iconSize = isSmallScreen ? 20 : (isTablet ? 32 : 24);
    double notificationSize = isSmallScreen ? iconSize * 1.2 : (isTablet ? 32 : iconSize * 1.3);
    double badgeSize = isSmallScreen ? 14 : (isTablet ? 26 : 18);
    double fontSize = isSmallScreen ? 8 : (isTablet ? 14 : 10);

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
                  padding: EdgeInsets.all(isSmallScreen ? 2 : (isTablet ? 6 : 3)),
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

class _LeaveStatusSection extends StatelessWidget {
  final List<Map<String, dynamic>> leaveStatusList;
  final List<Map<String, dynamic>> allLeaveStatusList;
  final bool showAll;
  final VoidCallback onToggleShowAll;

  const _LeaveStatusSection({
    required this.leaveStatusList,
    required this.allLeaveStatusList,
    required this.showAll,
    required this.onToggleShowAll,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final isTablet = screenWidth >= 600;
    
    double fontSize = isSmallScreen ? 12 : (isTablet ? 18 : 14);
    double paddingHorizontal = isSmallScreen ? 8 : (isTablet ? 24 : 12);
    double spacing = isSmallScreen ? 4 : (isTablet ? 12 : 8);
    
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: paddingHorizontal),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: isSmallScreen ? 8 : (isTablet ? 24 : 12)),
          Center(
            child: Text(
              'Leave Status',
              style: TextStyle(
                fontSize: isSmallScreen ? fontSize + 2 : (isTablet ? fontSize + 6 : fontSize + 4),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(height: isSmallScreen ? 8 : (isTablet ? 20 : 12)),
          if (leaveStatusList.isEmpty)
            Center(
              child: Padding(
                padding: EdgeInsets.all(isSmallScreen ? 16 : (isTablet ? 40 : 20)),
                child: Text(
                  'No leave requests yet',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: isSmallScreen ? fontSize * 0.8 : (isTablet ? fontSize + 2 : fontSize),
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
              isSmallScreen: isSmallScreen,
              isTablet: isTablet,
              fontSize: fontSize,
              spacing: spacing,
            )),
          SizedBox(height: isSmallScreen ? 4 : (isTablet ? 12 : 8)),
          if (allLeaveStatusList.length > 3)
            Center(
              child: TextButton(
                onPressed: onToggleShowAll,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF173B69),
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 12 : (isTablet ? 24 : 16),
                    vertical: isSmallScreen ? 6 : (isTablet ? 14 : 8),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      showAll ? 'Show Less' : 'See More',
                      style: TextStyle(
                        fontSize: isSmallScreen ? fontSize : (isTablet ? fontSize + 4 : fontSize + 2),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(width: isSmallScreen ? 2 : (isTablet ? 8 : 4)),
                    Icon(
                      showAll ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      size: isSmallScreen ? 14 : (isTablet ? 24 : 16),
                    ),
                  ],
                ),
              ),
            ),
          SizedBox(height: isSmallScreen ? 8 : (isTablet ? 24 : 12)),
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
  final bool isSmallScreen;
  final bool isTablet;
  final double fontSize;
  final double spacing;

  const LeaveStatusCard({
    super.key,
    required this.month,
    required this.date,
    required this.title,
    required this.status,
    required this.statusColor,
    required this.isSmallScreen,
    required this.isTablet,
    required this.fontSize,
    required this.spacing,
  });

  @override
  Widget build(BuildContext context) {
    double padding = isSmallScreen ? 8 : (isTablet ? 18 : 12);
    double borderRadius = isSmallScreen ? 8 : (isTablet ? 18 : 12);
    double horizontalPadding = isSmallScreen ? 6 : (isTablet ? 14 : 8);
    double verticalPadding = isSmallScreen ? 4 : (isTablet ? 10 : 6);
    
    return Container(
      margin: EdgeInsets.only(bottom: isSmallScreen ? 6 : (isTablet ? 14 : 8)),
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
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
              horizontal: horizontalPadding,
              vertical: verticalPadding,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF173B69).withOpacity(0.1),
              borderRadius: BorderRadius.circular(isSmallScreen ? 4 : (isTablet ? 10 : 6)),
            ),
            child: Column(
              children: [
                Text(
                  month,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: isSmallScreen ? fontSize * 0.7 : (isTablet ? fontSize + 2 : fontSize * 0.8),
                    color: const Color(0xFF173B69),
                  ),
                ),
                Text(
                  date,
                  style: TextStyle(
                    fontSize: isSmallScreen ? fontSize * 0.7 : (isTablet ? fontSize + 2 : fontSize * 0.8),
                    color: const Color(0xFF173B69),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: isSmallScreen ? 6 : (isTablet ? 18 : 10)),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: isSmallScreen ? fontSize * 0.75 : (isTablet ? fontSize + 2 : fontSize * 0.85),
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isSmallScreen ? 4 : (isTablet ? 10 : 6),
              vertical: isSmallScreen ? 2 : (isTablet ? 6 : 4),
            ),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(isSmallScreen ? 6 : (isTablet ? 14 : 8)),
            ),
            child: Text(
              status,
              style: TextStyle(
                color: statusColor,
                fontWeight: FontWeight.bold,
                fontSize: isSmallScreen ? fontSize * 0.6 : (isTablet ? fontSize + 2 : fontSize * 0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }
}