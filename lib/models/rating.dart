class Rating {
  final String ratingId;
  final String fromUserId;
  final String toUserId;
  final String matchId;
  final int score;
  final String comment;
  final String createdAt;
  final String targetType; // 'candidate' | 'recruiter'
  final bool isHidden;    // modéré par admin

  const Rating({
    required this.ratingId,
    required this.fromUserId,
    required this.toUserId,
    required this.matchId,
    required this.score,
    this.comment = '',
    required this.createdAt,
    this.targetType = 'candidate',
    this.isHidden = false,
  });

  Map<String, dynamic> toMap() => {
        'ratingId': ratingId,
        'fromUserId': fromUserId,
        'toUserId': toUserId,
        'matchId': matchId,
        'score': score,
        'comment': comment,
        'createdAt': createdAt,
        'targetType': targetType,
        'isHidden': isHidden,
      };

  factory Rating.fromMap(Map<String, dynamic> map, String id) => Rating(
        ratingId: id,
        fromUserId: map['fromUserId'] as String? ?? '',
        toUserId: map['toUserId'] as String? ?? '',
        matchId: map['matchId'] as String? ?? '',
        score: (map['score'] as num?)?.toInt() ?? 0,
        comment: map['comment'] as String? ?? '',
        createdAt: map['createdAt'] as String? ?? '',
        targetType: map['targetType'] as String? ?? 'candidate',
        isHidden: map['isHidden'] as bool? ?? false,
      );
}

class AverageRating {
  final String userId;
  final double averageScore;
  final int totalReviews;

  const AverageRating({
    required this.userId,
    required this.averageScore,
    required this.totalReviews,
  });

  factory AverageRating.fromMap(Map<String, dynamic> map) => AverageRating(
        userId: map['userId'] as String? ?? '',
        averageScore: (map['averageScore'] as num?)?.toDouble() ?? 0.0,
        totalReviews: (map['totalReviews'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'averageScore': averageScore,
        'totalReviews': totalReviews,
      };
}
