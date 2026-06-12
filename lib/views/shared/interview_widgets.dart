import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_theme_ext.dart';
import '../../models/interview.dart';
import '../../repositories/interview_repository.dart';
import '../../services/session_service.dart';

const _amber = Color(0xFFF59E0B);

String formatSlot(DateTime d) =>
    DateFormat('EEE d MMM • HH:mm', 'fr_FR').format(d);

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
      final i = await ref
          .read(interviewRepositoryProvider)
          .getForMatch(widget.matchId);
      if (mounted) setState(() { _interview = i; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _onTap() async {
    final session = ref.read(sessionProvider);
    bool changed = false;
    if (session.isRecruiter) {
      changed = await showProposeInterviewDialog(
        context, ref,
        matchId: widget.matchId,
        recruiterUserId: widget.recruiterUserId,
        candidateUserId: widget.candidateUserId,
        existing: _interview,
      );
    } else if (_interview != null) {
      changed = await showRespondInterviewDialog(context, ref, _interview!);
    }
    if (changed) _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox(width: 34, height: 34);
    final session = ref.watch(sessionProvider);
    final i = _interview;

    // Candidat sans proposition active : rien à afficher
    final hasActive = i != null && (i.isPending || i.isAccepted);
    if (!session.isRecruiter && !hasActive) return const SizedBox.shrink();

    late final IconData icon;
    late final String label;
    late final Color color;
    if (i == null || i.isDeclined || i.isCancelled) {
      icon = Icons.calendar_month_outlined;
      label = 'Entretien';
      color = context.textSecondaryColor;
    } else if (i.isPending) {
      icon = Icons.schedule;
      label = session.isRecruiter ? 'En attente' : 'Répondre';
      color = _amber;
    } else {
      icon = Icons.event_available;
      final d = i.acceptedDate;
      label = d != null ? DateFormat('d MMM HH:mm', 'fr_FR').format(d) : 'Confirmé';
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
      final i = await ref
          .read(interviewRepositoryProvider)
          .getForMatch(widget.matchId);
      if (mounted) setState(() => _interview = i);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final i = _interview;
    if (i == null || i.isDeclined || i.isCancelled) {
      return const SizedBox.shrink();
    }
    final session = ref.watch(sessionProvider);
    final isCandidate = session.isCandidate;

    final Color color = i.isAccepted ? AppColors.green : _amber;
    String text;
    if (i.isAccepted) {
      final d = i.acceptedDate;
      text = 'Entretien confirmé${d != null ? ' — ${formatSlot(d)}' : ''}';
    } else {
      text = isCandidate
          ? 'Entretien proposé — choisissez un créneau'
          : 'Proposition d\'entretien envoyée — en attente';
    }

    return GestureDetector(
      onTap: () async {
        bool changed = false;
        if (isCandidate && i.isPending) {
          changed = await showRespondInterviewDialog(context, ref, i);
        } else if (!isCandidate) {
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
            if (isCandidate && i.isPending)
              Icon(Icons.chevron_right, size: 18, color: color),
          ],
        ),
      ),
    );
  }
}

/// Dialog recruteur : choisir des créneaux + message, envoyer.
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
        content: Text(d != null
            ? 'Le candidat a confirmé le créneau :\n\n${formatSlot(d)}'
            : 'Le candidat a confirmé un créneau.'),
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

  final slots = <DateTime>[...?existing?.isPending == true
      ? existing!.slotDates
      : null];
  final msgCtrl = TextEditingController(text: existing?.message ?? '');

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
        title: const Text('Proposer un entretien'),
        content: SizedBox(
          width: 340,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Proposez un ou plusieurs créneaux. Le candidat en '
                'choisira un.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
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
                                style: const TextStyle(fontSize: 13))),
                        IconButton(
                          icon: const Icon(Icons.close, size: 16),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => setD(() => slots.remove(s)),
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
                  hintText: 'Message (lieu, visio, consignes...)',
                  isDense: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          if (existing != null && existing.isPending)
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Fermer'),
            )
          else
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler'),
            ),
          ElevatedButton.icon(
            onPressed: slots.isEmpty ? null : () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.send, size: 16),
            label: Text(existing?.isPending == true
                ? 'Mettre à jour'
                : 'Envoyer'),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.green),
          ),
        ],
      ),
    ),
  );

  if (sent != true) return false;
  await ref.read(interviewRepositoryProvider).propose(
        matchId: matchId,
        recruiterUserId: recruiterUserId,
        candidateUserId: candidateUserId,
        slots: slots,
        message: msgCtrl.text.trim(),
      );
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
        content: Text(d != null
            ? 'Votre entretien est confirmé :\n\n${formatSlot(d)}'
            : 'Votre entretien est confirmé.'),
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
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.green),
            child: const Text('Confirmer ce créneau'),
          ),
        ],
      ),
    ),
  );

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
    await ref.read(interviewRepositoryProvider).decline(interview.interviewId);
    return true;
  }
  return false;
}
