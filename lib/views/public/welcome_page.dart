import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/locale_service.dart';

class WelcomePage extends ConsumerWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context)!;
    final currentLocale = ref.watch(localeProvider);

    return Scaffold(
      body: Stack(
        children: [
          Container(
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
                      loc.appTagline,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withOpacity(0.72),
                        height: 1.5,
                        fontWeight: FontWeight.w300,
                      ),
                    ),

                    const Spacer(flex: 2),

                    // Feature chips — passent à la ligne plutôt que d'être
                    // coupés si leur largeur totale dépasse l'écran.
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _FeatureChip(icon: Icons.swipe_rounded, label: loc.featureSwipeMatch),
                        _FeatureChip(icon: Icons.bolt, label: loc.featureSuperLike),
                        _FeatureChip(icon: Icons.chat_bubble_rounded, label: loc.featureChatDirect),
                      ],
                    ),

                    const Spacer(flex: 3),

                    // Se connecter — white solid
                    _GradientButton(
                      label: loc.welcomeLogin,
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
                        child: Text(
                          loc.welcomeRegister,
                          style: const TextStyle(
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

          // Language toggle
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            right: 20,
            child: _LanguageToggle(
              currentLocale: currentLocale,
              onChanged: (l) => ref.read(localeProvider.notifier).setLocale(l),
            ),
          ),
        ],
      ),
    );
  }
}

class _LanguageToggle extends StatelessWidget {
  final Locale currentLocale;
  final ValueChanged<Locale> onChanged;
  const _LanguageToggle({required this.currentLocale, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _LangOption(
            label: 'FR',
            selected: currentLocale.languageCode == 'fr',
            onTap: () => onChanged(const Locale('fr')),
          ),
          _LangOption(
            label: 'EN',
            selected: currentLocale.languageCode == 'en',
            onTap: () => onChanged(const Locale('en')),
          ),
        ],
      ),
    );
  }
}

class _LangOption extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _LangOption({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: selected ? AppColors.primaryDark : Colors.white70,
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
