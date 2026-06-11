import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class AppAvatar extends StatelessWidget {
  final String name;
  final double radius;
  final String? photoPath;

  const AppAvatar({
    super.key,
    required this.name,
    this.radius = 24,
    this.photoPath,
  });

  String get _initials {
    final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  Widget _buildInitials() {
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primaryLight,
      child: Text(
        _initials,
        style: TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.bold,
          fontSize: radius * 0.55,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (photoPath != null && photoPath!.isNotEmpty) {
      return SizedBox(
        width: radius * 2,
        height: radius * 2,
        child: ClipOval(
          child: Image.network(
            photoPath!,
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildInitials(),
            loadingBuilder: (_, child, progress) =>
                progress == null ? child : _buildInitials(),
          ),
        ),
      );
    }
    return _buildInitials();
  }
}
