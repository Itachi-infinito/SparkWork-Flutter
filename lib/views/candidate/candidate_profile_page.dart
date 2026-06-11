import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_theme_ext.dart';
import '../../core/utils/profile_completion.dart';
import '../../core/widgets/app_avatar.dart';
import '../../core/widgets/profile_completion_card.dart';
import '../../models/candidate_profile.dart';
import '../../repositories/candidate_profile_repository.dart';
import '../../services/session_service.dart';
import '../shared/nav_bar.dart';

class CandidateProfilePage extends ConsumerStatefulWidget {
  const CandidateProfilePage({super.key});

  @override
  ConsumerState<CandidateProfilePage> createState() =>
      _CandidateProfilePageState();
}

class _CandidateProfilePageState extends ConsumerState<CandidateProfilePage> {
  CandidateProfile? _profile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool forceServer = false}) async {
    setState(() => _loading = true);
    final userId = ref.read(sessionProvider).userId;
    final profile = await ref
        .read(candidateProfileRepositoryProvider)
        .getProfile(userId, forceServer: forceServer);
    debugPrint('[SparkWork] Profile loaded — photoUrl: ${profile?.photoUrl}');
    if (mounted) setState(() { _profile = profile; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : _profile == null
              ? _buildEmpty()
              : _buildProfile(),
      bottomNavigationBar: const CandidateNavBar(currentIndex: 4),
    );
  }

  Widget _buildEmpty() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.person_off_outlined,
                  size: 64, color: context.textHintColor),
              const SizedBox(height: 16),
              Text('Profil introuvable',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: context.textPrimaryColor)),
              const SizedBox(height: 8),
              Text('Votre profil n\'a pas pu être chargé.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.textSecondaryColor)),
              const SizedBox(height: 24),
              ElevatedButton(
                  onPressed: _load, child: const Text('Réessayer')),
            ],
          ),
        ),
      );

  Widget _buildProfile() {
    final p = _profile!;
    final score = ProfileCompletion.calculate(_profile);
    final missing = ProfileCompletion.missing(_profile);

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Gradient hero
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(
                  20, MediaQuery.of(context).padding.top + 12, 20, 32),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF0D0117),
                    Color(0xFF1E0A3C),
                    AppColors.primary,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius:
                    BorderRadius.vertical(bottom: Radius.circular(32)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        onPressed: () => context.push('/settings'),
                        icon: const Icon(Icons.settings_outlined,
                            color: Colors.white),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  AppAvatar(name: p.fullName, radius: 48, photoPath: p.photoPath),
                  const SizedBox(height: 12),
                  Text(p.fullName,
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                  if (p.location.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.location_on_outlined,
                            size: 14, color: Colors.white70),
                        const SizedBox(width: 4),
                        Text(p.location,
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 13)),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () async {
                      await context.push('/candidate/profile/edit');
                      _load(forceServer: true);
                    },
                    icon: const Icon(Icons.edit_outlined,
                        size: 16, color: Colors.white),
                    label: const Text('Modifier le profil',
                        style: TextStyle(color: Colors.white)),
                    style: OutlinedButton.styleFrom(
                        side: BorderSide(
                            color: Colors.white.withOpacity(0.5))),
                  ),
                ],
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (score < 100) ...[
                    ProfileCompletionCard(score: score, missing: missing),
                    const SizedBox(height: 20),
                  ],

                  if (p.bio.isNotEmpty) ...[
                    _SectionTitle('À propos'),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: context.surfaceColor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: context.borderColor),
                      ),
                      child: Text(p.bio,
                          style: TextStyle(
                              color: context.textPrimaryColor, height: 1.5)),
                    ),
                    const SizedBox(height: 20),
                  ],

                  _SectionTitle('Compétences'),
                  const SizedBox(height: 8),
                  p.skillList.isEmpty
                      ? Text('Aucune compétence renseignée.',
                          style: TextStyle(
                              color: context.textHintColor, fontSize: 13))
                      : Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: p.skillList
                              .map((s) => Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryLight,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(s,
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.w500)),
                                  ))
                              .toList(),
                        ),
                  const SizedBox(height: 20),

                  _SectionTitle('Préférences'),
                  const SizedBox(height: 8),
                  _PrefsGrid(profile: p),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _SectionTitle(String text) => Text(text,
      style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: context.textPrimaryColor));
}

class _PrefsGrid extends StatelessWidget {
  final CandidateProfile profile;
  const _PrefsGrid({required this.profile});

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.work_outline, 'Contrat',
          profile.desiredContractType.isEmpty
              ? 'Non renseigné'
              : profile.desiredContractType),
      (Icons.star_outline, 'Niveau',
          profile.desiredLevel.isEmpty
              ? 'Non renseigné'
              : profile.desiredLevel),
      (Icons.euro_outlined, 'Salaire', profile.salaryDisplay),
      (Icons.wifi_outlined, 'Télétravail',
          profile.remotePreference.isEmpty
              ? 'Non renseigné'
              : profile.remotePreference),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 2.8,
      children: items
          .map((item) => Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: context.surfaceColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.borderColor),
                ),
                child: Row(
                  children: [
                    Icon(item.$1, size: 18, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(item.$2,
                              style: TextStyle(
                                  fontSize: 10,
                                  color: context.textSecondaryColor)),
                          Text(item.$3,
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: context.textPrimaryColor),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1),
                        ],
                      ),
                    ),
                  ],
                ),
              ))
          .toList(),
    );
  }
}