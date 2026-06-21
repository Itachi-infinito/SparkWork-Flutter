import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/pipeline_card.dart';
import 'local_notification_service.dart';

final pipelineServiceProvider = Provider<PipelineService>((ref) => PipelineService());

class PipelineService {
  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _cards(String recruiterId) =>
      _db.collection('recruiter_pipeline').doc(recruiterId).collection('cards');

  Future<List<PipelineCard>> getCards(String recruiterId) async {
    try {
      final q = await _cards(recruiterId).get();
      return q.docs.map((d) => PipelineCard.fromMap(d.data(), d.id)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Crée une carte "Nouveau match" si elle n'existe pas déjà pour ce match.
  Future<void> ensureCardForMatch({
    required String recruiterId,
    required String matchId,
    required String candidateId,
    required String offerId,
  }) async {
    final existing = await _cards(recruiterId).where('matchId', isEqualTo: matchId).limit(1).get();
    if (existing.docs.isNotEmpty) return;
    await _cards(recruiterId).add(PipelineCard(
      cardId: '',
      candidateId: candidateId,
      matchId: matchId,
      offerId: offerId,
      column: PipelineColumn.newMatch,
      movedAt: DateTime.now().toIso8601String(),
    ).toMap());
  }

  Future<void> moveCard(String recruiterId, String cardId, PipelineColumn column) async {
    await _cards(recruiterId).doc(cardId).update({
      'column': column.value,
      'movedAt': DateTime.now().toIso8601String(),
    });
  }

  Future<void> saveNote(String recruiterId, String cardId, String note) async {
    await _cards(recruiterId).doc(cardId).update({
      'note': note.length > 200 ? note.substring(0, 200) : note,
    });
  }

  Future<void> setReminder(
    String recruiterId,
    String cardId,
    DateTime? reminderAt, {
    String candidateName = 'ce candidat',
  }) async {
    await _cards(recruiterId).doc(cardId).update({
      'reminderAt': reminderAt?.toIso8601String(),
    });
    if (reminderAt == null) {
      await LocalNotificationService.cancelReminder(cardId);
    } else {
      await LocalNotificationService.scheduleReminder(
        cardId: cardId,
        title: 'Rappel pipeline',
        body: 'Suivi à faire pour $candidateName.',
        scheduledAt: reminderAt,
      );
    }
  }
}
