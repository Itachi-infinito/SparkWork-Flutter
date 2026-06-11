import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/recruiter_profile.dart';

final recruiterProfileRepositoryProvider =
    Provider<RecruiterProfileRepository>((ref) => RecruiterProfileRepository());

class RecruiterProfileRepository {
  final _col = FirebaseFirestore.instance.collection('recruiter_profiles');

  RecruiterProfile _fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RecruiterProfile.fromMap({...data, 'profileId': doc.id});
  }

  Future<RecruiterProfile?> getProfile(String userId,
      {bool forceServer = false}) async {
    final q = await _col.where('userId', isEqualTo: userId).limit(1).get(
          forceServer ? const GetOptions(source: Source.server) : null,
        );
    if (q.docs.isEmpty) return null;
    return _fromDoc(q.docs.first);
  }

  Future<Map<String, RecruiterProfile>> getProfilesForUserIds(
      List<String> userIds) async {
    if (userIds.isEmpty) return {};
    final result = <String, RecruiterProfile>{};
    // Firestore IN max 30 — chunk by 10
    const chunk = 10;
    for (var i = 0; i < userIds.length; i += chunk) {
      final batch = userIds.skip(i).take(chunk).toList();
      final q = await _col.where('userId', whereIn: batch).get();
      for (final doc in q.docs) {
        final p = _fromDoc(doc);
        result[p.userId] = p;
      }
    }
    return result;
  }

  Future<void> upsertProfile(RecruiterProfile profile) async {
    final existing =
        await _col.where('userId', isEqualTo: profile.userId).limit(1).get();
    final map = profile.toMap()..remove('profileId');
    if (existing.docs.isNotEmpty) {
      await existing.docs.first.reference.update(map);
    } else {
      await _col.add(map);
    }
  }
}
