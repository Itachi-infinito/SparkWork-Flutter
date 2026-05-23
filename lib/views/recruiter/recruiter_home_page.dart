import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_theme_ext.dart';
import '../../core/widgets/app_avatar.dart';
import '../../repositories/candidate_profile_repository.dart';
import '../../repositories/job_offer_repository.dart';
import '../../repositories/match_repository.dart';
import '../../repositories/recruiter_candidate_like_repository.dart';
import '../../services/session_service.dart';
import '../shared/nav_bar.dart';

class RecruiterHomePage extends ConsumerStatefulWidget {
  const RecruiterHomePage({super.key});

  @override
  ConsumerState<RecruiterHomePage> createState() =>
      _RecruiterHomePageState();
}

class _RecruiterHomePageState extends ConsumerState<RecruiterHomePage> {
  int _offersCount = 0;
  int _matchCount = 0;
  int _likesCount = 0;
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
    final profileRepo = ref.read(candidateProfileRepositoryProvider);
    final pending = await matchRepo.getPendingMatchAnimation(
        session.userId, session.userRole);
    if (pending == null || !mounted) return;
    final offer = await offerRepo.getOfferById(pending.jobOfferId);
    if (offer == null || !mounted) return;
    final candidateProfile =
        await profileRepo.getProfile(pending.candidateUserId);
    final candidateName = candidateProfile?.fullName ?? 'Un candidat';
    if (!mounted) return;
    context.push('/match', extra: {
      'matchId': pending.matchId,
      'jobOfferTitle': offer.title,
      'companyName': candidateName,
    });
  }

  Future<void> _loadStats() async {
    final session = ref.read(sessionProvider);
    final offerRepo = ref.read(jobOfferRepositoryProvider);
    final matchRepo = ref.read(matchRepositoryProvider);
    final likeRepo = ref.read(recruiterCandidateLikeRepositoryProvider);
    final profileRepo = ref.read(candidateProfileRepositoryProvider);

    final offers = await offerRepo.getOffersByRecruiter(session.userId);
    final matches = await matchRepo.getMatchesByRecruiter(session.userId);
    final likedIds = await likeRepo.getLikedCandidateIds(session.userId);

    final recent = <_RecentMatch>[];
    for (final m in matches.take(3)) {
      final profile = await profileRepo.getProfile(m.candidateUserId);
      final offer = await offerRepo.getOfferById(m.jobOfferId);
      if (profile != null && offer != null) {
        recent.add(_RecentMatch(
            matchId: m.matchId,
            candidateName: profile.fullName,
            offerTitle: offer.title));
      }
    }

    if (mounted) {
      setState(() {
        _offersCount = offers.length;
        _matchCount = matches.length;
        _likesCount = likedIds.length;
        _recentMatches = recent;
        _statsLoaded = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final displayName = session.userName.contains(' - ')
        ? session.userName.split(' - ').last
        : session.userName;

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
      body: RefreshIndicator(
        onRefresh: _loadStats,
        color: AppColors.green,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Bonjour, $displayName 👋',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: context.textPrimaryColor)),
              const SizedBox(height: 4),
              Text('Trouvez les meilleurs talents Horeca',
                  style:
                      TextStyle(color: context.textSecondaryColor)),
              const SizedBox(height: 20),

              // Stats
              if (_statsLoaded)
                Row(children: [
                  _StatTile(
                      label: 'Offres',
                      value: '$_offersCount',
                      icon: Icons.work_outline,
                      color: AppColors.primary),
                  const SizedBox(width: 10),
                  _StatTile(
                      label: 'Matches',
                      value: '$_matchCount',
                      icon: Icons.favorite_outline,
                      color: AppColors.red),
                  const SizedBox(width: 10),
                  _StatTile(
                      label: 'Swipés',
                      value: '$_likesCount',
                      icon: Icons.swipe_outlined,
                      color: AppColors.green),
                ])
              else
                Row(
                  children: List.generate(
                    3,
                    (_) => Expanded(
                      child: Container(
                        height: 72,
                        margin: const EdgeInsets.only(right: 10),
                        decoration: BoxDecoration(
                          color: context.surfaceVariantColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 20),

              // CTA
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
                        child: const Icon(Icons.person_search,
                            color: Colors.white, size: 28),
                      ),
                      const SizedBox(height: 16),
                      const Text('Explorer les candidats',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Text(
                          'Swipez pour trouver vos futurs collaborateurs',
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
                                color: AppColors.green,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Accès rapide
              Text('Accès rapide',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: context.textPrimaryColor)),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: _QuickAction(
                    icon: Icons.add_circle_outline,
                    label: 'Ajouter offre',
                    color: AppColors.green,
                    onTap: () =>
                        context.push('/recruiter/offers/add'),
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
                    icon: Icons.bar_chart_outlined,
                    label: 'Stats',
                    color: AppColors.primary,
                    onTap: () => context.push('/recruiter/stats'),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: _QuickAction(
                    icon: Icons.work_outline,
                    label: 'Mes offres',
                    color: AppColors.primaryDark,
                    onTap: () => context.go('/recruiter/offers'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickAction(
                    icon: Icons.people_outline,
                    label: 'Candidats',
                    color: AppColors.primary,
                    onTap: () =>
                        context.push('/recruiter/candidates'),
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
              ]),

              // Derniers matches
              if (_recentMatches.isNotEmpty) ...[
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Derniers matches',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: context.textPrimaryColor)),
                    TextButton(
                      onPressed: () =>
                          context.go('/recruiter/matches'),
                      child: const Text('Voir tout',
                          style: TextStyle(
                              color: AppColors.green,
                              fontSize: 13)),
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
            ],
          ),
        ),
      ),
      bottomNavigationBar: const RecruiterNavBar(currentIndex: 0),
    );
  }
}

class _RecentMatch {
  final int matchId;
  final String candidateName;
  final String offerTitle;
  _RecentMatch(
      {required this.matchId,
      required this.candidateName,
      required this.offerTitle});
}

class _RecentMatchTile extends StatelessWidget {
  final _RecentMatch match;
  final VoidCallback onMessage;
  const _RecentMatchTile(
      {required this.match, required this.onMessage});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.borderColor),
      ),
      child: Row(children: [
        AppAvatar(name: match.candidateName, radius: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(match.candidateName,
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: context.textPrimaryColor),
                  overflow: TextOverflow.ellipsis),
              Text(match.offerTitle,
                  style: TextStyle(
                      fontSize: 12,
                      color: context.textSecondaryColor),
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
        TextButton(
          onPressed: onMessage,
          style: TextButton.styleFrom(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: Size.zero),
          child: const Text('Message',
              style:
                  TextStyle(color: AppColors.green, fontSize: 12)),
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
        padding:
            const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.borderColor),
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
              style: TextStyle(
                  fontSize: 10,
                  color: context.textSecondaryColor)),
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
          color: context.surfaceColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.borderColor),
        ),
        child: Column(children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(height: 6),
          Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 11,
                  color: context.textSecondaryColor)),
        ]),
      ),
    );
  }
}