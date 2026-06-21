import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/app_user.dart';

final userRepositoryProvider =
    Provider<UserRepository>((ref) => UserRepository());

class UserRepository {
  final _db = FirebaseFirestore.instance;

  Future<void> createUser(AppUser user) async {
    await _db.collection('users').doc(user.uid).set({
      'email': user.email,
      'fullName': user.fullName,
      'role': user.role,
      'isAdmin': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<AppUser?> getUser(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return AppUser.fromMap({'uid': uid, ...?doc.data()});
  }
}