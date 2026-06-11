import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final candidateJobLikeRepositoryProvider =
    Provider<CandidateJobLikeRepository>((ref) {
  return CandidateJobLikeRepository();
});

class CandidateJobLikeRepository {
  final _col =
      FirebaseFirestore.instance.collection('candidate_job_likes');

  Future<List<String>> getLikedJobOfferIds(String candidateUserId) async {
    final q = await _col
        .where('candidateUserId', isEqualTo: candidateUserId)
        .get();
    return q.docs
        .map((d) =>
            (d.data() as Map<String, dynamic>)['jobOfferId'] as String)
        .toList();
  }

  Future<List<String>> getLikedOfferIds(String candidateUserId) =>
      getLikedJobOfferIds(candidateUserId);

  Future<bool> hasLiked(String candidateUserId, String jobOfferId) async {
    final q = await _col
        .where('candidateUserId', isEqualTo: candidateUserId)
        .where('jobOfferId', isEqualTo: jobOfferId)
        .limit(1)
        .get();
    return q.docs.isNotEmpty;
  }

  Future<void> addLike(String candidateUserId, String jobOfferId,
      {bool isSuperLike = false}) async {
    if (await hasLiked(candidateUserId, jobOfferId)) return;
    await _col.add({
      'candidateUserId': candidateUserId,
      'jobOfferId': jobOfferId,
      'isSuperLike': isSuperLike,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> removeLike(String candidateUserId, String jobOfferId) async {
    final q = await _col
        .where('candidateUserId', isEqualTo: candidateUserId)
        .where('jobOfferId', isEqualTo: jobOfferId)
        .get();
    for (final doc in q.docs) {
      await doc.reference.delete();
    }
  }

  Future<int> countLikesForOffers(List<String> jobOfferIds) async {
    if (jobOfferIds.isEmpty) return 0;
    int count = 0;
    for (final id in jobOfferIds) {
      final q = await _col.where('jobOfferId', isEqualTo: id).get();
      count += q.docs.length;
    }
    return count;
  }

  Future<Map<String, int>> getLikeCountPerOffer(
      List<String> jobOfferIds) async {
    final result = <String, int>{};
    for (final id in jobOfferIds) {
      final q = await _col.where('jobOfferId', isEqualTo: id).get();
      result[id] = q.docs.length;
    }
    return result;
  }

  /// Retourne les likes reçus sur les offres d'un recruteur :
  /// liste de {candidateUserId, jobOfferId, isSuperLike}.
  Future<List<Map<String, dynamic>>> getLikesReceivedForOffers(
      List<String> jobOfferIds) async {
    if (jobOfferIds.isEmpty) return [];
    final result = <Map<String, dynamic>>[];
    // Firestore IN query max 30 items — on chunke par 10 pour rester safe
    const chunkSize = 10;
    for (var i = 0; i < jobOfferIds.length; i += chunkSize) {
      final chunk = jobOfferIds.skip(i).take(chunkSize).toList();
      final q =
          await _col.where('jobOfferId', whereIn: chunk).get();
      for (final doc in q.docs) {
        final data = doc.data() as Map<String, dynamic>;
        result.add({
          'candidateUserId': data['candidateUserId'] as String? ?? '',
          'jobOfferId': data['jobOfferId'] as String? ?? '',
          'isSuperLike': data['isSuperLike'] as bool? ?? false,
        });
      }
    }
    return result;
  }
}