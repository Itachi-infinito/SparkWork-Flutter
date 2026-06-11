import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_avatar.dart';
import '../../models/candidate_profile.dart';
import '../../models/job_offer.dart';
import '../../repositories/candidate_job_like_repository.dart';
import '../../repositories/candidate_profile_repository.dart';
import '../../repositories/job_offer_repository.dart';
import '../../services/session_service.dart';

class LikesReceivedPage extends ConsumerStatefulWidget {
  const LikesReceivedPage({super.key});

  @override
  ConsumerState<LikesReceivedPage> createState() =>
      _LikesReceivedPageState();
}

class _LikesReceivedItem {
  final CandidateProfile profile;
  final JobOffer offer;
  final bool isSuperLike;
  const _LikesReceivedItem(
      {required this.profile, required this.offer, required this.isSuperLike});
}

class _LikesReceivedPageState extends ConsumerState<LikesReceivedPage> {
  List<_LikesReceivedItem> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final session = ref.read(sessionProvider);
      final offerRepo = ref.read(jobOfferRepositoryProvider);
      final likeRepo = ref.read(candidateJobLikeRepositoryProvider);
      final profileRepo = ref.read(candidateProfileRepositoryProvider);

      // 1. Get all this recruiter's offers
      final myOffers = await offerRepo.getOffersByRecruiter(session.userId);
      if (myOffers.isEmpty) {
        if (mounted) setState(() { _items = []; _loading = false; });
        return;
      }

      final offerMap = {for (final o in myOffers) o.jobOfferId: o};

      // 2. Get all likes received on those offers
      final likes = await likeRepo.getLikesReceivedForOffers(
          myOffers.map((o) => o.jobOfferId).toList());

      // 3. Deduplicate by candidateUserId (keep latest / most recent)
      final seen = <String>{};
      final unique = likes
          .where((l) => seen.add(l['candidateUserId'] as String))
          .toList();

      // 4. Load candidate profiles
      final items = <_LikesReceivedItem>[];
      for (final like in unique) {
        final candidateId = like['candidateUserId'] as String;
        final offerId = like['jobOfferId'] as String;
        final offer = offerMap[offerId];
        if (offer == null) continue;
        final profile = await profileRepo.getProfile(candidateId);
        if (profile == null) continue;
        items.add(_LikesReceivedItem(
          profile: profile,
          offer: offer,
          isSuperLike: like['isSuperLike'] as bool,
        ));
      }

      if (mounted) setState(() { _items = items; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Likes reçus'),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.orange))
          : _items.isEmpty
              ? _buildEmpty()
              : _buildList(),
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
                decoration: BoxDecoration(
                    color: AppColors.orange.withOpacity(0.1),
                    shape: BoxShape.circle),
                child: const Icon(Icons.thumb_up_outlined,
                    color: AppColors.orange, size: 40),
              ),
              const SizedBox(height: 20),
              const Text('Aucun like reçu',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              const Text(
                  'Les candidats qui ont liké vos offres apparaîtront ici.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => context.go('/recruiter/offers/add'),
                icon: const Icon(Icons.add),
                label: const Text('Publier une offre'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.orange),
              ),
            ],
          ),
        ),
      );

  Widget _buildList() => RefreshIndicator(
        onRefresh: _load,
        color: AppColors.orange,
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: _items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (ctx, i) {
            final item = _items[i];
            final c = item.profile;
            return GestureDetector(
              onTap: () =>
                  context.push('/recruiter/candidates/${c.userId}'),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Stack(
                      children: [
                        AppAvatar(name: c.fullName, radius: 26),
                        if (item.isSuperLike)
                          Positioned(
                            bottom: 0, right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(
                                  color: AppColors.orange,
                                  shape: BoxShape.circle),
                              child: const Icon(Icons.bolt,
                                  color: Colors.white, size: 10),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(c.fullName,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: AppColors.textPrimary)),
                              ),
                              if (item.isSuperLike)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.orangeLight,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text('Super',
                                      style: TextStyle(
                                          color: AppColors.orange,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold)),
                                ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text('sur "${item.offer.title}"',
                              style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12)),
                          if (c.location.isNotEmpty)
                            Text(c.location,
                                style: const TextStyle(
                                    color: AppColors.textHint,
                                    fontSize: 11)),
                          if (c.skillList.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 4,
                              children: c.skillList
                                  .take(3)
                                  .map((s) => Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                            color: AppColors.orangeLight,
                                            borderRadius:
                                                BorderRadius.circular(20)),
                                        child: Text(s,
                                            style: const TextStyle(
                                                color: AppColors.orange,
                                                fontSize: 10)),
                                      ))
                                  .toList(),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right,
                        color: AppColors.textHint),
                  ],
                ),
              ),
            );
          },
        ),
      );
}
