import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/match.dart';

final matchRepositoryProvider = Provider<MatchRepository>((ref) {
  return MatchRepository();
});

class MatchRepository {
  final _col = FirebaseFirestore.instance.collection('matches');

  Match _fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Match.fromMap({...data, 'matchId': doc.id});
  }

  Future<String> addMatch({
    required String candidateUserId,
    required String recruiterUserId,
    required String jobOfferId,
    String jobOfferTitle = '',
    String companyName = '',
  }) async {
    final ref = await _col.add({
      'candidateUserId': candidateUserId,
      'recruiterUserId': recruiterUserId,
      'jobOfferId': jobOfferId,
      'jobOfferTitle': jobOfferTitle,
      'companyName': companyName,
      'candidateAnimationSeen': false,
      'recruiterAnimationSeen': false,
      'createdAt': DateTime.now().toIso8601String(),
    });
    return ref.id;
  }

  Future<Match?> getMatchById(String matchId) async {
    final doc = await _col.doc(matchId).get();
    if (!doc.exists) return null;
    return _fromDoc(doc);
  }

  /// Flux temps réel d'un match (utilisé pour refléter la confirmation
  /// d'embauche de l'autre partie sans recharger manuellement).
  Stream<Match?> watchMatch(String matchId) {
    return _col.doc(matchId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return _fromDoc(doc);
    });
  }

  /// Confirme l'embauche pour une des deux parties. Quand les deux parties
  /// ont confirmé, la Cloud Function `onHireConfirmed` enregistre `hiredAt`
  /// et notifie les deux utilisateurs — ce n'est pas géré côté client.
  Future<void> confirmHire(String matchId, {required bool isCandidate}) async {
    final field = isCandidate ? 'hiredByCandidate' : 'hiredByRecruiter';
    await _col.doc(matchId).update({field: true});
  }

  Future<bool> matchExists(
    String candidateUserId,
    String recruiterUserId,
    String jobOfferId,
  ) async {
    final q = await _col
        .where('candidateUserId', isEqualTo: candidateUserId)
        .where('recruiterUserId', isEqualTo: recruiterUserId)
        .where('jobOfferId', isEqualTo: jobOfferId)
        .limit(1)
        .get();
    return q.docs.isNotEmpty;
  }

  Future<List<Match>> getMatchesByCandidate(String candidateUserId) async {
    final q = await _col
        .where('candidateUserId', isEqualTo: candidateUserId)
        .orderBy('createdAt', descending: true)
        .get();
    return q.docs.map(_fromDoc).toList();
  }

  Future<List<Match>> getMatchesByRecruiter(String recruiterUserId) async {
    final q = await _col
        .where('recruiterUserId', isEqualTo: recruiterUserId)
        .orderBy('createdAt', descending: true)
        .get();
    return q.docs.map(_fromDoc).toList();
  }

  Future<Match?> getPendingMatchAnimation(String userId, String role) async {
    final isCandidate = role == 'candidate';
    final userField = isCandidate ? 'candidateUserId' : 'recruiterUserId';
    final seenField =
        isCandidate ? 'candidateAnimationSeen' : 'recruiterAnimationSeen';

    final q = await _col
        .where(userField, isEqualTo: userId)
        .where(seenField, isEqualTo: false)
        .limit(1)
        .get();
    if (q.docs.isEmpty) return null;
    return _fromDoc(q.docs.first);
  }

  Future<void> markAnimationSeen(
    String matchId, {
    required bool isCandidate,
  }) async {
    final field =
        isCandidate ? 'candidateAnimationSeen' : 'recruiterAnimationSeen';
    await _col.doc(matchId).update({field: true});
  }
}