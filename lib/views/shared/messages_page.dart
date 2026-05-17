import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../models/job_offer.dart';
import '../../models/match.dart';
import '../../models/message.dart';
import '../../repositories/job_offer_repository.dart';
import '../../repositories/match_repository.dart';
import '../../repositories/message_repository.dart';
import '../../services/session_service.dart';
import '../shared/nav_bar.dart';

class MessagesPage extends ConsumerStatefulWidget {
  const MessagesPage({super.key});

  @override
  ConsumerState<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends ConsumerState<MessagesPage> {
  List<_ConvItem> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
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
    if (mounted) setState(() { _items = items; _loading = false; });
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
          : _items.isEmpty
              ? _buildEmpty()
              : _buildList(session.userId),
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
                    color: AppColors.primaryLight,
                    shape: BoxShape.circle),
                child: const Icon(Icons.chat_bubble_outline,
                    color: AppColors.primary, size: 40),
              ),
              const SizedBox(height: 20),
              const Text('Aucune conversation',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              const Text(
                  'Vos conversations apparaîtront ici après un match.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary)),
            ],
          ),
        ),
      );

  Widget _buildList(int userId) => RefreshIndicator(
        onRefresh: _load,
        color: AppColors.primary,
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: _items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (ctx, i) {
            final item = _items[i];
            final title = item.offer?.title ?? 'Offre supprimée';
            final company = item.offer?.companyName ?? '';
            final initials = item.offer?.initials ?? '?';
            final lastMsg = item.lastMessage;
            final isFromMe = lastMsg?.senderUserId == userId;
            final preview = lastMsg == null
                ? 'Commencez la conversation !'
                : '${isFromMe ? 'Vous : ' : ''}${lastMsg.content}';

            return GestureDetector(
              onTap: () =>
                  context.push('/messages/${item.match.matchId}'),
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
                          Text(title,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: AppColors.textPrimary)),
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
                                  fontSize: 12,
                                  color: AppColors.textHint)),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right,
                        color: AppColors.textHint),
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