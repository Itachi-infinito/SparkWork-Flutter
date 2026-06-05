class Message {
  final String messageId;
  final String matchId;
  final String senderUserId;
  final String content;
  final String sentAt;
  final String? seenAt;

  const Message({
    required this.messageId,
    required this.matchId,
    required this.senderUserId,
    required this.content,
    required this.sentAt,
    this.seenAt,
  });

  bool get isSeen => seenAt != null;

  Map<String, dynamic> toMap() => {
        'messageId': messageId,
        'matchId': matchId,
        'senderUserId': senderUserId,
        'content': content,
        'sentAt': sentAt,
        'seenAt': seenAt,
      };

  factory Message.fromMap(Map<String, dynamic> map) => Message(
        messageId: map['messageId'] as String? ?? '',
        matchId: map['matchId'] as String? ?? '',
        senderUserId: map['senderUserId'] as String? ?? '',
        content: map['content'] as String? ?? '',
        sentAt: map['sentAt'] as String? ?? '',
        seenAt: map['seenAt'] as String?,
      );
}