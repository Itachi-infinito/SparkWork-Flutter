import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/subscription.dart';
import '../models/swipe_history_entry.dart';

final swipeHistoryServiceProvider =
    Provider<SwipeHistoryService>((ref) => SwipeHistoryService());

class SwipeHistoryService {
  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _history =>
      _db.collection('swipe_history');
  CollectionReference<Map<String, dynamic>> get _favorites =>
      _db.collection('candidate_favorites');

  Future<void> recordSwipe({
    required String recruiterId,
    required String candidateId,
    required String offerId,
    required String action,
    int score = 0,
  }) async {
    await _history.add(SwipeHistoryEntry(
      entryId: '',
      recruiterId: recruiterId,
      candidateId: candidateId,
      offerId: offerId,
      action: action,
      swipedAt: DateTime.now().toIso8601String(),
      score: score,
    ).toMap());
  }

  /// Nombre de jours d'historique visibles selon le plan — 0 = pas d'historique.
  int historyDaysForPlan(SubscriptionPlan plan) {
    switch (plan) {
      case SubscriptionPlan.free: return 0;
      case SubscriptionPlan.starter: return 7;
      case SubscriptionPlan.pro: return 30;
    }
  }

  Future<List<SwipeHistoryEntry>> getHistory(String recruiterId, SubscriptionPlan plan) async {
    final days = historyDaysForPlan(plan);
    if (days == 0) return [];
    final cutoff = DateTime.now().subtract(Duration(days: days)).toIso8601String();
    try {
      final q = await _history
          .where('recruiterId', isEqualTo: recruiterId)
          .where('swipedAt', isGreaterThan: cutoff)
          .orderBy('swipedAt', descending: true)
          .get();
      return q.docs.map((d) => SwipeHistoryEntry.fromMap(d.data(), d.id)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> markRecovered(String entryId) async {
    await _history.doc(entryId).update({'recovered': true});
  }

  Future<void> addFavorite(String recruiterId, String candidateId) async {
    await _favorites.doc('${recruiterId}_$candidateId').set({
      'recruiterId': recruiterId,
      'candidateId': candidateId,
      'favoritedAt': DateTime.now().toIso8601String(),
    });
  }

  Future<void> removeFavorite(String recruiterId, String candidateId) async {
    await _favorites.doc('${recruiterId}_$candidateId').delete();
  }

  Future<bool> isFavorited(String recruiterId, String candidateId) async {
    final doc = await _favorites.doc('${recruiterId}_$candidateId').get();
    return doc.exists;
  }

  Future<List<String>> getFavoriteCandidateIds(String recruiterId) async {
    try {
      final q = await _favorites.where('recruiterId', isEqualTo: recruiterId).get();
      return q.docs.map((d) => d.data()['candidateId'] as String).toList();
    } catch (_) {
      return [];
    }
  }
}
