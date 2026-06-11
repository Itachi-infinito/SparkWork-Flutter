import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';

class RegisterPage extends StatelessWidget {
  const RegisterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Gradient header
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(
                24, MediaQuery.of(context).padding.top + 16, 24, 32),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1E0A3C), AppColors.primary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius:
                  BorderRadius.vertical(bottom: Radius.circular(28)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(height: 20),
                const Icon(Icons.bolt, color: Colors.white, size: 30),
                const SizedBox(height: 8),
                const Text('Je suis…',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5)),
                const SizedBox(height: 4),
                Text('Choisissez votre profil pour commencer',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.72),
                        fontSize: 14)),
              ],
            ),
          ),

          // Role selection
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  _RoleCard(
                    title: 'Candidat',
                    subtitle: 'Je cherche un emploi dans le Horeca',
                    icon: Icons.person_search_rounded,
                    gradient: const LinearGradient(
                        colors: [AppColors.primaryDark, AppColors.primary]),
                    onTap: () => context.push('/register/candidate'),
                  ),
                  const SizedBox(height: 16),
                  _RoleCard(
                    title: 'Recruteur',
                    subtitle: 'Je cherche des talents pour mon établissement',
                    icon: Icons.business_center_rounded,
                    gradient: const LinearGradient(
                        colors: [Color(0xFF059669), AppColors.green]),
                    onTap: () => context.push('/register/recruiter'),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => context.go('/login'),
                    child: RichText(
                      text: const TextSpan(
                        text: 'Déjà un compte ? ',
                        style: TextStyle(color: AppColors.textSecondary),
                        children: [
                          TextSpan(
                            text: 'Se connecter',
                            style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Gradient gradient;
  final VoidCallback onTap;

  const _RoleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 16,
                offset: const Offset(0, 6)),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: Colors.white, size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 13)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded,
                color: Colors.white.withOpacity(0.7), size: 18),
          ],
        ),
      ),
    );
  }
}
