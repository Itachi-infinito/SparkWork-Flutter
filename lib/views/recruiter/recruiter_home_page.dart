import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../services/session_service.dart';
import '../shared/nav_bar.dart';

class RecruiterHomePage extends ConsumerWidget {
  const RecruiterHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final firstName = session.userName.split(' ').first;

    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: const RecruiterNavBar(currentIndex: 0),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Bonjour,  👋',
                        style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                    const SizedBox(height: 4),
                    Text('Trouvez votre prochain talent.',
                        style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary)),
                  ]),
                  GestureDetector(
                    onTap: () => context.go('/settings'),
                    child: Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                      child: const Icon(Icons.settings_outlined, color: AppColors.textSecondary, size: 20),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // Bouton swipe principal
              GestureDetector(
                onTap: () => context.go('/recruiter/swipe'),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF34D399)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: AppColors.green.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8))],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Swiper des candidats', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
                          const SizedBox(height: 6),
                          Text('Découvrez les profils qui\ncorrespondent à vos offres.', style: GoogleFonts.inter(fontSize: 13, color: Colors.white70, height: 1.5)),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                            child: Text('Découvrir', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.green)),
                          ),
                        ]),
                      ),
                      const SizedBox(width: 16),
                      const Icon(Icons.people_rounded, size: 64, color: Colors.white30),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              Text('Actions rapides', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(child: _QuickAction(icon: Icons.add_circle_rounded, color: AppColors.green, label: 'Nouvelle offre', onTap: () => context.go('/recruiter/offers/add'))),
                const SizedBox(width: 12),
                Expanded(child: _QuickAction(icon: Icons.favorite_rounded, color: AppColors.red, label: 'Matches', onTap: () => context.go('/recruiter/matches'))),
                const SizedBox(width: 12),
                Expanded(child: _QuickAction(icon: Icons.thumb_up_rounded, color: AppColors.primary, label: 'Likes reçus', onTap: () => context.go('/recruiter/likes'))),
              ]),
              const SizedBox(height: 24),

              Text('Conseil du jour', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.greenLight,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.green.withOpacity(0.2)),
                ),
                child: Row(children: [
                  Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(color: AppColors.green, borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.lightbulb_rounded, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Publie tes compétences requises précisément pour obtenir un meilleur score de matching !',
                      style: GoogleFonts.inter(fontSize: 13, color: AppColors.green, height: 1.5, fontWeight: FontWeight.w500),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 24),

              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Mon profil', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                GestureDetector(
                  onTap: () => context.go('/recruiter/profile'),
                  child: Text('Voir', style: GoogleFonts.inter(fontSize: 13, color: AppColors.green, fontWeight: FontWeight.w600)),
                ),
              ]),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
                child: Row(children: [
                  CircleAvatar(
                    radius: 28, backgroundColor: AppColors.greenLight,
                    child: Text(session.userName.isNotEmpty ? session.userName[0].toUpperCase() : 'R',
                        style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.green)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(session.userName, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                      Text(session.userEmail, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: AppColors.greenLight, borderRadius: BorderRadius.circular(6)),
                        child: Text('Recruteur', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.green)),
                      ),
                    ]),
                  ),
                  const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textLight),
                ]),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;
  const _QuickAction({required this.icon, required this.color, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
        child: Column(children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(height: 6),
          Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textPrimary), textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}
