import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/message.dart';

final messageRepositoryProvider = Provider<MessageRepository>((ref) {
  return MessageRepository();
});

class MessageRepository {
  final _col = FirebaseFirestore.instance.collection('messages');

  Message _fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Message.fromMap({...data, 'messageId': doc.id});
  }

  Stream<List<Message>> watchMessages(String matchId) {
    return _col
        .where('matchId', isEqualTo: matchId)
        .orderBy('sentAt')
        .snapshots()
        .map((snap) => snap.docs.map(_fromDoc).toList());
  }

  Future<List<Message>> getMessages(String matchId) async {
    final q = await _col
        .where('matchId', isEqualTo: matchId)
        .orderBy('sentAt')
        .get();
    return q.docs.map(_fromDoc).toList();
  }

  Future<void> sendMessage({
    required String matchId,
    required String senderUserId,
    required String content,
  }) async {
    await _col.add({
      'matchId': matchId,
      'senderUserId': senderUserId,
      'content': content,
      'sentAt': DateTime.now().toIso8601String(),
      'seenAt': null,
    });
  }

  Future<void> markAsSeen(String messageId) async {
    await _col.doc(messageId).update({
      'seenAt': DateTime.now().toIso8601String(),
    });
  }

  Future<void> markMessagesSeen(String matchId, String userId) async {
    final q = await _col
        .where('matchId', isEqualTo: matchId)
        .where('senderUserId', isNotEqualTo: userId)
        .get();
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in q.docs) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['seenAt'] == null) {
        batch.update(
            doc.reference, {'seenAt': DateTime.now().toIso8601String()});
      }
    }
    await batch.commit();
  }

  Future<Message?> getLastMessage(String matchId) async {
    final q = await _col
        .where('matchId', isEqualTo: matchId)
        .orderBy('sentAt', descending: true)
        .limit(1)
        .get();
    if (q.docs.isEmpty) return null;
    return _fromDoc(q.docs.first);
  }
}