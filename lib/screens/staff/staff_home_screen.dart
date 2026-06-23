// lib/screens/staff/staff_home_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';

class StaffHomeScreen extends StatefulWidget {
  const StaffHomeScreen({super.key});

  @override
  State<StaffHomeScreen> createState() => _StaffHomeScreenState();
}

class _StaffHomeScreenState extends State<StaffHomeScreen> {
  String userName = 'Staff User';
  bool isLoading = true;
  List<Map<String, dynamic>> leaveStatusList = [];
  Map<String, int> leaveStats = {
    'total': 24,
    'used': 0,
    'remaining': 24,
    'pending': 0,
    'approved': 0,
    'rejected': 0,
    'autoApproved': 0,
  };

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadLeaveStatus();
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
          setState(() {
            userName = data['fullName'] ?? data['username'] ?? 'Staff User';
            isLoading = false;
          });
        } else {
          setState(() {
            userName = user.email?.split('@').first ?? 'Staff User';
            isLoading = false;
          });
        }
      } catch (e) {
        print('Error loading user name: $e');
        setState(() {
          isLoading = false;
        });
      }
    } else {
      setState(() {
        isLoading = false;
      });
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

      setState(() {
        leaveStatusList = requests;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadLeaveStatus();
          await _loadUserData();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              _HeaderSection(
                userName: userName, 
                isLoading: isLoading,
                leaveStats: leaveStats,
              ),
              const SizedBox(height: 20),
              _LeaveStatusSection(leaveStatusList: leaveStatusList),
            ],
          ),
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

  const _HeaderSection({
    required this.userName, 
    required this.isLoading,
    required this.leaveStats,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFF173B69),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _UserHeader(userName: userName, isLoading: isLoading),
          const SizedBox(height: 20),
          const Text(
            'Your Leave Balance',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _BalanceCard(
                count: '${leaveStats['used'] ?? 0}',
                type: 'USED',
                total: '/${leaveStats['total'] ?? 24}',
              ),
              const SizedBox(width: 12),
              _BalanceCard(
                count: '${leaveStats['remaining'] ?? 0}',
                type: 'REMAINING',
                total: '/${leaveStats['total'] ?? 24}',
              ),
              const SizedBox(width: 12),
              _BalanceCard(
                count: '${leaveStats['autoApproved'] ?? 0}',
                type: 'AUTO-APPROVED',
                total: '',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _BalanceCardSmall(
                count: '${leaveStats['pending'] ?? 0}',
                type: 'PENDING',
              ),
              const SizedBox(width: 8),
              _BalanceCardSmall(
                count: '${leaveStats['approved'] ?? 0}',
                type: 'APPROVED',
              ),
              const SizedBox(width: 8),
              _BalanceCardSmall(
                count: '${leaveStats['rejected'] ?? 0}',
                type: 'REJECTED',
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

  const _BalanceCard({
    required this.count,
    required this.type,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              count,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              type,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 10,
              ),
            ),
            if (total.isNotEmpty)
              Text(
                total,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 10,
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

  const _BalanceCardSmall({
    required this.count,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              count,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              type,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserHeader extends StatelessWidget {
  final String userName;
  final bool isLoading;

  const _UserHeader({required this.userName, required this.isLoading});

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
            backgroundColor: Colors.white24,
            child: Icon(Icons.person, size: 40, color: Colors.white),
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
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              else
                Text(
                  userName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              const SizedBox(height: 4),
              const Text(
                'Staff',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const NotificationsScreen()),
          ),
          icon: const Icon(Icons.notifications_none, color: Colors.white, size: 28),
        ),
      ],
    );
  }
}

// ================= LEAVE STATUS SECTION =================
class _LeaveStatusSection extends StatelessWidget {
  final List<Map<String, dynamic>> leaveStatusList;

  const _LeaveStatusSection({required this.leaveStatusList});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Center(
            child: Text(
              'Leave Status',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 16),
          if (leaveStatusList.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'No leave requests yet',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            ...leaveStatusList.map((request) => LeaveStatusCard(
              month: request['month'],
              date: request['date'],
              title: request['title'],
              status: request['status'],
              statusColor: request['statusColor'],
            )),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: () {
                // Navigate to full history
              },
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF173B69),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text(
                'See More',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
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

  const LeaveStatusCard({
    super.key,
    required this.month,
    required this.date,
    required this.title,
    required this.status,
    required this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF173B69).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Text(
                  month,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFF173B69),
                  ),
                ),
                Text(
                  date,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF173B69),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              status,
              style: TextStyle(
                color: statusColor,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}