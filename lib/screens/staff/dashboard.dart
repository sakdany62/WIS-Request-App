// lib/screens/staff/dashboard.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../providers/auth_provider.dart';
import '../../app_fonts.dart';
import '../../utils/responsive.dart';
import 'staff_home_screen.dart';
import 'request_screen.dart';
import 'settings_screen.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  int _currentIndex = 0;
  late final List<Widget> _pages;
  bool _isViewingAsStaff = false;

  static const LinearGradient _gradient = LinearGradient(
    colors: [Color(0xFF173B69), Color(0xFF2A5F8F)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  @override
  void initState() {
    super.initState();
    _pages = [
      const StaffHomeScreen(),
      const RequestScreen(),
      const SettingsScreen(),
    ];
    _checkViewMode();
  }

  Future<void> _checkViewMode() async {
    final prefs = await SharedPreferences.getInstance();
    final isViewing = prefs.getBool('view_as_staff') ?? false;
    if (mounted) {
      setState(() {
        _isViewingAsStaff = isViewing;
      });
    }
  }

  Future<void> _returnToManagerView() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('view_as_staff', false);

    if (mounted) {
      Navigator.pushReplacementNamed(context, '/manager-dashboard');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('returned_to_manager_view'.tr()),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    
    EasyLocalization.of(context);
    
    final bool isMobile = Responsive.isMobile(context);
    final double spacing = Responsive.spacing(context);
    final double iconSize = Responsive.iconSize(context, 24);
    final double fontSize = Responsive.fontSize(context, 12);

    return PopScope(
      canPop: false,
      onPopInvoked: (bool didPop) async {
        if (didPop) return;
        _showExitDialog(context);
      },
      child: Scaffold(
        extendBody: true,
        body: _pages[_currentIndex],
        bottomNavigationBar: _buildModernBottomNavBar(
          isMobile: isMobile,
          spacing: spacing,
          iconSize: iconSize,
          fontSize: fontSize,
        ),
        floatingActionButton: _isViewingAsStaff
            ? FloatingActionButton.small(
                onPressed: _returnToManagerView,
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                tooltip: 'return_to_manager_view'.tr(),
                child: const Icon(Icons.arrow_back, size: 20),
              )
            : null,
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      ),
    );
  }

  void _showExitDialog(BuildContext context) {
    final bool isMobile = Responsive.isMobile(context);
    final double fontSize = Responsive.fontSize(context, 14);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'exit_app'.tr(),
          style: TextStyle(
            fontSize: isMobile ? fontSize : fontSize + 2,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'exit_app_message'.tr(),
          style: TextStyle(fontSize: fontSize),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'cancel'.tr(),
              style: TextStyle(fontSize: fontSize),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              SystemNavigator.pop();
            },
            child: Text(
              'exit'.tr(),
              style: TextStyle(fontSize: fontSize, color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernBottomNavBar({
    required bool isMobile,
    required double spacing,
    required double iconSize,
    required double fontSize,
  }) {
    return Container(
      margin: EdgeInsets.all(isMobile ? 12 : 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(isMobile ? 24 : 30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: isMobile ? 15 : 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(isMobile ? 24 : 30),
        child: Container(
          decoration: BoxDecoration(
            gradient: _gradient,
          ),
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: spacing,
                vertical: isMobile ? 4 : 8,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(
                    0,
                    Icons.home_outlined,
                    Icons.home,
                    'home'.tr(),
                    isMobile,
                    iconSize,
                    fontSize,
                  ),
                  _buildNavItem(
                    1,
                    Icons.assignment_outlined,
                    Icons.assignment,
                    'request'.tr(),
                    isMobile,
                    iconSize,
                    fontSize,
                  ),
                  _buildNavItem(
                    2,
                    Icons.settings_outlined,
                    Icons.settings,
                    'settings'.tr(),
                    isMobile,
                    iconSize,
                    fontSize,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    IconData outlinedIcon,
    IconData filledIcon,
    String label,
    bool isMobile,
    double iconSize,
    double fontSize,
  ) {
    final isSelected = _currentIndex == index;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _currentIndex = index;
          });
        },
        child: Container(
          padding: EdgeInsets.symmetric(vertical: isMobile ? 6 : 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white.withValues(alpha: 0.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(isMobile ? 20 : 25),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isSelected ? filledIcon : outlinedIcon,
                color: Colors.white,
                size: isSelected ? iconSize + 4 : iconSize,
              ),
              SizedBox(height: isMobile ? 2 : 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: isMobile ? fontSize * 0.9 : fontSize,
                  color: isSelected ? Colors.white : Colors.white70,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}