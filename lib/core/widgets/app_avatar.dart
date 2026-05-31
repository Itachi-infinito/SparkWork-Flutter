import 'dart:io';
import 'package:flutter/material.dart';
import '../utils/avatar_colors.dart';

class AppAvatar extends StatelessWidget {
  final String name;
  final double radius;
  final String? photoPath;

  const AppAvatar({super.key, required this.name, this.radius = 26, this.photoPath});

  @override
  Widget build(BuildContext context) {
    if (photoPath != null && photoPath!.isNotEmpty) {
      final file = File(photoPath!);
      if (file.existsSync()) {
        return CircleAvatar(radius: radius, backgroundImage: FileImage(file));
      }
    }
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(shape: BoxShape.circle, gradient: AvatarColors.gradientForString(name)),
      child: Center(
        child: Text(_initials(name), style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: radius * 0.72)),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty || parts[0].isEmpty) return '?';
    if (parts.length >= 2 && parts[1].isNotEmpty) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return parts[0][0].toUpperCase();
  }
}