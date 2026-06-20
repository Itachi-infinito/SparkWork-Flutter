import 'package:flutter_test/flutter_test.dart';
import 'package:sparkwork/models/subscription.dart';
import 'package:sparkwork/models/swipe_history_entry.dart';
import 'package:sparkwork/services/swipe_history_service.dart';

void main() {
  group('SwipeHistoryEntry', () {
    test('toMap/fromMap conservent les données', () {
      const entry = SwipeHistoryEntry(
        entryId: 'e1',
        recruiterId: 'r1',
        candidateId: 'c1',
        offerId: 'o1',
        action: 'superlike',
        swipedAt: '2026-01-01T00:00:00.000',
        recovered: true,
        score: 87,
      );
      final restored = SwipeHistoryEntry.fromMap(entry.toMap(), 'e1');

      expect(restored.recruiterId, entry.recruiterId);
      expect(restored.candidateId, entry.candidateId);
      expect(restored.offerId, entry.offerId);
      expect(restored.action, entry.action);
      expect(restored.recovered, entry.recovered);
      expect(restored.score, entry.score);
    });

    test('fromMap retombe sur des valeurs par défaut si champs manquants', () {
      final entry = SwipeHistoryEntry.fromMap({}, 'docId');
      expect(entry.entryId, 'docId');
      expect(entry.action, 'pass');
      expect(entry.recovered, isFalse);
      expect(entry.score, 0);
    });
  });

  group('SwipeHistoryService.historyDaysForPlan', () {
    test('Free : aucun historique', () {
      expect(SwipeHistoryService.historyDaysForPlan(SubscriptionPlan.free), 0);
    });

    test('Starter : 7 jours', () {
      expect(SwipeHistoryService.historyDaysForPlan(SubscriptionPlan.starter), 7);
    });

    test('Pro : 30 jours', () {
      expect(SwipeHistoryService.historyDaysForPlan(SubscriptionPlan.pro), 30);
    });
  });
}
