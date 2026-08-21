import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Structure commune aux parcours d'inscription en plusieurs étapes
/// (sélection de secteur(s), infos personnelles, préférences...) :
/// en-tête dégradé avec bouton retour + barre de progression, contenu
/// scrollable au centre, bouton d'action fixé en bas.
class OnboardingStepScaffold extends StatelessWidget {
  final int step; // 0-based
  final int totalSteps;
  final String title;
  final String subtitle;
  final IconData headerIcon;
  final Gradient headerGradient;
  final Widget child;
  final VoidCallback onBack;
  final VoidCallback? onNext;
  final String nextLabel;
  final bool loading;
  final String? errorText;
  final Color buttonColor;

  const OnboardingStepScaffold({
    super.key,
    required this.step,
    required this.totalSteps,
    required this.title,
    required this.subtitle,
    required this.headerIcon,
    required this.headerGradient,
    required this.child,
    required this.onBack,
    required this.onNext,
    required this.nextLabel,
    this.loading = false,
    this.errorText,
    this.buttonColor = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(
                24, MediaQuery.of(context).padding.top + 12, 24, 24),
            decoration: BoxDecoration(
              gradient: headerGradient,
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(28)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(height: 14),
                Icon(headerIcon, color: Colors.white, size: 28),
                const SizedBox(height: 8),
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5)),
                const SizedBox(height: 4),
                Text(subtitle,
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.72), fontSize: 13)),
                const SizedBox(height: 18),
                Row(
                  children: List.generate(totalSteps, (i) {
                    final active = i <= step;
                    return Expanded(
                      child: Container(
                        margin: EdgeInsets.only(
                            right: i == totalSteps - 1 ? 0 : 6),
                        height: 4,
                        decoration: BoxDecoration(
                          color: active
                              ? Colors.white
                              : Colors.white.withOpacity(0.28),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (errorText != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFDE8E8),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(errorText!,
                          style: const TextStyle(color: Color(0xFFD92D20))),
                    ),
                    const SizedBox(height: 16),
                  ],
                  child,
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
              child: ElevatedButton(
                onPressed: loading ? null : onNext,
                style: ElevatedButton.styleFrom(
                  backgroundColor: buttonColor,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : Text(nextLabel),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
