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

  Future<void> addLike(String candidateUserId, String jobOfferId) async {
    if (await hasLiked(candidateUserId, jobOfferId)) return;
    await _col.add({
      'candidateUserId': candidateUserId,
      'jobOfferId': jobOfferId,
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
}