import 'package:appinio_swiper/appinio_swiper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../models/candidate_profile.dart';
import '../../models/job_offer.dart';
import '../../repositories/candidate_profile_repository.dart';
import '../../repositories/job_offer_repository.dart';
import '../../repositories/match_repository.dart';
import '../../repositories/recruiter_candidate_like_repository.dart';
import '../../repositories/candidate_job_like_repository.dart';
import '../../services/compatibility_service.dart';
import '../../services/session_service.dart';
import '../shared/nav_bar.dart';
import '../../core/utils/avatar_colors.dart';
import '../../core/widgets/animated_action_button.dart';
import 'package:flutter/services.dart';
import '../../core/utils/avatar_colors.dart';
import '../../core/widgets/animated_action_button.dart';
import '../../core/widgets/swipe_overlay.dart';


class RecruiterSwipePage extends ConsumerStatefulWidget {
  const RecruiterSwipePage({super.key});

  @override
  ConsumerState<RecruiterSwipePage> createState() => _RecruiterSwipePageState();
}

class _RecruiterSwipePageState extends ConsumerState<RecruiterSwipePage> {
  final AppinioSwiperController _controller = AppinioSwiperController();
  List<_SwipeItem> _items = [];
  List<_SwipeItem> _activeItems = [];
  bool _loading = true;
  JobOffer? _selectedOffer;
  List<JobOffer> _myOffers = [];
  SwipeOverlayType _overlayType = SwipeOverlayType.none;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final session = ref.read(sessionProvider);
      final repo = ref.read(recruiterCandidateLikeRepositoryProvider);
      final profileRepo = ref.read(candidateProfileRepositoryProvider);
      final offerRepo = ref.read(jobOfferRepositoryProvider);
      final compat = ref.read(compatibilityServiceProvider);

      _myOffers = await offerRepo.getOffersByRecruiter(session.userId);
      if (_myOffers.isEmpty) {
        if (mounted) setState(() { _loading = false; _items = []; _activeItems = []; });
        return;
      }
      if (_selectedOffer == null) {
        _selectedOffer = _myOffers.first;
      } else {
        _selectedOffer = _myOffers.firstWhere(
          (o) => o.jobOfferId == _selectedOffer!.jobOfferId,
          orElse: () => _myOffers.first,
        );
      }

      final allProfiles = await profileRepo.getAllProfiles();
      final likedIds = await repo.getLikedCandidateIds(session.userId);

      final unseenProfiles = allProfiles
          .where((p) => p.userId != session.userId && !likedIds.contains(p.userId))
          .toList();

      _items = unseenProfiles.map((p) {
        final score = _selectedOffer != null ? compat.calculateScore(p, _selectedOffer!) : 50;
        return _SwipeItem(profile: p, score: score);
      }).toList();
      _items.sort((a, b) => b.score.compareTo(a.score));
      _activeItems = List.from(_items);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleLike(_SwipeItem item, {bool isSuperLike = false}) async {
    if (_selectedOffer == null) return;
    final session = ref.read(sessionProvider);
    final likeRepo = ref.read(recruiterCandidateLikeRepositoryProvider);
    final candidateLikeRepo = ref.read(candidateJobLikeRepositoryProvider);
    final matchRepo = ref.read(matchRepositoryProvider);

    await likeRepo.addLike(
      session.userId,
      item.profile.userId,
      _selectedOffer!.jobOfferId,
      isSuperLike: isSuperLike,
    );

    final candidateAlsoLiked =
        await candidateLikeRepo.hasLiked(item.profile.userId, _selectedOffer!.jobOfferId);
    if (candidateAlsoLiked) {
      final alreadyMatched = await matchRepo.matchExists(
          item.profile.userId, session.userId, _selectedOffer!.jobOfferId);
      if (!alreadyMatched) {
        final matchId = await matchRepo.addMatch(
          candidateUserId: item.profile.userId,
          recruiterUserId: session.userId,
          jobOfferId: _selectedOffer!.jobOfferId,
        );
        if (mounted) {
          context.push('/match', extra: {
            'matchId': matchId,
            'jobOfferTitle': _selectedOffer!.title,
            'companyName': item.profile.fullName,
          });
        }
      }
    }
  }

  void _onSwipeEnd(int prev, int? target, SwiperActivity activity) async {
    setState(() => _overlayType = SwipeOverlayType.none); // reset
    if (activity is Swipe) {
      if (activity.direction == AxisDirection.right) {
        HapticFeedback.mediumImpact();
        if (prev < _activeItems.length) await _handleLike(_activeItems[prev]);
      } else if (activity.direction == AxisDirection.up) {
        HapticFeedback.heavyImpact();
        if (prev < _activeItems.length) await _handleLike(_activeItems[prev], isSuperLike: true);
      } else if (activity.direction == AxisDirection.left) {
        HapticFeedback.lightImpact();
      }
    }
    if (target != null && target >= _activeItems.length) {
      if (mounted) setState(() => _activeItems = []);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Explorer les candidats'),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: Column(
        children: [
          if (_myOffers.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: DropdownButtonFormField<JobOffer>(
                value: _selectedOffer,
                decoration: const InputDecoration(
                    labelText: 'Offre associée',
                    prefixIcon: Icon(Icons.work_outline)),
                items: _myOffers
                    .map((o) => DropdownMenuItem(
                        value: o,
                        child: Text(o.title, overflow: TextOverflow.ellipsis)))
                    .toList(),
                onChanged: (o) {
                  setState(() {
                    _selectedOffer = o;
                    _activeItems = [];
                  });
                  _load();
                },
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.green))
                : _activeItems.isEmpty
                    ? _buildEmpty()
                    : _buildSwiper(),
          ),
        ],
      ),
      bottomNavigationBar: const RecruiterNavBar(currentIndex: 1),
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
                color: AppColors.greenLight, shape: BoxShape.circle),
            child: const Icon(Icons.people_outline,
                color: AppColors.green, size: 48),
          ),
          const SizedBox(height: 20),
          const Text('Aucun candidat disponible',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          const Text('Revenez plus tard !',
              style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh, color: AppColors.green),
            label: const Text('Actualiser',
                style: TextStyle(color: AppColors.green)),
            style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.green)),
          ),
        ],
      ),
    );
  }

  Widget _buildSwiper() {
    return Column(
      children: [
        Expanded(
          child: Listener(
            onPointerMove: (event) {
              final dx = event.delta.dx;
              final dy = event.delta.dy;
              SwipeOverlayType newType;
              if (dy < -2 && dy.abs() > dx.abs()) {
                newType = SwipeOverlayType.superLike;
              } else if (dx > 2) {
                newType = SwipeOverlayType.like;
              } else if (dx < -2) {
                newType = SwipeOverlayType.pass;
              } else {
                return;
              }
              if (newType != _overlayType) setState(() => _overlayType = newType);
            },
            onPointerUp: (_) => setState(() => _overlayType = SwipeOverlayType.none),
            child: AppinioSwiper(
              controller: _controller,
              cardCount: _activeItems.length,
              onSwipeEnd: _onSwipeEnd,
              cardBuilder: (context, index) {
                if (index >= _activeItems.length) return const SizedBox();
                return Stack(
                  children: [
                    _buildCard(_activeItems[index]),
                    SwipeOverlay(type: _overlayType),
                  ],
                );
              },
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              AnimatedActionButton(
                icon: Icons.close,
                color: AppColors.red,
                size: 56,
                onTap: () {
                  HapticFeedback.lightImpact();
                  _controller.swipeLeft();
                },
              ),
              AnimatedActionButton(
                icon: Icons.bolt,
                color: AppColors.orange,
                size: 46,
                onTap: () {
                  HapticFeedback.heavyImpact();
                  _controller.swipeUp();
                },
              ),
              AnimatedActionButton(
                icon: Icons.favorite,
                color: AppColors.green,
                size: 56,
                onTap: () {
                  HapticFeedback.mediumImpact();
                  _controller.swipeRight();
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCard(_SwipeItem item) {
    final p = item.profile;
    final scoreColor =
        item.score >= 70 ? AppColors.green : AppColors.orange;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 140,
            decoration: BoxDecoration(
              gradient: AvatarColors.gradientForString(p.fullName),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Stack(children: [
              Center(child: Text(p.initials, style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold))),
              Positioned(
                top: 12, right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: scoreColor, borderRadius: BorderRadius.circular(20)),
                  child: Text('${item.score}%', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ),
            ]),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.fullName,
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary)),
                    if (p.location.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(children: [
                        const Icon(Icons.location_on_outlined,
                            size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(p.location,
                            style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13)),
                      ]),
                    ],
                    const SizedBox(height: 12),
                    Wrap(spacing: 6, runSpacing: 4, children: [
                      if (p.desiredContractType.isNotEmpty)
                        _Badge(p.desiredContractType,
                            AppColors.primaryLight, AppColors.primary),
                      if (p.desiredLevel.isNotEmpty)
                        _Badge(p.desiredLevel, AppColors.greenLight,
                            AppColors.green),
                    ]),
                    if (p.skillList.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: p.skillList
                              .take(5)
                              .map((s) => _Badge(
                                  s,
                                  AppColors.primaryLight,
                                  AppColors.primary))
                              .toList()),
                    ],
                    if (p.bio.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(p.bio,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13)),
                    ],
                  ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _SwipeItem {
  final CandidateProfile profile;
  final int score;
  _SwipeItem({required this.profile, required this.score});
}

class _Badge extends StatelessWidget {
  final String text;
  final Color bg;
  final Color fg;
  const _Badge(this.text, this.bg, this.fg);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: TextStyle(fontSize: 11, color: fg)),
    );
  }
}

