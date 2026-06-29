// lib/screens/admin/admin_home_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../app_fonts.dart'; 
import '../../services/request_service.dart';
import '../../services/user_service.dart';
import '../staff/notifications_screen.dart';
import '../staff/profile_screen.dart';
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
                    fontSize: AppFonts.md, // ✅
                    fontWeight: FontWeight.bold,
                    color: Colors.red[700],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: AppFonts.md), // ✅
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
          type: 'users',
        ),
        _buildStatCard(
          icon: Icons.pending_actions,
          label: 'Pending Requests',
          value: _stats['pendingRequests']?.toString() ?? '0',
          color: Colors.orange,
          type: 'pending',
        ),
        _buildStatCard(
          icon: Icons.today,
          label: "Today's Requests",
          value: _stats['todayRequests']?.toString() ?? '0',
          color: Colors.blue,
          type: 'today',
        ),
        _buildStatCard(
          icon: Icons.assignment,
          label: 'Total Requests',
          value: _stats['totalRequests']?.toString() ?? '0',
          color: Colors.green,
          type: 'total',
        ),
        _buildStatCard(
          icon: Icons.check_circle,
          label: 'Approved Today',
          value: _stats['approvedToday']?.toString() ?? '0',
          color: Colors.purple,
          type: 'approved',
        ),
        _buildStatCard(
          icon: Icons.cancel,
          label: 'Rejected Today',
          value: _stats['rejectedToday']?.toString() ?? '0',
          color: Colors.red,
          type: 'rejected',
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required String type,
  }) {
    return GestureDetector(
      onTap: () => _navigateToDetail(type),
      child: Container(
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
                fontSize: AppFonts.md, // ✅
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: AppFonts.md, // ✅
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
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
        MaterialPageRoute(
          builder: (context) => const UserManagementScreen(),
        ),
      ).then((_) {
        _loadStats();
        _refreshUnreadCount();
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
    });
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
                    fontSize: AppFonts.md, // ✅
                    fontWeight: FontWeight.bold,
                  ),
                ),
              const SizedBox(height: 4),
              const Text(
                'Administrator',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: AppFonts.md, // ✅
                ),
              ),
            ],
          ),
        ),
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
              icon: const Icon(
                Icons.notifications_none,
                color: Color(0xFF173B69),
                size: 28,
              ),
            ),
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
                      fontSize: AppFonts.md, // ✅
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
  
  // Cache for user data to avoid multiple Firestore calls
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

  // Function to get user data
  Future<Map<String, dynamic>> _getUserData(String userId) async {
    if (_userCache.containsKey(userId)) {
      return _userCache[userId]!;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();

      Map<String, dynamic> userData = {};
      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data() as Map<String, dynamic>;
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
      
      // Get user data with department
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
        // Add user details
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
      
      // Get user data with department
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
        // Add user details
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
      case 'pending': return Colors.orange;
      case 'today': return Colors.blue;
      case 'total': return Colors.green;
      case 'approved': return Colors.purple;
      case 'rejected': return Colors.red;
      default: return Colors.blue;
    }
  }

  IconData _getIcon() {
    switch (widget.type) {
      case 'pending': return Icons.pending_actions;
      case 'today': return Icons.today;
      case 'total': return Icons.assignment;
      case 'approved': return Icons.check_circle;
      case 'rejected': return Icons.cancel;
      default: return Icons.info;
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

  String _formatDateTime(dynamic timestamp) {
    try {
      if (timestamp == null) return 'N/A';
      if (timestamp is Timestamp) {
        final date = timestamp.toDate();
        return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
      }
      return 'N/A';
    } catch (e) {
      return 'N/A';
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved': return Colors.green;
      case 'rejected': return Colors.red;
      case 'pending':
      default: return Colors.orange;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'approved': return Icons.check_circle;
      case 'rejected': return Icons.cancel;
      case 'pending':
      default: return Icons.pending;
    }
  }

  // ============ ROLE HELPER METHODS ============
  Color _getRoleColor(String role) {
    final roleLower = role.toLowerCase();
    switch (roleLower) {
      case 'admin': return Colors.purple;
      case 'manager': return Colors.orange;
      case 'staff': return Colors.green;
      case 'employee': return Colors.blue;
      default: return Colors.grey;
    }
  }

  String _getRoleName(String role) {
    final roleLower = role.toLowerCase();
    switch (roleLower) {
      case 'admin': return 'Admin';           // ✅ was អ្នកគ្រប់គ្រងប្រព័ន្ធ
      case 'manager': return 'Manager';       // ✅ was អ្នកគ្រប់គ្រង
      case 'staff': return 'Staff';           // ✅ was បុគ្គលិក
      case 'employee': return 'Employee';     // ✅ was បុគ្គលិក
      default: return role;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _getTitle(),
          style: const TextStyle(fontSize: AppFonts.md), // ✅
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
                        style: const TextStyle(fontSize: AppFonts.md), // ✅
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _loadData,
                        child: const Text('Retry'),
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
                            'No Data', // ✅ was គ្មានទិន្នន័យ
                            style: TextStyle(
                              fontSize: AppFonts.md, // ✅
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: _items.length,
                      itemBuilder: (context, index) {
                        final item = _items[index];
                        return _buildItemCard(item);
                      },
                    ),
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: 2,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getStatusColor(item['status'] ?? 'pending').withOpacity(0.2),
          child: Icon(
            _getStatusIcon(item['status'] ?? 'pending'),
            color: _getStatusColor(item['status'] ?? 'pending'),
            size: 20,
          ),
        ),
        title: Text(
          item['fullName'] ?? item['userName'] ?? 'Unknown User',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: AppFonts.md, // ✅
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Show Department
            if (item['department'] != null && item['department'] != 'N/A')
              Row(
                children: [
                  Icon(Icons.business, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    'Department: ${item['department']}',
                    style: TextStyle(fontSize: AppFonts.md, color: Colors.grey[700]), // ✅
                  ),
                ],
              ),
            Text(
              'Reason: ${item['reason'] ?? 'No reason'}',
              style: const TextStyle(fontSize: AppFonts.md), // ✅
            ),
            Text(
              '${_formatDate(item['startDate'])} - ${_formatDate(item['endDate'])}',
              style: TextStyle(fontSize: AppFonts.md, color: Colors.grey[600]), // ✅
            ),
            Text(
              'Requested: ${_formatDateTime(item['createdAt'])}',
              style: TextStyle(fontSize: AppFonts.md, color: Colors.grey[500]), // ✅
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Status badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: _getStatusColor(item['status'] ?? 'pending'),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                item['status']?.toString().toUpperCase() ?? 'PENDING',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: AppFonts.md, // ✅
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            // Role badge
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                  fontSize: AppFonts.md, // ✅
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        isThreeLine: true,
        onTap: () => _showRequestDetail(item),
      ),
    );
  }

  void _showRequestDetail(Map<String, dynamic> request) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              _getStatusIcon(request['status'] ?? 'pending'),
              color: _getStatusColor(request['status'] ?? 'pending'),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Request Detail',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: AppFonts.md, // ✅
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Divider(),
              // User Information Section
              _buildSectionHeader('👤 User Information'),
              _buildDetailRow('Full Name', request['fullName'] ?? request['userName'] ?? 'N/A'),
              _buildDetailRow('Email', request['email'] ?? 'N/A'),
              _buildDetailRow('Phone', request['phone'] ?? 'N/A'),
              _buildDetailRow('Role', _getRoleName(request['role'] ?? 'user')),
              _buildDetailRow('Department', request['department'] ?? 'N/A'),
              
              const SizedBox(height: 12),
              _buildSectionHeader('📋 Request Information'),
              _buildDetailRow('Status', request['status']?.toString().toUpperCase() ?? 'PENDING'),
              _buildDetailRow('Reason', request['reason'] ?? 'No reason'),
              _buildDetailRow('Start Date', _formatDate(request['startDate'])),
              _buildDetailRow('End Date', _formatDate(request['endDate'])),
              _buildDetailRow('Requested', _formatDateTime(request['createdAt'])),
              
              const SizedBox(height: 12),
              _buildSectionHeader('🔑 System Information'),
              _buildDetailRow('User ID', request['userId'] ?? 'N/A'),
              _buildDetailRow('Request ID', request['id'] ?? 'N/A'),
              _buildDetailRow('Department ID', request['departmentId'] ?? 'N/A'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: AppFonts.md, // ✅
          color: Colors.grey[700],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
                fontSize: AppFonts.md, // ✅
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: AppFonts.md), // ✅
            ),
          ),
        ],
      ),
    );
  }
}