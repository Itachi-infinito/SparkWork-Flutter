import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_skills.dart';
import '../../core/widgets/app_avatar.dart';
import '../../models/candidate_profile.dart';
import '../../repositories/candidate_profile_repository.dart';

class BrowseCandidatesPage extends ConsumerStatefulWidget {
  const BrowseCandidatesPage({super.key});

  @override
  ConsumerState<BrowseCandidatesPage> createState() =>
      _BrowseCandidatesPageState();
}

class _BrowseCandidatesPageState extends ConsumerState<BrowseCandidatesPage> {
  List<CandidateProfile> _all = [];
  List<CandidateProfile> _filtered = [];
  bool _loading = true;
  final _searchCtrl = TextEditingController();

  String _filterLevel = '';
  String _filterContractType = '';
  String _filterLocation = '';
  String _filterSkill = '';

  bool get _hasActiveFilters =>
      _filterLevel.isNotEmpty ||
      _filterContractType.isNotEmpty ||
      _filterLocation.isNotEmpty ||
      _filterSkill.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(_filter);
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_filter);
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final profiles = await ref
          .read(candidateProfileRepositoryProvider)
          .getAllProfiles();
      if (mounted) {
        setState(() {
          _all = profiles;
          _loading = false;
        });
        _filter();
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _filter() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered = _all.where((p) {
        if (q.isNotEmpty &&
            !p.fullName.toLowerCase().contains(q) &&
            !p.location.toLowerCase().contains(q) &&
            !p.skillList.any((s) => s.toLowerCase().contains(q))) {
          return false;
        }
        if (_filterLevel.isNotEmpty && p.desiredLevel != _filterLevel) {
          return false;
        }
        if (_filterContractType.isNotEmpty) {
          final types = AppSkills.parseSkills(p.desiredContractType);
          if (!types.any((t) => t == _filterContractType)) return false;
        }
        if (_filterLocation.isNotEmpty &&
            !p.location.toLowerCase().contains(_filterLocation.toLowerCase())) {
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
    String tmpLevel = _filterLevel;
    String tmpContract = _filterContractType;
    String tmpLocation = _filterLocation;
    String tmpSkill = _filterSkill;
    final locationCtrl = TextEditingController(text: tmpLocation);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => DraggableScrollableSheet(
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
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Filtrer les candidats',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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

              const Text('Niveau d\'expérience',
                  style: TextStyle(fontWeight: FontWeight.w600)),
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

              const Text('Type de contrat',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8, runSpacing: 6,
                children: AppSkills.contractTypes.map((c) => FilterChip(
                  label: Text(c),
                  selected: tmpContract == c,
                  onSelected: (v) => setSheet(() => tmpContract = v ? c : ''),
                  selectedColor: AppColors.primaryLight,
                  checkmarkColor: AppColors.primary,
                )).toList(),
              ),
              const SizedBox(height: 20),

              const Text('Compétence',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: tmpSkill.isEmpty ? null : tmpSkill,
                hint: const Text('Toutes les compétences'),
                decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.star_outline)),
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
                      tmpLevel = '';
                      tmpContract = '';
                      tmpLocation = '';
                      tmpSkill = '';
                      locationCtrl.clear();
                    }),
                    style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.textSecondary)),
                    child: const Text('Réinitialiser',
                        style: TextStyle(color: AppColors.textSecondary)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _filterLevel = tmpLevel;
                        _filterContractType = tmpContract;
                        _filterLocation = tmpLocation;
                        _filterSkill = tmpSkill;
                      });
                      _filter();
                      Navigator.pop(ctx);
                    },
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary),
                    child: const Text('Appliquer',
                        style: TextStyle(color: Colors.white)),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveChips() {
    if (!_hasActiveFilters) return const SizedBox();
    final chips = <Widget>[];
    void remove(VoidCallback fn) { fn(); _filter(); }
    if (_filterLocation.isNotEmpty) {
      chips.add(_Chip(_filterLocation,
          () => remove(() => setState(() => _filterLocation = ''))));
    }
    if (_filterLevel.isNotEmpty) {
      chips.add(_Chip(_filterLevel,
          () => remove(() => setState(() => _filterLevel = ''))));
    }
    if (_filterContractType.isNotEmpty) {
      chips.add(_Chip(_filterContractType,
          () => remove(() => setState(() => _filterContractType = ''))));
    }
    if (_filterSkill.isNotEmpty) {
      chips.add(_Chip(_filterSkill,
          () => remove(() => setState(() => _filterSkill = ''))));
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Candidats'),
        backgroundColor: AppColors.background,
        elevation: 0,
        actions: [
          Stack(children: [
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
                      color: AppColors.primary, shape: BoxShape.circle),
                ),
              ),
          ]),
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
                prefixIcon: const Icon(Icons.search, color: AppColors.textHint),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () { _searchCtrl.clear(); _filter(); },
                      )
                    : null,
                filled: true,
                fillColor: AppColors.surface,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.border)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.border)),
              ),
            ),
          ),
          _buildActiveChips(),
          if (!_loading)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Row(
                children: [
                  Text(
                    '${_filtered.length} candidat${_filtered.length > 1 ? 's' : ''}',
                    style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500),
                  ),
                  if (_hasActiveFilters) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _filterLevel = '';
                          _filterContractType = '';
                          _filterLocation = '';
                          _filterSkill = '';
                        });
                        _filter();
                      },
                      child: const Text('Effacer les filtres',
                          style: TextStyle(
                              fontSize: 13,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w500)),
                    ),
                  ],
                ],
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary))
                : _filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: const BoxDecoration(
                                  color: AppColors.primaryLight,
                                  shape: BoxShape.circle),
                              child: const Icon(Icons.people_outline,
                                  color: AppColors.primary, size: 36),
                            ),
                            const SizedBox(height: 16),
                            const Text('Aucun candidat trouvé',
                                style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(height: 6),
                            Text(
                              _hasActiveFilters
                                  ? 'Modifiez vos filtres'
                                  : 'Revenez plus tard',
                              style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        color: AppColors.primary,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                          itemCount: _filtered.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (ctx, i) {
                            final c = _filtered[i];
                            return _CandidateCard(profile: c);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _CandidateCard extends StatelessWidget {
  final CandidateProfile profile;
  const _CandidateCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    final contractTypes = AppSkills.parseSkills(profile.desiredContractType);

    return GestureDetector(
      onTap: () => context.push('/recruiter/candidates/${profile.userId}'),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            AppAvatar(name: profile.fullName, radius: 28, photoPath: profile.photoUrl),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(profile.fullName,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppColors.textPrimary)),
                  if (profile.location.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Row(children: [
                      const Icon(Icons.location_on_outlined,
                          size: 12, color: AppColors.textSecondary),
                      const SizedBox(width: 2),
                      Text(profile.location,
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 12)),
                    ]),
                  ],
                  const SizedBox(height: 8),
                  Wrap(spacing: 6, runSpacing: 4, children: [
                    if (profile.desiredLevel.isNotEmpty)
                      _MiniChip(
                          label: profile.desiredLevel,
                          bg: AppColors.greenLight,
                          fg: AppColors.green),
                    ...contractTypes.take(2).map((t) => _MiniChip(
                        label: t,
                        bg: AppColors.primaryLight,
                        fg: AppColors.primary)),
                    if (profile.remotePreference.isNotEmpty)
                      _MiniChip(
                          label: profile.remotePreference,
                          bg: AppColors.orangeLight,
                          fg: AppColors.orange),
                  ]),
                  if (profile.skillList.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 4, runSpacing: 4,
                      children: profile.skillList.take(3).map((s) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                            color: AppColors.surfaceVariant,
                            borderRadius: BorderRadius.circular(20)),
                        child: Text(s,
                            style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 10)),
                      )).toList(),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textHint),
          ],
        ),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;
  const _MiniChip({required this.label, required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(fontSize: 10, color: fg)),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;
  const _Chip(this.label, this.onRemove);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8, top: 4, bottom: 4),
      child: Chip(
        label: Text(label,
            style: const TextStyle(fontSize: 12, color: AppColors.primary)),
        deleteIcon:
            const Icon(Icons.close, size: 14, color: AppColors.primary),
        onDeleted: onRemove,
        backgroundColor: AppColors.primaryLight,
        visualDensity: VisualDensity.compact,
        side: BorderSide.none,
      ),
    );
  }
}