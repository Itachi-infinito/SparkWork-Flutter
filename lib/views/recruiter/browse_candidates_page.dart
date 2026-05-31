import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_skills.dart';
import '../../core/widgets/empty_state.dart';
import '../../models/candidate_profile.dart';
import '../../repositories/candidate_profile_repository.dart';

class BrowseCandidatesPage extends ConsumerStatefulWidget {
  const BrowseCandidatesPage({super.key});

  @override
  ConsumerState<BrowseCandidatesPage> createState() =>
      _BrowseCandidatesPageState();
}

class _BrowseCandidatesPageState extends ConsumerState<BrowseCandidatesPage> {
  static const _pageSize = 20;

  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  List<CandidateProfile> _all = [];
  List<CandidateProfile> _filtered = [];
  List<CandidateProfile> _displayed = [];
  bool _loading = true;

  String _filterSkill = '';
  String _filterLevel = '';
  String _filterContractType = '';
  String _filterLocation = '';

  bool get _hasFilters =>
      _filterSkill.isNotEmpty ||
      _filterLevel.isNotEmpty ||
      _filterContractType.isNotEmpty ||
      _filterLocation.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(_applyFilters);
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final profiles = await ref
        .read(candidateProfileRepositoryProvider)
        .getAllProfiles();
    if (mounted) {
      setState(() {
        _all = profiles;
        _loading = false;
      });
      _applyFilters();
    }
  }

  void _applyFilters() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered = _all.where((p) {
        if (q.isNotEmpty &&
            !p.fullName.toLowerCase().contains(q) &&
            !p.location.toLowerCase().contains(q) &&
            !p.skills.toLowerCase().contains(q)) return false;
        if (_filterSkill.isNotEmpty &&
            !p.skills.toLowerCase().contains(_filterSkill.toLowerCase()))
          return false;
        if (_filterLevel.isNotEmpty && p.desiredLevel != _filterLevel)
          return false;
        if (_filterContractType.isNotEmpty &&
            p.desiredContractType != _filterContractType) return false;
        if (_filterLocation.isNotEmpty &&
            !p.location
                .toLowerCase()
                .contains(_filterLocation.toLowerCase())) return false;
        return true;
      }).toList();
      _displayed = _filtered.take(_pageSize).toList();
    });
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 200) {
      if (_displayed.length < _filtered.length) {
        setState(() {
          final next =
              _filtered.skip(_displayed.length).take(_pageSize);
          _displayed = [..._displayed, ...next];
        });
      }
    }
  }

  void _clearFilters() {
    setState(() {
      _filterSkill = '';
      _filterLevel = '';
      _filterContractType = '';
      _filterLocation = '';
    });
    _applyFilters();
  }

  void _showFilterSheet() {
    String tempSkill = _filterSkill;
    String tempLevel = _filterLevel;
    String tempContract = _filterContractType;
    String tempLocation = _filterLocation;
    final skillCtrl = TextEditingController(text: _filterSkill);
    final locationCtrl = TextEditingController(text: _filterLocation);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Filtres avancés',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary)),
                    TextButton(
                      onPressed: () => setSheet(() {
                        tempSkill = '';
                        tempLevel = '';
                        tempContract = '';
                        tempLocation = '';
                        skillCtrl.clear();
                        locationCtrl.clear();
                      }),
                      child: const Text('Réinitialiser',
                          style: TextStyle(color: AppColors.primary)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const _FilterLabel('Compétence clé'),
                const SizedBox(height: 8),
                TextField(
                  controller: skillCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Ex: Chef de rang, Barista...',
                    prefixIcon: Icon(Icons.star_outline, size: 18),
                    isDense: true,
                  ),
                  onChanged: (v) => tempSkill = v,
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
                const _FilterLabel('Contrat souhaité'),
                const SizedBox(height: 8),
                _ChipGroup(
                  options: AppSkills.contractTypes,
                  selected: tempContract,
                  onSelected: (v) => setSheet(
                      () => tempContract = v == tempContract ? '' : v),
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
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _filterSkill = tempSkill;
                        _filterLevel = tempLevel;
                        _filterContractType = tempContract;
                        _filterLocation = tempLocation;
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
                    child: const Text('Appliquer',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Candidats'),
        backgroundColor: AppColors.background,
        elevation: 0,
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.tune),
                onPressed: _showFilterSheet,
                tooltip: 'Filtres',
              ),
              if (_hasFilters)
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Nom, ville, compétence...',
                prefixIcon:
                    const Icon(Icons.search, color: AppColors.textHint),
                filled: true,
                fillColor: AppColors.surface,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        const BorderSide(color: AppColors.border)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        const BorderSide(color: AppColors.border)),
              ),
            ),
          ),
          if (_hasFilters) _buildActiveFilterChips(),
          if (!_loading && _all.isNotEmpty)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(children: [
                Text(
                  '${_filtered.length} candidat${_filtered.length > 1 ? 's' : ''}',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
              ]),
            ),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.primary))
                : _filtered.isEmpty
                    ? EmptyState(
                        icon: _hasFilters || _searchCtrl.text.isNotEmpty
                            ? Icons.person_search
                            : Icons.group_outlined,
                        title: _hasFilters || _searchCtrl.text.isNotEmpty
                            ? 'Aucun candidat trouvé'
                            : 'Aucun candidat',
                        subtitle: _hasFilters || _searchCtrl.text.isNotEmpty
                            ? 'Modifiez vos filtres pour voir plus de résultats.'
                            : 'Les candidats inscrits apparaîtront ici.',
                        action: _hasFilters
                            ? OutlinedButton.icon(
                                onPressed: _clearFilters,
                                icon: const Icon(Icons.filter_list_off,
                                    color: AppColors.primary, size: 16),
                                label: const Text('Effacer les filtres',
                                    style: TextStyle(
                                        color: AppColors.primary)),
                                style: OutlinedButton.styleFrom(
                                    side: const BorderSide(
                                        color: AppColors.primary)),
                              )
                            : null,
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        color: AppColors.primary,
                        child: ListView.separated(
                          controller: _scrollCtrl,
                          padding:
                              const EdgeInsets.fromLTRB(16, 4, 16, 16),
                          itemCount: _displayed.length +
                              (_displayed.length < _filtered.length
                                  ? 1
                                  : 0),
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (ctx, i) {
                            if (i == _displayed.length) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(16),
                                  child: CircularProgressIndicator(
                                      color: AppColors.primary,
                                      strokeWidth: 2),
                                ),
                              );
                            }
                            final c = _displayed[i];
                            return GestureDetector(
                              onTap: () => context.push(
                                  '/recruiter/candidates/${c.userId}'),
                              child: Card(
                                elevation: 0,
                                color: AppColors.surface,
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(14),
                                    side: const BorderSide(
                                        color: AppColors.border)),
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Row(children: [
                                    CircleAvatar(
                                      radius: 26,
                                      backgroundColor:
                                          AppColors.primaryLight,
                                      child: Text(c.initials,
                                          style: const TextStyle(
                                              color: AppColors.primary,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16)),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(c.fullName,
                                              style: const TextStyle(
                                                  fontWeight:
                                                      FontWeight.bold,
                                                  fontSize: 14,
                                                  color: AppColors
                                                      .textPrimary)),
                                          if (c.location.isNotEmpty)
                                            Row(children: [
                                              const Icon(
                                                  Icons
                                                      .location_on_outlined,
                                                  size: 12,
                                                  color: AppColors
                                                      .textSecondary),
                                              const SizedBox(width: 2),
                                              Text(c.location,
                                                  style: const TextStyle(
                                                      color: AppColors
                                                          .textSecondary,
                                                      fontSize: 12)),
                                            ]),
                                          if (c.desiredContractType
                                              .isNotEmpty)
                                            Text(c.desiredContractType,
                                                style: const TextStyle(
                                                    color: AppColors
                                                        .primary,
                                                    fontSize: 12,
                                                    fontWeight:
                                                        FontWeight.w500)),
                                          if (c.skillList.isNotEmpty) ...[
                                            const SizedBox(height: 6),
                                            Wrap(
                                              spacing: 4,
                                              runSpacing: 4,
                                              children: c.skillList
                                                  .take(3)
                                                  .map((s) => Container(
                                                        padding: const EdgeInsets
                                                            .symmetric(
                                                            horizontal: 8,
                                                            vertical: 2),
                                                        decoration: BoxDecoration(
                                                            color: AppColors
                                                                .primaryLight,
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                    20)),
                                                        child: Text(s,
                                                            style: const TextStyle(
                                                                color: AppColors
                                                                    .primary,
                                                                fontSize:
                                                                    10)),
                                                      ))
                                                  .toList(),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    const Icon(Icons.chevron_right,
                                        color: AppColors.textHint),
                                  ]),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveFilterChips() {
    final chips = <Widget>[];
    if (_filterSkill.isNotEmpty) {
      chips.add(_ActiveChip(
          label: _filterSkill,
          onRemove: () {
            setState(() => _filterSkill = '');
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
    if (_filterContractType.isNotEmpty) {
      chips.add(_ActiveChip(
          label: _filterContractType,
          onRemove: () {
            setState(() => _filterContractType = '');
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: chips
                    .map((c) => Padding(
                        padding: const EdgeInsets.only(right: 6), child: c))
                    .toList(),
              ),
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
}

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
                  : AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color:
                      isSelected ? AppColors.primary : AppColors.border),
            ),
            child: Text(o,
                style: TextStyle(
                    fontSize: 12,
                    color: isSelected
                        ? Colors.white
                        : AppColors.textSecondary,
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