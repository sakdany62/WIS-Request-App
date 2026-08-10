
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
      final querySnapshot = await FirebaseFirestore.instance
          .collection('leave_requests')
          .where('userId', isEqualTo: widget.userId)
          .orderBy('createdAt', descending: true)
          .get();

      List<Map<String, dynamic>> requests = [];

      for (var doc in querySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
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
    
    double fontSize = isSmallScreen ? 12 : (isTablet ? 18 : 14);
    double padding = isSmallScreen ? 12 : (isTablet ? 24 : 16);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: Text(
          widget.title,
          style: TextStyle(
            fontSize: isSmallScreen ? fontSize + 2 : (isTablet ? fontSize + 6 : fontSize + 4),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF173B69),
        foregroundColor: Colors.white,
        elevation: 0,
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
                          fontSize: isSmallScreen ? fontSize : (isTablet ? fontSize + 4 : fontSize + 2),
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.all(padding),
                  itemCount: leaveRequests.length,
                  itemBuilder: (context, index) {
                    final request = leaveRequests[index];
                    return _StatDetailCard(
                      request: request,
                      isSmallScreen: isSmallScreen,
                      isTablet: isTablet,
                      fontSize: fontSize,
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
  final double fontSize;

  const _StatDetailCard({
    required this.request,
    required this.isSmallScreen,
    required this.isTablet,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    double padding = isSmallScreen ? 12 : (isTablet ? 20 : 16);
    double borderRadius = isSmallScreen ? 8 : (isTablet ? 16 : 12);
    
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

    return Container(
      margin: EdgeInsets.only(bottom: isSmallScreen ? 8 : (isTablet ? 16 : 12)),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  request['reason'],
                  style: TextStyle(
                    fontSize: isSmallScreen ? fontSize * 0.9 : (isTablet ? fontSize + 2 : fontSize),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 6 : (isTablet ? 12 : 8),
                  vertical: isSmallScreen ? 2 : (isTablet ? 6 : 4),
                ),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(isSmallScreen ? 8 : (isTablet ? 14 : 10)),
                ),
                child: Text(
                  request['status'],
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: isSmallScreen ? fontSize * 0.7 : (isTablet ? fontSize + 2 : fontSize * 0.85),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: isSmallScreen ? 6 : (isTablet ? 12 : 8)),
          Row(
            children: [
              Icon(
                Icons.calendar_today,
                size: isSmallScreen ? 12 : (isTablet ? 20 : 16),
                color: Colors.grey.shade600,
              ),
              SizedBox(width: isSmallScreen ? 4 : (isTablet ? 8 : 6)),
              Text(
                '${request['startDate']} - ${request['endDate']}',
                style: TextStyle(
                  fontSize: isSmallScreen ? fontSize * 0.75 : (isTablet ? fontSize + 2 : fontSize * 0.9),
                  color: Colors.grey.shade700,
                ),
              ),
              const Spacer(),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 6 : (isTablet ? 12 : 8),
                  vertical: isSmallScreen ? 2 : (isTablet ? 6 : 4),
                ),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(isSmallScreen ? 6 : (isTablet ? 12 : 8)),
                ),
                child: Text(
                  '${request['totalDays']} days',
                  style: TextStyle(
                    color: Colors.blue.shade700,
                    fontWeight: FontWeight.w600,
                    fontSize: isSmallScreen ? fontSize * 0.7 : (isTablet ? fontSize + 2 : fontSize * 0.85),
                  ),
                ),
              ),
            ],
          ),
          if (request['isAutoApproved'] == true) ...[
            SizedBox(height: isSmallScreen ? 4 : (isTablet ? 8 : 6)),
            Row(
              children: [
                Icon(
                  Icons.autorenew,
                  size: isSmallScreen ? 12 : (isTablet ? 20 : 16),
                  color: Colors.purple.shade400,
                ),
                SizedBox(width: isSmallScreen ? 4 : (isTablet ? 8 : 6)),
                Text(
                  'Auto Approved',
                  style: TextStyle(
                    color: Colors.purple.shade400,
                    fontWeight: FontWeight.w500,
                    fontSize: isSmallScreen ? fontSize * 0.7 : (isTablet ? fontSize + 2 : fontSize * 0.85),
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