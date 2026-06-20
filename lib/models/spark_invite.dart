class SparkInvite {
  final String inviteId;
  final String senderId;
  final String receiverId;
  final String offerId;
  final String sentAt;
  final String status; // pending / viewed / accepted / declined

  const SparkInvite({
    required this.inviteId,
    required this.senderId,
    required this.receiverId,
    required this.offerId,
    required this.sentAt,
    this.status = 'pending',
  });

  Map<String, dynamic> toMap() => {
        'senderId': senderId,
        'receiverId': receiverId,
        'offerId': offerId,
        'sentAt': sentAt,
        'status': status,
      };

  factory SparkInvite.fromMap(Map<String, dynamic> map, String docId) => SparkInvite(
        inviteId: docId,
        senderId: map['senderId'] as String? ?? '',
        receiverId: map['receiverId'] as String? ?? '',
        offerId: map['offerId'] as String? ?? '',
        sentAt: map['sentAt'] as String? ?? '',
        status: map['status'] as String? ?? 'pending',
      );
}
