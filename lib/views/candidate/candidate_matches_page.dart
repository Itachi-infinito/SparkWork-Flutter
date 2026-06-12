import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_theme_ext.dart';
import '../../core/widgets/shimmer_loading.dart';
import '../../models/job_offer.dart';
import '../../models/match.dart';
import '../../repositories/candidate_job_like_repository.dart';
import '../../repositories/job_offer_repository.dart';
import '../../repositories/match_repository.dart';
import '../../repositories/rating_repository.dart';
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0D0117), Color(0xFF1E0A3C), AppColors.primary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
            ),
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: Row(
                      children: [
                        const Text('Activité',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  TabBar(
                    controller: _tabController,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white54,
                    indicatorColor: Colors.white,
                    indicatorSize: TabBarIndicatorSize.label,
                    tabs: [
                      Tab(child: _TabLabel(icon: Icons.favorite, label: 'Matches', count: _matches.length, active: true)),
                      Tab(child: _TabLabel(icon: Icons.bookmark_border, label: 'Mes likes', count: _likedOffers.length, active: false)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildMatchesTab(),
                _buildLikesTab(),
              ],
            ),
          ),
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
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: context.surfaceColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: context.borderColor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                  children: [
                    Container(
                      width: 52, height: 52,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.primaryDark, AppColors.primary],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.25),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(child: Text(offer.initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(offer.title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: context.textPrimaryColor)),
                          const SizedBox(height: 2),
                          Text(offer.companyName, style: TextStyle(color: context.textSecondaryColor, fontSize: 12)),
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
        Text('Pas encore de match', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: context.textPrimaryColor)),
        const SizedBox(height: 8),
        Text('Continuez à swiper pour trouver votre futur employeur !', textAlign: TextAlign.center, style: TextStyle(color: context.textSecondaryColor)),
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
        Text('Aucune offre likée', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: context.textPrimaryColor)),
        const SizedBox(height: 8),
        Text('Les offres que vous aimez apparaîtront ici.', textAlign: TextAlign.center, style: TextStyle(color: context.textSecondaryColor)),
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
    return Container(
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        // IntrinsicHeight + stretch : la barre d'accent suit la hauteur de la
        // carte sans contrainte infinie (crash) ni hauteur zéro (invisible).
        child: IntrinsicHeight(
          child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 4,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primaryDark, AppColors.primary],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  Container(
                    width: 56, height: 56,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primaryDark, AppColors.primary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                        child: Text(offer?.initials ?? '?',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18))),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(offer?.title ?? 'Offre supprimée',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: context.textPrimaryColor)),
                        if (offer?.companyName.isNotEmpty ?? false) ...[
                          const SizedBox(height: 2),
                          Text(offer!.companyName,
                              style: TextStyle(
                                  color: context.textSecondaryColor,
                                  fontSize: 13)),
                        ],
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 34,
                                child: ElevatedButton.icon(
                                  onPressed: onMessage,
                                  icon: const Icon(Icons.chat_bubble_outline,
                                      size: 14),
                                  label: const Text('Message',
                                      style: TextStyle(fontSize: 12)),
                                  style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8))),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _RateButton(
                              matchId: item.match.matchId,
                              toUserId: item.match.recruiterUserId,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ]),
              ),
            ),
          ],
          ),
        ),
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

class _RateButton extends ConsumerStatefulWidget {
  final String matchId;
  final String toUserId;
  const _RateButton({required this.matchId, required this.toUserId});
  @override
  ConsumerState<_RateButton> createState() => _RateButtonState();
}

class _RateButtonState extends ConsumerState<_RateButton> {
  int? _existingScore;
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    try {
      final session = ref.read(sessionProvider);
      final r = await ref
          .read(ratingRepositoryProvider)
          .getRatingForMatch(session.userId, widget.matchId);
      if (mounted) setState(() { _existingScore = r?.score; _checking = false; });
    } catch (_) {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _openDialog() async {
    int selected = _existingScore ?? 0;
    final comment = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Évaluer'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Votre expérience avec ce recruteur ?',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) => IconButton(
                  onPressed: () => setD(() => selected = i + 1),
                  icon: Icon(
                    selected >= i + 1 ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: selected >= i + 1
                        ? const Color(0xFFF59E0B)
                        : AppColors.textHint,
                    size: 36,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                )),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: comment,
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: 'Commentaire (optionnel)',
                  isDense: true,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: selected == 0 ? null : () => Navigator.pop(ctx, true),
              child: const Text('Envoyer'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    final session = ref.read(sessionProvider);
    await ref.read(ratingRepositoryProvider).addRating(
      fromUserId: session.userId,
      toUserId: widget.toUserId,
      matchId: widget.matchId,
      score: selected,
      comment: comment.text.trim(),
    );
    if (mounted) {
      setState(() => _existingScore = selected);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Évaluation envoyée !'),
        backgroundColor: AppColors.green,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const SizedBox(
          width: 34, height: 34,
          child: Center(child: SizedBox(width: 16, height: 16,
              child: CircularProgressIndicator(strokeWidth: 2))));
    }
    return SizedBox(
      height: 34,
      child: OutlinedButton.icon(
        onPressed: _openDialog,
        icon: Icon(
          _existingScore != null ? Icons.star_rounded : Icons.star_outline_rounded,
          size: 14,
          color: _existingScore != null
              ? const Color(0xFFF59E0B)
              : AppColors.textSecondary,
        ),
        label: Text(
          _existingScore != null ? '$_existingScore★' : 'Évaluer',
          style: TextStyle(
              fontSize: 12,
              color: _existingScore != null
                  ? const Color(0xFFF59E0B)
                  : AppColors.textSecondary),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          side: BorderSide(
              color: _existingScore != null
                  ? const Color(0xFFF59E0B)
                  : AppColors.border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}