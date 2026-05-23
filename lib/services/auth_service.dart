import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user.dart';
import 'database_service.dart';
import 'session_service.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref.read(databaseServiceProvider), ref);
});

class AuthService {
  final DatabaseService _db;
  final Ref _ref;

  AuthService(this._db, this._ref);

  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    return sha256.convert(bytes).toString();
  }

  Future<(bool, String)> register({
    required String fullName,
    required String email,
    required String password,
    required String role,
  }) async {
    final existing = await _db.getUserByEmail(email);
    if (existing != null) {
      return (false, 'Un compte existe déjà avec cet email.');
    }

    final hash = _hashPassword(password);
    final userId = await _db.insertUser({
      'fullName': fullName,
      'email': email,
      'passwordHash': hash,
      'role': role,
    });

    await _ref.read(sessionProvider.notifier).login(
          userId: userId,
          userName: fullName,
          userEmail: email,
          userRole: role,
        );

    return (true, '');
  }

  Future<User?> login(String email, String password) async {
    final user = await _db.getUserByEmail(email);
    if (user == null) return null;

    final hash = _hashPassword(password);
    if (user.passwordHash != hash) return null;

    await _ref.read(sessionProvider.notifier).login(
          userId: user.userId,
          userName: user.fullName,
          userEmail: user.email,
          userRole: user.role,
        );

    return user;
  }

  Future<(bool, String)> changePassword({
    required int userId,
    required String currentPassword,
    required String newPassword,
  }) async {
    if (newPassword.length < 6) {
      return (false, 'Le nouveau mot de passe doit faire au moins 6 caractères.');
    }
    final user = await _db.getUserById(userId);
    if (user == null) return (false, 'Utilisateur introuvable.');

    final currentHash = _hashPassword(currentPassword);
    if (user.passwordHash != currentHash) {
      return (false, 'Mot de passe actuel incorrect.');
    }

    final db = await _db.database;
    await db.update(
      'users',
      {'passwordHash': _hashPassword(newPassword)},
      where: 'userId = ?',
      whereArgs: [userId],
    );
    return (true, '');
  }

  Future<void> deleteAccount(int userId) async {
    final db = await _db.database;
    final matchIds = (await db.query('matches',
            columns: ['matchId'],
            where: 'candidateUserId = ? OR recruiterUserId = ?',
            whereArgs: [userId, userId]))
        .map((r) => r['matchId'] as int)
        .toList();

    for (final mid in matchIds) {
      await db.delete('messages', where: 'matchId = ?', whereArgs: [mid]);
    }
    await db.delete('matches',
        where: 'candidateUserId = ? OR recruiterUserId = ?',
        whereArgs: [userId, userId]);
    await db.delete('candidate_job_likes',
        where: 'candidateUserId = ?', whereArgs: [userId]);
    await db.delete('recruiter_candidate_likes',
        where: 'recruiterUserId = ? OR candidateUserId = ?',
        whereArgs: [userId, userId]);
    await db.delete('job_offers',
        where: 'recruiterUserId = ?', whereArgs: [userId]);
    await db.delete('candidate_profiles',
        where: 'userId = ?', whereArgs: [userId]);
    await db.delete('users', where: 'userId = ?', whereArgs: [userId]);
  }
}