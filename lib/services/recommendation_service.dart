import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/recommendation.dart';

final recommendationServiceProvider =
    Provider<RecommendationService>((ref) => RecommendationService());

class RecommendationService {
  final _db = FirebaseFirestore.instance;

  static const int maxPublished = 5;

  String _generateToken() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rand = Random.secure();
    return List.generate(20, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  /// Crée une demande de recommandation et retourne le lien unique.
  Future<String> requestRecommendation(String candidateId) async {
    final token = _generateToken();
    final docRef = _db.collection('recommendations').doc();
    await docRef.set({
      'recommendationId': docRef.id,
      'candidateId': candidateId,
      'authorName': '',
      'authorRole': '',
      'authorCompany': '',
      'text': '',
      'isPublished': false,
      'status': 'pending',
      'createdAt': DateTime.now().toIso8601String(),
      'linkToken': token,
    });
    return token;
  }

  /// Soumet le formulaire par un ancien employeur (via lien unique).
  Future<void> submitRecommendation({
    required String token,
    required String authorName,
    required String authorRole,
    required String authorCompany,
    required String text,
  }) async {
    final q = await _db
        .collection('recommendations')
        .where('linkToken', isEqualTo: token)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();
    if (q.docs.isEmpty) throw Exception('Lien invalide ou déjà utilisé.');
    final doc = q.docs.first;
    final candidateId = doc.data()['candidateId'] as String;

    // Vérifier la limite de 5 recommandations publiées
    final published = await getPublishedRecommendations(candidateId);
    if (published.length >= maxPublished) {
      throw Exception('Le candidat a atteint la limite de $maxPublished recommandations publiées.');
    }

    await doc.reference.update({
      'authorName': authorName.trim(),
      'authorRole': authorRole.trim(),
      'authorCompany': authorCompany.trim(),
      'text': text.trim().length > 400 ? text.trim().substring(0, 400) : text.trim(),
      'status': 'submitted',
      'submittedAt': DateTime.now().toIso8601String(),
    });
  }

  /// Récupère les recommandations en attente d'approbation par le candidat.
  Future<List<Recommendation>> getPendingRecommendations(String candidateId) async {
    try {
      final q = await _db
          .collection('recommendations')
          .where('candidateId', isEqualTo: candidateId)
          .where('status', isEqualTo: 'submitted')
          .orderBy('createdAt', descending: true)
          .get();
      return q.docs.map((d) => Recommendation.fromMap(d.data())).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<Recommendation>> getPublishedRecommendations(String candidateId) async {
    try {
      final q = await _db
          .collection('recommendations')
          .where('candidateId', isEqualTo: candidateId)
          .where('isPublished', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .get();
      return q.docs.map((d) => Recommendation.fromMap(d.data())).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> approveRecommendation(String recommendationId) async {
    await _db.collection('recommendations').doc(recommendationId).update({
      'isPublished': true,
      'status': 'approved',
    });
  }

  Future<void> rejectRecommendation(String recommendationId) async {
    await _db.collection('recommendations').doc(recommendationId).update({
      'isPublished': false,
      'status': 'rejected',
    });
  }
}
