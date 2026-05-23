import 'package:flutter/material.dart';

class AvatarColors {
  static const List<List<Color>> _gradients = [
    [Color(0xFF7C4DFF), Color(0xFF5E35B1)],
    [Color(0xFF10B981), Color(0xFF059669)],
    [Color(0xFFEF4444), Color(0xFFDC2626)],
    [Color(0xFFF59E0B), Color(0xFFD97706)],
    [Color(0xFF3B82F6), Color(0xFF2563EB)],
    [Color(0xFFEC4899), Color(0xFFDB2777)],
    [Color(0xFF14B8A6), Color(0xFF0D9488)],
    [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
    [Color(0xFFFF6B35), Color(0xFFE55A2B)],
    [Color(0xFF06B6D4), Color(0xFF0891B2)],
  ];

  static LinearGradient gradientForString(String value) {
    final index = value.hashCode.abs() % _gradients.length;
    return LinearGradient(
      colors: _gradients[index],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }
}