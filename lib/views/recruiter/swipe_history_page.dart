import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_avatar.dart';
import '../../models/candidate_profile.dart';
import '../../models/subscription.dart';
import '../../models/swipe_history_entry.dart';
import '../../repositories/candidate_profile_repository.dart';
import '../../services/session_service.dart';
import '../../services/subscription_service.dart';
import '../../services/swipe_history_service.dart';

class SwipeHistoryPage extends ConsumerStatefulWidget {
  const SwipeHistoryPage({super.key});

  @override
  ConsumerState<SwipeHistoryPage> createState() => _SwipeHistoryPageState();
}

class _SwipeHistoryPageState extends ConsumerState<SwipeHistoryPage> {
  bool _loading = true;
  SubscriptionPlan _plan = SubscriptionPlan.free;
  List<SwipeHistoryEntry> _entries = [];
  final Map<String, CandidateProfile?> _profiles = {};
  Set<String> _favoriteIds = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final session = ref.read(sessionProvider);
    final plan = await ref.read(subscriptionServiceProvider).getCurrentPlan(session.userId);
    final historySvc = ref.read(swipeHistoryServiceProvider);
    final entries = await historySvc.getHistory(session.userId, plan);
    final favIds = (await historySvc.getFavoriteCandidateIds(session.userId)).toSet();

    final profileRepo = ref.read(candidateProfileRepositoryProvider);
    for (final entry in entries) {
      if (!_profiles.containsKey(entry.candidateId)) {
        _profiles[entry.candidateId] = await profileRepo.getProfile(entry.candidateId);
      }
    }

    if (mounted) {
      setState(() {
        _plan = plan;
        _entries = entries;
        _favoriteIds = favIds;
        _loading = false;
      });
    }
  }

  Future<void> _recover(SwipeHistoryEntry entry) async {
    await ref.read(swipeHistoryServiceProvider).markRecovered(entry.entryId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Ce profil réapparaîtra en priorité lors de votre prochaine session de swipe.'),
        backgroundColor: AppColors.green,
      ));
    }
    _load();
  }

  Future<void> _toggleFavorite(SwipeHistoryEntry entry) async {
    final session = ref.read(sessionProvider);
    final svc = ref.read(swipeHistoryServiceProvider);
    if (_favoriteIds.contains(entry.candidateId)) {
      await svc.removeFavorite(session.userId, entry.candidateId);
    } else {
      await svc.addFavorite(session.userId, entry.candidateId);
    }
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Historique des profils')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _plan == SubscriptionPlan.free
              ? _buildUpsell()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _entries.isEmpty
                      ? ListView(children: const [
                          Padding(
                            padding: EdgeInsets.all(40),
                            child: Center(child: Text('Aucun profil dans votre historique.')),
                          ),
                        ])
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _entries.length,
                          itemBuilder: (context, i) => _HistoryTile(
                            entry: _entries[i],
                            profile: _profiles[_entries[i].candidateId],
                            isFavorite: _favoriteIds.contains(_entries[i].candidateId),
                            onRecover: () => _recover(_entries[i]),
                            onToggleFavorite: () => _toggleFavorite(_entries[i]),
                          ),
                        ),
                ),
    );
  }

  Widget _buildUpsell() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.history, size: 56, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            const Text('Historique non disponible',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
              'Disponible dès le plan Starter (7 jours) et Pro (30 jours).',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final SwipeHistoryEntry entry;
  final CandidateProfile? profile;
  final bool isFavorite;
  final VoidCallback onRecover;
  final VoidCallback onToggleFavorite;

  const _HistoryTile({
    required this.entry,
    required this.profile,
    required this.isFavorite,
    required this.onRecover,
    required this.onToggleFavorite,
  });

  (IconData, Color, String) get _actionInfo {
    switch (entry.action) {
      case 'like': return (Icons.favorite, AppColors.red, 'Liké');
      case 'superlike': return (Icons.bolt, AppColors.orange, 'Super liké');
      default: return (Icons.close, Colors.grey, 'Passé');
    }
  }

  @override
  Widget build(BuildContext context) {
    final date = DateTime.tryParse(entry.swipedAt);
    final dateLabel = date != null ? DateFormat('d MMM, HH:mm', 'fr_FR').format(date) : '';
    final (icon, color, label) = _actionInfo;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(children: [
        AppAvatar(
            name: profile?.fullName ?? '?', radius: 24, photoPath: profile?.photoUrl),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(profile?.fullName ?? 'Profil supprimé',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              if (profile?.jobTitle?.isNotEmpty == true)
                Text(profile!.jobTitle!,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              const SizedBox(height: 4),
              Row(children: [
                Icon(icon, size: 12, color: color),
                const SizedBox(width: 4),
                Text('$label · $dateLabel',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                if (entry.score > 0) ...[
                  const SizedBox(width: 8),
                  Text('${entry.score}%',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
                ],
              ]),
            ],
          ),
        ),
        IconButton(
          icon: Icon(isFavorite ? Icons.star : Icons.star_border,
              color: isFavorite ? Colors.amber : Colors.grey, size: 20),
          onPressed: onToggleFavorite,
        ),
        if (entry.action == 'pass' && !entry.recovered)
          IconButton(
            icon: const Icon(Icons.replay, color: AppColors.primary, size: 20),
            onPressed: onRecover,
          ),
      ]),
    );
  }
}
