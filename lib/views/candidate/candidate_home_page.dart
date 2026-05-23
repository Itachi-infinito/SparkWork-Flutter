import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_theme_ext.dart';
import '../../core/widgets/app_avatar.dart';
import '../../repositories/job_offer_repository.dart';
import '../../repositories/match_repository.dart';
import '../../services/session_service.dart';
import '../../services/unread_service.dart';
import '../shared/nav_bar.dart';

class CandidateHomePage extends ConsumerStatefulWidget {
  const CandidateHomePage({super.key});

  @override
  ConsumerState<CandidateHomePage> createState() => _CandidateHomePageState();
}

class _CandidateHomePageState extends ConsumerState<CandidateHomePage> {
  int _offerCount = 0;
  int _matchCount = 0;
  List<Map<String, dynamic>> _recentMatches = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _checkPendingMatch();
      await _loadStats();
    });
  }

  Future<void> _checkPendingMatch() async {
    final session = ref.read(sessionProvider);
    final matchRepo = ref.read(matchRepositoryProvider);
    final offerRepo = ref.read(jobOfferRepositoryProvider);

    final pending =
        await matchRepo.getPendingMatchAnimation(session.userId, session.userRole);
    if (pending == null || !mounted) return;

    final offer = await offerRepo.getOfferById(pending.jobOfferId);
    if (offer == null || !mounted) return;

    context.push('/match', extra: {
      'matchId': pending.matchId,
      'jobOfferTitle': offer.title,
      'companyName': offer.companyName,
    });
  }

  Future<void> _loadStats() async {
    final session = ref.read(sessionProvider);
    final matchRepo = ref.read(matchRepositoryProvider);
    final offerRepo = ref.read(jobOfferRepositoryProvider);

    final allOffers = await offerRepo.getAllOffers();
    final matches = await matchRepo.getMatchesByCandidate(session.userId);

    final recent = <Map<String, dynamic>>[];
    for (final m in matches.take(3)) {
      final offer = await offerRepo.getOfferById(m.jobOfferId);
      if (offer != null) {
        recent.add({'matchId': m.matchId, 'title': offer.title, 'company': offer.companyName});
      }
    }

    if (mounted) {
      setState(() {
        _offerCount = allOffers.length;
        _matchCount = matches.length;
        _recentMatches = recent;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final hasUnread = (ref.watch(unreadMessagesProvider).asData?.value as bool?) ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('SparkWork'),
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
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: context.textPrimaryColor)),
            const SizedBox(height: 4),
            Text('Prêt à trouver votre prochain poste ?',
                style: TextStyle(color: context.textSecondaryColor)),
            const SizedBox(height: 20),

            // Stats row
            Row(
              children: [
                _StatCard(label: 'Offres', value: '$_offerCount', color: AppColors.primary),
                const SizedBox(width: 12),
                _StatCard(label: 'Matches', value: '$_matchCount', color: AppColors.red),
                const SizedBox(width: 12),
                _StatCardWithBadge(
                  label: 'Messages',
                  value: hasUnread ? '!' : '—',
                  color: AppColors.green,
                  hasBadge: hasUnread,
                  onTap: () => context.go('/messages'),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // CTA swipe
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
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Text('Swipez pour trouver votre prochain emploi',
                        style:
                            TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13)),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                          color: Colors.white, borderRadius: BorderRadius.circular(10)),
                      child: const Text('Commencer',
                          style: TextStyle(
                              color: AppColors.primary, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Quick actions
            Text('Accès rapide',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: context.textPrimaryColor)),
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

            // Recent matches
            if (_recentMatches.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text('Derniers matches',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: context.textPrimaryColor)),
              const SizedBox(height: 12),
              ..._recentMatches.map((m) => _RecentMatchTile(
                    title: m['title'] as String,
                    company: m['company'] as String,
                    matchId: m['matchId'] as int,
                    onMessage: () =>
                        context.push('/messages/${m['matchId']}'),
                  )),
            ],

            const SizedBox(height: 24),
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

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatCard({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.borderColor),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(fontSize: 11, color: context.textSecondaryColor)),
          ],
        ),
      ),
    );
  }
}

class _StatCardWithBadge extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool hasBadge;
  final VoidCallback onTap;
  const _StatCardWithBadge(
      {required this.label,
      required this.value,
      required this.color,
      required this.hasBadge,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: context.surfaceColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: hasBadge ? color : context.borderColor, width: hasBadge ? 1.5 : 1),
          ),
          child: Column(
            children: [
              Text(value,
                  style: TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold, color: color)),
              const SizedBox(height: 2),
              Text(label,
                  style: TextStyle(fontSize: 11, color: context.textSecondaryColor)),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentMatchTile extends StatelessWidget {
  final String title;
  final String company;
  final int matchId;
  final VoidCallback onMessage;
  const _RecentMatchTile(
      {required this.title,
      required this.company,
      required this.matchId,
      required this.onMessage});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.borderColor),
      ),
      child: Row(
        children: [
          AppAvatar(name: title, radius: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: context.textPrimaryColor)),
                Text(company,
                    style: TextStyle(
                        fontSize: 12, color: context.textSecondaryColor)),
              ],
            ),
          ),
          SizedBox(
            height: 32,
            child: ElevatedButton(
              onPressed: onMessage,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                minimumSize: Size.zero,
              ),
              child: const Text('Message', style: TextStyle(fontSize: 12)),
            ),
          ),
        ],
      ),
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
          color: context.surfaceColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.borderColor),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 6),
            Text(label,
                style: TextStyle(fontSize: 11, color: context.textSecondaryColor)),
          ],
        ),
      ),
    );
  }
}