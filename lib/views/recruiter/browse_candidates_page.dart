import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../models/candidate_profile.dart';
import '../../repositories/candidate_profile_repository.dart';

class BrowseCandidatesPage extends ConsumerStatefulWidget {
  const BrowseCandidatesPage({super.key});

  @override
  ConsumerState<BrowseCandidatesPage> createState() =>
      _BrowseCandidatesPageState();
}

class _BrowseCandidatesPageState
    extends ConsumerState<BrowseCandidatesPage> {
  List<CandidateProfile> _all = [];
  List<CandidateProfile> _filtered = [];
  bool _loading = true;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(_filter);
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final profiles = await ref
        .read(candidateProfileRepositoryProvider)
        .getAllProfiles();
    if (mounted) {
      setState(() {
        _all = profiles;
        _filtered = profiles;
        _loading = false;
      });
    }
  }

  void _filter() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered = _all
          .where((p) =>
              p.fullName.toLowerCase().contains(q) ||
              p.location.toLowerCase().contains(q) ||
              p.skills.toLowerCase().contains(q))
          .toList();
    });
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_filter);
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Candidats'),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Nom, ville, compétence...',
                prefixIcon: const Icon(Icons.search,
                    color: AppColors.textHint),
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
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.primary))
                : _filtered.isEmpty
                    ? const Center(
                        child: Text('Aucun candidat trouvé.',
                            style: TextStyle(
                                color: AppColors.textSecondary)))
                    : RefreshIndicator(
                        onRefresh: _load,
                        color: AppColors.primary,
                        child: ListView.separated(
                          padding:
                              const EdgeInsets.fromLTRB(16, 4, 16, 16),
                          itemCount: _filtered.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (ctx, i) {
                            final c = _filtered[i];
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
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 26,
                                        backgroundColor:
                                            AppColors.primaryLight,
                                        child: Text(c.initials,
                                            style: const TextStyle(
                                                color: AppColors.primary,
                                                fontWeight:
                                                    FontWeight.bold,
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
                                            if (c.skillList
                                                .isNotEmpty) ...[
                                              const SizedBox(height: 6),
                                              Wrap(
                                                spacing: 4,
                                                runSpacing: 4,
                                                children: c.skillList
                                                    .take(3)
                                                    .map((s) =>
                                                        Container(
                                                          padding: const EdgeInsets
                                                              .symmetric(
                                                              horizontal:
                                                                  8,
                                                              vertical:
                                                                  2),
                                                          decoration: BoxDecoration(
                                                              color: AppColors
                                                                  .primaryLight,
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                      20)),
                                                          child: Text(
                                                              s,
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
                                    ],
                                  ),
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
}