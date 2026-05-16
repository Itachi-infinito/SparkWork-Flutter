import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user.dart';
import 'database_service.dart';

class AuthService {
  final DatabaseService _db;
  AuthService(this._db);

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
    if (fullName.trim().isEmpty) return (false, 'Le nom est requis.');
    if (!email.contains('@')) return (false, 'Email invalide.');
    if (password.length < 6) return (false, 'Minimum 6 caractères.');

    final normalized = email.trim().toLowerCase();
    final existing = await _db.getUserByEmail(normalized);
    if (existing != null) return (false, 'Un compte existe déjà avec cet email.');

    final user = User(
      fullName: fullName.trim(),
      email: normalized,
      passwordHash: _hashPassword(password),
      role: role,
    );
    await _db.insertUser(user);
    return (true, '');
  }

  Future<User?> login(String email, String password) async {
    final normalized = email.trim().toLowerCase();
    final user = await _db.getUserByEmail(normalized);
    if (user == null) return null;
    if (user.passwordHash != _hashPassword(password)) return null;
    return user;
  }
}

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref.read(databaseServiceProvider));
});
