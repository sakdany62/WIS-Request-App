// lib/screens/admin/terms_read_tracking_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/terms_service.dart';
import '../../app_fonts.dart';
import '../../utils/responsive.dart';

class TermsReadTrackingScreen extends StatefulWidget {
  final String termsId;
  final String termsTitle;

  const TermsReadTrackingScreen({
    super.key,
    required this.termsId,
    required this.termsTitle,
  });

  @override
  State<TermsReadTrackingScreen> createState() =>
      _TermsReadTrackingScreenState();
}

class _TermsReadTrackingScreenState extends State<TermsReadTrackingScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  Map<String, dynamic>? _stats;
  String? _errorMessage;
  String _selectedTab = 'all';
  late TabController _tabController;

  // ✅ Multiple real-time listeners
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _readStatusSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _usersSubscription;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadStats();
    
    // ✅ Listen to terms_read_status changes
    _readStatusSubscription = FirebaseFirestore.instance
        .collection('terms_read_status')
        .where('termsId', isEqualTo: widget.termsId)
        .snapshots()
        .listen((event) {
          _loadStats();
        });
    
    // ✅ Listen to users changes (when staff status or role changes)
    _usersSubscription = FirebaseFirestore.instance
        .collection('users')
        .snapshots()
        .listen((event) {
          _loadStats();
        });
  }

  @override
  void dispose() {
    _readStatusSubscription?.cancel();
    _usersSubscription?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final stats = await TermsService.getTermsReadStats(widget.termsId);
      if (mounted) {
        setState(() {
          _stats = stats;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load statistics: $e';
        });
      }
    }
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'Not read yet';
    try {
      if (timestamp is Timestamp) {
        return DateFormat('dd MMM yyyy, HH:mm').format(timestamp.toDate());
      }
      return timestamp.toString();
    } catch (e) {
      return 'Invalid date';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = Responsive.isMobile(context);
    final double fontSize = Responsive.fontSize(context, 14);
    final double spacing = Responsive.spacing(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A3B68),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            
            Text(
              widget.termsTitle,
              style: TextStyle(
                fontSize: isMobile ? fontSize * 0.8 : AppFonts.md * 0.8,
                color: Colors.white70,
              ),
            ),
          ],
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: Colors.white,
            size: isMobile ? 18 : 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadStats,
            tooltip: 'Refresh',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Container(
            color: const Color(0xFF1A3B68),
            child: TabBar(
              controller: _tabController,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              indicatorColor: Colors.white,
              tabs: const [
                Tab(text: ' All Staff'),
                Tab(text: ' Read'),
                Tab(text: ' Not Read'),
              ],
              onTap: (index) {
                setState(() {
                  _selectedTab = ['all', 'read', 'not_read'][index];
                });
              },
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF1A3B68),
              ),
            )
          : _errorMessage != null
              ? _buildErrorWidget(isMobile, fontSize)
              : _stats == null
                  ? _buildEmptyWidget(isMobile, fontSize)
                  : _buildContentWidget(isMobile, fontSize, spacing),
    );
  }

  Widget _buildErrorWidget(bool isMobile, double fontSize) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: isMobile ? 48 : 64,
              color: Colors.red,
            ),
            SizedBox(height: isMobile ? 12 : 16),
            Text(
              _errorMessage!,
              style: TextStyle(
                fontSize: isMobile ? fontSize : AppFonts.md,
                color: Colors.red,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: isMobile ? 16 : 24),
            ElevatedButton.icon(
              onPressed: _loadStats,
              icon: const Icon(Icons.refresh),
              label: Text(
                'Retry',
                style: TextStyle(
                  fontSize: isMobile ? fontSize : AppFonts.md,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A3B68),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyWidget(bool isMobile, double fontSize) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: isMobile ? 48 : 64,
              color: Colors.grey,
            ),
            SizedBox(height: isMobile ? 12 : 16),
            Text(
              'No staff data available',
              style: TextStyle(
                fontSize: isMobile ? fontSize : AppFonts.md,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContentWidget(bool isMobile, double fontSize, double spacing) {
    // Get read and not read lists from stats
    final readStaff = _stats!['readStaff'] ?? [];
    final notReadStaff = _stats!['notReadStaff'] ?? [];

    // Filter out unknown users from both lists
    final filteredReadList = readStaff.where((staff) {
      final name = staff['name'] ?? '';
      return name != 'Unknown User' && name != 'Unknown' && name.isNotEmpty;
    }).toList();

    final filteredNotReadList = notReadStaff.where((staff) {
      final name = staff['name'] ?? '';
      return name != 'Unknown User' && name != 'Unknown' && name.isNotEmpty;
    }).toList();

    // Calculate filtered counts
    final filteredTotalStaff = filteredReadList.length + filteredNotReadList.length;
    final filteredReadCount = filteredReadList.length;
    final filteredNotReadCount = filteredNotReadList.length;
    final filteredReadPercentage = filteredTotalStaff > 0 
        ? (filteredReadCount / filteredTotalStaff * 100) 
        : 0;

    // Determine which list to show based on selected tab
    List<dynamic> displayList = [];
    if (_selectedTab == 'all') {
      displayList = [...filteredReadList, ...filteredNotReadList];
    } else if (_selectedTab == 'read') {
      displayList = filteredReadList;
    } else {
      displayList = filteredNotReadList;
    }

    return Column(
      children: [
        // Statistics Summary Cards
        Container(
          padding: EdgeInsets.all(isMobile ? 12 : 16),
          margin: EdgeInsets.all(isMobile ? 12 : 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(isMobile ? 10 : 12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Total Staff',
                  filteredTotalStaff.toString(),
                  Icons.people,
                  Colors.blue,
                  isMobile,
                  fontSize,
                ),
              ),
              Container(
                width: 1,
                height: isMobile ? 40 : 50,
                color: Colors.grey.shade200,
              ),
              Expanded(
                child: _buildStatCard(
                  'Read',
                  filteredReadCount.toString(),
                  Icons.check_circle,
                  Colors.green,
                  isMobile,
                  fontSize,
                ),
              ),
              Container(
                width: 1,
                height: isMobile ? 40 : 50,
                color: Colors.grey.shade200,
              ),
              Expanded(
                child: _buildStatCard(
                  'Not Read',
                  filteredNotReadCount.toString(),
                  Icons.pending,
                  Colors.orange,
                  isMobile,
                  fontSize,
                ),
              ),
            ],
          ),
        ),

        // Read Progress
        Container(
          margin: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16),
          padding: EdgeInsets.symmetric(vertical: spacing),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    ' Read Progress',
                    style: TextStyle(
                      fontSize: isMobile ? fontSize : AppFonts.md,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  Text(
                    '${filteredReadPercentage.toStringAsFixed(1)}% (${filteredReadCount.toString()}/$filteredTotalStaff)',
                    style: TextStyle(
                      fontSize: isMobile ? fontSize : AppFonts.md,
                      fontWeight: FontWeight.bold,
                      color: filteredReadPercentage > 70 ? Colors.green : Colors.orange,
                    ),
                  ),
                ],
              ),
              SizedBox(height: spacing / 2),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: filteredTotalStaff > 0 ? filteredReadCount / filteredTotalStaff : 0,
                  minHeight: isMobile ? 8 : 10,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    filteredReadPercentage > 70 ? Colors.green : Colors.orange,
                  ),
                ),
              ),
            ],
          ),
        ),

        SizedBox(height: spacing / 2),

        // Staff List
        Expanded(
          child: displayList.isEmpty
              ? Center(
                  child: Padding(
                    padding: EdgeInsets.all(isMobile ? 16 : 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _selectedTab == 'read'
                              ? Icons.check_circle_outline
                              : Icons.people_outline,
                          size: isMobile ? 40 : 56,
                          color: Colors.grey,
                        ),
                        SizedBox(height: isMobile ? 8 : 12),
                        Text(
                          _selectedTab == 'read'
                              ? 'No staff have read this version yet'
                              : _selectedTab == 'not_read'
                                  ? '🎉 All staff have read this version!'
                                  : 'No staff found',
                          style: TextStyle(
                            fontSize: isMobile ? fontSize : AppFonts.md,
                            color: Colors.grey,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 12 : 16,
                    vertical: spacing,
                  ),
                  itemCount: displayList.length,
                  itemBuilder: (context, index) {
                    final staff = displayList[index];
                    
                    // ✅ Check if staff has read based on 'readAt' field
                    final isRead = staff.containsKey('readAt') && staff['readAt'] != null;
                    final status = staff['status'] ?? 'Active';
                    final isActive = status.toLowerCase() == 'active';
                    final role = staff['role'] ?? 'Staff';
                    final isManager = role.toLowerCase() == 'manager';
                    
                    return Card(
                      margin: EdgeInsets.only(bottom: spacing),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(isMobile ? 8 : 10),
                        side: BorderSide(
                          color: isRead ? Colors.green.shade100 : Colors.grey.shade200,
                          width: 1,
                        ),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isRead ? Colors.green.shade100 : Colors.grey.shade200,
                          child: Icon(
                            isRead ? Icons.check_circle : Icons.person,
                            color: isRead ? Colors.green : Colors.grey,
                            size: isMobile ? 18 : 20,
                          ),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                staff['name'] ?? 'Unknown',
                                style: TextStyle(
                                  fontSize: isMobile ? fontSize : AppFonts.md,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            // ✅ Show read status badge with real-time status
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: isRead ? Colors.green.shade50 : Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isRead ? Colors.green.shade200 : Colors.orange.shade200,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isRead ? Icons.check_circle : Icons.pending,
                                    size: isMobile ? 12 : 14,
                                    color: isRead ? Colors.green.shade700 : Colors.orange.shade700,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    isRead ? 'Read' : 'Not Read',
                                    style: TextStyle(
                                      fontSize: isMobile ? fontSize * 0.7 : AppFonts.md * 0.7,
                                      fontWeight: FontWeight.w600,
                                      color: isRead ? Colors.green.shade700 : Colors.orange.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              staff['email'] ?? '',
                              style: TextStyle(
                                fontSize: isMobile ? fontSize * 0.85 : AppFonts.md * 0.85,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            SizedBox(height: spacing / 3),
                            Wrap(
                              spacing: spacing / 2,
                              runSpacing: spacing / 2,
                              children: [
                                // ✅ Role Badge (Staff/Manager)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isManager 
                                        ? Colors.purple.shade50 
                                        : Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: isManager 
                                          ? Colors.purple.shade200 
                                          : Colors.blue.shade200,
                                      width: 0.5,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isManager ? Icons.people_alt : Icons.person,
                                        size: isMobile ? 10 : 12,
                                        color: isManager 
                                            ? Colors.purple.shade700 
                                            : Colors.blue.shade700,
                                      ),
                                      SizedBox(width: 2),
                                      Text(
                                        isManager ? 'Manager' : 'Staff',
                                        style: TextStyle(
                                          fontSize: isMobile ? fontSize * 0.7 : AppFonts.md * 0.7,
                                          fontWeight: FontWeight.w600,
                                          color: isManager 
                                              ? Colors.purple.shade700 
                                              : Colors.blue.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // ✅ Department
                                if (staff['department'] != null && staff['department'] != 'N/A' && staff['department'] != '')
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade50,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: Colors.green.shade200,
                                        width: 0.5,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.business,
                                          size: isMobile ? 10 : 12,
                                          color: Colors.green.shade700,
                                        ),
                                        SizedBox(width: 2),
                                        Text(
                                          staff['department'],
                                          style: TextStyle(
                                            fontSize: isMobile ? fontSize * 0.7 : AppFonts.md * 0.7,
                                            color: Colors.green.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              
                              ],
                            ),
                          ],
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (isRead)
                              Text(
                                'Read at:',
                                style: TextStyle(
                                  fontSize: isMobile ? fontSize * 0.65 : AppFonts.md * 0.65,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            if (isRead)
                              Text(
                                _formatDate(staff['readAt']),
                                style: TextStyle(
                                  fontSize: isMobile ? fontSize * 0.7 : AppFonts.md * 0.7,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                          ],
                        ),
                        isThreeLine: true,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String label, 
    String value, 
    IconData icon, 
    Color color, 
    bool isMobile,
    double fontSize,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: isMobile ? 20 : 24),
        SizedBox(height: isMobile ? 2 : 4),
        Text(
          value,
          style: TextStyle(
            fontSize: isMobile ? fontSize + 2 : AppFonts.md + 2,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: isMobile ? fontSize * 0.8 : AppFonts.md * 0.8,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}