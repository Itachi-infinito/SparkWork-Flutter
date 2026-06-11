import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final reportRepositoryProvider =
    Provider<ReportRepository>((ref) => ReportRepository());

/// Signalement et blocage d'utilisateurs (exigence Apple 1.2 pour le
/// contenu généré par les utilisateurs).
class ReportRepository {
  final _db = FirebaseFirestore.instance;

  static const reportReasons = [
    'Contenu inapproprié',
    'Harcèlement ou comportement abusif',
    'Spam ou arnaque',
    'Faux profil / fausse offre',
    'Autre',
  ];

  Future<void> reportUser({
    required String reporterUserId,
    required String reportedUserId,
    required String reason,
    String details = '',
    String? matchId,
  }) async {
    await _db.collection('reports').add({
      'reporterUserId': reporterUserId,
      'reportedUserId': reportedUserId,
      'reason': reason,
      'details': details,
      if (matchId != null) 'matchId': matchId,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> blockUser(String userId, String blockedUserId) async {
    await _db.collection('users').doc(userId).update({
      'blocked': FieldValue.arrayUnion([blockedUserId]),
    });
  }

  Future<void> unblockUser(String userId, String blockedUserId) async {
    await _db.collection('users').doc(userId).update({
      'blocked': FieldValue.arrayRemove([blockedUserId]),
    });
  }

  Future<List<String>> getBlockedIds(String userId) async {
    final doc = await _db.collection('users').doc(userId).get();
    final data = doc.data();
    if (data == null) return [];
    return List<String>.from(data['blocked'] as List? ?? []);
  }
}
