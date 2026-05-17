import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../repositories/job_offer_repository.dart';
import '../../repositories/match_repository.dart';
import '../../services/session_service.dart';
import '../shared/nav_bar.dart';

class RecruiterProfilePage extends ConsumerStatefulWidget {
  const RecruiterProfilePage({super.key});

  @override
  ConsumerState<RecruiterProfilePage> createState() =>
      _RecruiterProfilePageState();
}

class _RecruiterProfilePageState
    extends ConsumerState<RecruiterProfilePage> {
  int _offersCount = 0;
  int _matchesCount = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final session = ref.read(sessionProvider);
    final offers = await ref
        .read(jobOfferRepositoryProvider)
        .getOffersByRecruiter(session.userId);
    final matches = await ref
        .read(matchRepositoryProvider)
        .getMatchesByRecruiter(session.userId);
    if (mounted) {
      setState(() {
        _offersCount = offers.length;
        _matchesCount = matches.length;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final parts = session.userName.trim().split(' ');
    final initials = parts.length >= 2
        ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
        : session.userName.isNotEmpty
            ? session.userName[0].toUpperCase()
            : 'R';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Mon profil'),
        backgroundColor: AppColors.background,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () async {
              await context.push('/recruiter/profile/edit');
              _load();
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                  color: AppColors.green))
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.green,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 44,
                            backgroundColor: AppColors.greenLight,
                            child: Text(initials,
                                style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.green)),
                          ),
                          const SizedBox(height: 12),
                          Text(session.userName,
                              style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary)),
                          const SizedBox(height: 4),
                          Text(session.userEmail,
                              style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13)),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.greenLight,
                              borderRadius:
                                  BorderRadius.circular(20),
                            ),
                            child: const Text('Recruteur',
                                style: TextStyle(
                                    color: AppColors.green,
                                    fontSize: 12,
                                    fontWeight:
                                        FontWeight.w600)),
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            onPressed: () async {
                              await context.push(
                                  '/recruiter/profile/edit');
                              _load();
                            },
                            icon: const Icon(
                                Icons.edit_outlined,
                                size: 16),
                            label: const Text(
                                'Modifier le profil'),
                            style: OutlinedButton.styleFrom(
                                foregroundColor:
                                    AppColors.green,
                                side: const BorderSide(
                                    color: AppColors.green)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    const Text('Statistiques',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
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
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text('Actions',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary)),
                    const SizedBox(height: 12),
                    _ActionTile(
                        icon: Icons.work_outline,
                        label: 'Gérer mes offres',
                        color: AppColors.primary,
                        onTap: () =>
                            context.go('/recruiter/offers')),
                    _ActionTile(
                        icon: Icons.favorite_outline,
                        label: 'Voir mes matches',
                        color: AppColors.red,
                        onTap: () =>
                            context.go('/recruiter/matches')),
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
                        onTap: () => context
                            .push('/recruiter/candidates')),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: const RecruiterNavBar(currentIndex: 4),
    );
  }
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
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
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
                style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary)),
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
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(width: 14),
                Expanded(
                    child: Text(label,
                        style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w500))),
                const Icon(Icons.chevron_right,
                    color: AppColors.textHint, size: 20),
              ],
            ),
          ),
        ),
      );
}