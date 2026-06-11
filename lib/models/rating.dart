class Rating {
  final String ratingId;
  final String fromUserId;
  final String toUserId;
  final String matchId;
  final int score;
  final String comment;
  final String createdAt;

  const Rating({
    required this.ratingId,
    required this.fromUserId,
    required this.toUserId,
    required this.matchId,
    required this.score,
    this.comment = '',
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'ratingId': ratingId,
        'fromUserId': fromUserId,
        'toUserId': toUserId,
        'matchId': matchId,
        'score': score,
        'comment': comment,
        'createdAt': createdAt,
      };

  factory Rating.fromMap(Map<String, dynamic> map, String id) => Rating(
        ratingId: id,
        fromUserId: map['fromUserId'] as String? ?? '',
        toUserId: map['toUserId'] as String? ?? '',
        matchId: map['matchId'] as String? ?? '',
        score: (map['score'] as num?)?.toInt() ?? 0,
        comment: map['comment'] as String? ?? '',
        createdAt: map['createdAt'] as String? ?? '',
      );
}
