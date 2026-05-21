import 'package:flutter/material.dart';

class AvatarColors {
  static const List<List<Color>> _gradients = [
    [Color(0xFF7C4DFF), Color(0xFF5E35B1)],
    [Color(0xFF10B981), Color(0xFF059669)],
    [Color(0xFF3B82F6), Color(0xFF2563EB)],
    [Color(0xFFF59E0B), Color(0xFFD97706)],
    [Color(0xFFEC4899), Color(0xFFDB2777)],
    [Color(0xFF06B6D4), Color(0xFF0891B2)],
    [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
    [Color(0xFF14B8A6), Color(0xFF0D9488)],
    [Color(0xFFF97316), Color(0xFFEA580C)],
    [Color(0xFF6366F1), Color(0xFF4F46E5)],
  ];

  static List<Color> forString(String value) {
    if (value.isEmpty) return _gradients[0];
    int hash = 0;
    for (final char in value.codeUnits) {
      hash = (hash * 31 + char) & 0xFFFFFFFF;
    }
    return _gradients[hash % _gradients.length];
  }

  static LinearGradient gradientForString(String value) {
    return LinearGradient(
      colors: forString(value),
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }
}