import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../repositories/job_offer_repository.dart';
import '../../repositories/match_repository.dart';
import '../../services/session_service.dart';
import '../shared/nav_bar.dart';

class CandidateHomePage extends ConsumerStatefulWidget {
  const CandidateHomePage({super.key});

  @override
  ConsumerState<CandidateHomePage> createState() => _CandidateHomePageState();
}

class _CandidateHomePageState extends ConsumerState<CandidateHomePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkPendingMatch());
  }

  Future<void> _checkPendingMatch() async {
    try {
      final session = ref.read(sessionProvider);
      final matchRepo = ref.read(matchRepositoryProvider);
      final offerRepo = ref.read(jobOfferRepositoryProvider);

      final pending = await matchRepo.getPendingMatchAnimation(session.userId, session.userRole);
      if (pending == null || !mounted) return;

      final offer = await offerRepo.getOfferById(pending.jobOfferId);
      if (offer == null || !mounted) return;

      context.push('/match', extra: {
        'matchId': pending.matchId,
        'jobOfferTitle': offer.title,
        'companyName': offer.companyName,
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('SparkWork'),
        backgroundColor: AppColors.background,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bonjour, ${session.userName.split(' ').first} 👋',
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 4),
            const Text('Prêt à trouver votre prochain poste ?',
                style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 24),

            GestureDetector(
              onTap: () => context.go('/candidate/swipe'),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.swipe, color: Colors.white, size: 28),
                    ),
                    const SizedBox(height: 16),
                    const Text('Découvrir des offres',
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Text('Swipez pour trouver votre prochain emploi',
                        style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13)),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                      child: const Text('Commencer',
                          style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            const Text('Accès rapide',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: AppColors.textPrimary)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _QuickAction(
                    icon: Icons.favorite_outline,
                    label: 'Mes Matches',
                    color: AppColors.red,
                    onTap: () => context.go('/candidate/matches'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickAction(
                    icon: Icons.chat_bubble_outline,
                    label: 'Messages',
                    color: AppColors.primary,
                    onTap: () => context.go('/messages'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickAction(
                    icon: Icons.work_outline,
                    label: 'Offres',
                    color: AppColors.green,
                    onTap: () => context.go('/candidate/offers'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            GestureDetector(
              onTap: () => context.push('/candidate/liked-offers'),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: AppColors.redLight,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.thumb_up_outlined, color: AppColors.red, size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Mes offres likées',
                              style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                          SizedBox(height: 2),
                          Text('Retrouvez les offres que vous avez aimées',
                              style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textSecondary),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.orangeLight,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                children: [
                  Icon(Icons.lightbulb_outline, color: AppColors.orange),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Astuce : Complétez votre profil pour augmenter vos chances de match !',
                      style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const CandidateNavBar(currentIndex: 0),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}