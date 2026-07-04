import 'package:flutter/material.dart';
import 'manager_home_screen.dart';
import 'all_permission_today.dart' as permission;
import '../staff/settings_screen.dart';
import '../../app_fonts.dart';
class ManagerDashboard extends StatefulWidget {
  const ManagerDashboard({super.key});

  @override
  State<ManagerDashboard> createState() => _ManagerDashboardState();
}

class _ManagerDashboardState extends State<ManagerDashboard> {
  int _currentIndex = 0;
  late final List<Widget> _pages;

  // Gradient matching your primary colour (same as AdminDashboard)
  static const LinearGradient _gradient = LinearGradient(
    colors: [Color(0xFF173B69), Color(0xFF2A5F8F)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  @override
  void initState() {
    super.initState();
    _pages = [
      ManagerHomeScreen(),                       // not const
      const permission.ListStaffScreen(),
      const SettingsScreen(),
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
                    Icons.assignment_outlined,
                    Icons.assignment,
                    'Request Today',
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
        onTap: () {
          if (mounted) {
            setState(() => _currentIndex = index);
          }
        },
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
                  fontSize: AppFonts.md, // your existing font size constant
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