import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_avatar.dart';
import '../../models/candidate_profile.dart';
import '../../models/job_offer.dart';
import '../../models/pipeline_card.dart';
import '../../repositories/candidate_profile_repository.dart';
import '../../repositories/job_offer_repository.dart';
import '../../repositories/match_repository.dart';
import '../../services/pipeline_service.dart';
import '../../services/session_service.dart';

/// Pipeline de recrutement visuel kanban (Pro). Drag & drop custom via
/// Draggable/DragTarget (pas de dépendance externe flutter_kanban).
///
/// Les rappels (reminderAt) déclenchent une vraie notification locale
/// (cf. LocalNotificationService) en plus de l'indicateur visuel (horloge
/// rouge si échéance dépassée).
class PipelinePage extends ConsumerStatefulWidget {
  const PipelinePage({super.key});

  @override
  ConsumerState<PipelinePage> createState() => _PipelinePageState();
}

class _PipelinePageState extends ConsumerState<PipelinePage> {
  bool _loading = true;
  List<PipelineCard> _cards = [];
  final Map<String, CandidateProfile?> _candidates = {};
  final Map<String, JobOffer?> _offers = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final session = ref.read(sessionProvider);
    final pipelineSvc = ref.read(pipelineServiceProvider);

    // Crée les cartes manquantes pour les matchs récents (colonne "Nouveau match").
    final matches = await ref.read(matchRepositoryProvider).getMatchesByRecruiter(session.userId);
    for (final m in matches) {
      await pipelineSvc.ensureCardForMatch(
        recruiterId: session.userId,
        matchId: m.matchId,
        candidateId: m.candidateUserId,
        offerId: m.jobOfferId,
      );
    }

    final cards = await pipelineSvc.getCards(session.userId);
    final profileRepo = ref.read(candidateProfileRepositoryProvider);
    final offerRepo = ref.read(jobOfferRepositoryProvider);
    for (final c in cards) {
      if (!_candidates.containsKey(c.candidateId)) {
        _candidates[c.candidateId] = await profileRepo.getProfile(c.candidateId);
      }
      if (!_offers.containsKey(c.offerId)) {
        _offers[c.offerId] = await offerRepo.getOfferById(c.offerId);
      }
    }

    if (mounted) setState(() { _cards = cards; _loading = false; });
  }

  Future<void> _moveCard(PipelineCard card, PipelineColumn target) async {
    final session = ref.read(sessionProvider);
    await ref.read(pipelineServiceProvider).moveCard(session.userId, card.cardId, target);

    if (target == PipelineColumn.hired) {
      // Déclenche automatiquement le flow de confirmation d'embauche côté recruteur.
      await ref.read(matchRepositoryProvider).confirmHire(card.matchId, isCandidate: false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Embauche initiée — en attente de confirmation du candidat.'),
          backgroundColor: AppColors.green,
        ));
      }
    }
    _load();
  }

  void _exportCsv() {
    final buffer = StringBuffer('candidat,poste,colonne,note,déplacé le\n');
    for (final c in _cards) {
      final name = _candidates[c.candidateId]?.fullName ?? '';
      final title = _offers[c.offerId]?.title ?? '';
      buffer.writeln('"$name","$title","${c.column.label}","${c.note.replaceAll('"', '\'')}","${c.movedAt}"');
    }
    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pipeline exporté (CSV copié).')));
  }

  Future<void> _editCard(PipelineCard card) async {
    final noteCtrl = TextEditingController(text: card.note);
    DateTime? reminder = card.reminderAt != null ? DateTime.tryParse(card.reminderAt!) : null;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_candidates[card.candidateId]?.fullName ?? 'Candidat',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(
                controller: noteCtrl,
                maxLength: 200,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Note rapide', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: Text(reminder != null
                      ? 'Rappel : ${DateFormat('d MMM, HH:mm', 'fr_FR').format(reminder!)}'
                      : 'Aucun rappel'),
                ),
                TextButton(
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: ctx, initialDate: DateTime.now(),
                      firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date == null) return;
                    final time = await showTimePicker(context: ctx, initialTime: TimeOfDay.now());
                    if (time == null) return;
                    setSheet(() => reminder = DateTime(date.year, date.month, date.day, time.hour, time.minute));
                  },
                  child: const Text('Définir'),
                ),
              ]),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final session = ref.read(sessionProvider);
                    final svc = ref.read(pipelineServiceProvider);
                    await svc.saveNote(session.userId, card.cardId, noteCtrl.text);
                    await svc.setReminder(
                      session.userId, card.cardId, reminder,
                      candidateName: _candidates[card.candidateId]?.fullName ?? 'ce candidat',
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                    _load();
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                  child: const Text('Enregistrer', style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pipeline de recrutement'),
        actions: [
          IconButton(icon: const Icon(Icons.download_outlined), onPressed: _exportCsv, tooltip: 'Exporter CSV'),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: PipelineColumn.values.map((col) => _PipelineColumnWidget(
                      column: col,
                      cards: _cards.where((c) => c.column == col).toList(),
                      candidates: _candidates,
                      offers: _offers,
                      onDropCard: (card) => _moveCard(card, col),
                      onTapCard: _editCard,
                    )).toList(),
              ),
            ),
    );
  }
}

class _PipelineColumnWidget extends StatelessWidget {
  final PipelineColumn column;
  final List<PipelineCard> cards;
  final Map<String, CandidateProfile?> candidates;
  final Map<String, JobOffer?> offers;
  final void Function(PipelineCard) onDropCard;
  final void Function(PipelineCard) onTapCard;

  const _PipelineColumnWidget({
    required this.column,
    required this.cards,
    required this.candidates,
    required this.offers,
    required this.onDropCard,
    required this.onTapCard,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      margin: const EdgeInsets.only(right: 12),
      child: DragTarget<PipelineCard>(
        onAcceptWithDetails: (details) => onDropCard(details.data),
        builder: (context, candidateData, rejectedData) {
          final highlighted = candidateData.isNotEmpty;
          return Container(
            decoration: BoxDecoration(
              color: highlighted ? AppColors.primaryLight : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: highlighted ? AppColors.primary : Colors.grey.shade300),
            ),
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(child: Text(column.label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                    child: Text('${cards.length}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ]),
                const SizedBox(height: 10),
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 200),
                  child: Column(
                    children: cards.map((card) {
                      final candidate = candidates[card.candidateId];
                      final offer = offers[card.offerId];
                      final reminder = card.reminderAt != null ? DateTime.tryParse(card.reminderAt!) : null;
                      final overdue = reminder != null && reminder.isBefore(DateTime.now());

                      return Draggable<PipelineCard>(
                        data: card,
                        feedback: Material(
                          color: Colors.transparent,
                          child: _CardContent(candidate: candidate, offer: offer, card: card, overdue: overdue, dragging: true),
                        ),
                        childWhenDragging: Opacity(
                          opacity: 0.3,
                          child: _CardContent(candidate: candidate, offer: offer, card: card, overdue: overdue),
                        ),
                        child: GestureDetector(
                          onTap: () => onTapCard(card),
                          child: _CardContent(candidate: candidate, offer: offer, card: card, overdue: overdue),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CardContent extends StatelessWidget {
  final CandidateProfile? candidate;
  final JobOffer? offer;
  final PipelineCard card;
  final bool overdue;
  final bool dragging;

  const _CardContent({
    required this.candidate,
    required this.offer,
    required this.card,
    this.overdue = false,
    this.dragging = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: dragging ? 210 : null,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 4)],
      ),
      child: Row(children: [
        AppAvatar(name: candidate?.fullName ?? '?', radius: 16, photoPath: candidate?.photoUrl),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(candidate?.fullName ?? 'Candidat',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                  overflow: TextOverflow.ellipsis),
              if (offer != null)
                Text(offer!.title,
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade600), overflow: TextOverflow.ellipsis),
              if (card.note.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(card.note,
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                ),
            ],
          ),
        ),
        if (card.reminderAt != null)
          Icon(Icons.alarm, size: 14, color: overdue ? AppColors.red : Colors.grey.shade400),
      ]),
    );
  }
}
