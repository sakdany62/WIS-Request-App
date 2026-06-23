// lib/screens/admin/admin_home_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/request_service.dart';
import '../../services/user_service.dart';
import '../staff/notifications_screen.dart';
import '../staff/profile_screen.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  final RequestService _requestService = RequestService();
  final UserService _userService = UserService();
  String adminName = 'Admin User';
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
  
  // ============ អថេរសម្រាប់ Notification ============
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

  // ============ Stream Notification ============
  void _loadNotificationStream() {
    if (adminId.isNotEmpty) {
      _notificationStream = FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: adminId)
          .where('isRead', isEqualTo: false)
          .snapshots();
      
      // ស្តាប់ការផ្លាស់ប្តូរចំនួនសារមិនទាន់អាន
      _notificationStream?.listen((snapshot) {
        if (mounted) {
          setState(() {
            _unreadCount = snapshot.docs.length;
          });
          print('📬 Unread notifications: $_unreadCount');
        }
      });
    }
  }

  // ============ Refresh Unread Count ============
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

  Future<void> _loadAdminData() async {
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
          if (mounted) {
            setState(() {
              adminName = data['fullName'] ?? data['username'] ?? 'Admin User';
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
      // ==================== TOTAL USERS ====================
      final userStats = await _userService.getUserStats();
      _totalUsers = userStats['total'] ?? 0;
      
      // ==================== PENDING REQUESTS ====================
      try {
        final pendingSnapshot = await FirebaseFirestore.instance
            .collection('leave_requests')
            .where('status', isEqualTo: 'pending')
            .get();
        _pendingRequests = pendingSnapshot.docs.length;
      } catch (e) {
        print('⚠️ Error loading pending requests: $e');
        _pendingRequests = 0;
      }
      
      // ==================== TOTAL REQUESTS ====================
      try {
        final totalSnapshot = await FirebaseFirestore.instance
            .collection('leave_requests')
            .get();
        _totalRequests = totalSnapshot.docs.length;
      } catch (e) {
        print('⚠️ Error loading total requests: $e');
        _totalRequests = 0;
      }
      
      // ==================== TODAY'S REQUESTS ====================
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
        print('⚠️ Error loading today requests: $e');
        _todayRequests = 0;
      }
      
      // ==================== APPROVED TODAY ====================
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
        print('⚠️ Error loading approved today: $e');
        _approvedToday = 0;
      }
      
      // ==================== REJECTED TODAY ====================
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
        print('⚠️ Error loading rejected today: $e');
        _rejectedToday = 0;
      }
      
      print('✅ Stats loaded: Users: $_totalUsers, Pending: $_pendingRequests, Today: $_todayRequests, Total: $_totalRequests');
      
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
      print('❌ Error loading stats: $e');
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
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.red[700],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
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
                  child: const Text('Retry'),
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
        child: RefreshIndicator(
          onRefresh: () async {
            await _loadStats();
            await _refreshUnreadCount();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _AdminUserHeader(
                  adminName: adminName, 
                  isLoading: isLoading,
                  unreadCount: _unreadCount,
                  onNotificationPressed: _refreshUnreadCount,
                ),
                const SizedBox(height: 24),
                
                // ==================== STATS GRID ====================
                _buildStatsGrid(),
                
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsGrid() {
    return GridView.count(
      crossAxisCount: 3,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.1,
      children: [
        _buildStatCard(
          icon: Icons.people,
          label: 'Total Users',
          value: _stats['totalUsers']?.toString() ?? '0',
          color: const Color(0xFF173B69),
        ),
        _buildStatCard(
          icon: Icons.pending_actions,
          label: 'Pending Requests',
          value: _stats['pendingRequests']?.toString() ?? '0',
          color: Colors.orange,
        ),
        _buildStatCard(
          icon: Icons.today,
          label: "Today's Requests",
          value: _stats['todayRequests']?.toString() ?? '0',
          color: Colors.blue,
        ),
        _buildStatCard(
          icon: Icons.assignment,
          label: 'Total Requests',
          value: _stats['totalRequests']?.toString() ?? '0',
          color: Colors.green,
        ),
        _buildStatCard(
          icon: Icons.check_circle,
          label: 'Approved Today',
          value: _stats['approvedToday']?.toString() ?? '0',
          color: Colors.purple,
        ),
        _buildStatCard(
          icon: Icons.cancel,
          label: 'Rejected Today',
          value: _stats['rejectedToday']?.toString() ?? '0',
          color: Colors.red,
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ==================== ADMIN USER HEADER ====================
class _AdminUserHeader extends StatelessWidget {
  final String adminName;
  final bool isLoading;
  final int unreadCount;
  final VoidCallback? onNotificationPressed;

  const _AdminUserHeader({
    required this.adminName, 
    required this.isLoading,
    this.unreadCount = 0,
    this.onNotificationPressed,
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
          child: const CircleAvatar(
            radius: 40,
            backgroundColor: Color(0xFF173B69),
            child: Icon(Icons.admin_panel_settings, size: 40, color: Colors.white),
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
                    color: Color(0xFF173B69),
                  ),
                )
              else
                Text(
                  adminName,
                  style: const TextStyle(
                    color: Color(0xFF173B69),
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              const SizedBox(height: 4),
              const Text(
                'Administrator',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ],
          ),
        ),
        // ============ NOTIFICATION ICON WITH BADGE ============
        Stack(
          children: [
            IconButton(
              onPressed: () async {
                // ចូលទៅកាន់ Notifications Screen
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const NotificationsScreen(),
                  ),
                );
                
                // ពេលត្រឡប់មកវិញ ធ្វើបច្ចុប្បន្នភាពចំនួន
                if (onNotificationPressed != null) {
                  onNotificationPressed!();
                }
              },
              icon: const Icon(
                Icons.notifications_none,
                color: Color(0xFF173B69),
                size: 28,
              ),
            ),
            // ============ BADGE ============
            if (unreadCount > 0)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  child: Text(
                    unreadCount > 99 ? '99+' : unreadCount.toString(),
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
        ),
      ],
    );
  }
}