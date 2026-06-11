import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/rating.dart';

final ratingRepositoryProvider = Provider<RatingRepository>((_) => RatingRepository());

class RatingRepository {
  final _col = FirebaseFirestore.instance.collection('ratings');

  Future<void> addRating({
    required String fromUserId,
    required String toUserId,
    required String matchId,
    required int score,
    String comment = '',
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final map = {
      'fromUserId': fromUserId,
      'toUserId': toUserId,
      'matchId': matchId,
      'score': score,
      'comment': comment,
      'createdAt': now,
    };
    // Upsert: one rating per (fromUser, match)
    final existing = await _col
        .where('fromUserId', isEqualTo: fromUserId)
        .where('matchId', isEqualTo: matchId)
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) {
      await existing.docs.first.reference.update(map);
    } else {
      await _col.add(map);
    }
  }

  Future<Rating?> getRatingForMatch(String fromUserId, String matchId) async {
    final q = await _col
        .where('fromUserId', isEqualTo: fromUserId)
        .where('matchId', isEqualTo: matchId)
        .limit(1)
        .get();
    if (q.docs.isEmpty) return null;
    return Rating.fromMap(q.docs.first.data(), q.docs.first.id);
  }

  Future<({double average, int count})> getUserRatingSummary(String userId) async {
    final q = await _col.where('toUserId', isEqualTo: userId).get();
    if (q.docs.isEmpty) return (average: 0.0, count: 0);
    final scores = q.docs.map((d) => (d.data()['score'] as num?)?.toInt() ?? 0).toList();
    final avg = scores.reduce((a, b) => a + b) / scores.length;
    return (average: avg, count: scores.length);
  }
}
