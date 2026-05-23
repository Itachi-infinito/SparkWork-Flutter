import 'package:flutter/material.dart';
import 'app_colors.dart';

extension AppThemeExt on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  Color get bgColor => Theme.of(this).scaffoldBackgroundColor;

  Color get surfaceColor => Theme.of(this).colorScheme.surface;

  Color get borderColor =>
      isDark ? const Color(0xFF2C2C2C) : AppColors.border;

  Color get surfaceVariantColor =>
      isDark ? const Color(0xFF252525) : AppColors.surfaceVariant;

  Color get textPrimaryColor =>
      isDark ? const Color(0xFFF2F2F7) : AppColors.textPrimary;

  Color get textSecondaryColor =>
      isDark ? const Color(0xFF8E8E93) : AppColors.textSecondary;

  Color get textHintColor =>
      isDark ? const Color(0xFF636366) : AppColors.textHint;
}