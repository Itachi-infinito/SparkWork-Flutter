import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/spark_invite.dart';
import '../repositories/recruiter_candidate_like_repository.dart';

final sparkInviteServiceProvider = Provider<SparkInviteService>((ref) => SparkInviteService());

const int sparkInviteDailyLimit = 5;

class SparkInviteService {
  final _db = FirebaseFirestore.instance;
  final _likeRepo = RecruiterCandidateLikeRepository();

  CollectionReference<Map<String, dynamic>> get _col => _db.collection('sparkInvites');

  Future<int> getTodayCount(String senderId) async {
    final startOfDay = DateTime.now().toIso8601String().substring(0, 10);
    try {
      final q = await _col
          .where('senderId', isEqualTo: senderId)
          .where('sentAt', isGreaterThanOrEqualTo: startOfDay)
          .get();
      return q.docs.length;
    } catch (_) {
      return 0;
    }
  }

  Future<bool> canSendInvite(String senderId) async {
    return await getTodayCount(senderId) < sparkInviteDailyLimit;
  }

  /// Envoie un SparkInvite. La Cloud Function onSparkInviteCreated se
  /// charge d'envoyer la notification push (le client n'a pas accès à FCM
  /// directement). Retourne false si la limite quotidienne est atteinte
  /// ou si une invitation existe déjà pour ce couple candidat/offre.
  ///
  /// Compte aussi comme un like recruteur sur ce candidat pour cette
  /// offre : sans ça, un candidat qui aime l'offre en retour après avoir
  /// reçu l'invitation ne déclenchait jamais de match, puisque le
  /// recruteur n'avait techniquement jamais "liké" — seulement notifié.
  Future<bool> sendInvite({
    required String senderId,
    required String receiverId,
    required String offerId,
  }) async {
    if (!await canSendInvite(senderId)) return false;

    final existing = await _col
        .where('senderId', isEqualTo: senderId)
        .where('receiverId', isEqualTo: receiverId)
        .where('offerId', isEqualTo: offerId)
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) return false;

    await _col.add(SparkInvite(
      inviteId: '',
      senderId: senderId,
      receiverId: receiverId,
      offerId: offerId,
      sentAt: DateTime.now().toIso8601String(),
    ).toMap());
    await _likeRepo.addLike(senderId, receiverId, offerId);
    return true;
  }

  Future<void> markViewed(String inviteId) async {
    await _col.doc(inviteId).update({'status': 'viewed'});
  }
}
