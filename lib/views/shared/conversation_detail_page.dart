import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../models/message.dart';
import '../../repositories/job_offer_repository.dart';
import '../../repositories/match_repository.dart';
import '../../repositories/message_repository.dart';
import '../../services/session_service.dart';
import '../../services/unread_service.dart';
import '../../services/notification_service.dart';

class ConversationDetailPage extends ConsumerStatefulWidget {
  final String matchId;  
  const ConversationDetailPage({super.key, required this.matchId});

  @override
  ConsumerState<ConversationDetailPage> createState() => _ConversationDetailPageState();
}

class _ConversationDetailPageState extends ConsumerState<ConversationDetailPage> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  List<Message> _messages = [];
  bool _loading = true;
  String _title = 'Conversation';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final session = ref.read(sessionProvider);
    final msgRepo = ref.read(messageRepositoryProvider);

    final msgs = await msgRepo.getMessages(widget.matchId);

    // Marquer les messages de l'autre personne comme lus
    await msgRepo.markMessagesSeen(widget.matchId, session.userId);

    final matches = session.isCandidate
        ? await ref.read(matchRepositoryProvider).getMatchesByCandidate(session.userId)
        : await ref.read(matchRepositoryProvider).getMatchesByRecruiter(session.userId);

    try {
      final match = matches.firstWhere((m) => m.matchId == widget.matchId);
      final offer = await ref.read(jobOfferRepositoryProvider).getOfferById(match.jobOfferId);
      if (offer != null && mounted) setState(() => _title = offer.title);
    } catch (_) {}

    await markMessagesAsSeen(session.userId);
    ref.invalidate(unreadMessagesProvider);

    if (mounted) setState(() { _messages = msgs; _loading = false; });
    _scrollToBottom();
  }

  Future<void> _send() async {
    final content = _msgCtrl.text.trim();
    if (content.isEmpty) return;
    _msgCtrl.clear();
    final session = ref.read(sessionProvider);
    await ref.read(messageRepositoryProvider).sendMessage(
      matchId: widget.matchId,
      senderUserId: session.userId,
      content: content,
    );
    await _load();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _goBack(BuildContext context) {
    if (Navigator.canPop(context)) {
      context.pop();
    } else {
      final role = ref.read(sessionProvider).userRole;
      context.go(role == 'candidate' ? '/candidate/home' : '/recruiter/home');
    }
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final myUserId = session.userId;

    // Dernier message envoyé par moi
    final myMessages = _messages.where((m) => m.senderUserId == myUserId).toList();
    final lastMyMessageId = myMessages.isNotEmpty ? myMessages.last.messageId : null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_title, overflow: TextOverflow.ellipsis),
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => _goBack(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.home_outlined),
            onPressed: () {
              final role = ref.read(sessionProvider).userRole;
              context.go(role == 'candidate' ? '/candidate/home' : '/recruiter/home');
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : Column(
              children: [
                Expanded(
                  child: _messages.isEmpty
                      ? const Center(
                          child: Text(
                            'Aucun message.\nCommencez la conversation !',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.textHint),
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollCtrl,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          itemCount: _messages.length,
                          itemBuilder: (ctx, i) {
                            final msg = _messages[i];
                            final isMe = msg.senderUserId == myUserId;
                            final showSeen = isMe && msg.messageId == lastMyMessageId && msg.isSeen;
                            return _Bubble(message: msg, isMe: isMe, showSeenIndicator: showSeen);
                          },
                        ),
                ),
                _InputBar(controller: _msgCtrl, onSend: _send),
              ],
            ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final Message message;
  final bool isMe;
  final bool showSeenIndicator;
  const _Bubble({required this.message, required this.isMe, this.showSeenIndicator = false});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 2),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
            decoration: BoxDecoration(
              color: isMe ? AppColors.primary : AppColors.surface,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isMe ? 16 : 4),
                bottomRight: Radius.circular(isMe ? 4 : 16),
              ),
              border: isMe ? null : Border.all(color: AppColors.border),
            ),
            child: Text(
              message.content,
              style: TextStyle(color: isMe ? Colors.white : AppColors.textPrimary, fontSize: 14),
            ),
          ),
          if (showSeenIndicator)
            Padding(
              padding: const EdgeInsets.only(right: 4, bottom: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.done_all, size: 14, color: AppColors.primary),
                  SizedBox(width: 3),
                  Text('Lu', style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w500)),
                ],
              ),
            )
          else if (isMe)
            const SizedBox(height: 6),
        ],
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  const _InputBar({required this.controller, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: 'Écrivez un message...',
                  hintStyle: const TextStyle(color: AppColors.textHint),
                  filled: true,
                  fillColor: AppColors.background,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                ),
                maxLines: null,
                textInputAction: TextInputAction.newline,
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onSend,
              child: Container(
                width: 44, height: 44,
                decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}