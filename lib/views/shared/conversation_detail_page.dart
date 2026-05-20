import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../models/message.dart';
import '../../repositories/job_offer_repository.dart';
import '../../repositories/match_repository.dart';
import '../../repositories/message_repository.dart';
import '../../services/session_service.dart';
import '../../services/unread_service.dart';

class ConversationDetailPage extends ConsumerStatefulWidget {
  final int matchId;
  const ConversationDetailPage({super.key, required this.matchId});

  @override
  ConsumerState<ConversationDetailPage> createState() =>
      _ConversationDetailPageState();
}

class _ConversationDetailPageState
    extends ConsumerState<ConversationDetailPage> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  List<Message> _messages = [];
  bool _loading = true;
  String _title = 'Conversation';
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _load();
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (_) => _reload());
  }

  Future<void> _load() async {
    final msgs =
        await ref.read(messageRepositoryProvider).getMessages(widget.matchId);
    final session = ref.read(sessionProvider);
    final matches = session.isCandidate
        ? await ref
            .read(matchRepositoryProvider)
            .getMatchesByCandidate(session.userId)
        : await ref
            .read(matchRepositoryProvider)
            .getMatchesByRecruiter(session.userId);
    try {
      final match = matches.firstWhere((m) => m.matchId == widget.matchId);
      final offer = await ref
          .read(jobOfferRepositoryProvider)
          .getOfferById(match.jobOfferId);
      if (offer != null && mounted) {
        setState(() => _title = offer.title);
      }
    } catch (_) {}
    await markMessagesAsSeen(session.userId);
    ref.invalidate(unreadMessagesProvider);
    if (mounted) {
      setState(() {
        _messages = msgs;
        _loading = false;
      });
      _scrollToBottom();
    }
  }

  Future<void> _reload() async {
    if (!mounted) return;
    final msgs =
        await ref.read(messageRepositoryProvider).getMessages(widget.matchId);
    if (!mounted) return;
    if (msgs.length != _messages.length) {
      setState(() => _messages = msgs);
      _scrollToBottom();
    }
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
    await _reload();
    _scrollToBottom();
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

  String _formatTime(String sentAt) {
    final dt = DateTime.tryParse(sentAt)?.toLocal();
    if (dt == null) return '';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final msgDay = DateTime(dt.year, dt.month, dt.day);
    final time = DateFormat('HH:mm').format(dt);
    if (msgDay == today) return time;
    if (msgDay == yesterday) return 'Hier $time';
    return DateFormat('d MMM', 'fr_FR').format(dt) + ' $time';
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
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
              context.go(role == 'candidate'
                  ? '/candidate/home'
                  : '/recruiter/home');
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
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
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          itemCount: _messages.length,
                          itemBuilder: (ctx, i) {
                            final msg = _messages[i];
                            final isMe = msg.senderUserId == session.userId;
                            final showTime = i == _messages.length - 1 ||
                                _shouldShowTime(_messages[i], _messages[i + 1]);
                            return _Bubble(
                              message: msg,
                              isMe: isMe,
                              timeLabel: showTime ? _formatTime(msg.sentAt) : null,
                            );
                          },
                        ),
                ),
                _InputBar(controller: _msgCtrl, onSend: _send),
              ],
            ),
    );
  }

  bool _shouldShowTime(Message current, Message next) {
    final a = DateTime.tryParse(current.sentAt);
    final b = DateTime.tryParse(next.sentAt);
    if (a == null || b == null) return false;
    return b.difference(a).inMinutes >= 5;
  }
}

class _Bubble extends StatelessWidget {
  final Message message;
  final bool isMe;
  final String? timeLabel;
  const _Bubble({required this.message, required this.isMe, this.timeLabel});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.only(bottom: 2),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.72),
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
              style: TextStyle(
                color: isMe ? Colors.white : AppColors.textPrimary,
                fontSize: 14,
              ),
            ),
          ),
        ),
        if (timeLabel != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8, left: 4, right: 4),
            child: Text(
              timeLabel!,
              style: const TextStyle(
                  fontSize: 10, color: AppColors.textHint),
            ),
          )
        else
          const SizedBox(height: 6),
      ],
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
                  hintStyle:
                      const TextStyle(color: AppColors.textHint),
                  filled: true,
                  fillColor: AppColors.background,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none),
                ),
                maxLines: null,
                textInputAction: TextInputAction.newline,
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onSend,
              child: Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                    color: AppColors.primary, shape: BoxShape.circle),
                child: const Icon(Icons.send_rounded,
                    color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}