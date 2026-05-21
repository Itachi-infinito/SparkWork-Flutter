import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../models/candidate_profile.dart';
import '../../repositories/candidate_profile_repository.dart';
import '../../repositories/recruiter_candidate_like_repository.dart';
import '../../services/session_service.dart';
import '../../core/widgets/app_avatar.dart';

class LikesReceivedPage extends ConsumerStatefulWidget {
  const LikesReceivedPage({super.key});

  @override
  ConsumerState<LikesReceivedPage> createState() =>
      _LikesReceivedPageState();
}

class _LikesReceivedPageState extends ConsumerState<LikesReceivedPage> {
  List<CandidateProfile> _candidates = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final session = ref.read(sessionProvider);
    final likedIds = await ref
        .read(recruiterCandidateLikeRepositoryProvider)
        .getLikedCandidateIds(session.userId);
    final all = await ref
        .read(candidateProfileRepositoryProvider)
        .getAllProfiles();
    final liked =
        all.where((p) => likedIds.contains(p.userId)).toList();
    if (mounted) setState(() { _candidates = liked; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Candidats likés'),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                  color: AppColors.orange))
          : _candidates.isEmpty
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
                decoration: const BoxDecoration(
                    color: AppColors.orangeLight,
                    shape: BoxShape.circle),
                child: const Icon(Icons.thumb_up_outlined,
                    color: AppColors.orange, size: 40),
              ),
              const SizedBox(height: 20),
              const Text('Aucun like envoyé',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              const Text(
                  'Les candidats que vous aimez apparaîtront ici.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => context.go('/recruiter/swipe'),
                icon: const Icon(Icons.swipe),
                label: const Text('Swiper des candidats'),
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
          itemCount: _candidates.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (ctx, i) {
            final c = _candidates[i];
            return GestureDetector(
              onTap: () =>
                  context.push('/recruiter/candidates/${c.userId}'),
              child: Card(
                elevation: 0,
                color: AppColors.surface,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: AppColors.border)),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      AppAvatar(name: c.fullName, radius: 26),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(c.fullName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: AppColors.textPrimary)),
                            if (c.location.isNotEmpty)
                              Text(c.location,
                                  style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12)),
                            if (c.skillList.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 4,
                                children: c.skillList
                                    .take(3)
                                    .map((s) => Container(
                                          padding: const EdgeInsets
                                              .symmetric(
                                              horizontal: 8,
                                              vertical: 2),
                                          decoration: BoxDecoration(
                                              color: AppColors
                                                  .orangeLight,
                                              borderRadius:
                                                  BorderRadius
                                                      .circular(20)),
                                          child: Text(s,
                                              style: const TextStyle(
                                                  color: AppColors
                                                      .orange,
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
              ),
            );
          },
        ),
      );
}