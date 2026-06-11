import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: AppColors.heroGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              children: [
                const Spacer(flex: 2),

                // Logo with glow
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.25), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                          color: AppColors.primary.withOpacity(0.6),
                          blurRadius: 32,
                          spreadRadius: 4),
                    ],
                  ),
                  child: const Icon(Icons.bolt, color: Colors.white, size: 50),
                ),
                const SizedBox(height: 22),

                const Text(
                  'SparkWork',
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: -1.0,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Le recrutement Horeca\nréinventé.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.72),
                    height: 1.5,
                    fontWeight: FontWeight.w300,
                  ),
                ),

                const Spacer(flex: 2),

                // Feature chips row
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      _FeatureChip(icon: Icons.swipe_rounded, label: 'Swipe & Match'),
                      SizedBox(width: 8),
                      _FeatureChip(icon: Icons.bolt, label: 'SuperLike'),
                      SizedBox(width: 8),
                      _FeatureChip(icon: Icons.chat_bubble_rounded, label: 'Chat direct'),
                    ],
                  ),
                ),

                const Spacer(flex: 3),

                // Se connecter — white solid
                _GradientButton(
                  label: 'Se connecter',
                  onPressed: () => context.push('/login'),
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFFFFF), Color(0xFFEDE7FF)],
                  ),
                  textColor: AppColors.primaryDark,
                  glowColor: Colors.white.withOpacity(0.35),
                ),
                const SizedBox(height: 14),

                // Créer un compte — outlined white
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton(
                    onPressed: () => context.push('/register'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side:
                          BorderSide(color: Colors.white.withOpacity(0.5), width: 1.5),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text(
                      'Créer un compte',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _FeatureChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 15),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final Gradient gradient;
  final Color textColor;
  final Color glowColor;

  const _GradientButton({
    required this.label,
    required this.onPressed,
    required this.gradient,
    required this.textColor,
    required this.glowColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 52,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: glowColor, blurRadius: 20, offset: const Offset(0, 6)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(14),
          child: Center(
            child: Text(label,
                style: TextStyle(
                    color: textColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w700)),
          ),
        ),
      ),
    );
  }
}
