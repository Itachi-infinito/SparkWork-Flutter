import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/rating.dart';
import '../models/match.dart';

final ratingServiceProvider =
    Provider<RatingService>((ref) => RatingService());

class RatingService {
  final _db = FirebaseFirestore.instance;

  /// Soumet une note. Lève une exception si les conditions ne sont pas remplies.
  Future<void> submitRating({
    required String fromUserId,
    required String toUserId,
    required String matchId,
    required int score,
    required String targetType,
    String comment = '',
  }) async {
    // Vérifier que le match est en statut "hired confirmé"
    final matchDoc = await _db.collection('matches').doc(matchId).get();
    if (!matchDoc.exists) throw Exception('Match introuvable.');
    final match = Match.fromMap(matchDoc.data()!);
    if (!match.isHiredConfirmed) {
      throw Exception('La notation est disponible uniquement après confirmation d\'embauche des deux côtés.');
    }

    // Vérifier qu'il n'a pas déjà noté
    final existing = await _db
        .collection('ratings')
        .where('fromUserId', isEqualTo: fromUserId)
        .where('matchId', isEqualTo: matchId)
        .get();
    if (existing.docs.isNotEmpty) throw Exception('Vous avez déjà laissé une évaluation pour ce match.');

    if (score < 1 || score > 5) throw Exception('La note doit être entre 1 et 5.');

    final now = DateTime.now().toIso8601String();
    final docRef = _db.collection('ratings').doc();
    await docRef.set(Rating(
      ratingId: docRef.id,
      fromUserId: fromUserId,
      toUserId: toUserId,
      matchId: matchId,
      score: score,
      comment: comment.trim().length > 300 ? comment.trim().substring(0, 300) : comment.trim(),
      createdAt: now,
      targetType: targetType,
    ).toMap());

    // Recalcule la moyenne
    await _recalculateAverage(toUserId);
  }

  Future<void> _recalculateAverage(String userId) async {
    final all = await _db
        .collection('ratings')
        .where('toUserId', isEqualTo: userId)
        .where('isHidden', isEqualTo: false)
        .get();
    if (all.docs.isEmpty) return;
    final scores = all.docs.map((d) => (d.data()['score'] as num).toInt()).toList();
    final avg = scores.reduce((a, b) => a + b) / scores.length;
    await _db.collection('average_ratings').doc(userId).set({
      'userId': userId,
      'averageScore': double.parse(avg.toStringAsFixed(1)),
      'totalReviews': scores.length,
    });
  }

  Future<AverageRating?> getAverageRating(String userId) async {
    try {
      final doc = await _db.collection('average_ratings').doc(userId).get();
      if (!doc.exists) return null;
      return AverageRating.fromMap(doc.data()!);
    } catch (_) {
      return null;
    }
  }

  Future<List<Rating>> getRatingsForUser(String userId) async {
    try {
      final q = await _db
          .collection('ratings')
          .where('toUserId', isEqualTo: userId)
          .where('isHidden', isEqualTo: false)
          .orderBy('createdAt', descending: true)
          .get();
      return q.docs.map((d) => Rating.fromMap(d.data(), d.id)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<bool> hasAlreadyRated(String fromUserId, String matchId) async {
    try {
      final q = await _db
          .collection('ratings')
          .where('fromUserId', isEqualTo: fromUserId)
          .where('matchId', isEqualTo: matchId)
          .get();
      return q.docs.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Confirme l'embauche pour un participant (candidat ou recruteur).
  Future<void> confirmHired(String matchId, String userId, bool isRecruiter) async {
    await _db.collection('matches').doc(matchId).update(
      isRecruiter
          ? {'hiredByRecruiter': true, 'hiredAt': DateTime.now().toIso8601String()}
          : {'hiredByCandidate': true, 'hiredAt': DateTime.now().toIso8601String()},
    );
  }
}
