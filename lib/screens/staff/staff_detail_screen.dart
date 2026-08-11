import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StatDetailScreen extends StatefulWidget {
  final String title;
  final String statType;
  final String userId;

  const StatDetailScreen({
    super.key,
    required this.title,
    required this.statType,
    required this.userId,
  });

  @override
  State<StatDetailScreen> createState() => _StatDetailScreenState();
}

class _StatDetailScreenState extends State<StatDetailScreen> {
  List<Map<String, dynamic>> leaveRequests = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLeaveRequests();
  }

  Future<void> _loadLeaveRequests() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final querySnapshot = await FirebaseFirestore.instance
          .collection('leave_requests')
          .where('userId', isEqualTo: widget.userId)
          .orderBy('createdAt', descending: true)
          .get();

      List<Map<String, dynamic>> requests = [];

      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        final status = data['status'] ?? 'pending';
        final isAutoApproved = data['autoApproved'] ?? false;

        bool shouldInclude = false;
        switch (widget.statType) {
          case 'total':
            shouldInclude = true;
            break;
          case 'used':
            shouldInclude = status == 'approved';
            break;
          case 'remaining':
            shouldInclude = false;
            break;
          case 'pending':
            shouldInclude = status == 'pending';
            break;
          case 'approved':
            shouldInclude = status == 'approved' && !isAutoApproved;
            break;
          case 'rejected':
            shouldInclude = status == 'rejected';
            break;
          case 'autoApproved':
            shouldInclude = status == 'approved' && isAutoApproved;
            break;
        }

        if (shouldInclude) {
          requests.add({
            'id': doc.id,
            'reason': data['reason'] ?? 'Leave Request',
            'startDate': data['startDate'] ?? 'N/A',
            'endDate': data['endDate'] ?? 'N/A',
            'status': status.toUpperCase(),
            'totalDays': (data['totalDays'] as num?)?.toInt() ?? 0,
            'createdAt': data['createdAt'],
            'isAutoApproved': isAutoApproved,
          });
        }
      }

      setState(() {
        leaveRequests = requests;
        isLoading = false;
      });
    } catch (e) {
      print('Error loading leave requests: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final isTablet = screenWidth >= 600;

    double padding = isSmallScreen ? 10 : (isTablet ? 20 : 14);
    double appBarHeight = isSmallScreen ? 50 : (isTablet ? 70 : 56);
    double titleSize = isSmallScreen ? 16 : (isTablet ? 24 : 20);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(appBarHeight),
        child: AppBar(
          title: Text(
            widget.title,
            style: TextStyle(
              fontSize: titleSize,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: const Color(0xFF173B69),
          foregroundColor: Colors.white,
          elevation: 0,
          toolbarHeight: appBarHeight,
          centerTitle: false,
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : leaveRequests.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: isSmallScreen ? 48 : (isTablet ? 80 : 64),
                        color: Colors.grey.shade400,
                      ),
                      SizedBox(height: isSmallScreen ? 12 : (isTablet ? 24 : 16)),
                      Text(
                        'No ${widget.statType} leave requests',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 14 : (isTablet ? 20 : 16),
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.symmetric(
                    horizontal: padding,
                    vertical: padding,
                  ),
                  itemCount: leaveRequests.length,
                  itemBuilder: (context, index) {
                    final request = leaveRequests[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _StatDetailCard(
                        request: request,
                        isSmallScreen: isSmallScreen,
                        isTablet: isTablet,
                      ),
                    );
                  },
                ),
    );
  }
}

class _StatDetailCard extends StatelessWidget {
  final Map<String, dynamic> request;
  final bool isSmallScreen;
  final bool isTablet;

  const _StatDetailCard({
    required this.request,
    required this.isSmallScreen,
    required this.isTablet,
  });

  @override
  Widget build(BuildContext context) {
    double cardPadding = isSmallScreen ? 14 : (isTablet ? 22 : 18);
    double borderRadius = isSmallScreen ? 10 : (isTablet ? 16 : 12);
    double iconSize = isSmallScreen ? 14 : (isTablet ? 20 : 16);
    double spacing = isSmallScreen ? 10 : (isTablet ? 16 : 12);

    Color statusColor;
    switch (request['status'].toString().toLowerCase()) {
      case 'approved':
        statusColor = Colors.green;
        break;
      case 'rejected':
        statusColor = Colors.red;
        break;
      case 'pending':
        statusColor = Colors.orange;
        break;
      default:
        statusColor = Colors.grey;
    }

    // Responsive text sizes
    double titleSize = isSmallScreen ? 14 : (isTablet ? 19 : 16);
    double statusSize = isSmallScreen ? 10 : (isTablet ? 15 : 12);
    double dateSize = isSmallScreen ? 12 : (isTablet ? 17 : 14);
    double daysSize = isSmallScreen ? 12 : (isTablet ? 17 : 14);

    return Container(
      padding: EdgeInsets.all(cardPadding),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Title and Status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  request['reason'],
                  style: TextStyle(
                    fontSize: titleSize,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 10 : (isTablet ? 16 : 12),
                  vertical: isSmallScreen ? 4 : (isTablet ? 8 : 6),
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(isSmallScreen ? 8 : (isTablet ? 14 : 10)),
                ),
                child: Text(
                  request['status'],
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: statusSize,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Row 2: Date and Days
          Row(
            children: [
              Icon(
                Icons.calendar_today,
                size: iconSize,
                color: Colors.grey.shade600,
              ),
              const SizedBox(width: 8),
              Text(
                '${request['startDate']} - ${request['endDate']}',
                style: TextStyle(
                  fontSize: dateSize,
                  color: Colors.grey.shade700,
                ),
              ),
              const Spacer(),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 8 : (isTablet ? 14 : 10),
                  vertical: isSmallScreen ? 4 : (isTablet ? 8 : 6),
                ),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(isSmallScreen ? 8 : (isTablet ? 14 : 10)),
                ),
                child: Text(
                  '${request['totalDays']} days',
                  style: TextStyle(
                    color: Colors.blue.shade700,
                    fontWeight: FontWeight.w600,
                    fontSize: daysSize,
                  ),
                ),
              ),
            ],
          ),
          
          // Auto Approved badge
          if (request['isAutoApproved'] == true) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  Icons.autorenew,
                  size: iconSize,
                  color: Colors.purple.shade400,
                ),
                const SizedBox(width: 8),
                Text(
                  'Auto Approved',
                  style: TextStyle(
                    color: Colors.purple.shade400,
                    fontWeight: FontWeight.w500,
                    fontSize: dateSize,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}