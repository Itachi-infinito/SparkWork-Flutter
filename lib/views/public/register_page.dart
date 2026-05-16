import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';

class RegisterPage extends StatelessWidget {
  const RegisterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.go('/welcome'),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Text('Créer un compte',
                  style: GoogleFonts.inter(fontSize: 30, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              Text('Rejoins SparkWork et trouve ton match parfait.',
                  style: GoogleFonts.inter(fontSize: 15, color: AppColors.textSecondary)),
              const SizedBox(height: 48),
              _RoleCard(
                icon: Icons.person_search_rounded,
                color: AppColors.primary,
                title: 'Je suis candidat',
                subtitle: 'Je cherche un emploi et je veux swiper des offres.',
                onTap: () => context.go('/register-candidate'),
              ),
              const SizedBox(height: 16),
              _RoleCard(
                icon: Icons.business_center_rounded,
                color: AppColors.green,
                title: 'Je suis recruteur',
                subtitle: 'Je publie des offres et je cherche des talents.',
                onTap: () => context.go('/register-recruiter'),
              ),
              const Spacer(),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('Déjà un compte ? ', style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 14)),
                GestureDetector(
                  onTap: () => context.go('/login'),
                  child: Text('Se connecter', style: GoogleFonts.inter(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 14)),
                ),
              ]),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _RoleCard({required this.icon, required this.color, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                Text(subtitle, style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary, height: 1.4)),
              ]),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppColors.textLight),
          ],
        ),
      ),
    );
  }
}
