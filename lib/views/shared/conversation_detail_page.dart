import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_theme_ext.dart';
import '../../models/message.dart';
import '../../repositories/job_offer_repository.dart';
import '../../repositories/match_repository.dart';
import '../../repositories/message_repository.dart';
import '../../repositories/report_repository.dart';
import '../../services/session_service.dart';
import '../../services/unread_service.dart';
import 'interview_widgets.dart';

class ConversationDetailPage extends ConsumerStatefulWidget {
  final String matchId;
  const ConversationDetailPage({super.key, required this.matchId});

  @override
  ConsumerState<ConversationDetailPage> createState() => _ConversationDetailPageState();
}

class _ConversationDetailPageState extends ConsumerState<ConversationDetailPage> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  StreamSubscription<List<Message>>? _messagesSub;
  List<Message> _messages = [];
  bool _loading = true;
  String? _error;
  String _title = 'Conversation';
  bool _sending = false;
  String _otherUserId = '';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    setState(() { _loading = true; _error = null; });
    final session = ref.read(sessionProvider);
    final msgRepo = ref.read(messageRepositoryProvider);

    try {
      // Titre de la conversation (offre liée au match)
      final match = await ref
          .read(matchRepositoryProvider)
          .getMatchById(widget.matchId);
      if (match != null) {
        _otherUserId = match.candidateUserId == session.userId
            ? match.recruiterUserId
            : match.candidateUserId;
        final offer = await ref
            .read(jobOfferRepositoryProvider)
            .getOfferById(match.jobOfferId);
        if (offer != null && mounted) setState(() => _title = offer.title);
      }

      // Écoute temps réel des messages
      _messagesSub?.cancel();
      _messagesSub = msgRepo.watchMessages(widget.matchId).listen((msgs) {
        if (!mounted) return;
        final hadNew = msgs.length > _messages.length;
        setState(() { _messages = msgs; _loading = false; });
        if (hadNew) _scrollToBottom();
        // Marquer comme lus les messages reçus
        msgRepo.markMessagesSeen(widget.matchId, session.userId);
        ref.invalidate(unreadMessagesProvider);
      }, onError: (_) {
        if (mounted) {
          setState(() { _error = 'Erreur de connexion au chat.'; _loading = false; });
        }
      });

      await markMessagesAsSeen(session.userId);
    } catch (_) {
      if (mounted) {
        setState(() { _error = 'Erreur lors du chargement.'; _loading = false; });
      }
    }
  }

  Future<void> _send() async {
    final content = _msgCtrl.text.trim();
    if (content.isEmpty || _sending) return;
    _msgCtrl.clear();
    setState(() => _sending = true);
    final session = ref.read(sessionProvider);
    try {
      await ref.read(messageRepositoryProvider).sendMessage(
        matchId: widget.matchId,
        senderUserId: session.userId,
        content: content,
      );
      // Le stream mettra la liste à jour automatiquement
    } catch (_) {
      if (mounted) {
        _msgCtrl.text = content;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Message non envoyé. Réessayez.'),
            backgroundColor: AppColors.red));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
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

  void _showReportDialog() {
    String selectedReason = ReportRepository.reportReasons.first;
    final detailsCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: const Text('Signaler'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...ReportRepository.reportReasons.map((r) => RadioListTile<String>(
                    title: Text(r, style: const TextStyle(fontSize: 13)),
                    value: r,
                    groupValue: selectedReason,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (v) =>
                        setDialog(() => selectedReason = v ?? selectedReason),
                  )),
              const SizedBox(height: 8),
              TextField(
                controller: detailsCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: 'Détails (optionnel)',
                  isDense: true,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () async {
                final session = ref.read(sessionProvider);
                try {
                  await ref.read(reportRepositoryProvider).reportUser(
                        reporterUserId: session.userId,
                        reportedUserId: _otherUserId,
                        reason: selectedReason,
                        details: detailsCtrl.text.trim(),
                        matchId: widget.matchId,
                      );
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text(
                          'Signalement envoyé. Merci, nous allons l\'examiner.'),
                      backgroundColor: AppColors.green,
                    ));
                  }
                } catch (_) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Erreur lors du signalement.'),
                      backgroundColor: AppColors.red,
                    ));
                  }
                }
              },
              child: const Text('Signaler'),
            ),
          ],
        ),
      ),
    );
  }

  void _showBlockDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bloquer cet utilisateur'),
        content: const Text(
          'Vous ne verrez plus son profil ni ses messages, et cette '
          'conversation sera masquée. Continuer ?',
          style: TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () async {
              final session = ref.read(sessionProvider);
              try {
                await ref
                    .read(reportRepositoryProvider)
                    .blockUser(session.userId, _otherUserId);
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Utilisateur bloqué.'),
                  ));
                  _goBack(context);
                }
              } catch (_) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Erreur lors du blocage.'),
                    backgroundColor: AppColors.red,
                  ));
                }
              }
            },
            child:
                const Text('Bloquer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
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
    _messagesSub?.cancel();
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1E0A3C), AppColors.primary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: Text(_title,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actionsIconTheme: const IconThemeData(color: Colors.white),
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
          if (_otherUserId.isNotEmpty)
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'report') _showReportDialog();
                if (v == 'block') _showBlockDialog();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'report',
                  child: ListTile(
                    leading: Icon(Icons.flag_outlined),
                    title: Text('Signaler'),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                ),
                PopupMenuItem(
                  value: 'block',
                  child: ListTile(
                    leading: Icon(Icons.block, color: AppColors.red),
                    title: Text('Bloquer',
                        style: TextStyle(color: AppColors.red)),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                ),
              ],
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: AppColors.red),
                      const SizedBox(height: 12),
                      Text(_error!, style: const TextStyle(color: AppColors.textSecondary)),
                      const SizedBox(height: 16),
                      OutlinedButton(onPressed: _init, child: const Text('Réessayer')),
                    ],
                  ),
                )
              : Column(
              children: [
                InterviewBanner(matchId: widget.matchId),
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
              gradient: isMe
                  ? const LinearGradient(
                      colors: [AppColors.primaryDark, AppColors.primary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: isMe ? null : context.surfaceColor,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isMe ? 16 : 4),
                bottomRight: Radius.circular(isMe ? 4 : 16),
              ),
              border: isMe ? null : Border.all(color: context.borderColor),
              boxShadow: isMe
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Text(
              message.content,
              style: TextStyle(color: isMe ? Colors.white : context.textPrimaryColor, fontSize: 14),
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
        decoration: BoxDecoration(
          color: context.surfaceColor,
          border: Border(top: BorderSide(color: context.borderColor)),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: 'Écrivez un message...',
                  hintStyle: TextStyle(color: context.textHintColor),
                  filled: true,
                  fillColor: context.bgColor,
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
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primaryDark, AppColors.primary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}