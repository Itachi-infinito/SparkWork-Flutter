import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_theme_ext.dart';
import '../../core/widgets/app_avatar.dart';
import '../../core/widgets/email_verification_banner.dart';
import '../../repositories/candidate_profile_repository.dart';
import '../../repositories/job_offer_repository.dart';
import '../../repositories/match_repository.dart';
import '../../repositories/recruiter_candidate_like_repository.dart';
import '../../services/session_service.dart';
import '../shared/nav_bar.dart';

class RecruiterHomePage extends ConsumerStatefulWidget {
  const RecruiterHomePage({super.key});

  @override
  ConsumerState<RecruiterHomePage> createState() => _RecruiterHomePageState();
}

class _RecruiterHomePageState extends ConsumerState<RecruiterHomePage> {
  int _offerCount = 0;
  int _matchCount = 0;
  int _swipedCount = 0;
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
    try {
      final session = ref.read(sessionProvider);
      final matchRepo = ref.read(matchRepositoryProvider);
      final offerRepo = ref.read(jobOfferRepositoryProvider);
      final profileRepo = ref.read(candidateProfileRepositoryProvider);

      final pending =
          await matchRepo.getPendingMatchAnimation(session.userId, session.userRole);
      if (pending == null || !mounted) return;

      final offer = await offerRepo.getOfferById(pending.jobOfferId);
      if (offer == null || !mounted) return;

      final candidateProfile = await profileRepo.getProfile(pending.candidateUserId);
      final candidateName = candidateProfile?.fullName ?? 'Un candidat';

      if (!mounted) return;
      context.push('/match', extra: {
        'matchId': pending.matchId,
        'jobOfferTitle': offer.title,
        'companyName': candidateName,
      });
    } catch (_) {}
  }

  Future<void> _loadStats() async {
    try {
      final session = ref.read(sessionProvider);
      final offerRepo = ref.read(jobOfferRepositoryProvider);
      final matchRepo = ref.read(matchRepositoryProvider);
      final likeRepo = ref.read(recruiterCandidateLikeRepositoryProvider);
      final profileRepo = ref.read(candidateProfileRepositoryProvider);

      final offers = await offerRepo.getOffersByRecruiter(session.userId);
      final matches = await matchRepo.getMatchesByRecruiter(session.userId);
      final likedIds = await likeRepo.getLikedCandidateIds(session.userId);

      final recent = <Map<String, dynamic>>[];
      for (final m in matches.take(3)) {
        final profile = await profileRepo.getProfile(m.candidateUserId);
        if (profile != null) {
          recent.add({'matchId': m.matchId, 'name': profile.fullName});
        }
      }

      if (mounted) {
        setState(() {
          _offerCount = offers.length;
          _matchCount = matches.length;
          _swipedCount = likedIds.length;
          _recentMatches = recent;
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final displayName = session.userName.contains(' - ')
        ? session.userName.split(' - ').last
        : session.userName;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Gradient hero header
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(
                  20, MediaQuery.of(context).padding.top + 16, 20, 28),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF064E3B), Color(0xFF059669), AppColors.green],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text('SparkWork',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.3)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.settings_outlined,
                            color: Colors.white),
                        onPressed: () => context.push('/settings'),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text('Bonjour, $displayName 👋',
                      style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                  const SizedBox(height: 4),
                  Text('Trouvez les meilleurs talents Horeca',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.75),
                          fontSize: 14)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
            const EmailVerificationBanner(),
            const SizedBox(height: 8),

            // Stats row
            Row(
              children: [
                _StatCard(label: 'Offres', value: '$_offerCount', color: AppColors.green),
                const SizedBox(width: 12),
                _StatCard(label: 'Matches', value: '$_matchCount', color: AppColors.red),
                const SizedBox(width: 12),
                _StatCard(label: 'Swipés', value: '$_swipedCount', color: AppColors.primary),
              ],
            ),
            const SizedBox(height: 20),

            // CTA swipe
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
                    Text('Swipez pour trouver vos futurs collaborateurs',
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
            const SizedBox(height: 12),
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
                    name: m['name'] as String,
                    matchId: m['matchId'] as String,
                    onMessage: () =>
                        context.push('/messages/${m['matchId']}'),
                  )),
            ],
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const RecruiterNavBar(currentIndex: 0),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatCard(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    fontSize: 24, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 3),
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    color: color.withOpacity(0.75),
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

class _RecentMatchTile extends StatelessWidget {
  final String name;
  final String matchId;
  final VoidCallback onMessage;
  const _RecentMatchTile(
      {required this.name, required this.matchId, required this.onMessage});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.green.withOpacity(0.07),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          AppAvatar(name: name, radius: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(name,
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: context.textPrimaryColor)),
          ),
          SizedBox(
            height: 32,
            child: ElevatedButton(
              onPressed: onMessage,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.green,
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
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 8),
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 11,
                    color: color,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}