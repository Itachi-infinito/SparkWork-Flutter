import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_theme_ext.dart';
import '../../models/interview.dart';
import '../../repositories/interview_repository.dart';
import '../../services/session_service.dart';

const _amber = Color(0xFFF59E0B);

String formatSlot(DateTime d) =>
    DateFormat('EEE d MMM • HH:mm', 'fr_FR').format(d);

Future<void> _openLink(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

/// Bouton compact "Entretien" à placer dans une carte de match.
/// S'adapte au rôle de l'utilisateur connecté :
///  - recruteur : proposer des créneaux / voir le statut / annuler
///  - candidat  : répondre à une proposition / voir le créneau confirmé
class InterviewButton extends ConsumerStatefulWidget {
  final String matchId;
  final String recruiterUserId;
  final String candidateUserId;
  const InterviewButton({
    super.key,
    required this.matchId,
    required this.recruiterUserId,
    required this.candidateUserId,
  });

  @override
  ConsumerState<InterviewButton> createState() => _InterviewButtonState();
}

class _InterviewButtonState extends ConsumerState<InterviewButton> {
  Interview? _interview;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final session = ref.read(sessionProvider);
      final i = await ref.read(interviewRepositoryProvider).getForMatch(
            widget.matchId,
            userId: session.userId,
            isRecruiter: session.isRecruiter,
          );
      if (mounted) setState(() { _interview = i; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _onTap() async {
    final session = ref.read(sessionProvider);
    final i = _interview;
    bool changed = false;

    // Entretien accepté avec lien → ouvrir directement
    if (i != null && i.isAccepted && i.meetingLink.isNotEmpty) {
      await _openLink(i.meetingLink);
      return;
    }

    if (session.isRecruiter) {
      changed = await showProposeInterviewDialog(
        context, ref,
        matchId: widget.matchId,
        recruiterUserId: widget.recruiterUserId,
        candidateUserId: widget.candidateUserId,
        existing: i,
      );
    } else if (i != null) {
      changed = await showRespondInterviewDialog(context, ref, i);
    }
    if (changed) _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox(width: 34, height: 34);
    final session = ref.watch(sessionProvider);
    final i = _interview;

    late final IconData icon;
    late final String label;
    late final Color color;

    if (i == null || i.isCancelled) {
      // Pas d'entretien actif
      if (!session.isRecruiter) return const SizedBox.shrink();
      icon = Icons.calendar_month_outlined;
      label = 'Entretien';
      color = context.textSecondaryColor;
    } else if (i.isDeclined) {
      // Candidat a refusé
      if (!session.isRecruiter) return const SizedBox.shrink();
      icon = Icons.event_busy;
      label = 'Refusé — reproposer';
      color = AppColors.red;
    } else if (i.isPending) {
      icon = Icons.schedule;
      label = session.isRecruiter ? 'En attente' : 'Répondre';
      color = _amber;
    } else {
      // Accepté
      final hasLink = i.meetingLink.isNotEmpty;
      icon = hasLink ? Icons.video_call : Icons.event_available;
      final d = i.acceptedDate;
      label = hasLink
          ? 'Rejoindre l\'appel'
          : (d != null ? DateFormat('d MMM HH:mm', 'fr_FR').format(d) : 'Confirmé');
      color = AppColors.green;
    }

    return SizedBox(
      height: 34,
      child: OutlinedButton.icon(
        onPressed: _onTap,
        icon: Icon(icon, size: 14, color: color),
        label: Text(label, style: TextStyle(fontSize: 12, color: color)),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          minimumSize: Size.zero,
          side: BorderSide(color: color.withOpacity(0.6)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}

/// Bandeau affiché en haut d'une conversation quand un entretien est
/// proposé (candidat : répondre) ou confirmé (les deux).
class InterviewBanner extends ConsumerStatefulWidget {
  final String matchId;
  const InterviewBanner({super.key, required this.matchId});

  @override
  ConsumerState<InterviewBanner> createState() => _InterviewBannerState();
}

class _InterviewBannerState extends ConsumerState<InterviewBanner> {
  Interview? _interview;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final session = ref.read(sessionProvider);
      final i = await ref.read(interviewRepositoryProvider).getForMatch(
            widget.matchId,
            userId: session.userId,
            isRecruiter: session.isRecruiter,
          );
      if (mounted) setState(() => _interview = i);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final i = _interview;
    if (i == null || i.isCancelled) return const SizedBox.shrink();

    final session = ref.watch(sessionProvider);
    final isRecruiter = session.isRecruiter;

    // Candidat a refusé → bandeau visible seulement pour le recruteur
    if (i.isDeclined) {
      if (!isRecruiter) return const SizedBox.shrink();
      return GestureDetector(
        onTap: () async {
          final changed = await showProposeInterviewDialog(
            context, ref,
            matchId: i.matchId,
            recruiterUserId: i.recruiterUserId,
            candidateUserId: i.candidateUserId,
            existing: i,
          );
          if (changed) _load();
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          color: AppColors.red.withOpacity(0.1),
          child: Row(
            children: [
              const Icon(Icons.event_busy, size: 18, color: AppColors.red),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Le candidat a refusé — proposer de nouveaux créneaux',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.red,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right, size: 18, color: AppColors.red),
            ],
          ),
        ),
      );
    }

    final Color color = i.isAccepted ? AppColors.green : _amber;
    String text;
    if (i.isAccepted) {
      final d = i.acceptedDate;
      text = 'Entretien confirmé${d != null ? ' — ${formatSlot(d)}' : ''}';
    } else {
      text = !isRecruiter
          ? 'Entretien proposé — choisissez un créneau'
          : 'Proposition d\'entretien envoyée — en attente';
    }

    final hasLink = i.isAccepted && i.meetingLink.isNotEmpty;

    return GestureDetector(
      onTap: () async {
        bool changed = false;
        if (!isRecruiter && i.isPending) {
          changed = await showRespondInterviewDialog(context, ref, i);
        } else if (isRecruiter) {
          changed = await showProposeInterviewDialog(
            context, ref,
            matchId: i.matchId,
            recruiterUserId: i.recruiterUserId,
            candidateUserId: i.candidateUserId,
            existing: i,
          );
        }
        if (changed) _load();
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        color: color.withOpacity(0.12),
        child: Row(
          children: [
            Icon(i.isAccepted ? Icons.event_available : Icons.calendar_month,
                size: 18, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(text,
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: color)),
            ),
            if (hasLink)
              GestureDetector(
                onTap: () => _openLink(i.meetingLink),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.green,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.video_call, size: 14, color: Colors.white),
                      SizedBox(width: 4),
                      Text('Rejoindre',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.white,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              )
            else if (!isRecruiter && i.isPending)
              Icon(Icons.chevron_right, size: 18, color: color),
          ],
        ),
      ),
    );
  }
}

/// Dialog recruteur : choisir des créneaux + message + lien visio, envoyer.
/// Retourne true si une proposition a été créée/annulée.
Future<bool> showProposeInterviewDialog(
  BuildContext context,
  WidgetRef ref, {
  required String matchId,
  required String recruiterUserId,
  required String candidateUserId,
  Interview? existing,
}) async {
  // Entretien déjà confirmé : afficher le récap (+ annulation)
  if (existing != null && existing.isAccepted) {
    final d = existing.acceptedDate;
    final cancel = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Entretien confirmé'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(d != null
                ? 'Le candidat a confirmé le créneau :\n\n${formatSlot(d)}'
                : 'Le candidat a confirmé un créneau.'),
            if (existing.meetingLink.isNotEmpty) ...[
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => _openLink(existing.meetingLink),
                child: Row(
                  children: [
                    const Icon(Icons.video_call,
                        size: 16, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        existing.meetingLink,
                        style: const TextStyle(
                            color: AppColors.primary,
                            decoration: TextDecoration.underline,
                            fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Annuler l\'entretien',
                style: TextStyle(color: AppColors.red)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
    if (cancel == true) {
      await ref.read(interviewRepositoryProvider).cancel(existing.interviewId);
      return true;
    }
    return false;
  }

  // Pré-remplissage si re-proposition après refus ou mise à jour en attente
  final canPrefill =
      existing?.isPending == true || existing?.isDeclined == true;
  final slots = <DateTime>[...?canPrefill ? existing!.slotDates : null];
  final msgCtrl = TextEditingController(text: existing?.message ?? '');
  final linkCtrl =
      TextEditingController(text: existing?.meetingLink ?? '');

  Future<DateTime?> pickSlot(BuildContext ctx) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: ctx,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 60)),
      locale: const Locale('fr', 'FR'),
    );
    if (date == null || !ctx.mounted) return null;
    final time = await showTimePicker(
      context: ctx,
      initialTime: const TimeOfDay(hour: 10, minute: 0),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  final sent = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setD) => AlertDialog(
        title: Text(existing?.isDeclined == true
            ? 'Proposer de nouveaux créneaux'
            : 'Proposer un entretien'),
        content: SizedBox(
          width: 340,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (existing?.isDeclined == true)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.red.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Le candidat a refusé votre précédente proposition. '
                      'Proposez de nouveaux créneaux.',
                      style:
                          TextStyle(fontSize: 12.5, color: AppColors.red),
                    ),
                  )
                else
                  const Text(
                    'Proposez un ou plusieurs créneaux. Le candidat en '
                    'choisira un.',
                    style: TextStyle(
                        fontSize: 13, color: AppColors.textSecondary),
                  ),
                const SizedBox(height: 12),
                ...slots.map((s) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_month,
                              size: 16, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Expanded(
                              child: Text(formatSlot(s),
                                  style:
                                      const TextStyle(fontSize: 13))),
                          IconButton(
                            icon: const Icon(Icons.close, size: 16),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () =>
                                setD(() => slots.remove(s)),
                          ),
                        ],
                      ),
                    )),
                if (slots.length < 5)
                  TextButton.icon(
                    onPressed: () async {
                      final s = await pickSlot(ctx);
                      if (s != null) setD(() => slots..add(s)..sort());
                    },
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Ajouter un créneau'),
                  ),
                const SizedBox(height: 8),
                TextField(
                  controller: msgCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    hintText: 'Message (lieu, consignes...)',
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: linkCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Lien Teams / Meet / Zoom (optionnel)',
                    prefixIcon:
                        Icon(Icons.videocam_outlined, size: 18),
                    isDense: true,
                  ),
                  keyboardType: TextInputType.url,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(existing?.isPending == true ? 'Fermer' : 'Annuler'),
          ),
          ElevatedButton.icon(
            onPressed: slots.isEmpty ? null : () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.send, size: 16),
            label: Text(existing?.isPending == true
                ? 'Mettre à jour'
                : 'Envoyer'),
            style:
                ElevatedButton.styleFrom(backgroundColor: AppColors.green),
          ),
        ],
      ),
    ),
  );

  if (sent != true) return false;
  try {
    await ref.read(interviewRepositoryProvider).propose(
          matchId: matchId,
          recruiterUserId: recruiterUserId,
          candidateUserId: candidateUserId,
          slots: slots,
          message: msgCtrl.text.trim(),
          meetingLink: linkCtrl.text.trim(),
        );
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Envoi impossible : $e'),
        backgroundColor: AppColors.red,
        duration: const Duration(seconds: 5),
      ));
    }
    return false;
  }
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Proposition d\'entretien envoyée !'),
      backgroundColor: AppColors.green,
    ));
  }
  return true;
}

/// Dialog candidat : accepter un créneau ou refuser.
/// Retourne true si une réponse a été enregistrée.
Future<bool> showRespondInterviewDialog(
    BuildContext context, WidgetRef ref, Interview interview) async {
  if (interview.isAccepted) {
    final d = interview.acceptedDate;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Entretien confirmé'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(d != null
                ? 'Votre entretien est confirmé :\n\n${formatSlot(d)}'
                : 'Votre entretien est confirmé.'),
            if (interview.meetingLink.isNotEmpty) ...[
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => _openLink(interview.meetingLink),
                child: Row(
                  children: [
                    const Icon(Icons.video_call,
                        size: 16, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        interview.meetingLink,
                        style: const TextStyle(
                            color: AppColors.primary,
                            decoration: TextDecoration.underline,
                            fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Fermer')),
        ],
      ),
    );
    return false;
  }

  DateTime? selected;
  final result = await showDialog<String>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setD) => AlertDialog(
        title: const Text('Proposition d\'entretien'),
        content: SizedBox(
          width: 340,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Le recruteur vous propose ces créneaux :',
                  style: TextStyle(
                      fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(height: 10),
              ...interview.slotDates.map((s) => RadioListTile<DateTime>(
                    value: s,
                    groupValue: selected,
                    onChanged: (v) => setD(() => selected = v),
                    title: Text(formatSlot(s),
                        style: const TextStyle(fontSize: 14)),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    activeColor: AppColors.primary,
                  )),
              if (interview.message.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(interview.message,
                      style: const TextStyle(
                          fontSize: 12.5, color: AppColors.primary)),
                ),
              ],
              if (interview.meetingLink.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.videocam_outlined,
                        size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Réunion en ligne prévue',
                        style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'decline'),
            child: const Text('Refuser',
                style: TextStyle(color: AppColors.red)),
          ),
          ElevatedButton(
            onPressed:
                selected == null ? null : () => Navigator.pop(ctx, 'accept'),
            style:
                ElevatedButton.styleFrom(backgroundColor: AppColors.green),
            child: const Text('Confirmer ce créneau'),
          ),
        ],
      ),
    ),
  );

  try {
    if (result == 'accept' && selected != null) {
      await ref
          .read(interviewRepositoryProvider)
          .accept(interview.interviewId, selected!);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Entretien confirmé — ${formatSlot(selected!)}'),
          backgroundColor: AppColors.green,
        ));
      }
      return true;
    }
    if (result == 'decline') {
      await ref
          .read(interviewRepositoryProvider)
          .decline(interview.interviewId);
      return true;
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Réponse impossible : $e'),
        backgroundColor: AppColors.red,
        duration: const Duration(seconds: 5),
      ));
    }
  }
  return false;
}
