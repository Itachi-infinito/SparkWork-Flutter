import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/candidate_profile.dart';

final candidateProfileRepositoryProvider =
    Provider<CandidateProfileRepository>((ref) {
  return CandidateProfileRepository();
});

class CandidateProfileRepository {
  final _col = FirebaseFirestore.instance.collection('candidate_profiles');

  CandidateProfile _fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CandidateProfile.fromMap({...data, 'profileId': doc.id});
  }

  Future<CandidateProfile?> getProfile(String userId, {bool forceServer = false}) async {
    final q = await _col.where('userId', isEqualTo: userId).limit(1).get(
      forceServer ? const GetOptions(source: Source.server) : null,
    );
    if (q.docs.isEmpty) return null;
    return _fromDoc(q.docs.first);
  }

  Future<CandidateProfile?> getProfileByUserId(String userId) =>
      getProfile(userId);

  Future<List<CandidateProfile>> getAllProfiles() async {
    final q = await _col.get();
    return q.docs.map(_fromDoc).toList();
  }

  Future<void> insertProfile(CandidateProfile profile) async {
    final existing = await _col
        .where('userId', isEqualTo: profile.userId)
        .limit(1)
        .get();
    final map = profile.toMap()..remove('profileId');
    if (existing.docs.isNotEmpty) {
      await existing.docs.first.reference.update(map);
    } else {
      await _col.add(map);
    }
  }

  Future<void> upsertProfile(CandidateProfile profile) =>
      insertProfile(profile);

  Future<void> updateProfile(CandidateProfile profile) async {
    if (profile.profileId.isNotEmpty) {
      final map = profile.toMap()..remove('profileId');
      await _col.doc(profile.profileId).update(map);
    } else {
      await insertProfile(profile);
    }
  }

  Future<(List<CandidateProfile>, DocumentSnapshot?)> getProfilesBatch(
      int limit, {DocumentSnapshot? startAfter}) async {
    Query<Map<String, dynamic>> query = _col.limit(limit);
    if (startAfter != null) query = query.startAfterDocument(startAfter);
    final q = await query.get();
    final last = q.docs.isNotEmpty ? q.docs.last : null;
    return (q.docs.map(_fromDoc).toList(), last);
  }
}