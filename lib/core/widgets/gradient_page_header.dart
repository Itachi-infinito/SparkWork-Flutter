import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// En-tête dégradé réutilisable (login, register, settings, profil…).
/// Remplace l'AppBar classique sur fond blanc.
class GradientPageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? leadingIcon;
  final List<Color> gradientColors;
  final bool showBackButton;
  final List<Widget>? actions;

  const GradientPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.leadingIcon,
    this.gradientColors = const [Color(0xFF1E0A3C), AppColors.primary],
    this.showBackButton = true,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
          20, MediaQuery.of(context).padding.top + 12, 20, 28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius:
            const BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (showBackButton)
                IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                )
              else
                const SizedBox(width: 4),
              const Spacer(),
              if (actions != null) ...actions!,
            ],
          ),
          const SizedBox(height: 12),
          if (leadingIcon != null) ...[
            Icon(leadingIcon, color: Colors.white, size: 30),
            const SizedBox(height: 8),
          ],
          Text(title,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5)),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!,
                style: TextStyle(
                    color: Colors.white.withOpacity(0.72), fontSize: 14)),
          ],
        ],
      ),
    );
  }
}
