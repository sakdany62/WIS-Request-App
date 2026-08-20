// lib/screens/admin/admin_home_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../app_fonts.dart';
import '../../services/request_service.dart';
import '../../services/user_service.dart';
import '../../utils/responsive.dart';
import '../../widgets/profile_avatar.dart';
import '../staff/notifications_screen.dart';
import 'admin_profile_screen.dart';
import 'user_management_screen.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  final RequestService _requestService = RequestService();
  final UserService _userService = UserService();
  String adminName = 'Admin User';
  String? profileImageUrl;
  bool isLoading = true;
  String adminId = '';
  String? errorMessage;
  Map<String, int> _stats = {};
  int _pendingRequests = 0;
  int _totalUsers = 0;
  int _todayRequests = 0;
  int _totalRequests = 0;
  int _approvedRequests = 0;
  int _rejectedRequests = 0;

  int _unreadCount = 0;
  Stream<QuerySnapshot>? _notificationStream;

  @override
  void initState() {
    super.initState();
    _checkAuthAndLoad();
  }

  @override
  void dispose() {
    _notificationStream = null;
    super.dispose();
  }

  Future<void> _checkAuthAndLoad() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
      return;
    }
    setState(() => adminId = user.uid);
    await _loadAdminData();
    await _loadStats();
    _loadNotificationStream();
  }

  void _loadNotificationStream() {
    if (adminId.isEmpty) return;
    _notificationStream = FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: adminId)
        .where('isRead', isEqualTo: false)
        .snapshots();
    _notificationStream?.listen((snapshot) {
      if (mounted) setState(() => _unreadCount = snapshot.docs.length);
    });
  }

  Future<void> _refreshUnreadCount() async {
    if (adminId.isEmpty) return;
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: adminId)
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
            adminName = data['fullName'] ?? data['username'] ?? 'Admin User';
          });
        }
      }
    } catch (e) {
      print('Error refreshing profile image: $e');
    }
  }

  Future<void> _loadAdminData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final docSnapshot = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (docSnapshot.exists) {
        final data = docSnapshot.data() as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            adminName = data['fullName'] ?? data['username'] ?? 'Admin User';
            profileImageUrl = data['profileImageUrl'] ?? '';
            isLoading = false;
            errorMessage = null;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            adminName = user.email?.split('@').first ?? 'Admin User';
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

  Future<void> _loadStats() async {
    try {
      final userStats = await _userService.getUserStats();
      _totalUsers = userStats['total'] ?? 0;

      final totalSnapshot = await FirebaseFirestore.instance.collection('leave_requests').get();
      _totalRequests = totalSnapshot.docs.length;

      final pendingSnapshot = await FirebaseFirestore.instance
          .collection('leave_requests')
          .where('status', isEqualTo: 'pending')
          .get();
      _pendingRequests = pendingSnapshot.docs.length;

      final approvedSnapshot = await FirebaseFirestore.instance
          .collection('leave_requests')
          .where('status', isEqualTo: 'approved')
          .get();
      _approvedRequests = approvedSnapshot.docs.length;

      final rejectedSnapshot = await FirebaseFirestore.instance
          .collection('leave_requests')
          .where('status', isEqualTo: 'rejected')
          .get();
      _rejectedRequests = rejectedSnapshot.docs.length;

      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final todaySnapshot = await FirebaseFirestore.instance
          .collection('leave_requests')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('createdAt', isLessThan: Timestamp.fromDate(endOfDay))
          .get();
      _todayRequests = todaySnapshot.docs.length;

      if (mounted) {
        setState(() {
          _stats = {
            'totalUsers': _totalUsers,
            'pendingRequests': _pendingRequests,
            'todayRequests': _todayRequests,
            'totalRequests': _totalRequests,
            'approvedRequests': _approvedRequests,
            'rejectedRequests': _rejectedRequests,
          };
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _stats = {
            'totalUsers': 0,
            'pendingRequests': 0,
            'todayRequests': 0,
            'totalRequests': 0,
            'approvedRequests': 0,
            'rejectedRequests': 0,
          };
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = Responsive.isMobile(context);
    final double spacing = Responsive.spacing(context);
    final double iconSize = Responsive.iconSize(context, 28);
    double bottomPadding = MediaQuery.of(context).padding.bottom + 16;
    
    // Get screen dimensions for responsive sizing
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final bool isSmallScreen = screenWidth < 360;
    final bool isTablet = screenWidth >= 600;
    final bool isLargeScreen = screenWidth >= 900;

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
                const SizedBox(height: 16),
                Text(errorMessage!, style: TextStyle(fontSize: 16)),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      errorMessage = null;
                      isLoading = true;
                    });
                    _checkAuthAndLoad();
                  },
                  child: const Text('Retry'),
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
            await _loadStats();
            await _refreshUnreadCount();
            await _refreshProfileImage();
          },
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16),
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.only(top: isMobile ? 6 : 10, bottom: isMobile ? 6 : 10),
                  child: _buildProfileSection(isMobile, spacing, iconSize, screenWidth),
                ),
                Padding(
                  padding: EdgeInsets.only(bottom: isMobile ? 6 : 10),
                  child: _buildPieChartCard(isMobile, spacing, screenWidth),
                ),
                Expanded(
                  child: _buildStatsList(isMobile, spacing, screenWidth),
                ),
                SizedBox(height: bottomPadding),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileSection(bool isMobile, double spacing, double iconSize, double screenWidth) {
    final bool isSmallScreen = screenWidth < 360;
    final bool isTablet = screenWidth >= 600;

    // Responsive sizes based on screen width
    final double avatarRadius = isSmallScreen ? 22 : (isTablet ? 38 : 30);
    final double nameSize = isSmallScreen ? 13 : (isTablet ? 18 : 15);
    final double roleSize = isSmallScreen ? 9 : (isTablet ? 13 : 11);
    final double paddingSize = isSmallScreen ? 8 : (isTablet ? 14 : 10);

    return Container(
      padding: EdgeInsets.all(paddingSize),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A3B68), Color(0xFF2C5F8A)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          ProfileAvatar(
            userId: adminId,
            imageUrl: profileImageUrl,
            name: adminName,
            radius: avatarRadius,
            backgroundColor: Colors.white.withValues(alpha: 0.15),
            textColor: Colors.white,
            onTap: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AdminProfileScreen()),
              );
              if (result == true) await _refreshProfileImage();
            },
          ),
          SizedBox(width: isMobile ? 8 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  adminName,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: nameSize,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                SizedBox(height: isSmallScreen ? 1 : (isMobile ? 2 : 4)),
                Row(
                  children: [
                    Icon(
                      Icons.admin_panel_settings, 
                      size: isSmallScreen ? 12 : (isTablet ? 16 : 14), 
                      color: Colors.white70
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Administrator',
                      style: TextStyle(
                        color: Colors.white70, 
                        fontSize: roleSize
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ],
                ),
              ],
            ),
          ),
          _buildNotificationBadge(isMobile, screenWidth),
        ],
      ),
    );
  }

  Widget _buildNotificationBadge(bool isMobile, double screenWidth) {
    final bool isSmallScreen = screenWidth < 360;
    final double buttonSize = isSmallScreen ? 32 : (isMobile ? 38 : 44);
    final double badgeSize = isSmallScreen ? 12 : (isMobile ? 14 : 18);
    final double fontSize = isSmallScreen ? 6 : (isMobile ? 8 : 10);

    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const NotificationsScreen()),
            );
            _refreshUnreadCount();
          },
          icon: Icon(
            Icons.notifications_none, 
            color: Colors.white,
            size: buttonSize * 0.6,
          ),
          padding: EdgeInsets.zero,
          constraints: BoxConstraints(
            minWidth: buttonSize,
            minHeight: buttonSize,
          ),
        ),
        if (_unreadCount > 0)
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              padding: EdgeInsets.all(isSmallScreen ? 2 : 3),
              decoration: const BoxDecoration(
                color: Colors.red, 
                shape: BoxShape.circle
              ),
              constraints: BoxConstraints(
                minWidth: badgeSize,
                minHeight: badgeSize,
              ),
              child: Text(
                _unreadCount > 99 ? '99+' : _unreadCount.toString(),
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
  }

  Widget _buildPieChartCard(bool isMobile, double spacing, double screenWidth) {
    final bool isSmallScreen = screenWidth < 360;
    final bool isTablet = screenWidth >= 600;
    final bool isLargeScreen = screenWidth >= 900;

    final total = _stats['totalRequests'] ?? 0;
    final pending = _stats['pendingRequests'] ?? 0;
    final approved = _stats['approvedRequests'] ?? 0;
    final rejected = _stats['rejectedRequests'] ?? 0;

    final pendingPercent = total == 0 ? 0.0 : (pending / total) * 100;
    final approvedPercent = total == 0 ? 0.0 : (approved / total) * 100;
    final rejectedPercent = total == 0 ? 0.0 : (rejected / total) * 100;

    // Responsive padding and sizes - all as double
    final double chartHeight = isSmallScreen ? 90 : (isTablet ? 130 : 110);
    final double centerSpaceRadius = isSmallScreen ? 20 : (isTablet ? 38 : 30);
    final double sectionRadius = isSmallScreen ? 28 : (isTablet ? 38 : 32);
    final double titleSize = isSmallScreen ? 11 : (isTablet ? 15 : 13);
    final double legendFontSize = isSmallScreen ? 6 : (isTablet ? 10 : 8);
    final double legendCountSize = isSmallScreen ? 7 : (isTablet ? 13 : 11);
    final double percentSize = isSmallScreen ? 5 : (isTablet ? 9 : 7);
    final double paddingSize = isSmallScreen ? 6 : (isTablet ? 14 : 10);

    return Container(
      padding: EdgeInsets.all(paddingSize),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Statistics',
                style: TextStyle(
                  fontSize: titleSize,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1A3B68),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 6 : 8, 
                  vertical: isSmallScreen ? 1 : 2
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A3B68).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Total $total',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 8 : (isTablet ? 11 : 9),
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1A3B68),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (total == 0)
            SizedBox(
              height: chartHeight,
              child: Center(
                child: Text(
                  'No data available',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 10 : 12, 
                    color: Colors.grey.shade500
                  ),
                ),
              ),
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  flex: isSmallScreen ? 5 : 6,
                  child: SizedBox(
                    height: chartHeight,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        PieChart(
                          PieChartData(
                            sectionsSpace: 1,
                            centerSpaceRadius: centerSpaceRadius,
                            sections: [
                              PieChartSectionData(
                                color: const Color(0xFFF59E0B),
                                value: pending.toDouble(),
                                title: pendingPercent > 8 ? '${pendingPercent.toStringAsFixed(0)}%' : '',
                                radius: sectionRadius,
                                showTitle: true,
                                titleStyle: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  fontSize: isSmallScreen ? 6 : (isTablet ? 9 : 7),
                                ),
                              ),
                              PieChartSectionData(
                                color: const Color(0xFF10B981),
                                value: approved.toDouble(),
                                title: approvedPercent > 8 ? '${approvedPercent.toStringAsFixed(0)}%' : '',
                                radius: sectionRadius,
                                showTitle: true,
                                titleStyle: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  fontSize: isSmallScreen ? 6 : (isTablet ? 9 : 7),
                                ),
                              ),
                              PieChartSectionData(
                                color: const Color(0xFFEF4444),
                                value: rejected.toDouble(),
                                title: rejectedPercent > 8 ? '${rejectedPercent.toStringAsFixed(0)}%' : '',
                                radius: sectionRadius,
                                showTitle: true,
                                titleStyle: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  fontSize: isSmallScreen ? 6 : (isTablet ? 9 : 7),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '$total',
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 10 : (isTablet ? 16 : 13),
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF1A3B68),
                                ),
                              ),
                              Text(
                                'Total',
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 5 : (isTablet ? 9 : 7),
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  flex: isSmallScreen ? 5 : 4,
                  child: Padding(
                    padding: EdgeInsets.only(left: isSmallScreen ? 2 : (isMobile ? 4 : 8)),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildLegendItem(
                          'Pending', pending, '${pendingPercent.toStringAsFixed(1)}%', 
                          const Color(0xFFF59E0B), isSmallScreen, isTablet,
                          legendFontSize, legendCountSize, percentSize
                        ),
                        SizedBox(height: isSmallScreen ? 2 : 3),
                        _buildLegendItem(
                          'Approved', approved, '${approvedPercent.toStringAsFixed(1)}%', 
                          const Color(0xFF10B981), isSmallScreen, isTablet,
                          legendFontSize, legendCountSize, percentSize
                        ),
                        SizedBox(height: isSmallScreen ? 2 : 3),
                        _buildLegendItem(
                          'Rejected', rejected, '${rejectedPercent.toStringAsFixed(1)}%', 
                          const Color(0xFFEF4444), isSmallScreen, isTablet,
                          legendFontSize, legendCountSize, percentSize
                        ),
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

  Widget _buildLegendItem(
    String title, 
    int count, 
    String percent, 
    Color color, 
    bool isSmallScreen, 
    bool isTablet,
    double fontSize,
    double countSize,
    double percentSize
  ) {
    final double dotSize = isSmallScreen ? 6 : (isTablet ? 10 : 8);
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: dotSize,
          height: dotSize,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        SizedBox(width: isSmallScreen ? 3 : 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: fontSize,
                color: Colors.grey.shade600,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: countSize,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1A3B68),
                  ),
                ),
                SizedBox(width: 2),
                Text(
                  '($percent)',
                  style: TextStyle(
                    fontSize: percentSize,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatsList(bool isMobile, double spacing, double screenWidth) {
    final bool isTablet = screenWidth >= 600;
    final bool isSmallScreen = screenWidth < 360;
    final bool isLargeScreen = screenWidth >= 900;

    final List<Map<String, dynamic>> statsList = [
      {'title': 'Total Users', 'value': _stats['totalUsers'] ?? 0, 'color': const Color(0xFF6366F1), 'icon': Icons.people_rounded, 'type': 'users'},
      {'title': 'Pending Requests', 'value': _stats['pendingRequests'] ?? 0, 'color': const Color(0xFFF59E0B), 'icon': Icons.pending_rounded, 'type': 'pending'},
      {'title': "Today's Requests", 'value': _stats['todayRequests'] ?? 0, 'color': const Color(0xFF3B82F6), 'icon': Icons.today_rounded, 'type': 'today'},
      {'title': 'Approved Requests', 'value': _stats['approvedRequests'] ?? 0, 'color': const Color(0xFF8B5CF6), 'icon': Icons.check_circle_rounded, 'type': 'approved'},
      {'title': 'Total Requests', 'value': _stats['totalRequests'] ?? 0, 'color': const Color(0xFF10B981), 'icon': Icons.assignment_rounded, 'type': 'total'},
      {'title': 'Rejected Requests', 'value': _stats['rejectedRequests'] ?? 0, 'color': const Color(0xFFEF4444), 'icon': Icons.cancel_rounded, 'type': 'rejected'},
    ];

    if (statsList.isEmpty || _stats['totalRequests'] == 0) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.inbox_outlined, size: 36, color: Colors.grey.shade300),
              const SizedBox(height: 4),
              Text(
                'No data available',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    // Responsive grid or list layout
    final bool useGrid = isTablet && !isSmallScreen;
    
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 4 : (isMobile ? 6 : 12)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 4 : 0),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: isSmallScreen ? 10 : 12,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                SizedBox(width: isSmallScreen ? 4 : 6),
                Text(
                  'Additional Data',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 10 : (isTablet ? 14 : 12),
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1A3B68),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: isSmallScreen ? 2 : 4),
          useGrid 
            ? Expanded(
                child: GridView.builder(
                  padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 2 : 4),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: isLargeScreen ? 3 : 2,
                    childAspectRatio: isLargeScreen ? 3.5 : 3.2,
                    crossAxisSpacing: spacing * 0.5,
                    mainAxisSpacing: spacing * 0.5,
                  ),
                  itemCount: statsList.length,
                  itemBuilder: (context, index) {
                    return _buildStatListItem(
                      statsList[index], 
                      isMobile, 
                      isTablet, 
                      isSmallScreen, 
                      spacing,
                      screenWidth
                    );
                  },
                ),
              )
            : Expanded(
                child: ListView(
                  padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 2 : 4),
                  children: statsList.map((stat) {
                    return Padding(
                      padding: EdgeInsets.only(bottom: spacing * 0.25),
                      child: _buildStatListItem(
                        stat, isMobile, isTablet, isSmallScreen, spacing, screenWidth
                      ),
                    );
                  }).toList(),
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildStatListItem(
    Map<String, dynamic> stat,
    bool isMobile,
    bool isTablet,
    bool isSmallScreen,
    double spacing,
    double screenWidth,
  ) {
    final Color color = stat['color'] as Color;
    final String title = stat['title'] as String;
    final int value = stat['value'] as int;
    final IconData icon = stat['icon'] as IconData;
    final String type = stat['type'] as String;

    // Responsive sizes - all as double
    final double iconSize = isSmallScreen ? 10 : (isTablet ? 16 : 13);
    final double fontSize = isSmallScreen ? 10 : (isTablet ? 14 : 12);
    final double labelSize = isSmallScreen ? 7 : (isTablet ? 10 : 8);
    final double paddingV = isSmallScreen ? 2 : (isTablet ? 6 : 4);
    final double paddingH = isSmallScreen ? 4 : (isTablet ? 10 : 6);
    final double borderRadius = isSmallScreen ? 4 : 6;

    return InkWell(
      onTap: () => _navigateToDetail(type),
      borderRadius: BorderRadius.circular(borderRadius),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: paddingH,
          vertical: paddingV,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(color: color.withValues(alpha: 0.1), width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(isSmallScreen ? 2 : 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: iconSize),
            ),
            SizedBox(width: isSmallScreen ? 4 : (isMobile ? 6 : 10)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value.toString(),
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                    maxLines: 1,
                  ),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: labelSize,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.all(isSmallScreen ? 2 : 3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.arrow_forward_ios,
                size: isSmallScreen ? 6 : (isMobile ? 8 : 12),
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToDetail(String type) {
    if (type == 'users') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const UserManagementScreen()),
      ).then((_) {
        _loadStats();
        _refreshUnreadCount();
        _refreshProfileImage();
      });
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _DetailListScreen(type: type, stats: _stats),
      ),
    ).then((_) {
      _loadStats();
      _refreshUnreadCount();
      _refreshProfileImage();
    });
  }
}

// ==================== DETAIL LIST SCREEN ====================
class _DetailListScreen extends StatefulWidget {
  final String type;
  final Map<String, int> stats;

  const _DetailListScreen({required this.type, required this.stats});

  @override
  State<_DetailListScreen> createState() => _DetailListScreenState();
}

class _DetailListScreenState extends State<_DetailListScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _isLoading = true;
  String? _error;
  final Map<String, Map<String, dynamic>> _userCache = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _userCache.clear();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _error = null;
      _userCache.clear();
    });

    try {
      switch (widget.type) {
        case 'pending':
          await _loadRequests(status: 'pending');
          break;
        case 'today':
          await _loadTodayRequests();
          break;
        case 'total':
          await _loadRequests();
          break;
        case 'approved':
          await _loadRequests(status: 'approved');
          break;
        case 'rejected':
          await _loadRequests(status: 'rejected');
          break;
        default:
          if (mounted) setState(() => _items = []);
          break;
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Failed to load data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<Map<String, dynamic>> _getUserData(String userId) async {
    if (_userCache.containsKey(userId)) return _userCache[userId]!;
    try {
      final docSnapshot = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      Map<String, dynamic> userData = {};
      if (docSnapshot.exists) {
        final data = docSnapshot.data() as Map<String, dynamic>;
        userData = {
          'fullName': data['fullName'] ?? 'Unknown',
          'email': data['email'] ?? 'N/A',
          'department': data['department'] ?? 'N/A',
          'role': data['role'] ?? 'user',
          'phone': data['phone'] ?? 'N/A',
        };
      }
      _userCache[userId] = userData;
      return userData;
    } catch (e) {
      return {'fullName': 'Unknown', 'email': 'N/A', 'department': 'N/A', 'role': 'user', 'phone': 'N/A'};
    }
  }

  Future<void> _loadRequests({String? status}) async {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance.collection('leave_requests');
    if (status != null) query = query.where('status', isEqualTo: status);
    query = query.orderBy('createdAt', descending: true);
    final snapshot = await query.get();

    List<Map<String, dynamic>> items = [];
    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final userId = data['userId'] ?? '';
      final userData = await _getUserData(userId);
      items.add({
        'id': doc.id,
        'userId': userId,
        'reason': data['reason'] ?? 'No reason',
        'status': data['status'] ?? 'pending',
        'startDate': data['startDate'],
        'endDate': data['endDate'],
        'submitTime': data['submitTime'],
        'fullName': userData['fullName'] ?? data['userName'] ?? 'Unknown',
        'department': userData['department'] ?? 'N/A',
        'role': userData['role'] ?? 'user',
      });
    }
    if (mounted) setState(() => _items = items);
  }

  Future<void> _loadTodayRequests({String? status}) async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('leave_requests')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('createdAt', isLessThan: Timestamp.fromDate(endOfDay));
    if (status != null) query = query.where('status', isEqualTo: status);
    query = query.orderBy('createdAt', descending: true);
    final snapshot = await query.get();

    List<Map<String, dynamic>> items = [];
    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final userId = data['userId'] ?? '';
      final userData = await _getUserData(userId);
      items.add({
        'id': doc.id,
        'userId': userId,
        'reason': data['reason'] ?? 'No reason',
        'status': data['status'] ?? 'pending',
        'startDate': data['startDate'],
        'endDate': data['endDate'],
        'submitTime': data['submitTime'],
        'fullName': userData['fullName'] ?? data['userName'] ?? 'Unknown',
        'department': userData['department'] ?? 'N/A',
        'role': userData['role'] ?? 'user',
      });
    }
    if (mounted) setState(() => _items = items);
  }

  String _getTitle() {
    final labels = {
      'pending': 'Pending Requests (${widget.stats['pendingRequests'] ?? 0})',
      'today': "Today's Requests (${widget.stats['todayRequests'] ?? 0})",
      'total': 'Total Requests (${widget.stats['totalRequests'] ?? 0})',
      'approved': 'Approved Requests (${widget.stats['approvedRequests'] ?? 0})',
      'rejected': 'Rejected Requests (${widget.stats['rejectedRequests'] ?? 0})',
    };
    return labels[widget.type] ?? 'Details';
  }

  Color _getColor() {
    final colors = {
      'pending': const Color(0xFFF59E0B),
      'today': const Color(0xFF3B82F6),
      'total': const Color(0xFF10B981),
      'approved': const Color(0xFF8B5CF6),
      'rejected': const Color(0xFFEF4444),
    };
    return colors[widget.type] ?? const Color(0xFF6366F1);
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    if (timestamp is Timestamp) {
      return '${timestamp.toDate().day}/${timestamp.toDate().month}/${timestamp.toDate().year}';
    }
    return 'N/A';
  }

  String _formatTime(dynamic submitTime) {
    if (submitTime == null) return 'N/A';
    try {
      if (submitTime is String && (submitTime.contains('AM') || submitTime.contains('PM'))) {
        return submitTime;
      }
      DateTime? dt;
      if (submitTime is Timestamp) dt = submitTime.toDate();
      else if (submitTime is DateTime) dt = submitTime;
      else if (submitTime is String) {
        try { dt = DateTime.parse(submitTime); } catch (_) {}
      }
      if (dt == null) return 'N/A';
      final khmerTime = dt.toUtc().add(const Duration(hours: 7));
      int hour = khmerTime.hour;
      final minute = khmerTime.minute;
      final period = hour >= 12 ? 'PM' : 'AM';
      if (hour == 0) hour = 12;
      else if (hour > 12) hour -= 12;
      return '$hour:${minute.toString().padLeft(2, '0')} $period';
    } catch (_) { return 'N/A'; }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved': return const Color(0xFF10B981);
      case 'rejected': return const Color(0xFFEF4444);
      default: return const Color(0xFFF59E0B);
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'approved': return Icons.check_circle;
      case 'rejected': return Icons.cancel;
      default: return Icons.pending;
    }
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin': return const Color(0xFF8B5CF6);
      case 'manager': return const Color(0xFFF59E0B);
      case 'staff': return const Color(0xFF10B981);
      default: return const Color(0xFF3B82F6);
    }
  }

  String _getRoleName(String role) {
    switch (role.toLowerCase()) {
      case 'admin': return 'Admin';
      case 'manager': return 'Manager';
      case 'staff': return 'Staff';
      default: return 'Staff';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = Responsive.isMobile(context);
    final double fontSize = Responsive.fontSize(context, 14);
    final double spacing = Responsive.spacing(context);
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isSmallScreen = screenWidth < 360;
    final bool isTablet = screenWidth >= 600;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _getTitle(), 
          style: TextStyle(
            fontSize: isSmallScreen ? 14 : (isMobile ? 16 : 18), 
            fontWeight: FontWeight.bold
          ),
        ),
        backgroundColor: _getColor(),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              Icons.refresh, 
              size: isSmallScreen ? 18 : (isMobile ? 20 : 24)
            ), 
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(_error!, style: TextStyle(fontSize: fontSize)),
                      const SizedBox(height: 20),
                      ElevatedButton(onPressed: _loadData, child: const Text('Retry')),
                    ],
                  ),
                )
              : _items.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          Text('No Data', style: TextStyle(fontSize: fontSize, color: Colors.grey.shade600)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.all(spacing),
                      itemCount: _items.length,
                      itemBuilder: (context, index) {
                        final item = _items[index];
                        return _buildItemCard(item, isMobile, fontSize, spacing, screenWidth);
                      },
                    ),
    );
  }

  // ================================================================
  // ===== BUILD ITEM CARD WITH PROFILE AVATAR =====
  // ================================================================
  Widget _buildItemCard(
    Map<String, dynamic> item, 
    bool isMobile, 
    double fontSize, 
    double spacing,
    double screenWidth
  ) {
    final bool isSmallScreen = screenWidth < 360;
    final bool isTablet = screenWidth >= 600;
    final Color statusColor = _getStatusColor(item['status'] ?? 'pending');
    final String userId = item['userId'] ?? '';
    final String fullName = item['fullName'] ?? 'Unknown';
    final String department = item['department'] ?? 'N/A';
    final String reason = item['reason'] ?? 'No reason';
    final String status = item['status'] ?? 'pending';
    final String submitTime = _formatTime(item['submitTime']);
    final String role = item['role'] ?? 'user';
    final String startDate = _formatDate(item['startDate']);

    // Responsive sizes - all as double
    final double avatarRadius = isSmallScreen ? 16 : (isTablet ? 24 : 20);
    final double paddingSize = isSmallScreen ? 8 : (isMobile ? 12 : 16);
    final double nameSize = isSmallScreen ? fontSize * 0.9 : (isMobile ? fontSize : fontSize + 2);
    final double roleBadgeSize = isSmallScreen ? fontSize * 0.55 : (isMobile ? fontSize * 0.6 : fontSize * 0.7);
    final double detailSize = isSmallScreen ? fontSize * 0.6 : (isMobile ? fontSize * 0.7 : fontSize * 0.85);
    final double statusSize = isSmallScreen ? fontSize * 0.55 : (isMobile ? fontSize * 0.6 : fontSize * 0.75);
    final double dateSize = isSmallScreen ? fontSize * 0.45 : (isMobile ? fontSize * 0.5 : fontSize * 0.65);
    final double iconSize = isSmallScreen ? 8 : (isMobile ? 10 : 12);
    final double spacingSmall = isSmallScreen ? 1 : (isMobile ? 2 : 4);

    return Card(
      margin: EdgeInsets.only(bottom: spacing * 1.2),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isSmallScreen ? 10 : 14),
        side: BorderSide(
          color: statusColor.withValues(alpha: 0.2),
          width: 0.5,
        ),
      ),
      child: InkWell(
        onTap: () {
          // Optional: Navigate to detail
        },
        borderRadius: BorderRadius.circular(isSmallScreen ? 10 : 14),
        child: Padding(
          padding: EdgeInsets.all(paddingSize),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ✅ Profile Avatar
              ProfileAvatar(
                userId: userId,
                name: fullName,
                radius: avatarRadius,
                backgroundColor: statusColor.withValues(alpha: 0.12),
                textColor: statusColor,
              ),
              SizedBox(width: isSmallScreen ? 6 : (isMobile ? 10 : 14)),
              
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Name with Role Badge
                    Wrap(
                      spacing: 4,
                      runSpacing: 2,
                      alignment: WrapAlignment.start,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          fullName,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: nameSize,
                            color: Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: isSmallScreen ? 4 : (isMobile ? 6 : 8),
                            vertical: isSmallScreen ? 1 : (isMobile ? 1 : 2),
                          ),
                          decoration: BoxDecoration(
                            color: _getRoleColor(role).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: _getRoleColor(role).withValues(alpha: 0.3),
                              width: 0.5,
                            ),
                          ),
                          child: Text(
                            _getRoleName(role),
                            style: TextStyle(
                              color: _getRoleColor(role),
                              fontSize: roleBadgeSize,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: spacingSmall),
                    
                    // Department
                    if (department != 'N/A')
                      Row(
                        children: [
                          Icon(
                            Icons.business_center,
                            size: iconSize,
                            color: Colors.grey.shade500,
                          ),
                          SizedBox(width: isSmallScreen ? 2 : 4),
                          Flexible(
                            child: Text(
                              department,
                              style: TextStyle(
                                fontSize: detailSize,
                                color: Colors.grey.shade600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    
                    // Reason
                    Row(
                      children: [
                        Icon(
                          Icons.note,
                          size: iconSize,
                          color: Colors.grey.shade500,
                        ),
                        SizedBox(width: isSmallScreen ? 2 : 4),
                        Flexible(
                          child: Text(
                            reason,
                            style: TextStyle(
                              fontSize: detailSize,
                              color: Colors.grey.shade700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    
                    // Submit Time
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: iconSize,
                          color: Colors.blue.shade400,
                        ),
                        SizedBox(width: isSmallScreen ? 2 : 4),
                        Flexible(
                          child: Text(
                            'Submitted: $submitTime',
                            style: TextStyle(
                              fontSize: detailSize * 0.9,
                              color: Colors.blue.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Status Badge
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isSmallScreen ? 4 : (isMobile ? 8 : 12),
                      vertical: isSmallScreen ? 2 : (isMobile ? 4 : 6),
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(isSmallScreen ? 8 : 12),
                      border: Border.all(
                        color: statusColor.withValues(alpha: 0.3),
                        width: 0.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getStatusIcon(status),
                          color: statusColor,
                          size: isSmallScreen ? 8 : (isMobile ? 10 : 14),
                        ),
                        SizedBox(width: isSmallScreen ? 2 : 4),
                        Text(
                          status.toUpperCase(),
                          style: TextStyle(
                            color: statusColor,
                            fontSize: statusSize,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: isSmallScreen ? 2 : (isMobile ? 4 : 6)),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isSmallScreen ? 4 : (isMobile ? 6 : 10),
                      vertical: isSmallScreen ? 1 : (isMobile ? 2 : 4),
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(isSmallScreen ? 6 : 8),
                    ),
                    child: Text(
                      startDate,
                      style: TextStyle(
                        fontSize: dateSize,
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}