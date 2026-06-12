import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_theme_ext.dart';
import '../../models/recruiter_profile.dart';
import '../../repositories/job_offer_repository.dart';
import '../../repositories/match_repository.dart';
import '../../repositories/recruiter_profile_repository.dart';
import '../../services/session_service.dart';
import '../shared/nav_bar.dart';

class RecruiterProfilePage extends ConsumerStatefulWidget {
  const RecruiterProfilePage({super.key});

  @override
  ConsumerState<RecruiterProfilePage> createState() =>
      _RecruiterProfilePageState();
}

class _RecruiterProfilePageState extends ConsumerState<RecruiterProfilePage> {
  int _offersCount = 0;
  int _matchesCount = 0;
  bool _loading = true;
  RecruiterProfile? _profile;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final session = ref.read(sessionProvider);
    final results = await Future.wait([
      ref.read(jobOfferRepositoryProvider).getOffersByRecruiter(session.userId),
      ref.read(matchRepositoryProvider).getMatchesByRecruiter(session.userId),
      ref.read(recruiterProfileRepositoryProvider).getProfile(session.userId),
    ]);
    if (mounted) {
      setState(() {
        _offersCount = (results[0] as List).length;
        _matchesCount = (results[1] as List).length;
        _profile = results[2] as RecruiterProfile?;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.green))
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.green,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHero(session),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Company description
                          if (_profile != null &&
                              _profile!.companyDescription.isNotEmpty) ...[
                            const _SectionTitle('À propos'),
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: context.surfaceColor,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: context.borderColor),
                              ),
                              child: Text(_profile!.companyDescription,
                                  style: TextStyle(
                                      color: context.textPrimaryColor,
                                      height: 1.5)),
                            ),
                            const SizedBox(height: 20),
                          ],

                          const _SectionTitle('Statistiques'),
                          const SizedBox(height: 12),
                          Row(children: [
                            Expanded(
                                child: _StatCard(
                                    icon: Icons.work_outline,
                                    label: 'Offres publiées',
                                    value: '$_offersCount',
                                    color: AppColors.primary)),
                            const SizedBox(width: 12),
                            Expanded(
                                child: _StatCard(
                                    icon: Icons.favorite_outline,
                                    label: 'Matches',
                                    value: '$_matchesCount',
                                    color: AppColors.red)),
                          ]),
                          const SizedBox(height: 24),

                          const _SectionTitle('Actions'),
                          const SizedBox(height: 12),
                          _ActionTile(
                              icon: Icons.work_outline,
                              label: 'Gérer mes offres',
                              color: AppColors.primary,
                              onTap: () => context.go('/recruiter/offers')),
                          _ActionTile(
                              icon: Icons.favorite_outline,
                              label: 'Voir mes matches',
                              color: AppColors.red,
                              onTap: () => context.go('/recruiter/matches')),
                          _ActionTile(
                              icon: Icons.thumb_up_outlined,
                              label: 'Candidats likés',
                              color: AppColors.orange,
                              onTap: () =>
                                  context.push('/recruiter/likes')),
                          _ActionTile(
                              icon: Icons.people_outline,
                              label: 'Parcourir les candidats',
                              color: AppColors.primaryDark,
                              onTap: () =>
                                  context.push('/recruiter/candidates')),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: const RecruiterNavBar(currentIndex: 4),
    );
  }

  Widget _buildHero(session) {
    final contactPhotoUrl = _profile?.contactPhotoUrl;
    final logoUrl = _profile?.companyLogoUrl;
    final companyName = _profile?.companyName ?? session.userName;
    final location = _profile?.location ?? '';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
          20, MediaQuery.of(context).padding.top + 12, 20, 32),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF064E3B), Color(0xFF059669), AppColors.green],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                onPressed: () => context.push('/settings'),
                icon: const Icon(Icons.settings_outlined, color: Colors.white),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // Contact photo (main avatar) + optional logo badge
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              // Contact photo
              _CirclePhoto(url: contactPhotoUrl, name: companyName, radius: 48),

              // Company logo badge (bottom-right if both exist)
              if (logoUrl != null && logoUrl.isNotEmpty && contactPhotoUrl != null)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: ClipOval(
                      child: Image.network(logoUrl,
                          width: 32, height: 32, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const SizedBox()),
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 12),
          Text(companyName,
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
          if (location.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.location_on_outlined,
                    size: 13, color: Colors.white70),
                const SizedBox(width: 3),
                Text(location,
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 13)),
              ],
            ),
          ],
          const SizedBox(height: 4),
          Text(session.userEmail,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.7), fontSize: 12)),
          const SizedBox(height: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text('Recruteur',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () async {
              await context.push('/recruiter/profile/edit');
              _load();
            },
            icon: const Icon(Icons.edit_outlined, size: 16, color: Colors.white),
            label: const Text('Modifier le profil',
                style: TextStyle(color: Colors.white)),
            style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.white.withOpacity(0.5))),
          ),
        ],
      ),
    );
  }
}

class _CirclePhoto extends StatelessWidget {
  final String? url;
  final String name;
  final double radius;
  const _CirclePhoto({required this.url, required this.name, required this.radius});

  String get _initials {
    final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : 'R';
  }

  @override
  Widget build(BuildContext context) {
    if (url != null && url!.isNotEmpty) {
      return ClipOval(
        child: Image.network(url!,
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildInitials()),
      );
    }
    return _buildInitials();
  }

  Widget _buildInitials() => CircleAvatar(
        radius: radius,
        backgroundColor: Colors.white.withOpacity(0.2),
        child: Text(_initials,
            style: TextStyle(
                fontSize: radius * 0.6,
                fontWeight: FontWeight.bold,
                color: Colors.white)),
      );
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Text(text,
      style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: context.textPrimaryColor));
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _StatCard(
      {required this.icon,
      required this.label,
      required this.value,
      required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.borderColor),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(value,
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: color)),
            const SizedBox(height: 4),
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12, color: context.textSecondaryColor)),
          ],
        ),
      );
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionTile(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.surfaceColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.borderColor),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(width: 14),
                Expanded(
                    child: Text(label,
                        style: TextStyle(
                            fontSize: 14,
                            color: context.textPrimaryColor,
                            fontWeight: FontWeight.w500))),
                Icon(Icons.chevron_right,
                    color: context.textHintColor, size: 20),
              ],
            ),
          ),
        ),
      );
}
