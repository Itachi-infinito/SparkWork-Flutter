import 'package:flutter_test/flutter_test.dart';
import 'package:sparkwork/models/pipeline_card.dart';

void main() {
  group('PipelineColumnExt', () {
    test('value/fromValue font un aller-retour pour toutes les colonnes', () {
      for (final c in PipelineColumn.values) {
        expect(PipelineColumnExt.fromValue(c.value), c);
      }
    });

    test('fromValue retombe sur newMatch pour une valeur inconnue', () {
      expect(PipelineColumnExt.fromValue('inexistant'), PipelineColumn.newMatch);
    });

    test('chaque colonne a un label français non vide', () {
      for (final c in PipelineColumn.values) {
        expect(c.label, isNotEmpty);
      }
    });
  });

  group('PipelineCard', () {
    test('toMap/fromMap conservent les données', () {
      const card = PipelineCard(
        cardId: 'card1',
        candidateId: 'cand1',
        matchId: 'match1',
        offerId: 'offer1',
        column: PipelineColumn.interviewScheduled,
        movedAt: '2026-01-01T10:00:00.000',
        note: 'Bon profil',
        reminderAt: '2026-01-02T10:00:00.000',
      );
      final restored = PipelineCard.fromMap(card.toMap(), 'card1');

      expect(restored.cardId, card.cardId);
      expect(restored.candidateId, card.candidateId);
      expect(restored.matchId, card.matchId);
      expect(restored.offerId, card.offerId);
      expect(restored.column, card.column);
      expect(restored.movedAt, card.movedAt);
      expect(restored.note, card.note);
      expect(restored.reminderAt, card.reminderAt);
    });

    test('reminderAt absent du toMap si null', () {
      const card = PipelineCard(
        cardId: 'c', candidateId: 'a', matchId: 'm', offerId: 'o',
        column: PipelineColumn.newMatch, movedAt: '',
      );
      expect(card.toMap().containsKey('reminderAt'), isFalse);
    });

    test('fromMap retombe sur des valeurs par défaut si champs manquants', () {
      final card = PipelineCard.fromMap({}, 'docId');
      expect(card.cardId, 'docId');
      expect(card.candidateId, '');
      expect(card.column, PipelineColumn.newMatch);
      expect(card.note, '');
      expect(card.reminderAt, isNull);
    });
  });
}
