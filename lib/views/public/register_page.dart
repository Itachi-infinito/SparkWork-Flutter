import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';

class RegisterPage extends StatelessWidget {
  const RegisterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Créer un compte'),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            Text('Je suis...',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                )),
            const SizedBox(height: 8),
            const Text('Choisissez votre profil pour continuer',
                style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 40),
            _RoleCard(
              icon: Icons.person_search,
              color: AppColors.primary,
              title: 'Candidat',
              subtitle: 'Je cherche un emploi dans la restauration',
              onTap: () => context.push('/register/candidate'),
            ),
            const SizedBox(height: 16),
            _RoleCard(
              icon: Icons.business,
              color: AppColors.green,
              title: 'Recruteur',
              subtitle: 'Je cherche des talents pour mon établissement',
              onTap: () => context.push('/register/recruiter'),
            ),
          ],
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

  const _RoleCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

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
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textSecondary)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: color, size: 16),
          ],
        ),
      ),
    );
  }
}