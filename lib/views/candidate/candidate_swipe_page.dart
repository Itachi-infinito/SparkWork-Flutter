import 'package:appinio_swiper/appinio_swiper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../models/candidate_profile.dart';
import '../../models/job_offer.dart';
import '../../repositories/candidate_job_like_repository.dart';
import '../../repositories/candidate_profile_repository.dart';
import '../../repositories/job_offer_repository.dart';
import '../../repositories/match_repository.dart';
import '../../repositories/recruiter_candidate_like_repository.dart';
import '../../services/compatibility_service.dart';
import '../../services/session_service.dart';
import '../shared/nav_bar.dart';

class CandidateSwipePage extends ConsumerStatefulWidget {
  const CandidateSwipePage({super.key});

  @override
  ConsumerState<CandidateSwipePage> createState() => _CandidateSwipePageState();
}

class _CandidateSwipePageState extends ConsumerState<CandidateSwipePage> {
  final AppinioSwiperController _swiperController = AppinioSwiperController();

  List<JobOffer> _offers = [];
  CandidateProfile? _candidateProfile;
  Map<int, int> _scores = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _swiperController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() { _loading = true; _error = null; });
    try {
      final session = ref.read(sessionProvider);
      final userId = session.userId;
      final jobOfferRepo = ref.read(jobOfferRepositoryProvider);
      final likeRepo = ref.read(candidateJobLikeRepositoryProvider);
      final profileRepo = ref.read(candidateProfileRepositoryProvider);
      final compatService = ref.read(compatibilityServiceProvider);

      final allOffers = await jobOfferRepo.getAllOffers();
      final likedIds = await likeRepo.getLikedJobOfferIds(userId);
      final likedSet = likedIds.toSet();
      final filtered = allOffers.where((o) => !likedSet.contains(o.jobOfferId)).toList();
      final profile = await profileRepo.getProfile(userId);

      final scores = <int, int>{};
      if (profile != null) {
        for (final offer in filtered) {
          scores[offer.jobOfferId] = compatService.calculateScore(profile, offer);
        }
      }

      if (mounted) {
        setState(() {
          _offers = filtered;
          _candidateProfile = profile;
          _scores = scores;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = 'Erreur lors du chargement des offres.'; _loading = false; });
    }
  }

  Future<void> _handleSwipeRight(JobOffer offer) async {
    final session = ref.read(sessionProvider);
    final candidateUserId = session.userId;
    final likeRepo = ref.read(candidateJobLikeRepositoryProvider);
    final recruiterLikeRepo = ref.read(recruiterCandidateLikeRepositoryProvider);
    final matchRepo = ref.read(matchRepositoryProvider);

    await likeRepo.addLike(candidateUserId, offer.jobOfferId);

    final recruiterUserId = offer.recruiterUserId;
    final mutual = await recruiterLikeRepo.hasRecruiterLikedCandidate(
        recruiterUserId, candidateUserId, offer.jobOfferId);

    if (mutual) {
      final alreadyExists = await matchRepo.matchExists(candidateUserId, recruiterUserId, offer.jobOfferId);
      if (!alreadyExists) {
        final matchId = await matchRepo.addMatch(
          candidateUserId: candidateUserId,
          recruiterUserId: recruiterUserId,
          jobOfferId: offer.jobOfferId,
        );
        if (mounted) {
          context.push('/match', extra: {
            'matchId': matchId,
            'jobOfferTitle': offer.title,
            'companyName': offer.companyName,
          });
        }
      }
    }
  }

  void _onSwipeEnd(int previousIndex, int? targetIndex, SwiperActivity activity) {
    if (activity is Swipe) {
      final offer = _offers[previousIndex];
      if (activity.direction == AxisDirection.right) {
        _handleSwipeRight(offer);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Découvrir des offres'),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? _buildErrorState()
              : _offers.isEmpty
                  ? _buildEmptyState()
                  : _buildSwiper(),
      bottomNavigationBar: const CandidateNavBar(currentIndex: 1),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: AppColors.red),
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: AppColors.textSecondary), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            OutlinedButton(onPressed: _loadData, child: const Text('Réessayer')),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80, height: 80,
              decoration: const BoxDecoration(color: AppColors.primaryLight, shape: BoxShape.circle),
              child: const Icon(Icons.bolt, color: AppColors.primary, size: 40),
            ),
            const SizedBox(height: 20),
            const Text('Aucune offre disponible', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            const Text('Vous avez tout vu ! Revenez plus tard.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh, color: AppColors.primary),
              label: const Text('Actualiser', style: TextStyle(color: AppColors.primary)),
              style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.primary), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwiper() {
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: AppinioSwiper(
              controller: _swiperController,
              cardCount: _offers.length,
              onSwipeEnd: _onSwipeEnd,
              cardBuilder: (context, index) {
                final offer = _offers[index];
                final score = _scores[offer.jobOfferId];
                return _JobOfferCard(offer: offer, score: score);
              },
            ),
          ),
        ),
        _buildActionButtons(),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          GestureDetector(
            onTap: () => _swiperController.swipeLeft(),
            child: Container(
              width: 60, height: 60,
              decoration: const BoxDecoration(color: AppColors.redLight, shape: BoxShape.circle),
              child: const Icon(Icons.close, color: AppColors.red, size: 30),
            ),
          ),
          GestureDetector(
            onTap: () => _swiperController.swipeRight(),
            child: Container(
              width: 50, height: 50,
              decoration: const BoxDecoration(color: Color(0xFFFEF3C7), shape: BoxShape.circle),
              child: const Icon(Icons.bolt, color: Color(0xFFF59E0B), size: 26),
            ),
          ),
          GestureDetector(
            onTap: () => _swiperController.swipeRight(),
            child: Container(
              width: 60, height: 60,
              decoration: const BoxDecoration(color: AppColors.primaryLight, shape: BoxShape.circle),
              child: const Icon(Icons.favorite, color: AppColors.primary, size: 30),
            ),
          ),
        ],
      ),
    );
  }
}

class _JobOfferCard extends StatelessWidget {
  final JobOffer offer;
  final int? score;
  const _JobOfferCard({required this.offer, this.score});

  @override
  Widget build(BuildContext context) {
    final requiredSkills = offer.requiredSkillList;
    final shownSkills = requiredSkills.take(3).toList();
    final extraSkillsCount = requiredSkills.length - shownSkills.length;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.10), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 160,
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [AppColors.primary, AppColors.primaryDark], begin: Alignment.topLeft, end: Alignment.bottomRight),
            ),
            child: Stack(
              children: [
                Center(child: Text(offer.initials, style: const TextStyle(color: Colors.white, fontSize: 56, fontWeight: FontWeight.bold, letterSpacing: 2))),
                if (score != null)
                  Positioned(
                    top: 14, right: 14,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: score! >= 70 ? AppColors.green : const Color(0xFFF59E0B),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.bolt, color: Colors.white, size: 14),
                          const SizedBox(width: 2),
                          Text('$score%', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(offer.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  const SizedBox(height: 4),
                  Text(offer.companyName, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                  const SizedBox(height: 8),
                  Row(children: [
                    const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Expanded(child: Text(offer.location, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13), overflow: TextOverflow.ellipsis)),
                  ]),
                  const SizedBox(height: 12),
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    if (offer.contractType.isNotEmpty) _Badge(label: offer.contractType),
                    if (offer.level.isNotEmpty) _Badge(label: offer.level),
                    if (offer.remoteMode.isNotEmpty) _Badge(label: offer.remoteMode),
                  ]),
                  if (offer.hasSalary) ...[
                    const SizedBox(height: 12),
                    Row(children: [
                      const Icon(Icons.euro, size: 16, color: AppColors.green),
                      const SizedBox(width: 6),
                      Text(offer.salaryDisplay, style: const TextStyle(color: AppColors.green, fontWeight: FontWeight.w600, fontSize: 14)),
                    ]),
                  ],
                  if (shownSkills.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      ...shownSkills.map((s) => _SkillChip(label: s)),
                      if (extraSkillsCount > 0) _SkillChip(label: '+$extraSkillsCount'),
                    ]),
                  ],
                  const SizedBox(height: 12),
                  Text(offer.description, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13), maxLines: 3, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  const _Badge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(6), border: Border.all(color: AppColors.border)),
      child: Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
    );
  }
}

class _SkillChip extends StatelessWidget {
  final String label;
  const _SkillChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w500)),
    );
  }
}