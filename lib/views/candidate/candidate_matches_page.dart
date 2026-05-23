import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../models/job_offer.dart';
import '../../models/match.dart';
import '../../repositories/job_offer_repository.dart';
import '../../repositories/match_repository.dart';
import '../../services/session_service.dart';
import '../shared/nav_bar.dart';
import '../../core/widgets/app_avatar.dart';

class CandidateMatchesPage extends ConsumerStatefulWidget {
  const CandidateMatchesPage({super.key});

  @override
  ConsumerState<CandidateMatchesPage> createState() =>
      _CandidateMatchesPageState();
}

class _CandidateMatchesPageState extends ConsumerState<CandidateMatchesPage> {
  List<_MatchWithOffer> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMatches();
  }

  Future<void> _loadMatches() async {
    setState(() { _loading = true; _error = null; });
    try {
      final session = ref.read(sessionProvider);
      final matchRepo = ref.read(matchRepositoryProvider);
      final offerRepo = ref.read(jobOfferRepositoryProvider);
      final matches = await matchRepo.getMatchesByCandidate(session.userId);
      final items = <_MatchWithOffer>[];
      for (final match in matches) {
        final offer = await offerRepo.getOfferById(match.jobOfferId);
        items.add(_MatchWithOffer(match: match, offer: offer));
      }
      if (mounted) setState(() { _items = items; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = 'Erreur lors du chargement des matches.'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes matches'),
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? _buildError()
              : _items.isEmpty
                  ? _buildEmpty()
                  : _buildList(),
      bottomNavigationBar: const CandidateNavBar(currentIndex: 2),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 56, color: AppColors.red),
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: AppColors.textSecondary), textAlign: TextAlign.center),
            const SizedBox(height: 20),
            OutlinedButton(onPressed: _loadMatches, child: const Text('Réessayer')),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80, height: 80,
              decoration: const BoxDecoration(color: AppColors.redLight, shape: BoxShape.circle),
              child: const Icon(Icons.favorite, color: AppColors.red, size: 40),
            ),
            const SizedBox(height: 20),
            const Text('Pas encore de match', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            const Text('Continuez à swiper pour trouver votre futur employeur !', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => context.go('/candidate/swipe'),
              icon: const Icon(Icons.swipe),
              label: const Text('Découvrir des offres'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    return RefreshIndicator(
      onRefresh: _loadMatches,
      color: AppColors.primary,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final item = _items[index];
          return _MatchCard(item: item, onMessage: () => context.push('/messages/${item.match.matchId}'));
        },
      ),
    );
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
    final title = offer?.title ?? 'Offre supprimée';
    final company = offer?.companyName ?? '';
    final initials = offer?.initials ?? '?';

    return Card(
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            AppAvatar(name: title, radius: 28),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary)),
                  if (company.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(company, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}