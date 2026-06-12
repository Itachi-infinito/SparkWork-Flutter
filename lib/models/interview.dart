/// Proposition d'entretien envoyée par le recruteur après un match.
/// Le recruteur propose jusqu'à plusieurs créneaux ; le candidat en
/// accepte un (ou refuse), ce qui fige `acceptedSlot`.
class Interview {
  final String interviewId;
  final String matchId;
  final String recruiterUserId;
  final String candidateUserId;

  /// Créneaux proposés, en ISO 8601 (heure locale du recruteur).
  final List<String> slots;

  /// Créneau retenu par le candidat (ISO 8601), vide tant que pending.
  final String acceptedSlot;

  /// pending | accepted | declined | cancelled
  final String status;

  /// Message libre du recruteur (lieu, visio, consignes...).
  final String message;
  final String createdAt;

  const Interview({
    required this.interviewId,
    required this.matchId,
    required this.recruiterUserId,
    required this.candidateUserId,
    this.slots = const [],
    this.acceptedSlot = '',
    this.status = 'pending',
    this.message = '',
    this.createdAt = '',
  });

  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';
  bool get isDeclined => status == 'declined';
  bool get isCancelled => status == 'cancelled';

  DateTime? get acceptedDate =>
      acceptedSlot.isEmpty ? null : DateTime.tryParse(acceptedSlot);

  List<DateTime> get slotDates => slots
      .map(DateTime.tryParse)
      .whereType<DateTime>()
      .toList()
    ..sort();

  Map<String, dynamic> toMap() => {
        'matchId': matchId,
        'recruiterUserId': recruiterUserId,
        'candidateUserId': candidateUserId,
        'slots': slots,
        'acceptedSlot': acceptedSlot,
        'status': status,
        'message': message,
        'createdAt': createdAt,
      };

  factory Interview.fromMap(Map<String, dynamic> map) => Interview(
        interviewId: map['interviewId'] as String? ?? '',
        matchId: map['matchId'] as String? ?? '',
        recruiterUserId: map['recruiterUserId'] as String? ?? '',
        candidateUserId: map['candidateUserId'] as String? ?? '',
        slots: (map['slots'] as List?)?.cast<String>() ?? const [],
        acceptedSlot: map['acceptedSlot'] as String? ?? '',
        status: map['status'] as String? ?? 'pending',
        message: map['message'] as String? ?? '',
        createdAt: map['createdAt'] as String? ?? '',
      );
}
