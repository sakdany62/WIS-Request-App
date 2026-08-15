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
  int _approvedToday = 0;
  int _rejectedToday = 0;

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

      final pendingSnapshot =
          await FirebaseFirestore.instance.collection('leave_requests').where('status', isEqualTo: 'pending').get();
      _pendingRequests = pendingSnapshot.docs.length;

      final totalSnapshot = await FirebaseFirestore.instance.collection('leave_requests').get();
      _totalRequests = totalSnapshot.docs.length;

      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final todaySnapshot = await FirebaseFirestore.instance
          .collection('leave_requests')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('createdAt', isLessThan: Timestamp.fromDate(endOfDay))
          .get();
      _todayRequests = todaySnapshot.docs.length;

      final approvedTodaySnapshot = await FirebaseFirestore.instance
          .collection('leave_requests')
          .where('status', isEqualTo: 'approved')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('createdAt', isLessThan: Timestamp.fromDate(endOfDay))
          .get();
      _approvedToday = approvedTodaySnapshot.docs.length;

      final rejectedTodaySnapshot = await FirebaseFirestore.instance
          .collection('leave_requests')
          .where('status', isEqualTo: 'rejected')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('createdAt', isLessThan: Timestamp.fromDate(endOfDay))
          .get();
      _rejectedToday = rejectedTodaySnapshot.docs.length;

      if (mounted) {
        setState(() {
          _stats = {
            'totalUsers': _totalUsers,
            'pendingRequests': _pendingRequests,
            'todayRequests': _todayRequests,
            'totalRequests': _totalRequests,
            'approvedToday': _approvedToday,
            'rejectedToday': _rejectedToday,
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
            'approvedToday': 0,
            'rejectedToday': 0,
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
          // ✅ Profile និង Statistics នៅស្ងៀម (fixed)
          // ✅ Additional Data អាច scroll បាន
          child: Column(
            children: [
              // Profile Section - Fixed
              Padding(
                padding: EdgeInsets.all(isMobile ? 12 : 16),
                child: _buildProfileSection(isMobile, spacing, iconSize),
              ),
              // Statistics Section - Fixed
              Padding(
                padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16),
                child: _buildPieChartCard(isMobile, spacing),
              ),
              const SizedBox(height: 16),
              // Additional Data Section - Scrollable
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16),
                  child: Column(
                    children: [
                      _buildStatsList(isMobile, spacing),
                      SizedBox(height: bottomPadding),
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
            userId: adminId,
            imageUrl: profileImageUrl,
            name: adminName,
            radius: avatarRadius.toDouble(),
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
          SizedBox(width: isMobile ? 10 : 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  adminName,
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
                    Icon(Icons.admin_panel_settings, size: isMobile ? 14 : 16, color: Colors.white70),
                    const SizedBox(width: 4),
                    Text(
                      'Administrator',
                      style: TextStyle(color: Colors.white70, fontSize: roleSize.toDouble()),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _buildNotificationBadge(isMobile),
        ],
      ),
    );
  }

  Widget _buildNotificationBadge(bool isMobile) {
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
          icon: const Icon(Icons.notifications_none, color: Colors.white),
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

  Widget _buildPieChartCard(bool isMobile, double spacing) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final isTablet = screenWidth >= 600;

    final total = _stats['totalRequests'] ?? 0;
    final pending = _stats['pendingRequests'] ?? 0;
    final approved = _stats['approvedToday'] ?? 0;
    final rejected = _stats['rejectedToday'] ?? 0;

    final pendingPercent = total == 0 ? 0.0 : (pending / total) * 100;
    final approvedPercent = total == 0 ? 0.0 : (approved / total) * 100;
    final rejectedPercent = total == 0 ? 0.0 : (rejected / total) * 100;

    return Container(
      padding: EdgeInsets.all(isMobile ? 14 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
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
                  fontSize: isMobile ? 15 : 18,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1A3B68),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A3B68).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'Total $total',
                  style: TextStyle(
                    fontSize: isMobile ? 11 : 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1A3B68),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (total == 0)
            SizedBox(
              height: 180,
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
                    height: isSmallScreen ? 150 : (isTablet ? 200 : 170),
                    child: Stack(
                      children: [
                        PieChart(
                          PieChartData(
                            sectionsSpace: 4,
                            centerSpaceRadius: isSmallScreen ? 40 : 60,
                            sections: [
                              PieChartSectionData(
                                color: const Color(0xFFF59E0B),
                                value: pending.toDouble(),
                                title: pendingPercent > 0 ? '${pendingPercent.toStringAsFixed(0)}%' : '',
                                radius: 45,
                                showTitle: true,
                                titleStyle: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  fontSize: 10,
                                ),
                              ),
                              PieChartSectionData(
                                color: const Color(0xFF10B981),
                                value: approved.toDouble(),
                                title: approvedPercent > 0 ? '${approvedPercent.toStringAsFixed(0)}%' : '',
                                radius: 45,
                                showTitle: true,
                                titleStyle: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  fontSize: 10,
                                ),
                              ),
                              PieChartSectionData(
                                color: const Color(0xFFEF4444),
                                value: rejected.toDouble(),
                                title: rejectedPercent > 0 ? '${rejectedPercent.toStringAsFixed(0)}%' : '',
                                radius: 45,
                                showTitle: true,
                                titleStyle: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '$total',
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 18 : (isTablet ? 28 : 22),
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF1A3B68),
                                ),
                              ),
                              Text(
                                'Total',
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 8 : (isTablet ? 12 : 10),
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
                  flex: 4,
                  child: Padding(
                    padding: EdgeInsets.only(left: isMobile ? 6 : 12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLegendItem('Pending', pending, const Color(0xFFF59E0B), isSmallScreen, isTablet),
                        const SizedBox(height: 8),
                        _buildLegendItem('Approved', approved, const Color(0xFF10B981), isSmallScreen, isTablet),
                        const SizedBox(height: 8),
                        _buildLegendItem('Rejected', rejected, const Color(0xFFEF4444), isSmallScreen, isTablet),
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
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: isSmallScreen ? 9 : (isTablet ? 12 : 10),
                color: Colors.grey.shade600,
              ),
            ),
            Text(
              count.toString(),
              style: TextStyle(
                fontSize: isSmallScreen ? 12 : (isTablet ? 16 : 14),
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1A3B68),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatsList(bool isMobile, double spacing) {
    final bool isTablet = MediaQuery.of(context).size.width >= 600;
    final bool isSmallScreen = MediaQuery.of(context).size.width < 360;

    final List<Map<String, dynamic>> statsList = [
      {'title': 'Users', 'value': _stats['totalUsers'] ?? 0, 'color': const Color(0xFF6366F1), 'icon': Icons.people_rounded, 'type': 'users'},
      {'title': 'Pending', 'value': _stats['pendingRequests'] ?? 0, 'color': const Color(0xFFF59E0B), 'icon': Icons.pending_rounded, 'type': 'pending'},
      {'title': 'Today', 'value': _stats['todayRequests'] ?? 0, 'color': const Color(0xFF3B82F6), 'icon': Icons.today_rounded, 'type': 'today'},
      {'title': 'Approved', 'value': _stats['approvedToday'] ?? 0, 'color': const Color(0xFF8B5CF6), 'icon': Icons.check_circle_rounded, 'type': 'approved'},
      {'title': 'Total', 'value': _stats['totalRequests'] ?? 0, 'color': const Color(0xFF10B981), 'icon': Icons.assignment_rounded, 'type': 'total'},
      {'title': 'Rejected', 'value': _stats['rejectedToday'] ?? 0, 'color': const Color(0xFFEF4444), 'icon': Icons.cancel_rounded, 'type': 'rejected'},
    ];

    if (statsList.isEmpty || _stats['totalRequests'] == 0) {
      return Container(
        padding: const EdgeInsets.all(20),
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
        child: Center(
          child: Column(
            children: [
              Icon(Icons.inbox_outlined, size: 48, color: Colors.grey.shade300),
              const SizedBox(height: 8),
              Text(
                'No data available',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(isMobile ? 10 : 16),
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
                'Additional Data',
                style: TextStyle(
                  fontSize: isMobile ? 15 : 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1A3B68),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // ✅ ប្រើ Column ដើម្បីឱ្យ items ទាំងអស់បង្ហាញពេញ
          Column(
            children: statsList.map((stat) => _buildStatListItem(stat, isMobile, isTablet, isSmallScreen, spacing)).toList(),
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
  ) {
    final Color color = stat['color'] as Color;
    final String title = stat['title'] as String;
    final int value = stat['value'] as int;
    final IconData icon = stat['icon'] as IconData;
    final String type = stat['type'] as String;

    final iconSize = isSmallScreen ? 16 : (isTablet ? 22 : 18);
    final fontSize = isSmallScreen ? 14 : (isTablet ? 18 : 16);
    final labelSize = isSmallScreen ? 10 : (isTablet ? 13 : 11);

    return InkWell(
      onTap: () => _navigateToDetail(type),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: EdgeInsets.only(bottom: spacing * 0.6),
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 10 : 14,
          vertical: isMobile ? 8 : 12,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.12), width: 1),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: iconSize.toDouble()),
            ),
            SizedBox(width: isMobile ? 8 : 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value.toString(),
                    style: TextStyle(
                      fontSize: fontSize.toDouble(),
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: labelSize.toDouble(),
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: isMobile ? 12 : 16,
              color: Colors.grey.shade400,
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

  Future<void> _loadData() async {
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
          await _loadTodayRequests(status: 'approved');
          break;
        case 'rejected':
          await _loadTodayRequests(status: 'rejected');
          break;
        default:
          setState(() => _items = []);
          break;
      }
    } catch (e) {
      setState(() => _error = 'Failed to load data: $e');
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
    setState(() => _items = items);
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
    setState(() => _items = items);
  }

  String _getTitle() {
    final labels = {
      'pending': 'Pending Requests (${widget.stats['pendingRequests'] ?? 0})',
      'today': "Today's Requests (${widget.stats['todayRequests'] ?? 0})",
      'total': 'Total Requests (${widget.stats['totalRequests'] ?? 0})',
      'approved': 'Approved Today (${widget.stats['approvedToday'] ?? 0})',
      'rejected': 'Rejected Today (${widget.stats['rejectedToday'] ?? 0})',
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
      default: return 'Employee';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = Responsive.isMobile(context);
    final double fontSize = Responsive.fontSize(context, 14);
    final double spacing = Responsive.spacing(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_getTitle(), style: TextStyle(fontSize: isMobile ? 16 : 18, fontWeight: FontWeight.bold)),
        backgroundColor: _getColor(),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
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
                        return _buildItemCard(item, isMobile, fontSize, spacing);
                      },
                    ),
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item, bool isMobile, double fontSize, double spacing) {
    final Color statusColor = _getStatusColor(item['status'] ?? 'pending');

    return Card(
      margin: EdgeInsets.only(bottom: spacing),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 10 : 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar
            CircleAvatar(
              radius: isMobile ? 18 : 22,
              backgroundColor: statusColor.withValues(alpha: 0.15),
              child: Icon(
                _getStatusIcon(item['status'] ?? 'pending'),
                color: statusColor,
                size: isMobile ? 16 : 20,
              ),
            ),
            SizedBox(width: isMobile ? 10 : 14),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Name
                  Text(
                    item['fullName'] ?? 'Unknown',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: isMobile ? fontSize : fontSize + 2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: isMobile ? 1 : 2),
                  // Department
                  if (item['department'] != null && item['department'] != 'N/A')
                    Text(
                      item['department'],
                      style: TextStyle(
                        fontSize: isMobile ? fontSize * 0.7 : fontSize * 0.85,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  // Reason
                  Text(
                    'Reason: ${item['reason'] ?? 'No reason'}',
                    style: TextStyle(
                      fontSize: isMobile ? fontSize * 0.75 : fontSize * 0.9,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  // Date range
                  Text(
                    '${_formatDate(item['startDate'])} - ${_formatDate(item['endDate'])}',
                    style: TextStyle(
                      fontSize: isMobile ? fontSize * 0.7 : fontSize * 0.85,
                      color: Colors.grey.shade600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  // Submit time
                  Text(
                    'Submitted: ${_formatTime(item['submitTime'])}',
                    style: TextStyle(
                      fontSize: isMobile ? fontSize * 0.7 : fontSize * 0.85,
                      color: Colors.blue.shade700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Trailing badges
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 6 : 10,
                    vertical: isMobile ? 2 : 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    (item['status'] ?? 'pending').toUpperCase(),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isMobile ? fontSize * 0.55 : fontSize * 0.7,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(height: isMobile ? 2 : 4),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 4 : 8,
                    vertical: isMobile ? 1 : 3,
                  ),
                  decoration: BoxDecoration(
                    color: _getRoleColor(item['role'] ?? 'user').withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _getRoleColor(item['role'] ?? 'user'),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    _getRoleName(item['role'] ?? 'user'),
                    style: TextStyle(
                      color: _getRoleColor(item['role'] ?? 'user'),
                      fontSize: isMobile ? fontSize * 0.5 : fontSize * 0.65,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}