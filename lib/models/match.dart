class Match {
  final int matchId;
  final int candidateUserId;
  final int recruiterUserId;
  final int jobOfferId;
  final bool candidateAnimationSeen;
  final bool recruiterAnimationSeen;
  final String createdAt;

  const Match({
    required this.matchId,
    required this.candidateUserId,
    required this.recruiterUserId,
    required this.jobOfferId,
    required this.candidateAnimationSeen,
    required this.recruiterAnimationSeen,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'matchId': matchId,
        'candidateUserId': candidateUserId,
        'recruiterUserId': recruiterUserId,
        'jobOfferId': jobOfferId,
        'candidateAnimationSeen': candidateAnimationSeen ? 1 : 0,
        'recruiterAnimationSeen': recruiterAnimationSeen ? 1 : 0,
        'createdAt': createdAt,
      };

  factory Match.fromMap(Map<String, dynamic> map) => Match(
        matchId: map['matchId'] as int,
        candidateUserId: map['candidateUserId'] as int,
        recruiterUserId: map['recruiterUserId'] as int,
        jobOfferId: map['jobOfferId'] as int,
        candidateAnimationSeen: (map['candidateAnimationSeen'] as int) == 1,
        recruiterAnimationSeen: (map['recruiterAnimationSeen'] as int) == 1,
        createdAt: map['createdAt'] as String,
      );
}