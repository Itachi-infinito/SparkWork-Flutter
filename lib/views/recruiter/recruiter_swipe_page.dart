import 'package:appinio_swiper/appinio_swiper.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_theme_ext.dart';
import '../../core/constants/app_skills.dart';
import '../../models/candidate_profile.dart';
import '../../models/job_offer.dart';
import '../../repositories/candidate_profile_repository.dart';
import '../../repositories/job_offer_repository.dart';
import '../../repositories/match_repository.dart';
import '../../repositories/recruiter_candidate_like_repository.dart';
import '../../repositories/candidate_job_like_repository.dart';
import '../../repositories/report_repository.dart';
import 'package:flutter/services.dart';
import '../../services/compatibility_service.dart';
import '../../services/session_service.dart';
import '../../services/subscription_service.dart';
import '../shared/quota_reached_bottom_sheet.dart';
import '../shared/nav_bar.dart';
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

  String _filterContractType = '';
  String _filterLevel = '';
  String _filterRemoteMode = '';
  String _filterLocation = '';
  String _filterSkill = '';

  bool get _hasActiveFilters =>
      _filterContractType.isNotEmpty ||
      _filterLevel.isNotEmpty ||
      _filterRemoteMode.isNotEmpty ||
      _filterLocation.isNotEmpty ||
      _filterSkill.isNotEmpty;

  DocumentSnapshot? _lastDoc;
  bool _hasMore = true;
  bool _loadingMore = false;
  Set<String> _likedIds = {};
  Set<String> _blockedIds = {};
  final Set<String> _swipedProfileIds = {};
  SwipeOverlayType _overlayType = SwipeOverlayType.none;
  int _remainingSwipes = 9999;
  static const _batchSize = 20;
  static const _loadMoreThreshold = 4;

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
    setState(() {
      _loading = true;
      _items = [];
      _activeItems = [];
      _lastDoc = null;
      _hasMore = true;
      _swipedProfileIds.clear();
    });
    try {
      final session = ref.read(sessionProvider);
      final repo = ref.read(recruiterCandidateLikeRepositoryProvider);
      final profileRepo = ref.read(candidateProfileRepositoryProvider);
      final offerRepo = ref.read(jobOfferRepositoryProvider);
      final compat = ref.read(compatibilityServiceProvider);

      _myOffers = await offerRepo.getOffersByRecruiter(session.userId);
      if (_myOffers.isEmpty) {
        if (mounted) setState(() => _loading = false);
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

      final likedIds = await repo.getLikedCandidateIds(session.userId);
      _likedIds = likedIds.toSet();
      _blockedIds = (await ref
              .read(reportRepositoryProvider)
              .getBlockedIds(session.userId))
          .toSet();

      final (profiles, lastDoc) = await profileRepo.getProfilesBatch(_batchSize);
      _lastDoc = lastDoc;
      _hasMore = profiles.length == _batchSize;

      final unseenProfiles = profiles
          .where((p) =>
              p.userId != session.userId &&
              !_likedIds.contains(p.userId) &&
              !_blockedIds.contains(p.userId))
          .toList();

      _items = unseenProfiles.map((p) {
        final score = _selectedOffer != null ? compat.calculateScore(p, _selectedOffer!) : 50;
        return _SwipeItem(profile: p, score: score);
      }).toList();
      _items.sort((a, b) => b.score.compareTo(a.score));
      _applyFilters();

      final remaining = await ref.read(subscriptionServiceProvider).getRemainingSwipes(session.userId);
      if (mounted) setState(() => _remainingSwipes = remaining);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyFilters() {
    setState(() {
      _activeItems = _items.where((item) {
        if (_swipedProfileIds.contains(item.profile.userId)) return false;
        final p = item.profile;
        if (_filterLocation.isNotEmpty &&
            !p.location.toLowerCase().contains(_filterLocation.toLowerCase())) {
          return false;
        }
        if (_filterContractType.isNotEmpty) {
          final types = AppSkills.parseSkills(p.desiredContractType);
          if (!types.any((t) => t == _filterContractType)) return false;
        }
        if (_filterLevel.isNotEmpty && p.desiredLevel != _filterLevel) {
          return false;
        }
        if (_filterRemoteMode.isNotEmpty &&
            !AppSkills.parseSkills(p.remotePreference)
                .contains(_filterRemoteMode)) {
          return false;
        }
        if (_filterSkill.isNotEmpty && !p.skillList.contains(_filterSkill)) {
          return false;
        }
        return true;
      }).toList();
    });
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _lastDoc == null) return;
    setState(() => _loadingMore = true);
    try {
      final session = ref.read(sessionProvider);
      final profileRepo = ref.read(candidateProfileRepositoryProvider);
      final compat = ref.read(compatibilityServiceProvider);

      final (profiles, lastDoc) = await profileRepo.getProfilesBatch(_batchSize, startAfter: _lastDoc);
      _lastDoc = lastDoc;
      _hasMore = profiles.length == _batchSize;

      final newUnseen = profiles
          .where((p) =>
              p.userId != session.userId &&
              !_likedIds.contains(p.userId) &&
              !_blockedIds.contains(p.userId))
          .toList();

      final newItems = newUnseen.map((p) {
        final score = _selectedOffer != null ? compat.calculateScore(p, _selectedOffer!) : 50;
        return _SwipeItem(profile: p, score: score);
      }).toList();

      final filteredNew = newItems.where((item) {
        if (_swipedProfileIds.contains(item.profile.userId)) return false;
        final p = item.profile;
        if (_filterLocation.isNotEmpty && !p.location.toLowerCase().contains(_filterLocation.toLowerCase())) return false;
        if (_filterContractType.isNotEmpty) {
          final types = AppSkills.parseSkills(p.desiredContractType);
          if (!types.any((t) => t == _filterContractType)) return false;
        }
        if (_filterLevel.isNotEmpty && p.desiredLevel != _filterLevel) return false;
        if (_filterRemoteMode.isNotEmpty &&
            !AppSkills.parseSkills(p.remotePreference).contains(_filterRemoteMode)) return false;
        if (_filterSkill.isNotEmpty && !p.skillList.contains(_filterSkill)) return false;
        return true;
      }).toList();

      setState(() {
        _items.addAll(newItems);
        _activeItems.addAll(filteredNew);
      });
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _showFilterSheet() {
    String tmpLocation = _filterLocation;
    String tmpContractType = _filterContractType;
    String tmpLevel = _filterLevel;
    String tmpRemoteMode = _filterRemoteMode;
    String tmpSkill = _filterSkill;
    final locationCtrl = TextEditingController(text: tmpLocation);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.75,
              maxChildSize: 0.95,
              builder: (_, scrollCtrl) => ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                children: [
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Filtres', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),

                  const Text('Ville', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: locationCtrl,
                    decoration: const InputDecoration(
                      hintText: 'ex: Paris, Lyon...',
                      prefixIcon: Icon(Icons.location_on_outlined),
                    ),
                    onChanged: (v) => tmpLocation = v,
                  ),
                  const SizedBox(height: 20),

                  const Text('Type de contrat', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8, runSpacing: 6,
                    children: AppSkills.contractTypes.map((c) => FilterChip(
                      label: Text(c),
                      selected: tmpContractType == c,
                      onSelected: (v) => setSheet(() => tmpContractType = v ? c : ''),
                      selectedColor: AppColors.primaryLight,
                      checkmarkColor: AppColors.primary,
                    )).toList(),
                  ),
                  const SizedBox(height: 20),

                  const Text("Niveau d'expérience", style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8, runSpacing: 6,
                    children: AppSkills.levels.map((l) => FilterChip(
                      label: Text(l),
                      selected: tmpLevel == l,
                      onSelected: (v) => setSheet(() => tmpLevel = v ? l : ''),
                      selectedColor: AppColors.greenLight,
                      checkmarkColor: AppColors.green,
                    )).toList(),
                  ),
                  const SizedBox(height: 20),

                  const Text('Mode de travail', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8, runSpacing: 6,
                    children: AppSkills.remoteModes.map((r) => FilterChip(
                      label: Text(r),
                      selected: tmpRemoteMode == r,
                      onSelected: (v) => setSheet(() => tmpRemoteMode = v ? r : ''),
                      selectedColor: AppColors.primaryLight,
                      checkmarkColor: AppColors.primary,
                    )).toList(),
                  ),
                  const SizedBox(height: 20),

                  const Text('Compétence', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: tmpSkill.isEmpty ? null : tmpSkill,
                    hint: const Text('Toutes les compétences'),
                    decoration: const InputDecoration(prefixIcon: Icon(Icons.star_outline)),
                    isExpanded: true,
                    items: AppSkills.horecaSkills
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (v) => setSheet(() => tmpSkill = v ?? ''),
                  ),
                  const SizedBox(height: 32),

                  Row(children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => setSheet(() {
                          tmpLocation = '';
                          tmpContractType = '';
                          tmpLevel = '';
                          tmpRemoteMode = '';
                          tmpSkill = '';
                          locationCtrl.clear();
                        }),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: context.textSecondaryColor),
                        ),
                        child: Text('Réinitialiser',
                            style: TextStyle(color: context.textSecondaryColor)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _filterLocation = tmpLocation;
                            _filterContractType = tmpContractType;
                            _filterLevel = tmpLevel;
                            _filterRemoteMode = tmpRemoteMode;
                            _filterSkill = tmpSkill;
                          });
                          _applyFilters();
                          Navigator.pop(ctx);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                        ),
                        child: const Text('Appliquer',
                            style: TextStyle(color: Colors.white)),
                      ),
                    ),
                  ]),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildActiveFilterChips() {
    if (!_hasActiveFilters) return const SizedBox();
    final chips = <Widget>[];
    void removeFilter(VoidCallback fn) { fn(); _applyFilters(); }
    if (_filterLocation.isNotEmpty) {
      chips.add(_ActiveChip(_filterLocation, () => removeFilter(() => setState(() => _filterLocation = ''))));
    }
    if (_filterContractType.isNotEmpty) {
      chips.add(_ActiveChip(_filterContractType, () => removeFilter(() => setState(() => _filterContractType = ''))));
    }
    if (_filterLevel.isNotEmpty) {
      chips.add(_ActiveChip(_filterLevel, () => removeFilter(() => setState(() => _filterLevel = ''))));
    }
    if (_filterRemoteMode.isNotEmpty) {
      chips.add(_ActiveChip(_filterRemoteMode, () => removeFilter(() => setState(() => _filterRemoteMode = ''))));
    }
    if (_filterSkill.isNotEmpty) {
      chips.add(_ActiveChip(_filterSkill, () => removeFilter(() => setState(() => _filterSkill = ''))));
    }
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: chips,
      ),
    );
  }

  Future<void> _handleLike(_SwipeItem item, {bool isSuperLike = false}) async {
    if (_selectedOffer == null) return;
    final session = ref.read(sessionProvider);
    final subSvc = ref.read(subscriptionServiceProvider);

    final consumed = await subSvc.consumeSwipe(session.userId);
    if (!consumed) {
      final sub = await subSvc.getSubscription(session.userId);
      final resetTime = await subSvc.getQuotaResetTime(session.userId);
      if (mounted) {
        await showQuotaReachedSheet(
          context,
          quotaType: QuotaType.swipes,
          currentPlan: sub.effectivePlan,
          resetTime: resetTime,
        );
      }
      return;
    }
    final remaining = await subSvc.getRemainingSwipes(session.userId);
    if (mounted) setState(() => _remainingSwipes = remaining);

    final likeRepo = ref.read(recruiterCandidateLikeRepositoryProvider);
    final candidateLikeRepo = ref.read(candidateJobLikeRepositoryProvider);
    final matchRepo = ref.read(matchRepositoryProvider);

    await likeRepo.addLike(
        session.userId, item.profile.userId, _selectedOffer!.jobOfferId,
        isSuperLike: isSuperLike);

    final candidateAlsoLiked = await candidateLikeRepo.hasLiked(item.profile.userId, _selectedOffer!.jobOfferId);
    if (candidateAlsoLiked) {
      final alreadyMatched = await matchRepo.matchExists(item.profile.userId, session.userId, _selectedOffer!.jobOfferId);
      if (!alreadyMatched) {
        final matchId = await matchRepo.addMatch(
          candidateUserId: item.profile.userId,
          recruiterUserId: session.userId,
          jobOfferId: _selectedOffer!.jobOfferId,
          jobOfferTitle: _selectedOffer!.title,
          companyName: item.profile.fullName,
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
    setState(() => _overlayType = SwipeOverlayType.none);
    if (activity is Swipe) {
      if (prev < _activeItems.length) {
        _swipedProfileIds.add(_activeItems[prev].profile.userId);
        if (activity.direction == AxisDirection.right) {
          HapticFeedback.mediumImpact();
          await _handleLike(_activeItems[prev]);
        } else if (activity.direction == AxisDirection.up) {
          HapticFeedback.heavyImpact();
          await _handleLike(_activeItems[prev], isSuperLike: true);
        } else if (activity.direction == AxisDirection.left) {
          HapticFeedback.lightImpact();
        }
      }
    }
    final remaining = target != null ? _activeItems.length - target : 0;
    if (remaining <= _loadMoreThreshold && _hasMore && !_loadingMore) {
      _loadMore();
    }
    if (target != null && target >= _activeItems.length) {
      if (mounted) setState(() => _activeItems = []);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Explorer les candidats'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.tune),
                onPressed: _showFilterSheet,
              ),
              if (_hasActiveFilters)
                Positioned(
                  right: 8, top: 8,
                  child: Container(
                    width: 8, height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ],
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
                  prefixIcon: Icon(Icons.work_outline),
                ),
                items: _myOffers.map((o) => DropdownMenuItem(
                  value: o,
                  child: Text(o.title, overflow: TextOverflow.ellipsis),
                )).toList(),
                onChanged: (o) {
                  setState(() { _selectedOffer = o; _activeItems = []; });
                  _load();
                },
              ),
            ),
          _buildActiveFilterChips(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.green))
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
              color: AppColors.greenLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.people_outline, color: AppColors.green, size: 48),
          ),
          const SizedBox(height: 20),
          Text(
            'Aucun candidat disponible',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: context.textPrimaryColor),
          ),
          const SizedBox(height: 8),
          Text(
            _hasActiveFilters
                ? 'Essayez de modifier vos filtres'
                : 'Revenez plus tard !',
            style: TextStyle(color: context.textSecondaryColor),
          ),
          const SizedBox(height: 24),
          if (_hasActiveFilters)
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _filterLocation = '';
                  _filterContractType = '';
                  _filterLevel = '';
                  _filterRemoteMode = '';
                  _filterSkill = '';
                });
                _applyFilters();
              },
              icon: const Icon(Icons.filter_alt_off, color: AppColors.primary),
              label: const Text('Effacer les filtres', style: TextStyle(color: AppColors.primary)),
            )
          else
            OutlinedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh, color: AppColors.green),
              label: const Text('Actualiser', style: TextStyle(color: AppColors.green)),
              style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.green)),
            ),
        ],
      ),
    );
  }

  Widget _buildSwiper() {
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                if (newType != _overlayType) {
                  setState(() => _overlayType = newType);
                }
              },
              onPointerUp: (_) =>
                  setState(() => _overlayType = SwipeOverlayType.none),
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
        ),
        if (_remainingSwipes != 9999)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: _remainingSwipes <= 5
                      ? AppColors.red.withOpacity(0.1)
                      : AppColors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _remainingSwipes <= 5 ? AppColors.red : AppColors.green,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.swipe,
                        size: 14,
                        color: _remainingSwipes <= 5 ? AppColors.red : AppColors.green),
                    const SizedBox(width: 6),
                    Text(
                      _remainingSwipes == 0
                          ? 'Plus de swipes disponibles'
                          : '$_remainingSwipes swipe${_remainingSwipes > 1 ? 's' : ''} restant${_remainingSwipes > 1 ? 's' : ''}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _remainingSwipes <= 5 ? AppColors.red : AppColors.green,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              AnimatedActionButton(
                icon: Icons.close,
                color: AppColors.red,
                size: 60,
                onTap: () {
                  HapticFeedback.lightImpact();
                  _controller.swipeLeft();
                },
              ),
              AnimatedActionButton(
                icon: Icons.bolt,
                color: _remainingSwipes == 0 ? Colors.grey : AppColors.orange,
                size: 50,
                onTap: () {
                  HapticFeedback.heavyImpact();
                  _controller.swipeUp();
                },
              ),
              AnimatedActionButton(
                icon: Icons.favorite,
                color: _remainingSwipes == 0 ? Colors.grey : AppColors.green,
                size: 60,
                onTap: () {
                  HapticFeedback.mediumImpact();
                  _controller.swipeRight();
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildCard(_SwipeItem item) {
    final p = item.profile;
    final scoreColor = item.score >= 70 ? AppColors.green : AppColors.orange;
    final gradient = AvatarColors.gradientForString(p.fullName);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.35),
              blurRadius: 28,
              offset: const Offset(0, 14)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Photo or gradient background
          if (p.photoUrl != null && p.photoUrl!.isNotEmpty)
            Image.network(
              p.photoUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                decoration: BoxDecoration(gradient: gradient),
              ),
            )
          else
            Container(decoration: BoxDecoration(gradient: gradient)),

          // Decorative circles (only shown when no photo)
          if (p.photoUrl == null || p.photoUrl!.isEmpty) ...[
            Positioned(
              top: -40, right: -40,
              child: Container(
                width: 160, height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.07),
                ),
              ),
            ),
            // Initials
            Positioned(
              top: 0, left: 0, right: 0, bottom: 260,
              child: Center(
                child: Text(
                  p.initials,
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.92),
                      fontSize: 80,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],

          // Dark gradient overlay — bottom 55%
          Positioned(
            left: 0, right: 0, bottom: 0,
            height: 300,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xBB000000), Color(0xEE000000)],
                  stops: [0.0, 0.45, 1.0],
                ),
              ),
            ),
          ),

          // Score badge — top right
          Positioned(
            top: 16, right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: scoreColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                      color: scoreColor.withOpacity(0.5), blurRadius: 10)
                ],
              ),
              child: Text('${item.score}%',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
            ),
          ),

          // Content overlay — bottom
          Positioned(
            left: 20, right: 20, bottom: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(p.fullName,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold)),
                if (p.location.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.location_on_outlined,
                        color: Colors.white60, size: 13),
                    const SizedBox(width: 4),
                    Text(p.location,
                        style: const TextStyle(
                            color: Colors.white60, fontSize: 13)),
                  ]),
                ],
                if (p.hasSalary) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.green.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: AppColors.green.withOpacity(0.5)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.euro,
                          color: AppColors.green, size: 13),
                      const SizedBox(width: 3),
                      Text(p.salaryDisplay,
                          style: const TextStyle(
                              color: AppColors.green,
                              fontWeight: FontWeight.w700,
                              fontSize: 13)),
                    ]),
                  ),
                ],
                const SizedBox(height: 10),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  if (p.desiredContractType.isNotEmpty)
                    _CardBadge(p.desiredContractType),
                  if (p.desiredLevel.isNotEmpty)
                    _CardBadge(p.desiredLevel),
                  if (p.remotePreference.isNotEmpty)
                    _CardBadge(p.remotePreference),
                  ...p.skillList.take(3).map(_CardBadge.new),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CardBadge extends StatelessWidget {
  final String label;
  const _CardBadge(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Text(label,
          style: const TextStyle(
              color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500)),
    );
  }
}

class _SwipeItem {
  final CandidateProfile profile;
  final int score;
  _SwipeItem({required this.profile, required this.score});
}

class _ActiveChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;
  const _ActiveChip(this.label, this.onRemove);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8, top: 4, bottom: 4),
      child: Chip(
        label: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.primary)),
        deleteIcon: const Icon(Icons.close, size: 14, color: AppColors.primary),
        onDeleted: onRemove,
        backgroundColor: AppColors.primaryLight,
        visualDensity: VisualDensity.compact,
        side: BorderSide.none,
      ),
    );
  }
}

