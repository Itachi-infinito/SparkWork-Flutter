import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/match.dart';
import '../services/database_service.dart';

final matchRepositoryProvider = Provider<MatchRepository>((ref) {
  return MatchRepository(ref.read(databaseServiceProvider));
});

class MatchRepository {
  final DatabaseService _db;

  MatchRepository(this._db);

  Future<int> addMatch({
    required int candidateUserId,
    required int recruiterUserId,
    required int jobOfferId,
  }) async {
    final db = await _db.database;
    return db.insert('matches', {
      'candidateUserId': candidateUserId,
      'recruiterUserId': recruiterUserId,
      'jobOfferId': jobOfferId,
      'candidateAnimationSeen': 0,
      'recruiterAnimationSeen': 0,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  Future<bool> matchExists(
      int candidateUserId, int recruiterUserId, int jobOfferId) async {
    final db = await _db.database;
    final results = await db.query(
      'matches',
      where: 'candidateUserId = ? AND recruiterUserId = ? AND jobOfferId = ?',
      whereArgs: [candidateUserId, recruiterUserId, jobOfferId],
      limit: 1,
    );
    return results.isNotEmpty;
  }

  Future<List<Match>> getMatchesByCandidate(int candidateUserId) async {
    final db = await _db.database;
    final results = await db.query(
      'matches',
      where: 'candidateUserId = ?',
      whereArgs: [candidateUserId],
      orderBy: 'createdAt DESC',
    );
    return results.map(Match.fromMap).toList();
  }

  Future<List<Match>> getMatchesByRecruiter(int recruiterUserId) async {
    final db = await _db.database;
    final results = await db.query(
      'matches',
      where: 'recruiterUserId = ?',
      whereArgs: [recruiterUserId],
      orderBy: 'createdAt DESC',
    );
    return results.map(Match.fromMap).toList();
  }

  Future<Match?> getPendingMatchAnimation(
      int userId, String role) async {
    final db = await _db.database;
    final column = role == 'candidate'
        ? 'candidateAnimationSeen'
        : 'recruiterAnimationSeen';
    final userColumn =
        role == 'candidate' ? 'candidateUserId' : 'recruiterUserId';

    final results = await db.query(
      'matches',
      where: '$userColumn = ? AND $column = 0',
      whereArgs: [userId],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return Match.fromMap(results.first);
  }

  Future<void> markAnimationSeen(int matchId, String role) async {
    final db = await _db.database;
    final column = role == 'candidate'
        ? 'candidateAnimationSeen'
        : 'recruiterAnimationSeen';
    await db.update(
      'matches',
      {column: 1},
      where: 'matchId = ?',
      whereArgs: [matchId],
    );
  }
}