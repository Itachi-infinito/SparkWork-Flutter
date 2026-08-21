import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_theme_ext.dart';
import '../../models/match.dart';
import '../../models/message.dart';
import '../../models/message_template.dart';
import '../../models/subscription.dart';
import '../../repositories/candidate_profile_repository.dart';
import '../../repositories/job_offer_repository.dart';
import '../../repositories/match_repository.dart';
import '../../repositories/message_repository.dart';
import '../../repositories/recruiter_profile_repository.dart';
import '../../repositories/report_repository.dart';
import '../../services/message_template_service.dart';
import '../../services/session_service.dart';
import '../../services/subscription_service.dart';
import '../../services/unread_service.dart';
import 'interview_widgets.dart';
import '../../l10n/generated/app_localizations.dart';

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
  String _title = '';
  bool _sending = false;
  String _otherUserId = '';
  String _otherUserName = '';
  bool _isCandidate = false;
  Match? _match;
  StreamSubscription<Match?>? _matchSub;
  bool _confirmingHire = false;

  // Modèles de messages (Pro)
  String _offerLocation = '';
  String _myCompanyName = '';
  SubscriptionPlan _userPlan = SubscriptionPlan.free;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    setState(() { _loading = true; _error = null; });
    final session = ref.read(sessionProvider);
    final msgRepo = ref.read(messageRepositoryProvider);
    _isCandidate = session.userRole == 'candidate';

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
        if (offer != null && mounted) {
          setState(() { _title = offer.title; _offerLocation = offer.location; });
        }

        // Nom de l'autre partie — utilisé dans le bottom sheet de confirmation
        if (_isCandidate) {
          final p = await ref
              .read(recruiterProfileRepositoryProvider)
              .getProfile(_otherUserId);
          _otherUserName = p?.companyName ?? '';
        } else {
          final p = await ref
              .read(candidateProfileRepositoryProvider)
              .getProfile(_otherUserId);
          _otherUserName = p?.fullName ?? '';
          // Modèles de messages : réservés au recruteur.
          final myProfile = await ref
              .read(recruiterProfileRepositoryProvider)
              .getProfile(session.userId);
          _myCompanyName = myProfile?.companyName ?? '';
          _userPlan = await ref.read(subscriptionServiceProvider).getCurrentPlan(session.userId);
        }
      }

      // Écoute temps réel du statut du match (confirmation d'embauche)
      _matchSub?.cancel();
      _matchSub = ref
          .read(matchRepositoryProvider)
          .watchMatch(widget.matchId)
          .listen((m) {
        if (mounted) setState(() => _match = m);
      });

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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(AppLocalizations.of(context)!.convMessageNotSent),
            backgroundColor: AppColors.red));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _fillTemplateVariables(String body) {
    final loc = AppLocalizations.of(context)!;
    final firstName = _otherUserName.trim().isNotEmpty
        ? _otherUserName.trim().split(' ').first
        : loc.convTemplateDefaultCandidate;
    final dateLabel = DateFormat('d MMMM yyyy', 'fr_FR').format(DateTime.now());
    return body
        .replaceAll('{prénom_candidat}', firstName)
        .replaceAll('{poste}', _title)
        .replaceAll('{nom_entreprise}', _myCompanyName.isNotEmpty ? _myCompanyName : loc.convTemplateDefaultCompany)
        .replaceAll('{date}', dateLabel)
        .replaceAll('{lieu}', _offerLocation.isNotEmpty ? _offerLocation : loc.convTemplateDefaultLocation);
  }

  Future<void> _showTemplatesSheet() async {
    final session = ref.read(sessionProvider);
    final templateSvc = ref.read(messageTemplateServiceProvider);
    final templates = await templateSvc.ensureDefaultTemplates(session.userId);
    if (!mounted) return;
    final loc = AppLocalizations.of(context)!;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.85,
        builder: (_, scrollCtrl) => ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                    color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Text(loc.convTemplatesTitle,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ...templates.map((t) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: context.surfaceColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: context.borderColor),
                  ),
                  child: ListTile(
                    title: Text(t.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: Text(_fillTemplateVariables(t.body),
                        maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: context.textSecondaryColor)),
                    onTap: () {
                      _msgCtrl.text = _fillTemplateVariables(t.body);
                      templateSvc.incrementUsage(session.userId, t.templateId);
                      Navigator.pop(ctx);
                    },
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildHireBanner() {
    final match = _match;
    if (match == null) return const SizedBox();
    final loc = AppLocalizations.of(context)!;

    if (match.status == 'hired') {
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.greenLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.green.withOpacity(0.3)),
        ),
        child: Row(children: [
          const Icon(Icons.celebration_outlined, color: AppColors.green, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(loc.convHireConfirmedTitle,
                style: const TextStyle(color: AppColors.green, fontWeight: FontWeight.w600, fontSize: 13)),
          ),
          TextButton(
            onPressed: () => context.push('/rate/${widget.matchId}', extra: {
              'targetUserId': _otherUserId,
              'targetName': _otherUserName,
              'isRecruiter': !_isCandidate,
            }),
            child: Text(loc.convLeaveReview,
                style: const TextStyle(color: AppColors.green, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ]),
      );
    }

    // Flux séquentiel : le recruteur initie, le candidat ne voit
    // l'option de confirmation qu'une fois le recruteur passé à l'action.
    if (_isCandidate) {
      if (!match.hiredByRecruiter) {
        // Le recruteur n'a encore rien initié — rien à afficher côté candidat.
        return const SizedBox();
      }
      // Le recruteur a confirmé, le candidat doit confirmer à son tour.
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.greenLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.green.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.handshake_outlined, color: AppColors.green, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    loc.convOtherConfirmsHire(_otherUserName.isNotEmpty ? _otherUserName : loc.convFallbackRecruiter),
                    style: const TextStyle(
                        color: AppColors.green, fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
              ]),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _confirmingHire ? null : _confirmHire,
                  icon: _confirmingHire
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.check, color: Colors.white, size: 18),
                  label: Text(loc.convConfirmMyTurn,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.green,
                    minimumSize: const Size(double.infinity, 40),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Côté recruteur
    if (match.hiredByRecruiter) {
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.orangeLight,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          const Icon(Icons.hourglass_bottom_outlined, color: AppColors.orange, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(loc.convWaitingCandidateConfirm,
                style: const TextStyle(color: AppColors.orange, fontSize: 12, fontWeight: FontWeight.w500)),
          ),
        ]),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _confirmingHire ? null : _confirmHire,
          icon: _confirmingHire
              ? const SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(color: AppColors.green, strokeWidth: 2))
              : const Icon(Icons.handshake_outlined, color: AppColors.green, size: 18),
          label: Text(loc.convConfirmHireButton,
              style: const TextStyle(color: AppColors.green, fontWeight: FontWeight.w600)),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppColors.green),
            minimumSize: const Size(double.infinity, 44),
          ),
        ),
      ),
    );
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
    final loc = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: Text(loc.convReportTitle),
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
                decoration: InputDecoration(
                  hintText: loc.convReportDetailsHint,
                  isDense: true,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(loc.convCancel),
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
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(loc.convReportSent),
                      backgroundColor: AppColors.green,
                    ));
                  }
                } catch (_) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(loc.convReportError),
                      backgroundColor: AppColors.red,
                    ));
                  }
                }
              },
              child: Text(loc.convReportTitle),
            ),
          ],
        ),
      ),
    );
  }

  void _showBlockDialog() {
    final loc = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.convBlockTitle),
        content: Text(
          loc.convBlockBody,
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(loc.convCancel),
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
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(loc.convBlockedSuccess),
                  ));
                  _goBack(context);
                }
              } catch (_) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(loc.convBlockError),
                    backgroundColor: AppColors.red,
                  ));
                }
              }
            },
            child:
                Text(loc.convBlockConfirm, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmHire() async {
    final hasConfirmedAlready =
        _isCandidate ? (_match?.hiredByCandidate ?? false) : (_match?.hiredByRecruiter ?? false);
    if (hasConfirmedAlready || _confirmingHire) return;
    final loc = AppLocalizations.of(context)!;

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: context.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.greenLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.handshake_outlined, color: AppColors.green, size: 28),
            ),
            const SizedBox(height: 16),
            Text(
              loc.convConfirmHireButton,
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: context.textPrimaryColor),
            ),
            const SizedBox(height: 8),
            Text(
              _isCandidate
                  ? loc.convConfirmHireBodyCandidate(_otherUserName.isNotEmpty ? _otherUserName : loc.convFallbackEmployer)
                  : loc.convConfirmHireBodyRecruiter(_otherUserName.isNotEmpty ? _otherUserName : loc.convFallbackPerson),
              style: TextStyle(fontSize: 14, color: context.textSecondaryColor, height: 1.5),
            ),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  style: OutlinedButton.styleFrom(side: BorderSide(color: context.borderColor)),
                  child: Text(loc.convCancel, style: TextStyle(color: context.textSecondaryColor)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.green),
                  child: Text(loc.convConfirm, style: const TextStyle(color: Colors.white)),
                ),
              ),
            ]),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;
    setState(() => _confirmingHire = true);
    try {
      await ref
          .read(matchRepositoryProvider)
          .confirmHire(widget.matchId, isCandidate: _isCandidate);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(loc.convHireConfirmedSnack),
          backgroundColor: AppColors.green,
        ));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(loc.convHireConfirmError),
          backgroundColor: AppColors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _confirmingHire = false);
    }
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
    _matchSub?.cancel();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final loc = AppLocalizations.of(context)!;
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
        title: Text(_title.isEmpty ? loc.convDefaultTitle : _title,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actionsIconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => _goBack(context),
        ),
        actions: [
          if (!_isCandidate && _userPlan == SubscriptionPlan.pro)
            IconButton(
              icon: const Icon(Icons.description_outlined),
              tooltip: loc.convMatchReportTooltip,
              onPressed: () => context.push('/recruiter/match-report/${widget.matchId}'),
            ),
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
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'report',
                  child: ListTile(
                    leading: const Icon(Icons.flag_outlined),
                    title: Text(loc.convReportTitle),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                ),
                PopupMenuItem(
                  value: 'block',
                  child: ListTile(
                    leading: const Icon(Icons.block, color: AppColors.red),
                    title: Text(loc.convBlockConfirm,
                        style: const TextStyle(color: AppColors.red)),
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
                      OutlinedButton(onPressed: _init, child: Text(loc.convRetry)),
                    ],
                  ),
                )
              : Column(
              children: [
                InterviewBanner(matchId: widget.matchId),
                _buildHireBanner(),
                Expanded(
                  child: _messages.isEmpty
                      ? Center(
                          child: Text(
                            loc.convNoMessages,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppColors.textHint),
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
                _InputBar(
                  controller: _msgCtrl,
                  onSend: _send,
                  onTemplates: (!_isCandidate && _userPlan == SubscriptionPlan.pro)
                      ? _showTemplatesSheet
                      : null,
                ),
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
                children: [
                  const Icon(Icons.done_all, size: 14, color: AppColors.primary),
                  const SizedBox(width: 3),
                  Text(AppLocalizations.of(context)!.convSeenLabel,
                      style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w500)),
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
  final VoidCallback? onTemplates;
  const _InputBar({required this.controller, required this.onSend, this.onTemplates});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          border: Border(top: BorderSide(color: context.borderColor)),
        ),
        child: Row(
          children: [
            if (onTemplates != null)
              IconButton(
                icon: const Icon(Icons.bolt_outlined, color: AppColors.primary),
                tooltip: loc.convTemplatesTitle,
                onPressed: onTemplates,
              ),
            Expanded(
              child: TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: loc.convMessageHint,
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