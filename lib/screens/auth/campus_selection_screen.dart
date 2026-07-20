// lib/screens/auth/campus_selection_screen.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../app_fonts.dart';
import '../../utils/responsive.dart';

class CampusSelectionScreen extends StatefulWidget {
  const CampusSelectionScreen({super.key});

  @override
  State<CampusSelectionScreen> createState() => _CampusSelectionScreenState();
}

class _CampusSelectionScreenState extends State<CampusSelectionScreen> {
  String? _selectedCampusId;
  bool _isLoading = false;

  final List<Map<String, String>> _campuses = [
    {
      'id': 'campus_main',
      'name': 'Main Campus (Phnom Penh)',
      'address': '123 Norodom Blvd, Phnom Penh',
      'color': '#173B69',
    },
    {
      'id': 'campus_north',
      'name': 'North Campus (Siem Reap)',
      'address': '456 Angkor Wat Rd, Siem Reap',
      'color': '#2A5F8F',
    },
    {
      'id': 'campus_south',
      'name': 'South Campus (Kampot)',
      'address': '789 Riverside Rd, Kampot',
      'color': '#3A7FB7',
    },
    {
      'id': 'campus_east',
      'name': 'East Campus (Battambang)',
      'address': '101 National Rd, Battambang',
      'color': '#4A9FD7',
    },
  ];

  Future<void> _saveCampusAndProceed() async {
    if (_selectedCampusId == null) {
      _showError('Please select a campus');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selected_campus_id', _selectedCampusId!);
      
      // ស្វែងរកឈ្មោះសាខា
      final campus = _campuses.firstWhere(
        (c) => c['id'] == _selectedCampusId,
        orElse: () => {},
      );
      await prefs.setString('selected_campus_name', campus['name'] ?? '');

      if (mounted) {
        // ទៅកាន់ Login Screen
        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showError('Failed to save campus selection');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(fontSize: AppFonts.md),
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = Responsive.isMobile(context);
    final double fontSize = Responsive.fontSize(context, AppFonts.md);
    final double spacing = Responsive.spacing(context);
    final double iconSize = Responsive.iconSize(context, 48);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF173B69),
              const Color(0xFF2A5F8F),
              Colors.white.withOpacity(0.9),
            ],
            stops: const [0.0, 0.4, 1.0],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(spacing * 3),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo
                  Container(
                    width: isMobile ? 80 : 100,
                    height: isMobile ? 80 : 100,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.school,
                      size: 50,
                      color: Color(0xFF173B69),
                    ),
                  ),
                  SizedBox(height: spacing * 2),
                  Text(
                    'Welcome!',
                    style: TextStyle(
                      fontSize: isMobile ? fontSize + 8 : fontSize + 12,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF173B69),
                    ),
                  ),
                  SizedBox(height: spacing / 2),
                  Text(
                    'Select your campus to continue',
                    style: TextStyle(
                      fontSize: fontSize,
                      color: Colors.grey[600],
                    ),
                  ),
                  SizedBox(height: spacing * 3),
                  
                  // Campus Cards
                  Container(
                    constraints: const BoxConstraints(maxWidth: 500),
                    child: Column(
                      children: _campuses.map((campus) {
                        final isSelected = _selectedCampusId == campus['id'];
                        final color = Color(int.parse(
                          campus['color']!.replaceFirst('#', '0xFF'),
                        ));

                        return _CampusCard(
                          campus: campus,
                          isSelected: isSelected,
                          onTap: () {
                            setState(() {
                              _selectedCampusId = campus['id'];
                            });
                          },
                          isMobile: isMobile,
                          fontSize: fontSize,
                          spacing: spacing,
                          color: color,
                        );
                      }).toList(),
                    ),
                  ),
                  
                  SizedBox(height: spacing * 3),
                  
                  // Continue Button
                  SizedBox(
                    width: double.infinity,
                    height: Responsive.buttonHeight(context),
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _saveCampusAndProceed,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF173B69),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 4,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              'Continue to Login',
                              style: TextStyle(
                                fontSize: isMobile ? fontSize : fontSize + 2,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  
                  SizedBox(height: spacing * 2),
                  
                  Text(
                    'You can change campus later in settings',
                    style: TextStyle(
                      fontSize: isMobile ? fontSize * 0.8 : fontSize,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ==================== CAMPUS CARD ====================
class _CampusCard extends StatelessWidget {
  final Map<String, String> campus;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isMobile;
  final double fontSize;
  final double spacing;
  final Color color;

  const _CampusCard({
    required this.campus,
    required this.isSelected,
    required this.onTap,
    required this.isMobile,
    required this.fontSize,
    required this.spacing,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: spacing * 1.5),
        padding: EdgeInsets.all(spacing * 1.5),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? color.withOpacity(0.3)
                  : Colors.grey.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: isMobile ? 40 : 50,
              height: isMobile ? 40 : 50,
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.location_city,
                color: color,
                size: isMobile ? 20 : 24,
              ),
            ),
            SizedBox(width: spacing * 1.5),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    campus['name']!,
                    style: TextStyle(
                      fontSize: isMobile ? fontSize : fontSize + 2,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? color : Colors.black87,
                    ),
                  ),
                  Text(
                    campus['address']!,
                    style: TextStyle(
                      fontSize: isMobile ? fontSize * 0.8 : fontSize,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: color,
                size: isMobile ? 24 : 28,
              ),
          ],
        ),
      ),
    );
  }
}