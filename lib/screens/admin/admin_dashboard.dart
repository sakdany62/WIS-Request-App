import 'package:flutter/material.dart';
import '../../app_fonts.dart';
import 'admin_home_screen.dart';
import 'admin_setting.dart';
import 'report_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _currentIndex = 0;
  late final List<Widget> _pages;

  // Gradient matching your primary color
  static const LinearGradient _gradient = LinearGradient(
    colors: [Color(0xFF173B69), Color(0xFF2A5F8F)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  @override
  void initState() {
    super.initState();
    _pages = const [
      AdminHomeScreen(),
      ReportScreen(),
      AdminSettingsScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true, // lets the bottom nav float over the body
      body: _pages[_currentIndex],
      bottomNavigationBar: _buildModernBottomNavBar(),
    );
  }

  Widget _buildModernBottomNavBar() {
    return Container(
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Container(
          decoration: BoxDecoration(
            gradient: _gradient,
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(
                    0,
                    Icons.home_outlined,
                    Icons.home,
                    'Home',
                  ),
                  _buildNavItem(
                    1,
                    Icons.assessment_outlined,
                    Icons.assessment,
                    'Reports',
                  ),
                  _buildNavItem(
                    2,
                    Icons.settings_outlined,
                    Icons.settings,
                    'Settings',
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
  ) {
    final isSelected = _currentIndex == index;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _currentIndex = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color:
                isSelected ? Colors.white.withOpacity(0.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(25),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isSelected ? filledIcon : outlinedIcon,
                color: Colors.white,
                size: isSelected ? 26 : 22,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: AppFonts.md, // or 11 if you prefer
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
