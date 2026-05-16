class Match {
  final int matchId;
  final int candidateUserId;
  final String candidateName;
  final int recruiterUserId;
  final String companyName;
  final String jobTitle;
  final int jobOfferId;
  final bool animationSeenByCandidate;
  final bool animationSeenByRecruiter;

  Match({
    this.matchId = 0, required this.candidateUserId, required this.candidateName,
    required this.recruiterUserId, required this.companyName, required this.jobTitle,
    required this.jobOfferId,
    this.animationSeenByCandidate = false, this.animationSeenByRecruiter = false,
  });

  Map<String, dynamic> toMap() => {
    'matchId': matchId == 0 ? null : matchId,
    'candidateUserId': candidateUserId, 'candidateName': candidateName,
    'recruiterUserId': recruiterUserId, 'companyName': companyName,
    'jobTitle': jobTitle, 'jobOfferId': jobOfferId,
    'animationSeenByCandidate': animationSeenByCandidate ? 1 : 0,
    'animationSeenByRecruiter': animationSeenByRecruiter ? 1 : 0,
  };

  factory Match.fromMap(Map<String, dynamic> m) => Match(
    matchId: m['matchId'] as int? ?? 0,
    candidateUserId: m['candidateUserId'] as int,
    candidateName: m['candidateName'] as String,
    recruiterUserId: m['recruiterUserId'] as int,
    companyName: m['companyName'] as String,
    jobTitle: m['jobTitle'] as String,
    jobOfferId: m['jobOfferId'] as int,
    animationSeenByCandidate: (m['animationSeenByCandidate'] as int? ?? 0) == 1,
    animationSeenByRecruiter: (m['animationSeenByRecruiter'] as int? ?? 0) == 1,
  );
}
