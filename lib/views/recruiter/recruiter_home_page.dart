import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../repositories/job_offer_repository.dart';
import '../../repositories/match_repository.dart';
import '../../services/session_service.dart';
import '../shared/nav_bar.dart';

class RecruiterHomePage extends ConsumerStatefulWidget {
  const RecruiterHomePage({super.key});

  @override
  ConsumerState<RecruiterHomePage> createState() => _RecruiterHomePageState();
}

class _RecruiterHomePageState extends ConsumerState<RecruiterHomePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkPendingMatch());
  }

  Future<void> _checkPendingMatch() async {
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
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final displayName = session.userName.contains(' - ')
        ? session.userName.split(' - ').last
        : session.userName;

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
            Text('Bonjour, $displayName 👋',
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 4),
            const Text('Trouvez les meilleurs talents Horeca',
                style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 24),

            // CTA card
            GestureDetector(
              onTap: () => context.go('/recruiter/swipe'),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.green, Color(0xFF059669)],
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
                      child: const Icon(Icons.person_search, color: Colors.white, size: 28),
                    ),
                    const SizedBox(height: 16),
                    const Text('Explorer les candidats',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Text('Swipez pour trouver vos futurs collaborateurs',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.85), fontSize: 13)),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text('Commencer',
                          style: TextStyle(
                              color: AppColors.green,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            const Text('Accès rapide',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _QuickAction(
                    icon: Icons.add_circle_outline,
                    label: 'Ajouter offre',
                    color: AppColors.green,
                    onTap: () => context.push('/recruiter/offers/add'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickAction(
                    icon: Icons.favorite_outline,
                    label: 'Matches',
                    color: AppColors.red,
                    onTap: () => context.go('/recruiter/matches'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickAction(
                    icon: Icons.thumb_up_outlined,
                    label: 'Likes reçus',
                    color: AppColors.orange,
                    onTap: () => context.push('/recruiter/likes'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _QuickAction(
                    icon: Icons.work_outline,
                    label: 'Mes offres',
                    color: AppColors.primary,
                    onTap: () => context.go('/recruiter/offers'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickAction(
                    icon: Icons.people_outline,
                    label: 'Candidats',
                    color: AppColors.primaryDark,
                    onTap: () => context.push('/recruiter/candidates'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickAction(
                    icon: Icons.chat_bubble_outline,
                    label: 'Messages',
                    color: AppColors.green,
                    onTap: () => context.go('/messages'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: _QuickAction(
                icon: Icons.bar_chart_outlined,
                label: 'Statistiques',
                color: AppColors.primary,
                onTap: () => context.push('/recruiter/stats'),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const RecruiterNavBar(currentIndex: 0),
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
            Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}