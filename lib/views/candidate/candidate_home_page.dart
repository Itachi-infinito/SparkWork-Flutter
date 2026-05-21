import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_avatar.dart';
import '../../repositories/candidate_job_like_repository.dart';
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
  int _matchCount = 0;
  int _availableOffers = 0;
  bool _hasUnread = false;
  List<_RecentMatch> _recentMatches = [];
  bool _statsLoaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPendingMatch();
      _loadStats();
    });
  }

  Future<void> _checkPendingMatch() async {
    final session = ref.read(sessionProvider);
    final matchRepo = ref.read(matchRepositoryProvider);
    final offerRepo = ref.read(jobOfferRepositoryProvider);
    final pending = await matchRepo.getPendingMatchAnimation(
        session.userId, session.userRole);
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
    final likeRepo = ref.read(candidateJobLikeRepositoryProvider);

    final matches = await matchRepo.getMatchesByCandidate(session.userId);
    final allOffers = await offerRepo.getAllOffers();
    final likedIds = await likeRepo.getLikedJobOfferIds(session.userId);
    final likedSet = likedIds.toSet();
    final available =
        allOffers.where((o) => !likedSet.contains(o.jobOfferId)).length;

    final hasUnread =
        await ref.read(unreadMessagesProvider.future).catchError((_) => false);

    final recent = <_RecentMatch>[];
    for (final m in matches.take(3)) {
      final offer = await offerRepo.getOfferById(m.jobOfferId);
      if (offer != null) {
        recent.add(_RecentMatch(
            matchId: m.matchId,
            title: offer.title,
            company: offer.companyName));
      }
    }

    if (mounted) {
      setState(() {
        _matchCount = matches.length;
        _availableOffers = available;
        _hasUnread = hasUnread;
        _recentMatches = recent;
        _statsLoaded = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final firstName = session.userName.split(' ').first;

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
      body: RefreshIndicator(
        onRefresh: _loadStats,
        color: AppColors.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Bonjour, $firstName 👋',
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 4),
              const Text('Prêt à trouver votre prochain poste ?',
                  style: TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 20),

              // Stats row
              if (_statsLoaded)
                Row(children: [
                  _StatTile(
                    label: 'Offres',
                    value: '$_availableOffers',
                    icon: Icons.work_outline,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 10),
                  _StatTile(
                    label: 'Matches',
                    value: '$_matchCount',
                    icon: Icons.favorite_outline,
                    color: AppColors.red,
                  ),
                  const SizedBox(width: 10),
                  _StatTile(
                    label: 'Messages',
                    value: _hasUnread ? '🔴' : '✓',
                    icon: Icons.chat_bubble_outline,
                    color: _hasUnread ? AppColors.orange : AppColors.green,
                  ),
                ])
              else
                Row(children: List.generate(
                  3,
                  (_) => Expanded(
                    child: Container(
                      height: 72,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                )),

              const SizedBox(height: 20),

              // CTA card
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
                        child: const Icon(Icons.swipe,
                            color: Colors.white, size: 28),
                      ),
                      const SizedBox(height: 16),
                      const Text('Découvrir des offres',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Text('Swipez pour trouver votre prochain emploi',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.85),
                              fontSize: 13)),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10)),
                        child: const Text('Commencer',
                            style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Accès rapide
              const Text('Accès rapide',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: _QuickAction(
                    icon: Icons.favorite_outline,
                    label: 'Matches',
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
              ]),

              // Derniers matches
              if (_recentMatches.isNotEmpty) ...[
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Derniers matches',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: AppColors.textPrimary)),
                    TextButton(
                      onPressed: () => context.go('/candidate/matches'),
                      child: const Text('Voir tout',
                          style: TextStyle(
                              color: AppColors.primary, fontSize: 13)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ..._recentMatches.map((m) => _RecentMatchTile(
                      match: m,
                      onMessage: () =>
                          context.push('/messages/${m.matchId}'),
                    )),
              ],

              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.orangeLight,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Row(children: [
                  Icon(Icons.lightbulb_outline, color: AppColors.orange),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Astuce : Complétez votre profil pour augmenter vos chances de match !',
                      style: TextStyle(
                          fontSize: 13, color: AppColors.textPrimary),
                    ),
                  ),
                ]),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const CandidateNavBar(currentIndex: 0),
    );
  }
}

class _RecentMatch {
  final int matchId;
  final String title;
  final String company;
  _RecentMatch(
      {required this.matchId, required this.title, required this.company});
}

class _RecentMatchTile extends StatelessWidget {
  final _RecentMatch match;
  final VoidCallback onMessage;
  const _RecentMatchTile({required this.match, required this.onMessage});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(children: [
        AppAvatar(name: match.company, radius: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(match.title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: AppColors.textPrimary),
                  overflow: TextOverflow.ellipsis),
              Text(match.company,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
        ),
        TextButton(
          onPressed: onMessage,
          style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: Size.zero),
          child: const Text('Message',
              style: TextStyle(color: AppColors.primary, fontSize: 12)),
        ),
      ]),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatTile(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color)),
          Text(label,
              style: const TextStyle(
                  fontSize: 10, color: AppColors.textSecondary)),
        ]),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickAction(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

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
        child: Column(children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(height: 6),
          Text(label,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textSecondary)),
        ]),
      ),
    );
  }
}