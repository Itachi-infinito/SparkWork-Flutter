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

    // average_ratings/{toUserId} est recalculé côté serveur par la Cloud
    // Function onRatingCreated — les règles Firestore interdisent à
    // l'auteur de la note d'écrire la moyenne d'un AUTRE utilisateur.
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
}
