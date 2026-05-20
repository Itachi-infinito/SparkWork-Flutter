import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../models/job_offer.dart';
import '../../models/match.dart';
import '../../models/message.dart';
import '../../repositories/job_offer_repository.dart';
import '../../repositories/match_repository.dart';
import '../../repositories/message_repository.dart';
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
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
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

    final items = <_ConvItem>[];
    for (final m in matches) {
      final offer = await offerRepo.getOfferById(m.jobOfferId);
      final last = await msgRepo.getLastMessage(m.matchId);
      items.add(_ConvItem(match: m, offer: offer, lastMessage: last));
    }
    items.sort((a, b) {
      final aTime = a.lastMessage?.sentAt ?? a.match.createdAt;
      final bTime = b.lastMessage?.sentAt ?? b.match.createdAt;
      return bTime.compareTo(aTime);
    });
    await markMessagesAsSeen(session.userId);
    ref.invalidate(unreadMessagesProvider);
    if (mounted) {
      setState(() {
        _items = items;
        _loading = false;
      });
      _applySearch(_searchQuery);
    }
  }

  void _applySearch(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filtered = _items;
      } else {
        final q = query.toLowerCase();
        _filtered = _items.where((item) {
          final title = item.offer?.title.toLowerCase() ?? '';
          final company = item.offer?.companyName.toLowerCase() ?? '';
          return title.contains(q) || company.contains(q);
        }).toList();
      }
    });
  }

  String _formatPreviewTime(String? sentAt) {
    if (sentAt == null) return '';
    final dt = DateTime.tryParse(sentAt)?.toLocal();
    if (dt == null) return '';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDay = DateTime(dt.year, dt.month, dt.day);
    if (msgDay == today) return DateFormat('HH:mm').format(dt);
    if (msgDay == today.subtract(const Duration(days: 1))) return 'Hier';
    return DateFormat('d MMM', 'fr_FR').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Messages'),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: _applySearch,
                    decoration: InputDecoration(
                      hintText: 'Rechercher une conversation...',
                      hintStyle:
                          const TextStyle(color: AppColors.textHint, fontSize: 14),
                      prefixIcon: const Icon(Icons.search,
                          color: AppColors.textHint, size: 20),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close,
                                  color: AppColors.textHint, size: 18),
                              onPressed: () {
                                _searchCtrl.clear();
                                _applySearch('');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: AppColors.surface,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.border)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.border)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: AppColors.primary)),
                    ),
                  ),
                ),
                Expanded(
                  child: _filtered.isEmpty
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
                    ? 'Aucune conversation ne correspond à "$_searchQuery".'
                    : 'Vos conversations apparaîtront ici après un match.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );

  Widget _buildList(int userId) => RefreshIndicator(
        onRefresh: _load,
        color: AppColors.primary,
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          itemCount: _filtered.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (ctx, i) {
            final item = _filtered[i];
            final title = item.offer?.title ?? 'Offre supprimée';
            final company = item.offer?.companyName ?? '';
            final initials = item.offer?.initials ?? '?';
            final lastMsg = item.lastMessage;
            final isFromMe = lastMsg?.senderUserId == userId;
            final preview = lastMsg == null
                ? 'Commencez la conversation !'
                : '${isFromMe ? 'Vous : ' : ''}${lastMsg.content}';
            final timeStr = _formatPreviewTime(lastMsg?.sentAt);

            return GestureDetector(
              onTap: () => context.push('/messages/${item.match.matchId}'),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: AppColors.primaryLight,
                      child: Text(initials,
                          style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(title,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: AppColors.textPrimary),
                                    overflow: TextOverflow.ellipsis),
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
                              style: TextStyle(
                                  fontSize: 12,
                                  color: isFromMe
                                      ? AppColors.textHint
                                      : AppColors.textSecondary,
                                  fontStyle: lastMsg == null
                                      ? FontStyle.italic
                                      : FontStyle.normal)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
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