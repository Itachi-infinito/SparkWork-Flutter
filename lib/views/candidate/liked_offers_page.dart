import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../models/job_offer.dart';
import '../../repositories/candidate_job_like_repository.dart';
import '../../repositories/job_offer_repository.dart';
import '../../services/session_service.dart';
import '../shared/nav_bar.dart';

class LikedOffersPage extends ConsumerStatefulWidget {
  const LikedOffersPage({super.key});

  @override
  ConsumerState<LikedOffersPage> createState() => _LikedOffersPageState();
}

class _LikedOffersPageState extends ConsumerState<LikedOffersPage> {
  final _searchCtrl = TextEditingController();
  List<JobOffer> _all = [];
  List<JobOffer> _filtered = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(_filter);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final session = ref.read(sessionProvider);
      final likeRepo = ref.read(candidateJobLikeRepositoryProvider);
      final offerRepo = ref.read(jobOfferRepositoryProvider);

      final likedIds = await likeRepo.getLikedJobOfferIds(session.userId);
      final offers = <JobOffer>[];
      for (final id in likedIds) {
        final offer = await offerRepo.getOfferById(id);
        if (offer != null) offers.add(offer);
      }

      if (mounted) {
        setState(() {
          _all = offers;
          _filtered = offers;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _filter() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered = _all.where((o) =>
          o.title.toLowerCase().contains(q) ||
          o.companyName.toLowerCase().contains(q) ||
          o.location.toLowerCase().contains(q)).toList();
    });
  }

  Future<void> _unlike(JobOffer offer) async {
    final session = ref.read(sessionProvider);
    await ref.read(candidateJobLikeRepositoryProvider)
        .removeLike(session.userId, offer.jobOfferId);
    setState(() {
      _all.removeWhere((o) => o.jobOfferId == offer.jobOfferId);
      _filtered.removeWhere((o) => o.jobOfferId == offer.jobOfferId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Mes offres likées'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Rechercher par titre, entreprise...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          _filter();
                        },
                      )
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _filtered.isEmpty
                    ? _buildEmpty()
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filtered.length,
                        itemBuilder: (context, i) => _LikedOfferCard(
                          offer: _filtered[i],
                          onUnlike: () => _unlike(_filtered[i]),
                        ),
                      ),
          ),
        ],
      ),
      bottomNavigationBar: const CandidateNavBar(currentIndex: 0),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: AppColors.redLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.thumb_up_outlined, color: AppColors.red, size: 40),
          ),
          const SizedBox(height: 20),
          const Text(
            'Aucune offre likée',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 8),
          const Text(
            'Swipez à droite sur les offres qui vous intéressent !',
            style: TextStyle(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => context.go('/candidate/swipe'),
            icon: const Icon(Icons.swipe, color: Colors.white),
            label: const Text('Découvrir des offres', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
          ),
        ],
      ),
    );
  }
}

class _LikedOfferCard extends StatelessWidget {
  final JobOffer offer;
  final VoidCallback onUnlike;
  const _LikedOfferCard({required this.offer, required this.onUnlike});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/candidate/offers/${offer.jobOfferId}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.primaryLight,
              child: Text(
                offer.initials,
                style: const TextStyle(
                    color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(offer.title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text(offer.companyName,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 12, color: AppColors.textSecondary),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          offer.location,
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (offer.contractType.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(offer.contractType,
                              style: const TextStyle(color: AppColors.primary, fontSize: 10)),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.thumb_down_outlined, color: AppColors.red, size: 20),
              tooltip: 'Retirer le like',
              onPressed: onUnlike,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}
