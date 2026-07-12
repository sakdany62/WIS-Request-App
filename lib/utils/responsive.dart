// lib/utils/responsive.dart
import 'package:flutter/material.dart';

class Responsive {
  // ទទួលបានទំហំអេក្រង់
  static double screenWidth(BuildContext context) {
    return MediaQuery.of(context).size.width;
  }

  static double screenHeight(BuildContext context) {
    return MediaQuery.of(context).size.height;
  }

  // ពិនិត្យប្រភេទឧបករណ៍
  static bool isMobile(BuildContext context) {
    return screenWidth(context) < 600;
  }

  static bool isTablet(BuildContext context) {
    return screenWidth(context) >= 600 && screenWidth(context) < 1200;
  }

  static bool isDesktop(BuildContext context) {
    return screenWidth(context) >= 1200;
  }

  // Padding ប្រែប្រួលតាមអេក្រង់
  static EdgeInsets padding(BuildContext context) {
    if (isMobile(context)) {
      return const EdgeInsets.all(12);
    } else if (isTablet(context)) {
      return const EdgeInsets.all(20);
    } else {
      return const EdgeInsets.all(28);
    }
  }

  // Spacing ប្រែប្រួលតាមអេក្រង់
  static double spacing(BuildContext context) {
    if (isMobile(context)) {
      return 8;
    } else if (isTablet(context)) {
      return 14;
    } else {
      return 20;
    }
  }

  // Font Size ប្រែប្រួលតាមអេក្រង់
  static double fontSize(BuildContext context, double size) {
    if (isMobile(context)) {
      return size * 0.9; // ថយ 10%
    } else if (isTablet(context)) {
      return size * 1.0;
    } else {
      return size * 1.1; // កើន 10%
    }
  }

  // Button Height ប្រែប្រួល
  static double buttonHeight(BuildContext context) {
    if (isMobile(context)) {
      return 48;
    } else if (isTablet(context)) {
      return 52;
    } else {
      return 56;
    }
  }

  // Icon Size ប្រែប្រួល
  static double iconSize(BuildContext context, double size) {
    if (isMobile(context)) {
      return size * 0.85;
    } else if (isTablet(context)) {
      return size * 0.95;
    } else {
      return size * 1.0;
    }
  }
}