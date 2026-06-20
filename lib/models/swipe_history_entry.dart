class SwipeHistoryEntry {
  final String entryId;
  final String recruiterId;
  final String candidateId;
  final String offerId;
  final String action; // pass / like / superlike
  final String swipedAt;
  final bool recovered;
  final int score;

  const SwipeHistoryEntry({
    required this.entryId,
    required this.recruiterId,
    required this.candidateId,
    required this.offerId,
    required this.action,
    required this.swipedAt,
    this.recovered = false,
    this.score = 0,
  });

  Map<String, dynamic> toMap() => {
        'recruiterId': recruiterId,
        'candidateId': candidateId,
        'offerId': offerId,
        'action': action,
        'swipedAt': swipedAt,
        'recovered': recovered,
        'score': score,
      };

  factory SwipeHistoryEntry.fromMap(Map<String, dynamic> map, String docId) =>
      SwipeHistoryEntry(
        entryId: docId,
        recruiterId: map['recruiterId'] as String? ?? '',
        candidateId: map['candidateId'] as String? ?? '',
        offerId: map['offerId'] as String? ?? '',
        action: map['action'] as String? ?? 'pass',
        swipedAt: map['swipedAt'] as String? ?? '',
        recovered: map['recovered'] as bool? ?? false,
        score: (map['score'] as num?)?.toInt() ?? 0,
      );
}
