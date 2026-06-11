import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF7C4DFF);
  static const Color primaryLight = Color(0xFFEDE7FF);
  static const Color primaryDark = Color(0xFF5E35B1);
  static const Color primaryDeep = Color(0xFF3D1373);

  static const Color green = Color(0xFF10B981);
  static const Color greenLight = Color(0xFFD1FAE5);

  static const Color red = Color(0xFFE11D48);
  static const Color redLight = Color(0xFFFFE4E6);

  static const Color orange = Color(0xFFF59E0B);
  static const Color orangeLight = Color(0xFFFEF3C7);

  static const Color pink = Color(0xFFEC4899);
  static const Color pinkLight = Color(0xFFFCE4EC);

  static const Color background = Color(0xFFF8F9FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF3F4F6);

  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textHint = Color(0xFF9CA3AF);

  static const Color border = Color(0xFFE5E7EB);
  static const Color divider = Color(0xFFF3F4F6);

  static const Color shadow = Color(0x0F000000);

  // Hero gradient (dark purple → electric purple) — welcome/splash pages
  static const List<Color> heroGradient = [
    Color(0xFF0D0117),
    Color(0xFF1E0A3C),
    Color(0xFF7C4DFF),
  ];

  // Card dark overlay — bottom of swipe cards
  static const List<Color> cardOverlay = [
    Colors.transparent,
    Color(0xCC000000),
    Color(0xEE000000),
  ];

  // Glow — used in BoxShadow for CTA buttons
  static const Color primaryGlow = Color(0x887C4DFF);
  static const Color greenGlow = Color(0x8810B981);
}