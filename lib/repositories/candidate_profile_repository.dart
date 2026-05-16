import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/candidate_profile.dart';
import '../services/database_service.dart';

final candidateProfileRepositoryProvider = Provider<CandidateProfileRepository>((ref) {
  return CandidateProfileRepository(ref.read(databaseServiceProvider));
});

class CandidateProfileRepository {
  final DatabaseService _db;

  CandidateProfileRepository(this._db);

  Future<CandidateProfile?> getProfile(int userId) async {
    final db = await _db.database;
    final results = await db.query(
      'candidate_profiles',
      where: 'userId = ?',
      whereArgs: [userId],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return CandidateProfile.fromMap(results.first);
  }

  Future<List<CandidateProfile>> getAllProfiles() async {
    final db = await _db.database;
    final results = await db.query('candidate_profiles');
    return results.map(CandidateProfile.fromMap).toList();
  }

  Future<int> insertProfile(CandidateProfile profile) async {
    final db = await _db.database;
    final map = profile.toMap()..remove('profileId');
    return db.insert('candidate_profiles', map);
  }

  Future<void> updateProfile(CandidateProfile profile) async {
    final db = await _db.database;
    await db.update(
      'candidate_profiles',
      profile.toMap(),
      where: 'profileId = ?',
      whereArgs: [profile.profileId],
    );
  }
}