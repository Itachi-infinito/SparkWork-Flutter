import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_avatar.dart';
import '../../models/job_offer.dart';
import '../../models/match.dart';
import '../../models/message.dart';
import '../../repositories/job_offer_repository.dart';
import '../../repositories/match_repository.dart';
import '../../repositories/message_repository.dart';
import '../../repositories/report_repository.dart';
import '../../services/session_service.dart';
import '../shared/nav_bar.dart';
import '../../services/unread_service.dart';

class MessagesPage extends ConsumerStatefulWidget {
  const MessagesPage({super.key});

  @override
  ConsumerState<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends ConsumerState<MessagesPage> {
  List<_ConvItem> _items = [];
  List<_ConvItem> _filtered = [];
  bool _loading = true;
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(() {
      setState(() {
        _searchQuery = _searchCtrl.text.trim().toLowerCase();
        _applyFilter();
      });
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _applyFilter() {
    if (_searchQuery.isEmpty) {
      _filtered = List.from(_items);
    } else {
      _filtered = _items.where((item) {
        final title = (item.offer?.title ?? '').toLowerCase();
        final company = (item.offer?.companyName ?? '').toLowerCase();
        return title.contains(_searchQuery) || company.contains(_searchQuery);
      }).toList();
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final session = ref.read(sessionProvider);
    final matchRepo = ref.read(matchRepositoryProvider);
    final offerRepo = ref.read(jobOfferRepositoryProvider);
    final msgRepo = ref.read(messageRepositoryProvider);

    final matches = session.isCandidate
        ? await matchRepo.getMatchesByCandidate(session.userId)
        : await matchRepo.getMatchesByRecruiter(session.userId);

    // Masquer les conversations avec les utilisateurs bloqués
    final blocked = await ref
        .read(reportRepositoryProvider)
        .getBlockedIds(session.userId);
    final visibleMatches = matches.where((m) {
      final other = session.isCandidate ? m.recruiterUserId : m.candidateUserId;
      return !blocked.contains(other);
    }).toList();

    final items = <_ConvItem>[];
    for (final m in visibleMatches) {
      final offer = await offerRepo.getOfferById(m.jobOfferId);
      final last = await msgRepo.getLastMessage(m.matchId);
      items.add(_ConvItem(match: m, offer: offer, lastMessage: last));
    }

    // Sort by most recent message
    items.sort((a, b) {
      final aTime = a.lastMessage?.sentAt ?? '';
      final bTime = b.lastMessage?.sentAt ?? '';
      return bTime.compareTo(aTime);
    });

    await markMessagesAsSeen(session.userId);
    ref.invalidate(unreadMessagesProvider);
    if (mounted) {
      setState(() {
        _items = items;
        _applyFilter();
        _loading = false;
      });
    }
  }

  String _formatTime(String? sentAt) {
    if (sentAt == null || sentAt.isEmpty) return '';
    try {
      final dt = DateTime.parse(sentAt).toLocal();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final msgDay = DateTime(dt.year, dt.month, dt.day);
      if (msgDay == today) return DateFormat('HH:mm').format(dt);
      if (msgDay == today.subtract(const Duration(days: 1))) {
        return 'Hier';
      }
      return DateFormat('d MMM', 'fr_FR').format(dt);
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final isCandidate = session.isCandidate;
    final gradientColors = isCandidate
        ? const [Color(0xFF0D0117), Color(0xFF1E0A3C), AppColors.primary]
        : const [Color(0xFF064E3B), Color(0xFF059669), AppColors.green];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Messages',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _searchCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Rechercher...',
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                        prefixIcon: Icon(Icons.search, size: 20,
                            color: Colors.white.withOpacity(0.7)),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.clear,
                                    color: Colors.white.withOpacity(0.7)),
                                onPressed: () => _searchCtrl.clear(),
                              )
                            : null,
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.15),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        isDense: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary))
                : _filtered.isEmpty
                    ? _buildEmpty()
                    : _buildList(session.userId),
          ),
        ],
      ),
      bottomNavigationBar: session.isCandidate
          ? const CandidateNavBar(currentIndex: 3)
          : const RecruiterNavBar(currentIndex: 3),
    );
  }

  Widget _buildEmpty() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                    color: AppColors.primaryLight, shape: BoxShape.circle),
                child: const Icon(Icons.chat_bubble_outline,
                    color: AppColors.primary, size: 40),
              ),
              const SizedBox(height: 20),
              Text(
                _searchQuery.isNotEmpty
                    ? 'Aucun résultat'
                    : 'Aucune conversation',
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                _searchQuery.isNotEmpty
                    ? 'Aucune conversation ne correspond à votre recherche.'
                    : 'Vos conversations apparaîtront ici après un match.',
                textAlign: TextAlign.center,
                style:
                    const TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );

  Widget _buildList(String userId) => RefreshIndicator(
        onRefresh: _load,
        color: AppColors.primary,
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: _filtered.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (ctx, i) {
            final item = _filtered[i];
            final title = item.offer?.title ?? 'Offre supprimée';
            final company = item.offer?.companyName ?? '';
            final lastMsg = item.lastMessage;
            final isFromMe = lastMsg?.senderUserId == userId;
            final preview = lastMsg == null
                ? 'Commencez la conversation !'
                : '${isFromMe ? 'Vous : ' : ''}${lastMsg.content}';
            final timeStr = _formatTime(lastMsg?.sentAt);

            return GestureDetector(
              onTap: () => context.push('/messages/${item.match.matchId}'),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    AppAvatar(name: title, radius: 26),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(title,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: AppColors.textPrimary)),
                              ),
                              if (timeStr.isNotEmpty)
                                Text(timeStr,
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textHint)),
                            ],
                          ),
                          if (company.isNotEmpty)
                            Text(company,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary)),
                          const SizedBox(height: 4),
                          Text(preview,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.textHint)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right, color: AppColors.textHint),
                  ],
                ),
              ),
            );
          },
        ),
      );
}

class _ConvItem {
  final Match match;
  final JobOffer? offer;
  final Message? lastMessage;
  _ConvItem({required this.match, this.offer, this.lastMessage});
}