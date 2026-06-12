import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_theme_ext.dart';
import '../../models/candidate_profile.dart';
import '../../models/job_offer.dart';
import '../../models/match.dart';
import '../../repositories/candidate_profile_repository.dart';
import '../../repositories/job_offer_repository.dart';
import '../../repositories/match_repository.dart';
import '../../repositories/rating_repository.dart';
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Mes matches'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
              Text('Pas encore de match',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: context.textPrimaryColor)),
              const SizedBox(height: 8),
              Text(
                  'Continuez à swiper pour matcher avec des candidats !',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.textSecondaryColor)),
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
            return Container(
              decoration: BoxDecoration(
                color: context.surfaceColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.green.withOpacity(0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                // IntrinsicHeight + stretch : barre d'accent à hauteur de carte
                child: IntrinsicHeight(
                  child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: 4,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF059669), AppColors.green],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                    Expanded(
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
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: context.textPrimaryColor)),
                                  const SizedBox(height: 2),
                                  Text(offerTitle,
                                      style: TextStyle(
                                          color: context.textSecondaryColor,
                                          fontSize: 13)),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
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
                                      const SizedBox(width: 8),
                                      _RateButton(
                                        matchId: item.match.matchId,
                                        toUserId: item.match.candidateUserId,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  ),
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
              Text('Votre expérience avec ce candidat ?',
                  style: TextStyle(fontSize: 13, color: context.textSecondaryColor)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) => IconButton(
                  onPressed: () => setD(() => selected = i + 1),
                  icon: Icon(
                    selected >= i + 1 ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: selected >= i + 1
                        ? const Color(0xFFF59E0B)
                        : context.textHintColor,
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
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.green),
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
              child: CircularProgressIndicator(strokeWidth: 2,
                  color: AppColors.green))));
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
              : context.textSecondaryColor,
        ),
        label: Text(
          _existingScore != null ? '$_existingScore★' : 'Évaluer',
          style: TextStyle(
              fontSize: 12,
              color: _existingScore != null
                  ? const Color(0xFFF59E0B)
                  : context.textSecondaryColor),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          side: BorderSide(
              color: _existingScore != null
                  ? const Color(0xFFF59E0B)
                  : context.borderColor),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}
