class Match {
  final String matchId;
  final String candidateUserId;
  final String recruiterUserId;
  final String jobOfferId;
  final bool candidateAnimationSeen;
  final bool recruiterAnimationSeen;
  final String createdAt;

  // Statut embauche (Feature 1 — notation post-embauche)
  final bool hiredByCandidate;
  final bool hiredByRecruiter;
  final String? hiredAt;

  const Match({
    required this.matchId,
    required this.candidateUserId,
    required this.recruiterUserId,
    required this.jobOfferId,
    required this.candidateAnimationSeen,
    required this.recruiterAnimationSeen,
    required this.createdAt,
    this.hiredByCandidate = false,
    this.hiredByRecruiter = false,
    this.hiredAt,
  });

  bool get isHiredConfirmed => hiredByCandidate && hiredByRecruiter;

  Map<String, dynamic> toMap() => {
        'matchId': matchId,
        'candidateUserId': candidateUserId,
        'recruiterUserId': recruiterUserId,
        'jobOfferId': jobOfferId,
        'candidateAnimationSeen': candidateAnimationSeen,
        'recruiterAnimationSeen': recruiterAnimationSeen,
        'createdAt': createdAt,
        'hiredByCandidate': hiredByCandidate,
        'hiredByRecruiter': hiredByRecruiter,
        if (hiredAt != null) 'hiredAt': hiredAt,
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
        hiredByCandidate: map['hiredByCandidate'] as bool? ?? false,
        hiredByRecruiter: map['hiredByRecruiter'] as bool? ?? false,
        hiredAt: map['hiredAt'] as String?,
      );
}