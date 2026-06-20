enum PipelineColumn { newMatch, contacted, interviewScheduled, offerMade, hired, rejected }

extension PipelineColumnExt on PipelineColumn {
  String get value {
    switch (this) {
      case PipelineColumn.newMatch: return 'new_match';
      case PipelineColumn.contacted: return 'contacted';
      case PipelineColumn.interviewScheduled: return 'interview_scheduled';
      case PipelineColumn.offerMade: return 'offer_made';
      case PipelineColumn.hired: return 'hired';
      case PipelineColumn.rejected: return 'rejected';
    }
  }

  String get label {
    switch (this) {
      case PipelineColumn.newMatch: return 'Nouveau match';
      case PipelineColumn.contacted: return 'Contacté';
      case PipelineColumn.interviewScheduled: return 'Entretien prévu';
      case PipelineColumn.offerMade: return 'Offre faite';
      case PipelineColumn.hired: return 'Embauché';
      case PipelineColumn.rejected: return 'Refusé';
    }
  }

  static PipelineColumn fromValue(String v) {
    return PipelineColumn.values.firstWhere((c) => c.value == v, orElse: () => PipelineColumn.newMatch);
  }
}

class PipelineCard {
  final String cardId;
  final String candidateId;
  final String matchId;
  final String offerId;
  final PipelineColumn column;
  final String movedAt;
  final String note;
  final String? reminderAt;

  const PipelineCard({
    required this.cardId,
    required this.candidateId,
    required this.matchId,
    required this.offerId,
    required this.column,
    required this.movedAt,
    this.note = '',
    this.reminderAt,
  });

  Map<String, dynamic> toMap() => {
        'candidateId': candidateId,
        'matchId': matchId,
        'offerId': offerId,
        'column': column.value,
        'movedAt': movedAt,
        'note': note,
        if (reminderAt != null) 'reminderAt': reminderAt,
      };

  factory PipelineCard.fromMap(Map<String, dynamic> map, String docId) => PipelineCard(
        cardId: docId,
        candidateId: map['candidateId'] as String? ?? '',
        matchId: map['matchId'] as String? ?? '',
        offerId: map['offerId'] as String? ?? '',
        column: PipelineColumnExt.fromValue(map['column'] as String? ?? 'new_match'),
        movedAt: map['movedAt'] as String? ?? '',
        note: map['note'] as String? ?? '',
        reminderAt: map['reminderAt'] as String?,
      );
}
