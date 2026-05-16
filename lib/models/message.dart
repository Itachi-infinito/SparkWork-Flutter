class Message {
  final int messageId;
  final int matchId;
  final int senderUserId;
  final String content;
  final DateTime sentAt;

  Message({
    this.messageId = 0, required this.matchId,
    required this.senderUserId, required this.content, required this.sentAt,
  });

  Map<String, dynamic> toMap() => {
    'messageId': messageId == 0 ? null : messageId,
    'matchId': matchId, 'senderUserId': senderUserId,
    'content': content, 'sentAt': sentAt.toIso8601String(),
  };

  factory Message.fromMap(Map<String, dynamic> m) => Message(
    messageId: m['messageId'] as int? ?? 0,
    matchId: m['matchId'] as int,
    senderUserId: m['senderUserId'] as int,
    content: m['content'] as String,
    sentAt: DateTime.parse(m['sentAt'] as String),
  );
}
