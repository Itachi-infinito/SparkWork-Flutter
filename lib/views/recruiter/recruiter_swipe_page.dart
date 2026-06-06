import 'package:appinio_swiper/appinio_swiper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_skills.dart';
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
      _applyFilters();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyFilters() {
    setState(() {
      _activeItems = _items.where((item) {
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
        if (_filterRemoteMode.isNotEmpty && p.remotePreference != _filterRemoteMode) {
          return false;
        }
        if (_filterSkill.isNotEmpty && !p.skillList.contains(_filterSkill)) {
          return false;
        }
        return true;
      }).toList();
    });
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
      backgroundColor: AppColors.surface,
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
                          side: const BorderSide(color: AppColors.textSecondary),
                        ),
                        child: const Text('Réinitialiser',
                            style: TextStyle(color: AppColors.textSecondary)),
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

  Future<void> _handleLike(_SwipeItem item) async {
    if (_selectedOffer == null) return;
    final session = ref.read(sessionProvider);
    final likeRepo = ref.read(recruiterCandidateLikeRepositoryProvider);
    final candidateLikeRepo = ref.read(candidateJobLikeRepositoryProvider);
    final matchRepo = ref.read(matchRepositoryProvider);

    await likeRepo.addLike(session.userId, item.profile.userId, _selectedOffer!.jobOfferId);

    final candidateAlsoLiked = await candidateLikeRepo.hasLiked(item.profile.userId, _selectedOffer!.jobOfferId);
    if (candidateAlsoLiked) {
      final alreadyMatched = await matchRepo.matchExists(item.profile.userId, session.userId, _selectedOffer!.jobOfferId);
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
    if (activity is Swipe) {
      if (activity.direction == AxisDirection.right || activity.direction == AxisDirection.up) {
        if (prev < _activeItems.length) await _handleLike(_activeItems[prev]);
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
          const Text(
            'Aucun candidat disponible',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            _hasActiveFilters
                ? 'Essayez de modifier vos filtres'
                : 'Revenez plus tard !',
            style: const TextStyle(color: AppColors.textSecondary),
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
          child: AppinioSwiper(
            controller: _controller,
            cardCount: _activeItems.length,
            onSwipeEnd: _onSwipeEnd,
            cardBuilder: (context, index) {
              if (index >= _activeItems.length) return const SizedBox();
              return _buildCard(_activeItems[index]);
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ActionButton(icon: Icons.close, color: AppColors.red, size: 56, onTap: () => _controller.swipeLeft()),
              _ActionButton(icon: Icons.bolt, color: AppColors.orange, size: 46, onTap: () => _controller.swipeRight()),
              _ActionButton(icon: Icons.favorite, color: AppColors.green, size: 56, onTap: () => _controller.swipeRight()),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCard(_SwipeItem item) {
    final p = item.profile;
    final scoreColor = item.score >= 70 ? AppColors.green : AppColors.orange;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 140,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.green, Color(0xFF059669)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Stack(children: [
              Center(
                child: Text(
                  p.initials,
                  style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold),
                ),
              ),
              Positioned(
                top: 12, right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: scoreColor, borderRadius: BorderRadius.circular(20)),
                  child: Text('${item.score}%',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ),
            ]),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.fullName,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                if (p.location.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(p.location, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  ]),
                ],
                const SizedBox(height: 12),
                Wrap(spacing: 6, runSpacing: 4, children: [
                  if (p.desiredContractType.isNotEmpty)
                    _Badge(p.desiredContractType, AppColors.primaryLight, AppColors.primary),
                  if (p.desiredLevel.isNotEmpty)
                    _Badge(p.desiredLevel, AppColors.greenLight, AppColors.green),
                  if (p.remotePreference.isNotEmpty)
                    _Badge(p.remotePreference, AppColors.orangeLight, AppColors.orange),
                ]),
                if (p.skillList.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6, runSpacing: 4,
                    children: p.skillList.take(5)
                        .map((s) => _Badge(s, AppColors.primaryLight, AppColors.primary))
                        .toList(),
                  ),
                ],
                if (p.hasSalary) ...[
                  const SizedBox(height: 12),
                  Row(children: [
                    const Icon(Icons.euro, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(p.salaryDisplay, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  ]),
                ],
                if (p.bio.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(p.bio,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
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

class _Badge extends StatelessWidget {
  final String text;
  final Color bg;
  final Color fg;
  const _Badge(this.text, this.bg, this.fg);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: TextStyle(fontSize: 11, color: fg)),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final VoidCallback onTap;
  const _ActionButton({required this.icon, required this.color, required this.size, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size, height: size,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 2),
        ),
        child: Icon(icon, color: color, size: size * 0.45),
      ),
    );
  }
}
