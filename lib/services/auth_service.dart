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
    final db = await _db.database;
    final rows = await db.query('users',
        where: 'userId = ?', whereArgs: [userId], limit: 1);
    if (rows.isEmpty) return (false, 'Utilisateur introuvable.');
    final user = User.fromMap(rows.first);
    if (user.passwordHash != _hashPassword(currentPassword)) {
      return (false, 'Mot de passe actuel incorrect.');
    }
    if (newPassword.length < 6) {
      return (false, 'Le nouveau mot de passe doit faire au moins 6 caractères.');
    }
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
    await db.rawDelete(
      'DELETE FROM messages WHERE matchId IN '
      '(SELECT matchId FROM matches WHERE candidateUserId = ? OR recruiterUserId = ?)',
      [userId, userId],
    );
    await db.delete('matches',
        where: 'candidateUserId = ? OR recruiterUserId = ?',
        whereArgs: [userId, userId]);
    await db.delete('candidate_job_likes',
        where: 'candidateUserId = ?', whereArgs: [userId]);
    await db.delete('recruiter_candidate_likes',
        where: 'recruiterUserId = ?', whereArgs: [userId]);
    await db.delete('job_offers',
        where: 'recruiterUserId = ?', whereArgs: [userId]);
    await db.delete('candidate_profiles',
        where: 'userId = ?', whereArgs: [userId]);
    await db.delete('users', where: 'userId = ?', whereArgs: [userId]);
    await _ref.read(sessionProvider.notifier).logout();
  }
}