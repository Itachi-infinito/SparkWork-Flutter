import 'dart:async';
import 'package:appinio_swiper/appinio_swiper.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_skills.dart';
import '../../models/candidate_profile.dart';
import '../../models/job_offer.dart';
import '../../repositories/candidate_job_like_repository.dart';
import '../../models/recruiter_profile.dart';
import '../../repositories/candidate_profile_repository.dart';
import '../../repositories/job_offer_repository.dart';
import '../../repositories/match_repository.dart';
import '../../repositories/recruiter_candidate_like_repository.dart';
import '../../repositories/recruiter_profile_repository.dart';
import '../../repositories/report_repository.dart';
import '../../services/compatibility_service.dart';
import '../../services/session_service.dart';
import '../shared/nav_bar.dart';
import '../../core/utils/avatar_colors.dart';
import '../../core/widgets/animated_action_button.dart';
import '../../core/widgets/swipe_overlay.dart';
import '../../services/notification_service.dart';
import '../../core/widgets/empty_state.dart';

class CandidateSwipePage extends ConsumerStatefulWidget {
  const CandidateSwipePage({super.key});

  @override
  ConsumerState<CandidateSwipePage> createState() => _CandidateSwipePageState();
}

class _CandidateSwipePageState extends ConsumerState<CandidateSwipePage> {
  final AppinioSwiperController _swiperController = AppinioSwiperController();

  List<JobOffer> _allOffers = [];
  List<JobOffer> _offers = [];
  CandidateProfile? _candidateProfile;
  Map<String, int> _scores = {};
  Map<String, bool> _superLikedByRecruiter = {};
  Map<String, RecruiterProfile> _recruiterProfiles = {};
  bool _loading = true;
  String? _error;

  String _filterContractType = '';
  String _filterLevel = '';
  String _filterRemoteMode = '';
  String _filterLocation = '';
  int? _filterMinSalary;

  SwipeOverlayType _overlayType = SwipeOverlayType.none;

  DocumentSnapshot? _lastDoc;
  bool _hasMore = true;
  bool _loadingMore = false;
  Set<String> _likedIds = {};
  Set<String> _blockedIds = {};
  final Set<String> _swipedOfferIds = {};
  static const _batchSize = 20;
  static const _loadMoreThreshold = 4;

  bool get _hasActiveFilters =>
      _filterContractType.isNotEmpty ||
      _filterLevel.isNotEmpty ||
      _filterRemoteMode.isNotEmpty ||
      _filterLocation.isNotEmpty ||
      _filterMinSalary != null;

  

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
    setState(() {
      _loading = true;
      _error = null;
      _allOffers = [];
      _offers = [];
      _lastDoc = null;
      _hasMore = true;
      _swipedOfferIds.clear();
    });
    try {
      final session = ref.read(sessionProvider);
      final userId = session.userId;
      final jobOfferRepo = ref.read(jobOfferRepositoryProvider);
      final likeRepo = ref.read(candidateJobLikeRepositoryProvider);
      final profileRepo = ref.read(candidateProfileRepositoryProvider);
      final recruiterLikeRepo = ref.read(recruiterCandidateLikeRepositoryProvider);
      final compatService = ref.read(compatibilityServiceProvider);

      final likedIds = await likeRepo.getLikedJobOfferIds(userId);
      _likedIds = likedIds.toSet();
      _blockedIds =
          (await ref.read(reportRepositoryProvider).getBlockedIds(userId))
              .toSet();
      final profile = await profileRepo.getProfile(userId);

      final (offers, lastDoc) = await jobOfferRepo.getOffersBatch(_batchSize);
      _lastDoc = lastDoc;
      _hasMore = offers.length == _batchSize;

      final unseen = offers
          .where((o) =>
              !_likedIds.contains(o.jobOfferId) &&
              !_blockedIds.contains(o.recruiterUserId))
          .toList();

      final scores = <String, int>{};
      final superLiked = <String, bool>{};

      if (profile != null) {
        for (final offer in unseen) {
          scores[offer.jobOfferId] = compatService.calculateScore(profile, offer);
          superLiked[offer.jobOfferId] = await recruiterLikeRepo.hasSuperLiked(
            offer.recruiterUserId,
            userId,
            offer.jobOfferId,
          );
        }
      }

      // Batch-fetch recruiter profiles for swipe card photos
      final recruiterIds = unseen.map((o) => o.recruiterUserId).toSet().toList();
      final recruiterProfiles = await ref
          .read(recruiterProfileRepositoryProvider)
          .getProfilesForUserIds(recruiterIds);

      if (mounted) {
        setState(() {
          _allOffers = unseen;
          _candidateProfile = profile;
          _scores = scores;
          _superLikedByRecruiter = superLiked;
          _recruiterProfiles = recruiterProfiles;
          _loading = false;
        });
        _applyFilters();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Erreur lors du chargement des offres.';
          _loading = false;
        });
      }
    }
  }

  void _applyFilters() {
    setState(() {
      _offers = _allOffers.where((o) {
        if (_swipedOfferIds.contains(o.jobOfferId)) return false;
        if (_filterContractType.isNotEmpty &&
            o.contractType != _filterContractType) return false;
        if (_filterLevel.isNotEmpty && o.level != _filterLevel) return false;
        if (_filterRemoteMode.isNotEmpty &&
            o.remoteMode != _filterRemoteMode) return false;
        if (_filterLocation.isNotEmpty &&
            !o.location
                .toLowerCase()
                .contains(_filterLocation.toLowerCase())) return false;
        if (_filterMinSalary != null &&
            o.salaryMax > 0 &&
            o.salaryMax < _filterMinSalary!) return false;
        return true;
      }).toList();
    });
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _lastDoc == null) return;
    setState(() => _loadingMore = true);
    try {
      final session = ref.read(sessionProvider);
      final userId = session.userId;
      final jobOfferRepo = ref.read(jobOfferRepositoryProvider);
      final recruiterLikeRepo = ref.read(recruiterCandidateLikeRepositoryProvider);
      final compatService = ref.read(compatibilityServiceProvider);

      final (offers, lastDoc) = await jobOfferRepo.getOffersBatch(_batchSize, startAfter: _lastDoc);
      _lastDoc = lastDoc;
      _hasMore = offers.length == _batchSize;

      final newUnseen = offers
          .where((o) =>
              !_likedIds.contains(o.jobOfferId) &&
              !_blockedIds.contains(o.recruiterUserId))
          .toList();

      final newScores = <String, int>{};
      final newSuperLiked = <String, bool>{};
      if (_candidateProfile != null) {
        for (final offer in newUnseen) {
          newScores[offer.jobOfferId] = compatService.calculateScore(_candidateProfile!, offer);
          newSuperLiked[offer.jobOfferId] = await recruiterLikeRepo.hasSuperLiked(
            offer.recruiterUserId, userId, offer.jobOfferId);
        }
      }

      final filteredNew = newUnseen.where((o) {
        if (_swipedOfferIds.contains(o.jobOfferId)) return false;
        if (_filterContractType.isNotEmpty && o.contractType != _filterContractType) return false;
        if (_filterLevel.isNotEmpty && o.level != _filterLevel) return false;
        if (_filterRemoteMode.isNotEmpty && o.remoteMode != _filterRemoteMode) return false;
        if (_filterLocation.isNotEmpty && !o.location.toLowerCase().contains(_filterLocation.toLowerCase())) return false;
        if (_filterMinSalary != null && o.salaryMax > 0 && o.salaryMax < _filterMinSalary!) return false;
        return true;
      }).toList();

      final newRecruiterIds = newUnseen
          .map((o) => o.recruiterUserId)
          .where((id) => !_recruiterProfiles.containsKey(id))
          .toSet()
          .toList();
      final newRecruiterProfiles = await ref
          .read(recruiterProfileRepositoryProvider)
          .getProfilesForUserIds(newRecruiterIds);

      setState(() {
        _allOffers.addAll(newUnseen);
        _scores.addAll(newScores);
        _superLikedByRecruiter.addAll(newSuperLiked);
        _recruiterProfiles.addAll(newRecruiterProfiles);
        _offers.addAll(filteredNew);
      });
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _clearFilters() {
    setState(() {
      _filterContractType = '';
      _filterLevel = '';
      _filterRemoteMode = '';
      _filterLocation = '';
      _filterMinSalary = null;
    });
    _applyFilters();
  }

  void _showFilterSheet() {
    String tempContract = _filterContractType;
    String tempLevel = _filterLevel;
    String tempRemote = _filterRemoteMode;
    String tempLocation = _filterLocation;
    int? tempSalary = _filterMinSalary;
    final locationCtrl = TextEditingController(text: _filterLocation);
    final salaryCtrl =
        TextEditingController(text: _filterMinSalary?.toString() ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Filtres',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(ctx).colorScheme.onSurface)),
                    TextButton(
                      onPressed: () {
                        setSheet(() {
                          tempContract = '';
                          tempLevel = '';
                          tempRemote = '';
                          tempLocation = '';
                          tempSalary = null;
                          locationCtrl.clear();
                          salaryCtrl.clear();
                        });
                      },
                      child: const Text('Réinitialiser',
                          style: TextStyle(color: AppColors.primary)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const _FilterLabel('Type de contrat'),
                const SizedBox(height: 8),
                _ChipGroup(
                  options: AppSkills.contractTypes,
                  selected: tempContract,
                  onSelected: (v) =>
                      setSheet(() => tempContract = v == tempContract ? '' : v),
                ),
                const SizedBox(height: 16),
                const _FilterLabel('Niveau d\'expérience'),
                const SizedBox(height: 8),
                _ChipGroup(
                  options: AppSkills.levels,
                  selected: tempLevel,
                  onSelected: (v) =>
                      setSheet(() => tempLevel = v == tempLevel ? '' : v),
                ),
                const SizedBox(height: 16),
                const _FilterLabel('Télétravail'),
                const SizedBox(height: 8),
                _ChipGroup(
                  options: AppSkills.remoteModes,
                  selected: tempRemote,
                  onSelected: (v) =>
                      setSheet(() => tempRemote = v == tempRemote ? '' : v),
                ),
                const SizedBox(height: 16),
                const _FilterLabel('Localisation'),
                const SizedBox(height: 8),
                TextField(
                  controller: locationCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Ex: Paris, Lyon...',
                    prefixIcon:
                        Icon(Icons.location_on_outlined, size: 18),
                    isDense: true,
                  ),
                  onChanged: (v) => tempLocation = v,
                ),
                const SizedBox(height: 16),
                const _FilterLabel('Salaire minimum (€/mois)'),
                const SizedBox(height: 8),
                TextField(
                  controller: salaryCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    hintText: 'Ex: 2000',
                    prefixIcon: Icon(Icons.euro, size: 18),
                    isDense: true,
                  ),
                  onChanged: (v) => tempSalary = int.tryParse(v),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _filterContractType = tempContract;
                        _filterLevel = tempLevel;
                        _filterRemoteMode = tempRemote;
                        _filterLocation = tempLocation;
                        _filterMinSalary = tempSalary;
                      });
                      _applyFilters();
                      Navigator.pop(ctx);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Appliquer les filtres',
                        style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleSwipeRight(JobOffer offer, {bool isSuperLike = false}) async {
    final session = ref.read(sessionProvider);
    final candidateUserId = session.userId;
    final likeRepo = ref.read(candidateJobLikeRepositoryProvider);
    final recruiterLikeRepo = ref.read(recruiterCandidateLikeRepositoryProvider);
    final matchRepo = ref.read(matchRepositoryProvider);

    await likeRepo.addLike(candidateUserId, offer.jobOfferId,
        isSuperLike: isSuperLike);

    final recruiterUserId = offer.recruiterUserId;
    final mutual = await recruiterLikeRepo.hasRecruiterLikedCandidateAny(
        recruiterUserId, candidateUserId);

    if (mutual) {
      final alreadyExists = await matchRepo.matchExists(
          candidateUserId, recruiterUserId, offer.jobOfferId);
      if (!alreadyExists) {
        final matchId = await matchRepo.addMatch(
          candidateUserId: candidateUserId,
          recruiterUserId: recruiterUserId,
          jobOfferId: offer.jobOfferId,
          jobOfferTitle: offer.title,
          companyName: offer.companyName,
        );
        NotificationService.showMatch(
          jobOfferTitle: offer.title,
          companyName: offer.companyName,
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
    setState(() => _overlayType = SwipeOverlayType.none);
    if (activity is Swipe) {
      if (previousIndex < _offers.length) {
        final offer = _offers[previousIndex];
        _swipedOfferIds.add(offer.jobOfferId);
        if (activity.direction == AxisDirection.right) {
          HapticFeedback.mediumImpact();
          _handleSwipeRight(offer);
        } else if (activity.direction == AxisDirection.up) {
          HapticFeedback.heavyImpact();
          _handleSwipeRight(offer, isSuperLike: true);
        } else if (activity.direction == AxisDirection.left) {
          HapticFeedback.lightImpact();
        }
      }
    }
    final remaining = targetIndex != null ? _offers.length - targetIndex : 0;
    if (remaining <= _loadMoreThreshold && _hasMore && !_loadingMore) {
      _loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(profileVersionProvider, (prev, next) {
    if (mounted) _loadData(); 
    });
    return Scaffold(
      
      appBar: AppBar(
        title: const Text('Découvrir des offres'),
        elevation: 0,
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.tune),
                onPressed: _showFilterSheet,
                tooltip: 'Filtres',
              ),
              if (_hasActiveFilters)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (_hasActiveFilters) _buildActiveFilterChips(),
          if (!_loading && _error == null && _flashOffers.isNotEmpty)
            _buildFlashSection(),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.primary))
                : _error != null
                    ? _buildErrorState()
                    : _offers.isEmpty
                        ? _buildEmptyState()
                        : _buildSwiper(),
          ),
        ],
      ),
      bottomNavigationBar: const CandidateNavBar(currentIndex: 1),
    );
  }

  Widget _buildActiveFilterChips() {
    final chips = <Widget>[];
    if (_filterContractType.isNotEmpty) {
      chips.add(_ActiveChip(
          label: _filterContractType,
          onRemove: () {
            setState(() => _filterContractType = '');
            _applyFilters();
          }));
    }
    if (_filterLevel.isNotEmpty) {
      chips.add(_ActiveChip(
          label: _filterLevel,
          onRemove: () {
            setState(() => _filterLevel = '');
            _applyFilters();
          }));
    }
    if (_filterRemoteMode.isNotEmpty) {
      chips.add(_ActiveChip(
          label: _filterRemoteMode,
          onRemove: () {
            setState(() => _filterRemoteMode = '');
            _applyFilters();
          }));
    }
    if (_filterLocation.isNotEmpty) {
      chips.add(_ActiveChip(
          label: _filterLocation,
          onRemove: () {
            setState(() => _filterLocation = '');
            _applyFilters();
          }));
    }
    if (_filterMinSalary != null) {
      chips.add(_ActiveChip(
          label: '≥ ${_filterMinSalary}€',
          onRemove: () {
            setState(() => _filterMinSalary = null);
            _applyFilters();
          }));
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                  children: chips
                      .map((c) => Padding(
                          padding: const EdgeInsets.only(right: 6), child: c))
                      .toList()),
            ),
          ),
          TextButton(
            onPressed: _clearFilters,
            style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(60, 30)),
            child: const Text('Effacer',
                style:
                    TextStyle(color: AppColors.primary, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  List<JobOffer> get _flashOffers =>
      _allOffers.where((o) => o.isFlash && o.isFlashActive).toList();

  Widget _buildFlashSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
          child: Row(
            children: [
              const Icon(Icons.bolt, color: Color(0xFFF59E0B), size: 18),
              const SizedBox(width: 6),
              const Text('Missions Flash',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFF59E0B))),
              const Spacer(),
              Text('${_flashOffers.length} disponible${_flashOffers.length > 1 ? 's' : ''}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
        ),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _flashOffers.length,
            itemBuilder: (ctx, i) {
              final o = _flashOffers[i];
              return GestureDetector(
                onTap: () => context.push('/candidate/flash/${o.jobOfferId}', extra: o),
                child: _FlashMiniCard(offer: o),
              );
            },
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline,
                size: 64, color: AppColors.red),
            const SizedBox(height: 16),
            Text(_error!,
                style: const TextStyle(color: AppColors.textSecondary),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            OutlinedButton(
                onPressed: _loadData, child: const Text('Réessayer')),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
  final isFiltered = _hasActiveFilters && _allOffers.isNotEmpty;
  return EmptyState(
    icon: isFiltered ? Icons.filter_list_off : Icons.bolt,
    title: isFiltered ? 'Aucun résultat' : 'Aucune offre disponible',
    subtitle: isFiltered
        ? 'Aucune offre ne correspond à vos filtres.'
        : 'Vous avez tout vu ! Revenez plus tard.',
    action: isFiltered
        ? OutlinedButton.icon(
            onPressed: _clearFilters,
            icon: const Icon(Icons.filter_list_off, color: AppColors.primary),
            label: const Text('Supprimer les filtres',
                style: TextStyle(color: AppColors.primary)),
            style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.primary)),
          )
        : OutlinedButton.icon(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh, color: AppColors.primary),
            label: const Text('Actualiser',
                style: TextStyle(color: AppColors.primary)),
            style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12)),
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
                if (newType != _overlayType) setState(() => _overlayType = newType);
              },
              onPointerUp: (_) => setState(() => _overlayType = SwipeOverlayType.none),
              child: AppinioSwiper(
                controller: _swiperController,
                cardCount: _offers.length,
                onSwipeEnd: _onSwipeEnd,
                cardBuilder: (context, index) {
                  if (index >= _offers.length) return const SizedBox();
                  final offer = _offers[index];
                  final score = _scores[offer.jobOfferId];
                  final recruiterProfile =
                      _recruiterProfiles[offer.recruiterUserId];
                  return Stack(
                    children: [
                      _JobOfferCard(
                        offer: offer,
                        score: score,
                        recruiterProfile: recruiterProfile,
                      ),
                      SwipeOverlay(type: _overlayType),
                    ],
                  );
                },
              ),
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
          AnimatedActionButton(
            icon: Icons.close,
            color: AppColors.red,
            size: 60,
            onTap: () {
              HapticFeedback.lightImpact();
              _swiperController.swipeLeft();
            },
          ),
          AnimatedActionButton(
            icon: Icons.bolt,
            color: const Color(0xFFF59E0B),
            size: 50,
            onTap: () {
              HapticFeedback.heavyImpact();
              _swiperController.swipeUp();
            },
          ),
          AnimatedActionButton(
            icon: Icons.favorite,
            color: AppColors.primary,
            size: 60,
            onTap: () {
              HapticFeedback.mediumImpact();
              _swiperController.swipeRight();
            },
          ),
        ],
      ),
    );
  }
}

class _ChipGroup extends StatelessWidget {
  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelected;
  const _ChipGroup(
      {required this.options,
      required this.selected,
      required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((o) {
        final isSelected = o == selected;
        return GestureDetector(
          onTap: () => onSelected(o),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary
                  : Theme.of(context).colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: isSelected
                      ? AppColors.primary
                      : Theme.of(context).colorScheme.outline.withOpacity(0.4)),
            ),
            child: Text(o,
                style: TextStyle(
                    fontSize: 12,
                    color: isSelected
                        ? Colors.white
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal)),
          ),
        );
      }).toList(),
    );
  }
}

class _ActiveChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;
  const _ActiveChip({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w500)),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close,
                size: 14, color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}

class _FilterLabel extends StatelessWidget {
  final String text;
  const _FilterLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface));
  }
}

class _JobOfferCard extends StatelessWidget {
  final JobOffer offer;
  final int? score;
  final RecruiterProfile? recruiterProfile;
  const _JobOfferCard({required this.offer, this.score, this.recruiterProfile});

  @override
  Widget build(BuildContext context) {
    final shownSkills = offer.requiredSkillList.take(3).toList();
    final extra = offer.requiredSkillList.length - shownSkills.length;
    final isFlash = offer.isFlash && offer.isFlashActive;

    final contactPhotoUrl = recruiterProfile?.contactPhotoUrl;
    final logoUrl = recruiterProfile?.companyLogoUrl;
    final hasContactPhoto = contactPhotoUrl != null && contactPhotoUrl.isNotEmpty;
    final hasLogo = logoUrl != null && logoUrl.isNotEmpty;

    // Background: contact photo OR flash gradient OR company gradient
    final bgGradient = isFlash
        ? const LinearGradient(
            colors: [Color(0xFF92400E), Color(0xFFB45309), Color(0xFFF59E0B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : AvatarColors.gradientForString(offer.companyName);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: isFlash
                  ? const Color(0xFFF59E0B).withOpacity(0.4)
                  : Colors.black.withOpacity(0.35),
              blurRadius: 28,
              offset: const Offset(0, 14)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── Background ──────────────────────────────────────────────────
          if (hasContactPhoto)
            Image.network(
              contactPhotoUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  Container(decoration: BoxDecoration(gradient: bgGradient)),
            )
          else
            Container(decoration: BoxDecoration(gradient: bgGradient)),

          // Decorative circles (only when no photo)
          if (!hasContactPhoto) ...[
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
            Positioned(
              top: 80, left: -50,
              child: Container(
                width: 120, height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.05),
                ),
              ),
            ),
            // Company initials when no photo
            Positioned(
              top: 0, left: 0, right: 0, bottom: 260,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      offer.initials,
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.92),
                          fontSize: 80,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 4),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(offer.companyName,
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.85),
                              fontSize: 13,
                              fontWeight: FontWeight.w500)),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // ── Dark gradient overlay — bottom ──────────────────────────────
          Positioned(
            left: 0, right: 0, bottom: 0,
            height: 300,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Color(0xBB000000),
                    Color(0xEE000000)
                  ],
                  stops: [0.0, 0.45, 1.0],
                ),
              ),
            ),
          ),

          // ── Company logo badge — top left (when contact photo is shown) ─
          if (hasContactPhoto && hasLogo)
            Positioned(
              top: 16, left: 16,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.2), blurRadius: 6)
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(logoUrl,
                      width: 40, height: 40, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox()),
                ),
              ),
            ),

          // ── Flash badge — top left (when no logo or no contact photo) ──
          if (isFlash && !(hasContactPhoto && hasLogo))
            Positioned(
              top: 16, left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bolt, color: Color(0xFFFBBF24), size: 14),
                    SizedBox(width: 3),
                    Text('FLASH',
                        style: TextStyle(
                            color: Color(0xFFFBBF24),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            letterSpacing: 1)),
                  ],
                ),
              ),
            ),

          // Flash badge alongside logo (when both exist)
          if (isFlash && hasContactPhoto && hasLogo)
            Positioned(
              top: 16, left: 64,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.bolt, color: Color(0xFFFBBF24), size: 12),
                  SizedBox(width: 2),
                  Text('FLASH',
                      style: TextStyle(
                          color: Color(0xFFFBBF24),
                          fontWeight: FontWeight.bold,
                          fontSize: 11)),
                ]),
              ),
            ),

          // ── Compatibility score — top right ─────────────────────────────
          if (score != null)
            Positioned(
              top: 16, right: 16,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: score! >= 70 ? AppColors.green : AppColors.orange,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                        color: (score! >= 70
                                ? AppColors.green
                                : AppColors.orange)
                            .withOpacity(0.5),
                        blurRadius: 10)
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.bolt, color: Colors.white, size: 14),
                    const SizedBox(width: 3),
                    Text('$score%',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13)),
                  ],
                ),
              ),
            ),

          // ── Content overlay — bottom ─────────────────────────────────────
          Positioned(
            left: 20, right: 20, bottom: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Company name pill (only when contact photo shown — initials already show it)
                if (hasContactPhoto)
                  Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(offer.companyName,
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 12,
                            fontWeight: FontWeight.w500)),
                  ),
                if (recruiterProfile?.isVerifiedEmployer == true)
                  Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.4)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified, color: Colors.white, size: 11),
                        SizedBox(width: 4),
                        Text('Employeur vérifié',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                Text(offer.title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        height: 1.2)),
                const SizedBox(height: 5),
                Row(children: [
                  const Icon(Icons.location_on_outlined,
                      color: Colors.white60, size: 13),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(offer.location,
                        style: const TextStyle(
                            color: Colors.white60, fontSize: 13),
                        overflow: TextOverflow.ellipsis),
                  ),
                ]),
                if (offer.hasSalary) ...[
                  const SizedBox(height: 8),
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
                      const Icon(Icons.euro, color: AppColors.green, size: 13),
                      const SizedBox(width: 3),
                      Text(offer.salaryDisplay,
                          style: const TextStyle(
                              color: AppColors.green,
                              fontWeight: FontWeight.w700,
                              fontSize: 13)),
                    ]),
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Wrap(spacing: 6, runSpacing: 6, children: [
                        if (offer.contractType.isNotEmpty)
                          _CardBadge(offer.contractType),
                        if (offer.level.isNotEmpty) _CardBadge(offer.level),
                        if (offer.remoteMode.isNotEmpty)
                          _CardBadge(offer.remoteMode),
                        ...shownSkills.map((s) => _CardBadge(s)),
                        if (extra > 0) _CardBadge('+$extra'),
                      ]),
                    ),
                    if (isFlash) ...[
                      const SizedBox(width: 8),
                      _FlashCountdown(offer: offer),
                    ],
                  ],
                ),
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

class _FlashMiniCard extends StatelessWidget {
  final JobOffer offer;
  const _FlashMiniCard({required this.offer});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF92400E), Color(0xFFF59E0B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFFF59E0B).withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [
            const Icon(Icons.bolt, color: Color(0xFFFBBF24), size: 14),
            const SizedBox(width: 3),
            Text(offer.flashRemainingDisplay,
                style: const TextStyle(
                    color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
          ]),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(offer.title,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(offer.companyName,
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.75), fontSize: 10),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ],
      ),
    );
  }
}

class _FlashCountdown extends StatefulWidget {
  final JobOffer offer;
  const _FlashCountdown({required this.offer});
  @override
  State<_FlashCountdown> createState() => _FlashCountdownState();
}

class _FlashCountdownState extends State<_FlashCountdown> {
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.offer.flashRemainingDisplay;
    if (label.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.35),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timer_outlined, color: Colors.white, size: 12),
          const SizedBox(width: 3),
          Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}