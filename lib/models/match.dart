class Match {
  final String matchId;
  final String candidateUserId;
  final String recruiterUserId;
  final String jobOfferId;
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
        'candidateAnimationSeen': candidateAnimationSeen,
        'recruiterAnimationSeen': recruiterAnimationSeen,
        'createdAt': createdAt,
      };

  factory Match.fromMap(Map<String, dynamic> map) => Match(
        matchId: map['matchId'] as String? ?? '',
        candidateUserId: map['candidateUserId'] as String? ?? '',
        recruiterUserId: map['recruiterUserId'] as String? ?? '',
        jobOfferId: map['jobOfferId'] as String? ?? '',
        candidateAnimationSeen:
            map['candidateAnimationSeen'] as bool? ?? false,
        recruiterAnimationSeen:
            map['recruiterAnimationSeen'] as bool? ?? false,
        createdAt: map['createdAt'] as String? ?? '',
      );
}