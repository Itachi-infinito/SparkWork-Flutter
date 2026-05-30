import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/shimmer_loading.dart';
import '../../models/job_offer.dart';
import '../../models/match.dart';
import '../../repositories/candidate_job_like_repository.dart';
import '../../repositories/job_offer_repository.dart';
import '../../repositories/match_repository.dart';
import '../../services/session_service.dart';
import '../shared/nav_bar.dart';

class CandidateMatchesPage extends ConsumerStatefulWidget {
  const CandidateMatchesPage({super.key});

  @override
  ConsumerState<CandidateMatchesPage> createState() => _CandidateMatchesPageState();
}

class _CandidateMatchesPageState extends ConsumerState<CandidateMatchesPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<_MatchWithOffer> _matches = [];
  List<JobOffer> _likedOffers = [];
  bool _loadingMatches = true;
  bool _loadingLikes = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadMatches();
    _loadLikes();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadMatches() async {
    setState(() { _loadingMatches = true; _error = null; });
    try {
      final session = ref.read(sessionProvider);
      final matches = await ref.read(matchRepositoryProvider).getMatchesByCandidate(session.userId);
      final items = <_MatchWithOffer>[];
      for (final m in matches) {
        final offer = await ref.read(jobOfferRepositoryProvider).getOfferById(m.jobOfferId);
        items.add(_MatchWithOffer(match: m, offer: offer));
      }
      if (mounted) setState(() { _matches = items; _loadingMatches = false; });
    } catch (_) {
      if (mounted) setState(() { _error = 'Erreur lors du chargement.'; _loadingMatches = false; });
    }
  }

  Future<void> _loadLikes() async {
    setState(() => _loadingLikes = true);
    try {
      final session = ref.read(sessionProvider);
      final ids = await ref.read(candidateJobLikeRepositoryProvider).getLikedJobOfferIds(session.userId);
      final offers = <JobOffer>[];
      for (final id in ids) {
        final o = await ref.read(jobOfferRepositoryProvider).getOfferById(id);
        if (o != null) offers.add(o);
      }
      if (mounted) setState(() { _likedOffers = offers; _loadingLikes = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingLikes = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Activité'),
        backgroundColor: AppColors.background,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          indicatorSize: TabBarIndicatorSize.label,
          tabs: [
            Tab(child: _TabLabel(icon: Icons.favorite, label: 'Matches', count: _matches.length, active: true)),
            Tab(child: _TabLabel(icon: Icons.bookmark_border, label: 'Mes likes', count: _likedOffers.length, active: false)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMatchesTab(),
          _buildLikesTab(),
        ],
      ),
      bottomNavigationBar: const CandidateNavBar(currentIndex: 2),
    );
  }

  Widget _buildMatchesTab() {
    if (_loadingMatches) return SingleChildScrollView(child: Padding(padding: const EdgeInsets.only(top: 8), child: ShimmerList()));
    if (_error != null) return _buildError();
    if (_matches.isEmpty) return _buildEmptyMatches();
    return RefreshIndicator(
      onRefresh: _loadMatches,
      color: AppColors.primary,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _matches.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (ctx, i) {
          final item = _matches[i];
          return _MatchCard(item: item, onMessage: () => context.push('/messages/${item.match.matchId}'));
        },
      ),
    );
  }

  Widget _buildLikesTab() {
    if (_loadingLikes) return SingleChildScrollView(child: Padding(padding: const EdgeInsets.only(top: 8), child: ShimmerList()));
    if (_likedOffers.isEmpty) return _buildEmptyLikes();
    return RefreshIndicator(
      onRefresh: _loadLikes,
      color: AppColors.primary,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _likedOffers.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (ctx, i) {
          final offer = _likedOffers[i];
          return GestureDetector(
            onTap: () => context.push('/candidate/offers/${offer.jobOfferId}'),
            child: Card(
              elevation: 0,
              color: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: AppColors.border),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 52, height: 52,
                      decoration: const BoxDecoration(color: AppColors.primaryLight, shape: BoxShape.circle),
                      child: Center(child: Text(offer.initials, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 16))),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(offer.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary)),
                          const SizedBox(height: 2),
                          Text(offer.companyName, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                          if (offer.location.isNotEmpty)
                            Row(children: [
                              const Icon(Icons.location_on_outlined, size: 12, color: AppColors.textSecondary),
                              const SizedBox(width: 2),
                              Text(offer.location, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                            ]),
                          const SizedBox(height: 6),
                          Wrap(spacing: 4, children: [
                            if (offer.contractType.isNotEmpty) _SmallChip(label: offer.contractType),
                            if (offer.level.isNotEmpty) _SmallChip(label: offer.level),
                          ]),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: AppColors.textHint),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildError() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.error_outline, size: 56, color: AppColors.red),
        const SizedBox(height: 16),
        Text(_error!, style: const TextStyle(color: AppColors.textSecondary), textAlign: TextAlign.center),
        const SizedBox(height: 20),
        OutlinedButton(onPressed: _loadMatches, child: const Text('Réessayer')),
      ]),
    ),
  );

  Widget _buildEmptyMatches() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(width: 80, height: 80, decoration: const BoxDecoration(color: AppColors.redLight, shape: BoxShape.circle), child: const Icon(Icons.favorite, color: AppColors.red, size: 40)),
        const SizedBox(height: 20),
        const Text('Pas encore de match', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        const SizedBox(height: 8),
        const Text('Continuez à swiper pour trouver votre futur employeur !', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary)),
        const SizedBox(height: 24),
        ElevatedButton.icon(onPressed: () => context.go('/candidate/swipe'), icon: const Icon(Icons.swipe), label: const Text('Découvrir des offres')),
      ]),
    ),
  );

  Widget _buildEmptyLikes() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(width: 80, height: 80, decoration: const BoxDecoration(color: AppColors.primaryLight, shape: BoxShape.circle), child: const Icon(Icons.favorite_border, color: AppColors.primary, size: 40)),
        const SizedBox(height: 20),
        const Text('Aucune offre likée', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        const SizedBox(height: 8),
        const Text('Les offres que vous aimez apparaîtront ici.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary)),
        const SizedBox(height: 24),
        ElevatedButton.icon(onPressed: () => context.go('/candidate/swipe'), icon: const Icon(Icons.swipe), label: const Text('Découvrir des offres')),
      ]),
    ),
  );
}

class _TabLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final bool active;
  const _TabLabel({required this.icon, required this.label, required this.count, required this.active});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 15),
      const SizedBox(width: 5),
      Text(label),
      if (count > 0) ...[
        const SizedBox(width: 5),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            color: active ? AppColors.primary : AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text('$count', style: TextStyle(color: active ? Colors.white : AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold)),
        ),
      ],
    ]);
  }
}

class _MatchWithOffer {
  final Match match;
  final JobOffer? offer;
  _MatchWithOffer({required this.match, this.offer});
}

class _MatchCard extends StatelessWidget {
  final _MatchWithOffer item;
  final VoidCallback onMessage;
  const _MatchCard({required this.item, required this.onMessage});

  @override
  Widget build(BuildContext context) {
    final offer = item.offer;
    return Card(
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AppColors.border)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Container(
            width: 56, height: 56,
            decoration: const BoxDecoration(color: AppColors.primaryLight, shape: BoxShape.circle),
            child: Center(child: Text(offer?.initials ?? '?', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 18))),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(offer?.title ?? 'Offre supprimée', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary)),
            if (offer?.companyName.isNotEmpty ?? false) ...[
              const SizedBox(height: 2),
              Text(offer!.companyName, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            ],
            const SizedBox(height: 10),
            SizedBox(
              height: 34,
              child: ElevatedButton.icon(
                onPressed: onMessage,
                icon: const Icon(Icons.chat_bubble_outline, size: 14),
                label: const Text('Envoyer un message', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              ),
            ),
          ])),
        ]),
      ),
    );
  }
}

class _SmallChip extends StatelessWidget {
  final String label;
  const _SmallChip({required this.label});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(6)),
    child: Text(label, style: const TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.w500)),
  );
}