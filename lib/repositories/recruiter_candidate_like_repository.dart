import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final recruiterCandidateLikeRepositoryProvider =
    Provider<RecruiterCandidateLikeRepository>((ref) {
  return RecruiterCandidateLikeRepository();
});

class RecruiterCandidateLikeRepository {
  final _col =
      FirebaseFirestore.instance.collection('recruiter_candidate_likes');

  Future<bool> hasRecruiterLikedCandidate(
    String recruiterUserId,
    String candidateUserId,
    String jobOfferId,
  ) async {
    final q = await _col
        .where('recruiterUserId', isEqualTo: recruiterUserId)
        .where('candidateUserId', isEqualTo: candidateUserId)
        .where('jobOfferId', isEqualTo: jobOfferId)
        .limit(1)
        .get();
    return q.docs.isNotEmpty;
  }

  Future<bool> hasRecruiterLikedCandidateAny(
    String recruiterUserId,
    String candidateUserId,
  ) async {
    final q = await _col
        .where('recruiterUserId', isEqualTo: recruiterUserId)
        .where('candidateUserId', isEqualTo: candidateUserId)
        .limit(1)
        .get();
    return q.docs.isNotEmpty;
  }

  Future<bool> hasSuperLiked(
    String recruiterUserId,
    String candidateUserId,
    String jobOfferId,
  ) async {
    final q = await _col
        .where('recruiterUserId', isEqualTo: recruiterUserId)
        .where('candidateUserId', isEqualTo: candidateUserId)
        .where('jobOfferId', isEqualTo: jobOfferId)
        .where('isSuperLike', isEqualTo: true)
        .limit(1)
        .get();
    return q.docs.isNotEmpty;
  }

  Future<void> addLike(
    String recruiterUserId,
    String candidateUserId,
    String jobOfferId, {
    bool isSuperLike = false,
  }) async {
    final exists = await hasRecruiterLikedCandidate(
        recruiterUserId, candidateUserId, jobOfferId);
    if (exists) return;
    await _col.add({
      'recruiterUserId': recruiterUserId,
      'candidateUserId': candidateUserId,
      'jobOfferId': jobOfferId,
      'isSuperLike': isSuperLike,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<List<String>> getLikedCandidateIds(String recruiterUserId) async {
    final q = await _col
        .where('recruiterUserId', isEqualTo: recruiterUserId)
        .get();
    return q.docs
        .map((d) =>
            (d.data() as Map<String, dynamic>)['candidateUserId'] as String)
        .toList();
  }

  Future<List<Map<String, dynamic>>> getLikedCandidatesWithOffer(
      String recruiterUserId) async {
    final q = await _col
        .where('recruiterUserId', isEqualTo: recruiterUserId)
        .get();
    return q.docs.map((d) => d.data() as Map<String, dynamic>).toList();
  }
}