import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
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
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
      return;
    }

    setState(() {
      adminId = user.uid;
    });

    await _loadAdminData();
    await _loadStats();
    _loadNotificationStream();
  }

  void _loadNotificationStream() {
    if (adminId.isNotEmpty) {
      _notificationStream = FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: adminId)
          .where('isRead', isEqualTo: false)
          .snapshots();

      _notificationStream?.listen((snapshot) {
        if (mounted) {
          setState(() {
            _unreadCount = snapshot.docs.length;
          });
        }
      });
    }
  }

  Future<void> _refreshUnreadCount() async {
    if (adminId.isEmpty) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: adminId)
          .where('isRead', isEqualTo: false)
          .get();

      if (mounted) {
        setState(() {
          _unreadCount = snapshot.docs.length;
        });
      }
    } catch (e) {
      print('❌ Error refreshing unread count: $e');
    }
  }

  // ✅ Method to refresh profile image after update
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
            adminName = data['fullName'] ?? data['username'] ?? 'Admin User';
          });
        }
      }
    } catch (e) {
      print('❌ Error refreshing profile image: $e');
    }
  }

  Future<void> _loadAdminData() async {
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

  Future<void> _loadStats() async {
    try {
      final userStats = await _userService.getUserStats();
      _totalUsers = userStats['total'] ?? 0;

      try {
        final pendingSnapshot = await FirebaseFirestore.instance
            .collection('leave_requests')
            .where('status', isEqualTo: 'pending')
            .get();
        _pendingRequests = pendingSnapshot.docs.length;
      } catch (e) {
        _pendingRequests = 0;
      }

      try {
        final totalSnapshot = await FirebaseFirestore.instance
            .collection('leave_requests')
            .get();
        _totalRequests = totalSnapshot.docs.length;
      } catch (e) {
        _totalRequests = 0;
      }

      try {
        final now = DateTime.now();
        final startOfDay = DateTime(now.year, now.month, now.day, 0, 0, 0);
        final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

        final todaySnapshot = await FirebaseFirestore.instance
            .collection('leave_requests')
            .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
            .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
            .get();
        _todayRequests = todaySnapshot.docs.length;
      } catch (e) {
        _todayRequests = 0;
      }

      try {
        final now = DateTime.now();
        final startOfDay = DateTime(now.year, now.month, now.day, 0, 0, 0);
        final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

        final approvedTodaySnapshot = await FirebaseFirestore.instance
            .collection('leave_requests')
            .where('status', isEqualTo: 'approved')
            .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
            .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
            .get();
        _approvedToday = approvedTodaySnapshot.docs.length;
      } catch (e) {
        _approvedToday = 0;
      }

      try {
        final now = DateTime.now();
        final startOfDay = DateTime(now.year, now.month, now.day, 0, 0, 0);
        final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

        final rejectedTodaySnapshot = await FirebaseFirestore.instance
            .collection('leave_requests')
            .where('status', isEqualTo: 'rejected')
            .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
            .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
            .get();
        _rejectedToday = rejectedTodaySnapshot.docs.length;
      } catch (e) {
        _rejectedToday = 0;
      }

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
    final double fontSize = Responsive.fontSize(context, 14);
    final double spacing = Responsive.spacing(context);
    final double iconSize = Responsive.iconSize(context, 28);
    final double gridSpacing = isMobile ? 6 : 12;

    const int crossAxisCount = 3;
    const int rowCount = 2;

    final double screenHeight = MediaQuery.of(context).size.height;
    final double screenWidth = MediaQuery.of(context).size.width;
    final double safeAreaTop = MediaQuery.of(context).padding.top;
    final double safeAreaBottom = MediaQuery.of(context).padding.bottom;
    
    final double headerHeight = isMobile ? 90 : 120;
    
    final double totalAvailableHeight = screenHeight - safeAreaTop - safeAreaBottom - (spacing * 2);
    final double gridHeight = totalAvailableHeight * 0.7;
    
    final double horizontalPadding = spacing * 2;
    final double gridWidth = screenWidth - horizontalPadding;
    final double itemWidth = (gridWidth - (gridSpacing * (crossAxisCount - 1))) / crossAxisCount;
    final double itemHeight = (gridHeight - (gridSpacing * (rowCount - 1))) / rowCount;
    final double reducedItemHeight = itemHeight * 0.95;
    final double childAspectRatio = itemWidth / (reducedItemHeight > 0 ? reducedItemHeight : 1);

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
                const SizedBox(height: 16),
                Text(
                  'Error',
                  style: TextStyle(
                    fontSize: fontSize + 2,
                    fontWeight: FontWeight.bold,
                    color: Colors.red[700],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  errorMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: fontSize),
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
                    style: TextStyle(fontSize: fontSize),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                vertical: isMobile ? 16 : 24,
                horizontal: spacing * 1.5,
              ),
              decoration: const BoxDecoration(
                color: Color(0xFF173B69),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
              child: _AdminUserHeader(
                adminName: adminName,
                adminId: adminId,
                profileImageUrl: profileImageUrl,
                isLoading: isLoading,
                unreadCount: _unreadCount,
                onNotificationPressed: _refreshUnreadCount,
                onProfileUpdated: _refreshProfileImage, // ✅ Pass callback
                useWhiteTheme: true,
                isMobile: isMobile,
                fontSize: fontSize,
                spacing: spacing,
                iconSize: iconSize,
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  await _loadStats();
                  await _refreshUnreadCount();
                  await _refreshProfileImage(); // ✅ Also refresh profile
                },
                child: SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.all(spacing * 1.5),
                  child: SizedBox(
                    height: gridHeight,
                    width: double.infinity,
                    child: _buildStatsGrid(
                      crossAxisCount: crossAxisCount,
                      gridSpacing: gridSpacing,
                      childAspectRatio: childAspectRatio > 0 ? childAspectRatio : 1.2,
                      iconSize: iconSize,
                      fontSize: fontSize,
                      isMobile: isMobile,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid({
    required int crossAxisCount,
    required double gridSpacing,
    required double childAspectRatio,
    required double iconSize,
    required double fontSize,
    required bool isMobile,
  }) {
    return GridView.count(
      crossAxisCount: crossAxisCount,
      crossAxisSpacing: gridSpacing,
      mainAxisSpacing: gridSpacing,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: childAspectRatio,
      children: [
        _buildStatCard(
          icon: Icons.people,
          label: 'Total Users',
          value: _stats['totalUsers']?.toString() ?? '0',
          color: const Color(0xFF173B69),
          type: 'users',
          iconSize: isMobile ? iconSize + 4 : iconSize + 10,
          fontSize: fontSize,
          isMobile: isMobile,
        ),
        _buildStatCard(
          icon: Icons.pending_actions,
          label: 'Pending',
          value: _stats['pendingRequests']?.toString() ?? '0',
          color: Colors.orange,
          type: 'pending',
          iconSize: isMobile ? iconSize + 4 : iconSize + 10,
          fontSize: fontSize,
          isMobile: isMobile,
        ),
        _buildStatCard(
          icon: Icons.today,
          label: "Today's",
          value: _stats['todayRequests']?.toString() ?? '0',
          color: Colors.blue,
          type: 'today',
          iconSize: isMobile ? iconSize + 4 : iconSize + 10,
          fontSize: fontSize,
          isMobile: isMobile,
        ),
        _buildStatCard(
          icon: Icons.assignment,
          label: 'Total',
          value: _stats['totalRequests']?.toString() ?? '0',
          color: Colors.green,
          type: 'total',
          iconSize: isMobile ? iconSize + 4 : iconSize + 10,
          fontSize: fontSize,
          isMobile: isMobile,
        ),
        _buildStatCard(
          icon: Icons.check_circle,
          label: 'Approved',
          value: _stats['approvedToday']?.toString() ?? '0',
          color: Colors.purple,
          type: 'approved',
          iconSize: isMobile ? iconSize + 4 : iconSize + 10,
          fontSize: fontSize,
          isMobile: isMobile,
        ),
        _buildStatCard(
          icon: Icons.cancel,
          label: 'Rejected',
          value: _stats['rejectedToday']?.toString() ?? '0',
          color: Colors.red,
          type: 'rejected',
          iconSize: isMobile ? iconSize + 4 : iconSize + 10,
          fontSize: fontSize,
          isMobile: isMobile,
        ),
      ],
    );
  }

  // ✅ បានបន្ថយកំពស់ card 5% ដោយប្រើ FractionallySizedBox
  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required String type,
    required double iconSize,
    required double fontSize,
    required bool isMobile,
  }) {
    return GestureDetector(
      onTap: () => _navigateToDetail(type),
      child: Container(
        padding: EdgeInsets.all(isMobile ? 6 : 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade200,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        // ✅ រុំ Column ជាមួយ FractionallySizedBox ដើម្បីបន្ថយកំពស់ 5%
        child: FractionallySizedBox(
          heightFactor: 0.95, // បន្ថយកំពស់ 5%
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: color,
                size: isMobile ? iconSize + 4 : iconSize + 10,
              ),
              SizedBox(height: isMobile ? 2 : 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: isMobile ? fontSize + 4 : fontSize + 6,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              SizedBox(height: isMobile ? 1 : 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: isMobile ? fontSize * 0.7 : fontSize + 2,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToDetail(String type) {
    if (type == 'users') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const UserManagementScreen(),
        ),
      ).then((_) {
        _loadStats();
        _refreshUnreadCount();
        _refreshProfileImage(); // ✅ Refresh profile after returning
      });
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _DetailListScreen(
          type: type,
          stats: _stats,
        ),
      ),
    ).then((_) {
      _loadStats();
      _refreshUnreadCount();
      _refreshProfileImage(); // ✅ Refresh profile after returning
    });
  }
}

// ==================== ADMIN USER HEADER ====================
class _AdminUserHeader extends StatelessWidget {
  final String adminName;
  final String? adminId;
  final String? profileImageUrl;
  final bool isLoading;
  final int unreadCount;
  final VoidCallback? onNotificationPressed;
  final VoidCallback? onProfileUpdated; // ✅ Add callback
  final bool useWhiteTheme;
  final bool isMobile;
  final double fontSize;
  final double spacing;
  final double iconSize;

  const _AdminUserHeader({
    required this.adminName,
    this.adminId,
    this.profileImageUrl,
    required this.isLoading,
    this.unreadCount = 0,
    this.onNotificationPressed,
    this.onProfileUpdated, // ✅ Add callback
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

    return Row(
      children: [
        ProfileAvatar(
          userId: adminId,
          imageUrl: profileImageUrl,
          name: adminName,
          radius: isMobile ? 28 : 42,
          backgroundColor: useWhiteTheme ? Colors.white : const Color(0xFF173B69),
          textColor: useWhiteTheme ? const Color(0xFF173B69) : Colors.white,
          onTap: () async {
            // ✅ Wait for result from Profile Screen
            final result = await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AdminProfileScreen()),
            );
            
            // ✅ If changes were made, call callback to refresh
            if (result == true && onProfileUpdated != null) {
              onProfileUpdated!();
            }
          },
        ),
        SizedBox(width: isMobile ? spacing : spacing * 1.5),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
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
                  adminName,
                  style: TextStyle(
                    color: textColor,
                    fontSize: isMobile ? fontSize + 2 : fontSize + 6,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              SizedBox(height: spacing / 3),
              Text(
                'Administrator',
                style: TextStyle(
                  color: subTextColor,
                  fontSize: isMobile ? fontSize * 0.75 : fontSize + 2,
                ),
              ),
            ],
          ),
        ),
        // ✅ Notification Bell with Badge
        Stack(
          children: [
            IconButton(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const NotificationsScreen(),
                  ),
                );
                if (onNotificationPressed != null) {
                  onNotificationPressed!();
                }
              },
              icon: Icon(
                Icons.notifications_none,
                color: iconColor,
                size: isMobile ? iconSize + 4 : iconSize + 8,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            if (unreadCount > 0)
              Positioned(
                right: 2,
                top: 2,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  constraints: BoxConstraints(
                    minWidth: isMobile ? 14 : 20,
                    minHeight: isMobile ? 14 : 20,
                  ),
                  child: Text(
                    unreadCount > 99 ? '99+' : unreadCount.toString(),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isMobile ? 8 : 11,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
        SizedBox(width: isMobile ? 4 : 8),
      ],
    );
  }
}

// ==================== DETAIL LIST SCREEN ====================
class _DetailListScreen extends StatefulWidget {
  final String type;
  final Map<String, int> stats;

  const _DetailListScreen({
    required this.type,
    required this.stats,
  });

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
          setState(() {
            _items = [];
          });
          break;
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to load data: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<Map<String, dynamic>> _getUserData(String userId) async {
    if (_userCache.containsKey(userId)) {
      return _userCache[userId]!;
    }

    try {
      final docSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      Map<String, dynamic> userData = {};
      if (docSnapshot.exists) {
        final data = docSnapshot.data()!;
        userData = {
          'fullName': data['fullName'] ?? 'Unknown',
          'email': data['email'] ?? 'N/A',
          'department': data['department'] ?? 'N/A',
          'departmentId': data['departmentId'] ?? '',
          'role': data['role'] ?? 'user',
          'roleId': data['roleId'] ?? '4',
          'phone': data['phone'] ?? 'N/A',
        };
      }

      _userCache[userId] = userData;
      return userData;
    } catch (e) {
      print('❌ Error fetching user data for $userId: $e');
      return {
        'fullName': 'Unknown',
        'email': 'N/A',
        'department': 'N/A',
        'departmentId': '',
        'role': 'user',
        'roleId': '4',
        'phone': 'N/A',
      };
    }
  }

  String _formatSubmitTimeLikeTelegram(dynamic submitTime) {
    if (submitTime == null) return 'N/A';
    
    try {
      if (submitTime is String) {
        String cleaned = submitTime.trim();
        if (cleaned.contains('AM') || cleaned.contains('PM')) {
          return cleaned;
        }
      }
      
      DateTime? parsedDateTime;
      bool isUTC = false;
      
      if (submitTime is String) {
        String cleaned = submitTime.trim();
        
        if (cleaned.contains('T') && cleaned.endsWith('Z')) {
          try {
            parsedDateTime = DateTime.parse(cleaned);
            isUTC = true;
          } catch (e) {}
        }
        else if (cleaned.contains('T')) {
          try {
            parsedDateTime = DateTime.parse(cleaned);
            isUTC = false;
          } catch (e) {}
        }
        else if (cleaned.contains(' ') && cleaned.contains('-')) {
          final parts = cleaned.split(' ');
          if (parts.length == 2) {
            final dateParts = parts[0].split('-');
            final timeParts = parts[1].split(':');
            
            if (dateParts.length == 3 && timeParts.length >= 2) {
              final year = int.parse(dateParts[0]);
              final month = int.parse(dateParts[1]);
              final day = int.parse(dateParts[2]);
              final hour = int.parse(timeParts[0]);
              final minute = int.parse(timeParts[1]);
              parsedDateTime = DateTime(year, month, day, hour, minute);
              isUTC = false;
            }
          }
        }
        else if (cleaned.contains('/') && cleaned.contains(' ')) {
          final parts = cleaned.split(' ');
          if (parts.length == 2) {
            final dateParts = parts[0].split('/');
            final timeParts = parts[1].split(':');
            
            if (dateParts.length == 3 && timeParts.length >= 2) {
              final day = int.parse(dateParts[0]);
              final month = int.parse(dateParts[1]);
              final year = int.parse(dateParts[2]);
              final hour = int.parse(timeParts[0]);
              final minute = int.parse(timeParts[1]);
              parsedDateTime = DateTime(year, month, day, hour, minute);
              isUTC = false;
            }
          }
        }
        else if (cleaned.contains('-') && !cleaned.contains(' ')) {
          final parts = cleaned.split('-');
          if (parts.length == 3) {
            final year = int.parse(parts[0]);
            final month = int.parse(parts[1]);
            final day = int.parse(parts[2]);
            parsedDateTime = DateTime(year, month, day, 0, 0);
            isUTC = false;
          }
        }
      }
      else if (submitTime is Timestamp) {
        parsedDateTime = submitTime.toDate();
        isUTC = true;
      }
      else if (submitTime is DateTime) {
        parsedDateTime = submitTime;
        isUTC = submitTime.isUtc;
      }
      
      if (parsedDateTime == null) {
        return submitTime.toString();
      }
      
      DateTime cambodiaTime;
      if (isUTC) {
        cambodiaTime = parsedDateTime.toUtc().add(const Duration(hours: 7));
      } else {
        cambodiaTime = parsedDateTime;
      }
      
      final year = cambodiaTime.year;
      final month = cambodiaTime.month.toString().padLeft(2, '0');
      final day = cambodiaTime.day.toString().padLeft(2, '0');
      int hour = cambodiaTime.hour;
      final int minute = cambodiaTime.minute;
      final String period = hour >= 12 ? 'PM' : 'AM';
      
      if (hour == 0) {
        hour = 12;
      } else if (hour > 12) {
        hour = hour - 12;
      }
      
      return '$year-$month-$day $hour:${minute.toString().padLeft(2, '0')}$period';
      
    } catch (e) {
      print('❌ Error formatting submitTime: $e');
      return 'N/A';
    }
  }

  Future<void> _loadRequests({String? status}) async {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('leave_requests');

    if (status != null) {
      query = query.where('status', isEqualTo: status);
    }

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
        'userName': data['userName'] ?? 'Unknown',
        'reason': data['reason'] ?? 'No reason',
        'status': data['status'] ?? 'pending',
        'startDate': data['startDate'],
        'endDate': data['endDate'],
        'createdAt': data['createdAt'],
        'submitTime': data['submitTime'],
        'fullName': userData['fullName'] ?? data['userName'] ?? 'Unknown',
        'email': userData['email'] ?? 'N/A',
        'department': userData['department'] ?? 'N/A',
        'departmentId': userData['departmentId'] ?? '',
        'role': userData['role'] ?? 'user',
        'roleId': userData['roleId'] ?? '4',
        'phone': userData['phone'] ?? 'N/A',
      });
    }

    setState(() {
      _items = items;
    });
  }

  Future<void> _loadTodayRequests({String? status}) async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day, 0, 0, 0);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('leave_requests')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay));

    if (status != null) {
      query = query.where('status', isEqualTo: status);
    }

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
        'userName': data['userName'] ?? 'Unknown',
        'reason': data['reason'] ?? 'No reason',
        'status': data['status'] ?? 'pending',
        'startDate': data['startDate'],
        'endDate': data['endDate'],
        'createdAt': data['createdAt'],
        'submitTime': data['submitTime'],
        'fullName': userData['fullName'] ?? data['userName'] ?? 'Unknown',
        'email': userData['email'] ?? 'N/A',
        'department': userData['department'] ?? 'N/A',
        'departmentId': userData['departmentId'] ?? '',
        'role': userData['role'] ?? 'user',
        'roleId': userData['roleId'] ?? '4',
        'phone': userData['phone'] ?? 'N/A',
      });
    }

    setState(() {
      _items = items;
    });
  }

  String _getTitle() {
    switch (widget.type) {
      case 'pending':
        return 'Pending Requests (${widget.stats['pendingRequests'] ?? 0})';
      case 'today':
        return "Today's Requests (${widget.stats['todayRequests'] ?? 0})";
      case 'total':
        return 'Total Requests (${widget.stats['totalRequests'] ?? 0})';
      case 'approved':
        return 'Approved Today (${widget.stats['approvedToday'] ?? 0})';
      case 'rejected':
        return 'Rejected Today (${widget.stats['rejectedToday'] ?? 0})';
      default:
        return 'Details';
    }
  }

  Color _getColor() {
    switch (widget.type) {
      case 'pending':
        return Colors.orange;
      case 'today':
        return Colors.blue;
      case 'total':
        return Colors.green;
      case 'approved':
        return Colors.purple;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  IconData _getIcon() {
    switch (widget.type) {
      case 'pending':
        return Icons.pending_actions;
      case 'today':
        return Icons.today;
      case 'total':
        return Icons.assignment;
      case 'approved':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      default:
        return Icons.info;
    }
  }

  String _formatDate(dynamic timestamp) {
    try {
      if (timestamp == null) return 'N/A';
      if (timestamp is Timestamp) {
        return '${timestamp.toDate().day}/${timestamp.toDate().month}/${timestamp.toDate().year}';
      }
      return 'N/A';
    } catch (e) {
      return 'N/A';
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'pending':
      default:
        return Colors.orange;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      case 'pending':
      default:
        return Icons.pending;
    }
  }

  Color _getRoleColor(String role) {
    final roleLower = role.toLowerCase();
    switch (roleLower) {
      case 'admin':
        return Colors.purple;
      case 'manager':
        return Colors.orange;
      case 'staff':
        return Colors.green;
      case 'employee':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _getRoleName(String role) {
    final roleLower = role.toLowerCase();
    switch (roleLower) {
      case 'admin':
        return 'Admin';
      case 'manager':
        return 'Manager';
      case 'staff':
        return 'Staff';
      case 'employee':
        return 'Employee';
      default:
        return role;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = Responsive.isMobile(context);
    final double fontSize = Responsive.fontSize(context, 14);
    final double spacing = Responsive.spacing(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _getTitle(),
          style: TextStyle(
            fontSize: isMobile ? 16 : 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: _getColor(),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
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
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: fontSize),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _loadData,
                        child: Text(
                          'Retry',
                          style: TextStyle(fontSize: fontSize),
                        ),
                      ),
                    ],
                  ),
                )
              : _items.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(_getIcon(), size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            'No Data',
                            style: TextStyle(
                              fontSize: fontSize,
                              color: Colors.grey[600],
                            ),
                          ),
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
    final String submitTimeDisplay = _formatSubmitTimeLikeTelegram(item['submitTime']);

    return Card(
      margin: EdgeInsets.symmetric(horizontal: spacing / 2, vertical: spacing / 2),
      elevation: 2,
      child: ListTile(
        contentPadding: EdgeInsets.all(isMobile ? 10 : 16),
        leading: CircleAvatar(
          radius: isMobile ? 18 : 24,
          backgroundColor: _getStatusColor(item['status'] ?? 'pending').withOpacity(0.2),
          child: Icon(
            _getStatusIcon(item['status'] ?? 'pending'),
            color: _getStatusColor(item['status'] ?? 'pending'),
            size: isMobile ? 16 : 20,
          ),
        ),
        title: Text(
          item['fullName'] ?? item['userName'] ?? 'Unknown User',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: isMobile ? fontSize : fontSize + 2,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (item['department'] != null && item['department'] != 'N/A')
              Row(
                children: [
                  Icon(Icons.business, size: isMobile ? 12 : 14, color: Colors.grey[600]),
                  SizedBox(width: spacing / 3),
                  Expanded(
                    child: Text(
                      item['department'],
                      style: TextStyle(
                        fontSize: isMobile ? fontSize * 0.8 : fontSize,
                        color: Colors.grey[700],
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            Text(
              'Reason: ${item['reason'] ?? 'No reason'}',
              style: TextStyle(
                fontSize: isMobile ? fontSize * 0.85 : fontSize,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '${_formatDate(item['startDate'])} - ${_formatDate(item['endDate'])}',
              style: TextStyle(
                fontSize: isMobile ? fontSize * 0.8 : fontSize,
                color: Colors.grey[600],
              ),
            ),
            Text(
              'Submitted: $submitTimeDisplay',
              style: TextStyle(
                fontSize: isMobile ? fontSize * 0.8 : fontSize,
                color: Colors.blue[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 6 : 12,
                vertical: isMobile ? 2 : 4,
              ),
              decoration: BoxDecoration(
                color: _getStatusColor(item['status'] ?? 'pending'),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                item['status']?.toString().toUpperCase() ?? 'PENDING',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isMobile ? fontSize * 0.7 : fontSize,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SizedBox(height: spacing / 3),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 4 : 8,
                vertical: isMobile ? 1 : 4,
              ),
              decoration: BoxDecoration(
                color: _getRoleColor(item['role'] ?? 'user').withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _getRoleColor(item['role'] ?? 'user'),
                  width: 1,
                ),
              ),
              child: Text(
                _getRoleName(item['role'] ?? 'user'),
                style: TextStyle(
                  color: _getRoleColor(item['role'] ?? 'user'),
                  fontSize: isMobile ? fontSize * 0.65 : fontSize,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        isThreeLine: true,
        dense: isMobile,
      ),
    );
  }
}