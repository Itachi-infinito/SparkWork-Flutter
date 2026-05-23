import 'package:flutter/material.dart';
import '../utils/avatar_colors.dart';

class AppAvatar extends StatelessWidget {
  final String name;
  final double radius;

  const AppAvatar({super.key, required this.name, this.radius = 26});

  String _initials(String name) {
    final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        gradient: AvatarColors.gradientForString(name),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AvatarColors.gradientForString(name).colors.first.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          _initials(name),
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: radius * 0.65,
          ),
        ),
      ),
    );
  }
}