// lib/screens/staff/staff_home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
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

  static const Color appBarColor = Color(0xFF1A3B68);

  @override
  void initState() {
    super.initState();
    StaffHomeScreenStateManager.setInstance(this);
    
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
    );
    
    _loadUserData();
    _loadLeaveStatus();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    StaffHomeScreenStateManager.clearInstance();
    
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
    );
    
    super.dispose();
  }

  Future<void> refreshData() async {
    await _loadLeaveStatus();
    await _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      userId = user.uid;
      try {
        final docSnapshot = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

        if (docSnapshot.exists) {
          final data = docSnapshot.data()!;
          if (mounted) {
            setState(() {
              userName = data['fullName'] ?? data['username'] ?? 'staff'.tr();
              profileImageUrl = data['profileImageUrl'] ?? '';
              isLoading = false;
            });
          }
        } else {
          if (mounted) {
            setState(() {
              userName = user.email?.split('@').first ?? 'staff'.tr();
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
        final data = doc.data();
        requests.add({
          'id': doc.id,
          'month': _getMonthFromDate(data['startDate']),
          'date': _getDateRange(data['startDate'], data['endDate']),
          'title': data['reason'] ?? 'leave_request'.tr(),
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
    // ✅ បន្ថែមនេះដើម្បីឲ្យ Rebuild ពេលភាសាប្តូរ
    EasyLocalization.of(context);
    
    final bool isMobile = Responsive.isMobile(context);
    final double spacing = Responsive.spacing(context);
    final EdgeInsets padding = Responsive.padding(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: const Color(0xFFF7F8FA),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await _loadLeaveStatus();
            await _loadUserData();
          },
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: EdgeInsets.only(
                  top: isMobile ? 8 : 12,
                  bottom: isMobile ? 14 : 20,
                  left: isMobile ? 12 : 24,
                  right: isMobile ? 12 : 24,
                ),
                decoration: const BoxDecoration(
                  color: Color(0xFF1A3B68),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
                child: _UserHeader(
                  userName: userName,
                  userId: userId,
                  profileImageUrl: profileImageUrl,
                  isLoading: isLoading,
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.all(isMobile ? 12 : 16),
                  child: Column(
                    children: [
                      _buildBalanceStats(context, isMobile),
                      const SizedBox(height: 16),
                      _LeaveStatusSection(
                        leaveStatusList: leaveStatusList,
                        allLeaveStatusList: allLeaveStatusList,
                        showAll: showAll,
                        onToggleShowAll: _toggleShowAll,
                        userId: userId,
                      ),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBalanceStats(BuildContext context, bool isMobile) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final isTablet = screenWidth >= 600;

    double cardSpacing = isSmallScreen ? 3 : (isTablet ? 6 : 4);
    final availableWidth = screenWidth - (isMobile ? 16 : 32);
    
    final cardWidth = ((availableWidth - (cardSpacing * 2)) / 3) - 12;
    final cardHeight = ((availableWidth - (cardSpacing * 2)) / 3) - 50;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'your_leave_balance'.tr(),
          style: TextStyle(
            color: const Color(0xFF1A3B68),
            fontSize: isMobile ? 16 : 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: cardSpacing,
          runSpacing: cardSpacing,
          children: [
            _BalanceCard(
              count: '${leaveStats.total}',
              type: 'total'.tr(),
              color: const Color(0xFF4A90D9),
              icon: Icons.calendar_today,
              cardWidth: cardWidth,
              cardHeight: cardHeight,
              isSmallScreen: isSmallScreen,
              isTablet: isTablet,
              statType: 'total',
              userId: userId,
            ),
            _BalanceCard(
              count: '${leaveStats.used}',
              type: 'used'.tr(),
              color: const Color(0xFF2ECC71),
              icon: Icons.check_circle_outline,
              cardWidth: cardWidth,
              cardHeight: cardHeight,
              isSmallScreen: isSmallScreen,
              isTablet: isTablet,
              statType: 'used',
              userId: userId,
            ),
            _BalanceCard(
              count: '${leaveStats.autoApproved}',
              type: 'auto_approved'.tr(),
              color: const Color(0xFF1ABC9C),
              icon: Icons.autorenew,
              cardWidth: cardWidth,
              cardHeight: cardHeight,
              isSmallScreen: isSmallScreen,
              isTablet: isTablet,
              statType: 'autoApproved',
              userId: userId,
            ),
            _BalanceCard(
              count: '${leaveStats.pending}',
              type: 'pending'.tr(),
              color: const Color(0xFFF39C12),
              icon: Icons.hourglass_empty,
              cardWidth: cardWidth,
              cardHeight: cardHeight,
              isSmallScreen: isSmallScreen,
              isTablet: isTablet,
              statType: 'pending',
              userId: userId,
            ),
            _BalanceCard(
              count: '${leaveStats.approved}',
              type: 'approved'.tr(),
              color: Colors.green,
              icon: Icons.thumb_up_alt_outlined,
              cardWidth: cardWidth,
              cardHeight: cardHeight,
              isSmallScreen: isSmallScreen,
              isTablet: isTablet,
              statType: 'approved',
              userId: userId,
            ),
            _BalanceCard(
              count: '${leaveStats.rejected}',
              type: 'rejected'.tr(),
              color: const Color(0xFFE74C3C),
              icon: Icons.cancel_outlined,
              cardWidth: cardWidth,
              cardHeight: cardHeight,
              isSmallScreen: isSmallScreen,
              isTablet: isTablet,
              statType: 'rejected',
              userId: userId,
            ),
          ],
        ),
      ],
    );
  }
}

class _BalanceCard extends StatelessWidget {
  final String count;
  final String type;
  final Color color;
  final IconData icon;
  final double cardWidth;
  final double cardHeight;
  final bool isSmallScreen;
  final bool isTablet;
  final String statType;
  final String userId;

  const _BalanceCard({
    required this.count,
    required this.type,
    required this.color,
    required this.icon,
    required this.cardWidth,
    required this.cardHeight,
    required this.isSmallScreen,
    required this.isTablet,
    required this.statType,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    final textSize = (cardWidth * 0.18).clamp(8.0, 14.0);
    final countSize = (cardWidth * 0.24).clamp(14.0, 24.0);
    final iconSize = (textSize * 1.2).clamp(10.0, 18.0);
    final paddingSize = (cardWidth * 0.06).clamp(4.0, 10.0);
    final borderRadius = (cardWidth * 0.08).clamp(6.0, 12.0);
    final iconPadding = (cardWidth * 0.04).clamp(2.0, 6.0);
    final spacing = (cardWidth * 0.03).clamp(2.0, 6.0);

    return SizedBox(
      width: cardWidth,
      height: cardHeight,
      child: InkWell(
        onTap: () {
          String title = '';
          switch (statType) {
            case 'total':
              title = 'total_leave_requests'.tr();
              break;
            case 'used':
              title = 'used_leave_requests'.tr();
              break;
            case 'pending':
              title = 'pending_leave_requests'.tr();
              break;
            case 'approved':
              title = 'approved_leave_requests'.tr();
              break;
            case 'rejected':
              title = 'rejected_leave_requests'.tr();
              break;
            case 'autoApproved':
              title = 'auto_approved_leave_requests'.tr();
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
            color: color,
            borderRadius: BorderRadius.circular(borderRadius),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.25),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: EdgeInsets.all(paddingSize),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                    padding: EdgeInsets.all(iconPadding),
                    child: Icon(
                      icon,
                      color: Colors.white,
                      size: iconSize,
                    ),
                  ),
                  SizedBox(width: spacing),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        type,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: textSize,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Align(
                alignment: Alignment.bottomRight,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    count,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: countSize,
                      fontWeight: FontWeight.bold,
                      height: 1.0,
                    ),
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

  const _UserHeader({
    required this.userName,
    required this.userId,
    this.profileImageUrl,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final isTablet = screenWidth >= 600;

    final avatarRadius = isSmallScreen ? 28.0 : (isTablet ? 48.0 : 34.0);
    final nameSize = isSmallScreen ? 16.0 : (isTablet ? 24.0 : 20.0);
    final roleSize = isSmallScreen ? 12.0 : (isTablet ? 18.0 : 14.0);

    return Row(
      children: [
        ProfileAvatar(
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
        SizedBox(width: isSmallScreen ? 12 : (isTablet ? 20 : 16)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isLoading)
                SizedBox(
                  height: isSmallScreen ? 16 : (isTablet ? 24 : 20),
                  width: isSmallScreen ? 16 : (isTablet ? 24 : 20),
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
                    fontSize: nameSize,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              SizedBox(height: isSmallScreen ? 2 : (isTablet ? 6 : 4)),
              Text(
                'staff'.tr(),
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: roleSize,
                ),
              ),
            ],
          ),
        ),
        _NotificationIconWithBadge(
          userId: userId,
          isSmallScreen: isSmallScreen,
          isTablet: isTablet,
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
    final iconSize = isSmallScreen ? 24.0 : (isTablet ? 36.0 : 28.0);
    final badgeSize = isSmallScreen ? 16.0 : (isTablet ? 28.0 : 20.0);
    final fontSize = isSmallScreen ? 9.0 : (isTablet ? 15.0 : 11.0);

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
                size: iconSize,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            if (unreadCount > 0)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.all(isSmallScreen ? 2.0 : (isTablet ? 6.0 : 4.0)),
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
  final String userId;

  const _LeaveStatusSection({
    required this.leaveStatusList,
    required this.allLeaveStatusList,
    required this.showAll,
    required this.onToggleShowAll,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    final bool isMobile = Responsive.isMobile(context);

    final titleSize = isMobile ? 18.0 : 22.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'recent_leave_requests'.tr(),
          style: TextStyle(
            fontSize: titleSize,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1A3B68),
          ),
        ),
        const SizedBox(height: 16),
        if (leaveStatusList.isEmpty)
          Center(
            child: Padding(
              padding: EdgeInsets.all(isMobile ? 20 : 32),
              child: Column(
                children: [
                  Icon(
                    Icons.inbox_outlined,
                    size: isMobile ? 48 : 64,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'no_leave_requests'.tr(),
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: isMobile ? 14 : 16,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ...leaveStatusList.map((request) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: LeaveStatusCard(
                  key: ValueKey(request['id']),
                  month: request['month'],
                  date: request['date'],
                  title: request['title'],
                  status: request['status'],
                  statusColor: request['statusColor'],
                  isSmallScreen: isMobile,
                  isTablet: false,
                  userId: userId,
                ),
              )),
        if (allLeaveStatusList.length > 3)
          Center(
            child: TextButton(
              onPressed: onToggleShowAll,
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF1A3B68),
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 16 : 24,
                  vertical: isMobile ? 8 : 12,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    showAll ? 'show_less'.tr() : 'see_more'.tr(),
                    style: TextStyle(
                      fontSize: isMobile ? 14 : 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    showAll ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    size: isMobile ? 16 : 20,
                  ),
                ],
              ),
            ),
          ),
      ],
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
  final String userId;

  const LeaveStatusCard({
    super.key,
    required this.month,
    required this.date,
    required this.title,
    required this.status,
    required this.statusColor,
    required this.isSmallScreen,
    required this.isTablet,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    final padding = isSmallScreen ? 14.0 : (isTablet ? 22.0 : 18.0);
    final borderRadius = isSmallScreen ? 12.0 : (isTablet ? 20.0 : 16.0);
    final monthSize = isSmallScreen ? 12.0 : (isTablet ? 18.0 : 14.0);
    final titleSize = isSmallScreen ? 13.0 : (isTablet ? 19.0 : 15.0);
    final statusSize = isSmallScreen ? 10.0 : (isTablet ? 16.0 : 12.0);

    return InkWell(
      onTap: () {
        String title = '';
        String statType = '';

        switch (status.toLowerCase()) {
          case 'pending':
            title = 'pending_leave_requests'.tr();
            statType = 'pending';
            break;
          case 'approved':
            title = 'approved_leave_requests'.tr();
            statType = 'approved';
            break;
          case 'rejected':
            title = 'rejected_leave_requests'.tr();
            statType = 'rejected';
            break;
          default:
            title = 'leave_requests'.tr();
            statType = 'total';
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
        padding: EdgeInsets.all(padding),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(borderRadius),
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
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: isSmallScreen ? 10 : (isTablet ? 18 : 14),
                vertical: isSmallScreen ? 8 : (isTablet ? 14 : 10),
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF1A3B68).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(isSmallScreen ? 8 : (isTablet ? 14 : 10)),
              ),
              child: Column(
                children: [
                  Text(
                    month,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: monthSize,
                      color: const Color(0xFF1A3B68),
                    ),
                  ),
                  Text(
                    date,
                    style: TextStyle(
                      fontSize: monthSize * 0.9,
                      color: const Color(0xFF1A3B68),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: isSmallScreen ? 12 : (isTablet ? 20 : 16)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: titleSize,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isSmallScreen ? 8 : (isTablet ? 14 : 10),
                      vertical: isSmallScreen ? 3 : (isTablet ? 6 : 4),
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(isSmallScreen ? 6 : (isTablet ? 12 : 8)),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: statusSize,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: isSmallScreen ? 14 : (isTablet ? 22 : 18),
              color: Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }
}