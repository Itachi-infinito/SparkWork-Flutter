import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../models/candidate_profile.dart';
import '../../models/job_offer.dart';
import '../../models/match.dart';
import '../../repositories/candidate_profile_repository.dart';
import '../../repositories/job_offer_repository.dart';
import '../../repositories/match_repository.dart';
import '../../services/session_service.dart';
import '../shared/nav_bar.dart';
import '../../core/widgets/app_avatar.dart';

class RecruiterMatchesPage extends ConsumerStatefulWidget {
  const RecruiterMatchesPage({super.key});

  @override
  ConsumerState<RecruiterMatchesPage> createState() =>
      _RecruiterMatchesPageState();
}

class _RecruiterMatchesPageState
    extends ConsumerState<RecruiterMatchesPage> {
  List<_MatchItem> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final session = ref.read(sessionProvider);
    final matches = await ref
        .read(matchRepositoryProvider)
        .getMatchesByRecruiter(session.userId);
    final items = <_MatchItem>[];
    for (final m in matches) {
      final candidate = await ref
          .read(candidateProfileRepositoryProvider)
          .getProfile(m.candidateUserId);
      final offer = await ref
          .read(jobOfferRepositoryProvider)
          .getOfferById(m.jobOfferId);
      items.add(_MatchItem(match: m, candidate: candidate, offer: offer));
    }
    if (mounted) setState(() { _items = items; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Mes matches'),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.green))
          : _items.isEmpty
              ? _buildEmpty()
              : _buildList(),
      bottomNavigationBar: const RecruiterNavBar(currentIndex: 3),
    );
  }

  Widget _buildEmpty() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80, height: 80,
                decoration: const BoxDecoration(
                    color: AppColors.redLight, shape: BoxShape.circle),
                child: const Icon(Icons.favorite,
                    color: AppColors.red, size: 40),
              ),
              const SizedBox(height: 20),
              const Text('Pas encore de match',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              const Text(
                  'Continuez à swiper pour matcher avec des candidats !',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => context.go('/recruiter/swipe'),
                icon: const Icon(Icons.swipe),
                label: const Text('Découvrir des candidats'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.green),
              ),
            ],
          ),
        ),
      );

  Widget _buildList() => RefreshIndicator(
        onRefresh: _load,
        color: AppColors.green,
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: _items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (ctx, i) {
            final item = _items[i];
            final name = item.candidate?.fullName ?? 'Candidat inconnu';
            final initials = item.candidate?.initials ?? '?';
            final offerTitle = item.offer?.title ?? 'Offre supprimée';
            return Card(
              elevation: 0,
              color: AppColors.surface,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: AppColors.border)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    AppAvatar(name: name, radius: 28),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: AppColors.textPrimary)),
                          const SizedBox(height: 2),
                          Text(offerTitle,
                              style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13)),
                          const SizedBox(height: 10),
                          SizedBox(
                            height: 34,
                            child: ElevatedButton.icon(
                              onPressed: () => context.push(
                                  '/messages/${item.match.matchId}'),
                              icon: const Icon(
                                  Icons.chat_bubble_outline,
                                  size: 14),
                              label: const Text('Message',
                                  style: TextStyle(fontSize: 12)),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.green,
                                  padding:
                                      const EdgeInsets.symmetric(
                                          horizontal: 12),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(8))),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
}

class _MatchItem {
  final Match match;
  final CandidateProfile? candidate;
  final JobOffer? offer;
  _MatchItem({required this.match, this.candidate, this.offer});
}