import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import '../services/database_service.dart';

final candidateJobLikeRepositoryProvider = Provider<CandidateJobLikeRepository>((ref) {
  return CandidateJobLikeRepository(ref.read(databaseServiceProvider));
});

class CandidateJobLikeRepository {
  final DatabaseService _db;

  CandidateJobLikeRepository(this._db);

  Future<List<int>> getLikedJobOfferIds(int candidateUserId) async {
    final db = await _db.database;
    final results = await db.query(
      'candidate_job_likes',
      columns: ['jobOfferId'],
      where: 'candidateUserId = ?',
      whereArgs: [candidateUserId],
    );
    return results.map((r) => r['jobOfferId'] as int).toList();
  }

  Future<bool> hasLiked(int candidateUserId, int jobOfferId) async {
    final db = await _db.database;
    final results = await db.query(
      'candidate_job_likes',
      where: 'candidateUserId = ? AND jobOfferId = ?',
      whereArgs: [candidateUserId, jobOfferId],
      limit: 1,
    );
    return results.isNotEmpty;
  }

  Future<void> addLike(int candidateUserId, int jobOfferId) async {
    final db = await _db.database;
    await db.insert(
      'candidate_job_likes',
      {'candidateUserId': candidateUserId, 'jobOfferId': jobOfferId},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }
}