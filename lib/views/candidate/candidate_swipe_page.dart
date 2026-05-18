import 'package:appinio_swiper/appinio_swiper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_skills.dart';
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
  ConsumerState<CandidateSwipePage> createState() =>
      _CandidateSwipePageState();
}

class _CandidateSwipePageState extends ConsumerState<CandidateSwipePage> {
  final AppinioSwiperController _swiperController =
      AppinioSwiperController();

  List<JobOffer> _allOffers = [];
  List<JobOffer> _offers = [];
  CandidateProfile? _candidateProfile;
  Map<int, int> _scores = {};
  bool _loading = true;
  String? _error;

  // Filtres
  String? _filterContractType;
  String? _filterLevel;
  String? _filterRemoteMode;
  String _filterLocation = '';
  int? _filterMinSalary;

  bool get _hasActiveFilters =>
      _filterContractType != null ||
      _filterLevel != null ||
      _filterRemoteMode != null ||
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
      final unseen = allOffers
          .where((o) => !likedSet.contains(o.jobOfferId))
          .toList();
      final profile = await profileRepo.getProfile(userId);

      final scores = <int, int>{};
      if (profile != null) {
        for (final offer in unseen) {
          scores[offer.jobOfferId] =
              compatService.calculateScore(profile, offer);
        }
      }

      if (mounted) {
        setState(() {
          _allOffers = unseen;
          _candidateProfile = profile;
          _scores = scores;
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
        if (_filterContractType != null &&
            o.contractType != _filterContractType) return false;
        if (_filterLevel != null && o.level != _filterLevel) return false;
        if (_filterRemoteMode != null &&
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

  void _clearFilters() {
    setState(() {
      _filterContractType = null;
      _filterLevel = null;
      _filterRemoteMode = null;
      _filterLocation = '';
      _filterMinSalary = null;
    });
    _applyFilters();
  }

  void _showFilterSheet() {
    // Copie locale pour annuler si besoin
    String? contractType = _filterContractType;
    String? level = _filterLevel;
    String? remoteMode = _filterRemoteMode;
    String location = _filterLocation;
    int? minSalary = _filterMinSalary;
    final locationCtrl = TextEditingController(text: location);
    final salaryCtrl = TextEditingController(
        text: minSalary != null ? minSalary.toString() : '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Text('Filtres',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary)),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        setSheetState(() {
                          contractType = null;
                          level = null;
                          remoteMode = null;
                          location = '';
                          minSalary = null;
                          locationCtrl.clear();
                          salaryCtrl.clear();
                        });
                      },
                      child: const Text('Tout effacer',
                          style: TextStyle(color: AppColors.red)),
                    ),
                  ],
                ),
                const Divider(),
                const SizedBox(height: 8),

                // Contrat
                const _FilterLabel('Type de contrat'),
                const SizedBox(height: 8),
                _ChipGroup(
                  options: AppSkills.contractTypes,
                  selected: contractType,
                  onSelected: (v) =>
                      setSheetState(() => contractType = v),
                ),
                const SizedBox(height: 16),

                // Niveau
                const _FilterLabel('Niveau d\'expérience'),
                const SizedBox(height: 8),
                _ChipGroup(
                  options: AppSkills.levels,
                  selected: level,
                  onSelected: (v) =>
                      setSheetState(() => level = v),
                ),
                const SizedBox(height: 16),

                // Télétravail
                const _FilterLabel('Télétravail'),
                const SizedBox(height: 8),
                _ChipGroup(
                  options: AppSkills.remoteModes,
                  selected: remoteMode,
                  onSelected: (v) =>
                      setSheetState(() => remoteMode = v),
                ),
                const SizedBox(height: 16),

                // Localisation
                const _FilterLabel('Ville / Région'),
                const SizedBox(height: 8),
                TextField(
                  controller: locationCtrl,
                  decoration: InputDecoration(
                    hintText: 'Ex: Bruxelles',
                    prefixIcon: const Icon(Icons.location_on_outlined,
                        color: AppColors.textHint),
                    filled: true,
                    fillColor: AppColors.surfaceVariant,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                  ),
                  onChanged: (v) => location = v,
                ),
                const SizedBox(height: 16),

                // Salaire minimum
                const _FilterLabel('Salaire minimum (€/mois)'),
                const SizedBox(height: 8),
                TextField(
                  controller: salaryCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: 'Ex: 2000',
                    prefixIcon: const Icon(Icons.euro_outlined,
                        color: AppColors.textHint),
                    filled: true,
                    fillColor: AppColors.surfaceVariant,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                  ),
                  onChanged: (v) =>
                      minSalary = int.tryParse(v),
                ),
                const SizedBox(height: 24),

                // Bouton Appliquer
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _filterContractType = contractType;
                        _filterLevel = level;
                        _filterRemoteMode = remoteMode;
                        _filterLocation = location;
                        _filterMinSalary = minSalary;
                      });
                      _applyFilters();
                      Navigator.pop(ctx);
                    },
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14))),
                    child: const Text('Appliquer les filtres',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleSwipeRight(JobOffer offer) async {
    final session = ref.read(sessionProvider);
    final candidateUserId = session.userId;
    final likeRepo = ref.read(candidateJobLikeRepositoryProvider);
    final recruiterLikeRepo =
        ref.read(recruiterCandidateLikeRepositoryProvider);
    final matchRepo = ref.read(matchRepositoryProvider);

    await likeRepo.addLike(candidateUserId, offer.jobOfferId);

    final recruiterUserId = offer.recruiterUserId;
    final mutual = await recruiterLikeRepo.hasRecruiterLikedCandidate(
        recruiterUserId, candidateUserId, offer.jobOfferId);

    if (mutual) {
      final alreadyExists = await matchRepo.matchExists(
          candidateUserId, recruiterUserId, offer.jobOfferId);
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

  void _onSwipeEnd(
      int previousIndex, int? targetIndex, SwiperActivity activity) {
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
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.tune_rounded),
                tooltip: 'Filtres',
                onPressed: _showFilterSheet,
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
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? _buildErrorState()
              : Column(
                  children: [
                    if (_hasActiveFilters) _buildActiveFilterChips(),
                    Expanded(
                      child: _offers.isEmpty
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

    if (_filterContractType != null) {
      chips.add(_ActiveChip(
          label: _filterContractType!,
          onRemove: () {
            setState(() => _filterContractType = null);
            _applyFilters();
          }));
    }
    if (_filterLevel != null) {
      chips.add(_ActiveChip(
          label: _filterLevel!,
          onRemove: () {
            setState(() => _filterLevel = null);
            _applyFilters();
          }));
    }
    if (_filterRemoteMode != null) {
      chips.add(_ActiveChip(
          label: _filterRemoteMode!,
          onRemove: () {
            setState(() => _filterRemoteMode = null);
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
          label: '≥ $_filterMinSalary €',
          onRemove: () {
            setState(() => _filterMinSalary = null);
            _applyFilters();
          }));
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      color: AppColors.background,
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                  children: chips
                      .map((c) => Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: c))
                      .toList()),
            ),
          ),
          TextButton(
            onPressed: _clearFilters,
            style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8)),
            child: const Text('Effacer',
                style: TextStyle(
                    color: AppColors.red, fontSize: 12)),
          ),
        ],
      ),
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
                style: const TextStyle(
                    color: AppColors.textSecondary),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            OutlinedButton(
                onPressed: _loadData,
                child: const Text('Réessayer')),
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
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                  color: AppColors.primaryLight,
                  shape: BoxShape.circle),
              child: const Icon(Icons.search_off_rounded,
                  color: AppColors.primary, size: 40),
            ),
            const SizedBox(height: 20),
            Text(
              _hasActiveFilters
                  ? 'Aucune offre correspond à vos filtres'
                  : 'Aucune offre disponible',
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _hasActiveFilters
                  ? 'Essayez de modifier ou supprimer vos filtres.'
                  : 'Vous avez tout vu ! Revenez plus tard.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            if (_hasActiveFilters)
              ElevatedButton.icon(
                onPressed: _clearFilters,
                icon: const Icon(Icons.filter_alt_off_outlined),
                label: const Text('Supprimer les filtres'),
              )
            else
              OutlinedButton.icon(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh,
                    color: AppColors.primary),
                label: const Text('Actualiser',
                    style: TextStyle(color: AppColors.primary)),
                style: OutlinedButton.styleFrom(
                    side: const BorderSide(
                        color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12)),
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
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 8),
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
      padding: const EdgeInsets.symmetric(
          horizontal: 40, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          GestureDetector(
            onTap: () => _swiperController.swipeLeft(),
            child: Container(
              width: 60,
              height: 60,
              decoration: const BoxDecoration(
                  color: AppColors.redLight,
                  shape: BoxShape.circle),
              child: const Icon(Icons.close,
                  color: AppColors.red, size: 30),
            ),
          ),
          GestureDetector(
            onTap: () => _swiperController.swipeRight(),
            child: Container(
              width: 50,
              height: 50,
              decoration: const BoxDecoration(
                  color: Color(0xFFFEF3C7),
                  shape: BoxShape.circle),
              child: const Icon(Icons.bolt,
                  color: Color(0xFFF59E0B), size: 26),
            ),
          ),
          GestureDetector(
            onTap: () => _swiperController.swipeRight(),
            child: Container(
              width: 60,
              height: 60,
              decoration: const BoxDecoration(
                  color: AppColors.primaryLight,
                  shape: BoxShape.circle),
              child: const Icon(Icons.favorite,
                  color: AppColors.primary, size: 30),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Widgets helpers ────────────────────────────────────────

class _FilterLabel extends StatelessWidget {
  final String text;
  const _FilterLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary));
}

class _ChipGroup extends StatelessWidget {
  final List<String> options;
  final String? selected;
  final ValueChanged<String?> onSelected;
  const _ChipGroup(
      {required this.options,
      required this.selected,
      required this.onSelected});

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: options.map((o) {
          final isSelected = selected == o;
          return GestureDetector(
            onTap: () => onSelected(isSelected ? null : o),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary
                    : AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.border,
                ),
              ),
              child: Text(o,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isSelected
                          ? Colors.white
                          : AppColors.textSecondary)),
            ),
          );
        }).toList(),
      );
}

class _ActiveChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;
  const _ActiveChip({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.only(
            left: 10, right: 4, top: 4, bottom: 4),
        decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(20)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
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

class _JobOfferCard extends StatelessWidget {
  final JobOffer offer;
  final int? score;
  const _JobOfferCard({required this.offer, this.score});

  @override
  Widget build(BuildContext context) {
    final requiredSkills = offer.requiredSkillList;
    final shownSkills = requiredSkills.take(3).toList();
    final extraSkillsCount =
        requiredSkills.length - shownSkills.length;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.10),
              blurRadius: 20,
              offset: const Offset(0, 8))
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 160,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                  colors: [
                    AppColors.primary,
                    AppColors.primaryDark
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
            ),
            child: Stack(
              children: [
                Center(
                    child: Text(offer.initials,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 56,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2))),
                if (score != null)
                  Positioned(
                    top: 14,
                    right: 14,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: score! >= 70
                            ? AppColors.green
                            : const Color(0xFFF59E0B),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.bolt,
                              color: Colors.white, size: 14),
                          const SizedBox(width: 2),
                          Text('$score%',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13)),
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
                  Text(offer.title,
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 4),
                  Text(offer.companyName,
                      style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14)),
                  const SizedBox(height: 8),
                  Row(children: [
                    const Icon(Icons.location_on_outlined,
                        size: 14,
                        color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Expanded(
                        child: Text(offer.location,
                            style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13),
                            overflow: TextOverflow.ellipsis)),
                  ]),
                  const SizedBox(height: 12),
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    if (offer.contractType.isNotEmpty)
                      _Badge(label: offer.contractType),
                    if (offer.level.isNotEmpty)
                      _Badge(label: offer.level),
                    if (offer.remoteMode.isNotEmpty)
                      _Badge(label: offer.remoteMode),
                  ]),
                  if (offer.hasSalary) ...[
                    const SizedBox(height: 12),
                    Row(children: [
                      const Icon(Icons.euro,
                          size: 16, color: AppColors.green),
                      const SizedBox(width: 6),
                      Text(offer.salaryDisplay,
                          style: const TextStyle(
                              color: AppColors.green,
                              fontWeight: FontWeight.w600,
                              fontSize: 14)),
                    ]),
                  ],
                  if (shownSkills.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      ...shownSkills
                          .map((s) => _SkillChip(label: s)),
                      if (extraSkillsCount > 0)
                        _SkillChip(label: '+$extraSkillsCount'),
                    ]),
                  ],
                  const SizedBox(height: 12),
                  Text(offer.description,
                      style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis),
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
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.border)),
        child: Text(label,
            style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500)),
      );
}

class _SkillChip extends StatelessWidget {
  final String label;
  const _SkillChip({required this.label});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(6)),
        child: Text(label,
            style: const TextStyle(
                fontSize: 11,
                color: AppColors.primary,
                fontWeight: FontWeight.w500)),
      );
}