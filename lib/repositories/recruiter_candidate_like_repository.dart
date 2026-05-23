import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import '../services/database_service.dart';

final recruiterCandidateLikeRepositoryProvider =
    Provider<RecruiterCandidateLikeRepository>((ref) {
  return RecruiterCandidateLikeRepository(ref.read(databaseServiceProvider));
});

class RecruiterCandidateLikeRepository {
  final DatabaseService _db;

  RecruiterCandidateLikeRepository(this._db);

  Future<bool> hasRecruiterLikedCandidate(
      int recruiterUserId, int candidateUserId, int jobOfferId) async {
    final db = await _db.database;
    final results = await db.query(
      'recruiter_candidate_likes',
      where: 'recruiterUserId = ? AND candidateUserId = ? AND jobOfferId = ?',
      whereArgs: [recruiterUserId, candidateUserId, jobOfferId],
      limit: 1,
    );
    return results.isNotEmpty;
  }

  Future<bool> hasRecruiterLikedCandidateAny(
      int recruiterUserId, int candidateUserId) async {
    final db = await _db.database;
    final results = await db.query(
      'recruiter_candidate_likes',
      where: 'recruiterUserId = ? AND candidateUserId = ?',
      whereArgs: [recruiterUserId, candidateUserId],
      limit: 1,
    );
    return results.isNotEmpty;
  }

  Future<bool> hasSuperLiked(
      int recruiterUserId, int candidateUserId, int jobOfferId) async {
    final db = await _db.database;
    final results = await db.query(
      'recruiter_candidate_likes',
      where:
          'recruiterUserId = ? AND candidateUserId = ? AND jobOfferId = ? AND isSuperLike = 1',
      whereArgs: [recruiterUserId, candidateUserId, jobOfferId],
      limit: 1,
    );
    return results.isNotEmpty;
  }

  Future<void> addLike(
    int recruiterUserId,
    int candidateUserId,
    int jobOfferId, {
    bool isSuperLike = false,
  }) async {
    final db = await _db.database;
    await db.insert(
      'recruiter_candidate_likes',
      {
        'recruiterUserId': recruiterUserId,
        'candidateUserId': candidateUserId,
        'jobOfferId': jobOfferId,
        'isSuperLike': isSuperLike ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<List<int>> getLikedCandidateIds(int recruiterUserId) async {
    final db = await _db.database;
    final results = await db.query(
      'recruiter_candidate_likes',
      columns: ['candidateUserId'],
      where: 'recruiterUserId = ?',
      whereArgs: [recruiterUserId],
    );
    return results.map((r) => r['candidateUserId'] as int).toList();
  }

  Future<List<Map<String, dynamic>>> getLikedCandidatesWithOffer(
      int recruiterUserId) async {
    final db = await _db.database;
    return db.query(
      'recruiter_candidate_likes',
      where: 'recruiterUserId = ?',
      whereArgs: [recruiterUserId],
    );
  }
}