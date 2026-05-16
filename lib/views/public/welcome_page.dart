import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const Spacer(flex: 2),
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Icon(Icons.bolt, color: Colors.white, size: 48),
              ),
              const SizedBox(height: 20),
              const Text(
                'SparkWork',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Trouvez votre prochain emploi\ndans la restauration et l\'hôtellerie',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const Spacer(flex: 2),
              _FeatureRow(
                icon: Icons.swipe,
                color: AppColors.primary,
                title: 'Swipe pour matcher',
                subtitle: 'Explorez les offres d\'un geste',
              ),
              const SizedBox(height: 16),
              _FeatureRow(
                icon: Icons.favorite,
                color: AppColors.red,
                title: 'Matchs instantanés',
                subtitle: 'Connectez-vous dès qu\'il y a accord',
              ),
              const SizedBox(height: 16),
              _FeatureRow(
                icon: Icons.chat_bubble,
                color: AppColors.green,
                title: 'Messagerie intégrée',
                subtitle: 'Échangez directement avec les recruteurs',
              ),
              const Spacer(flex: 3),
              ElevatedButton(
                onPressed: () => context.push('/login'),
                child: const Text('Se connecter'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => context.push('/register'),
                child: const Text('Créer un compte'),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  const _FeatureRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: AppColors.textPrimary)),
              Text(subtitle,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
        ),
      ],
    );
  }
}