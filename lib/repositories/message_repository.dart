import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/message.dart';
import '../services/database_service.dart';

final messageRepositoryProvider = Provider<MessageRepository>((ref) {
  return MessageRepository(ref.read(databaseServiceProvider));
});

class MessageRepository {
  final DatabaseService _db;
  MessageRepository(this._db);

  Future<List<Message>> getMessages(int matchId) async {
    final db = await _db.database;
    final results = await db.query('messages', where: 'matchId = ?', whereArgs: [matchId], orderBy: 'sentAt ASC');
    return results.map(Message.fromMap).toList();
  }

  Future<int> sendMessage({required int matchId, required int senderUserId, required String content}) async {
    final db = await _db.database;
    return db.insert('messages', {
      'matchId': matchId,
      'senderUserId': senderUserId,
      'content': content,
      'sentAt': DateTime.now().toIso8601String(),
    });
  }

  Future<Message?> getLastMessage(int matchId) async {
    final db = await _db.database;
    final results = await db.query('messages', where: 'matchId = ?', whereArgs: [matchId], orderBy: 'sentAt DESC', limit: 1);
    if (results.isEmpty) return null;
    return Message.fromMap(results.first);
  }

  Future<void> markMessagesSeen({required int matchId, required int currentUserId}) async {
    final db = await _db.database;
    await db.update(
      'messages',
      {'seenAt': DateTime.now().toIso8601String()},
      where: 'matchId = ? AND senderUserId != ? AND seenAt IS NULL',
      whereArgs: [matchId, currentUserId],
    );
  }
}