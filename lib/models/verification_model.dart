enum VeriffStatus {
  unverified,
  pending,
  verified,
  rejected,
  resubmissionRequested;

  /// Maps from Firestore string value
  static VeriffStatus fromString(String? s) {
    switch (s) {
      case 'pending':
        return VeriffStatus.pending;
      case 'verified':
        return VeriffStatus.verified;
      case 'rejected':
        return VeriffStatus.rejected;
      case 'resubmission_requested':
        return VeriffStatus.resubmissionRequested;
      default:
        return VeriffStatus.unverified;
    }
  }

  String toFirestoreString() {
    switch (this) {
      case VeriffStatus.pending:
        return 'pending';
      case VeriffStatus.verified:
        return 'verified';
      case VeriffStatus.rejected:
        return 'rejected';
      case VeriffStatus.resubmissionRequested:
        return 'resubmission_requested';
      case VeriffStatus.unverified:
        return 'unverified';
    }
  }
}

enum DocumentType {
  nationalId,
  passport,
  drivingLicense;

  String toVeriffString() {
    switch (this) {
      case DocumentType.nationalId:
        return 'NATIONAL_IDENTITY_CARD';
      case DocumentType.passport:
        return 'PASSPORT';
      case DocumentType.drivingLicense:
        return 'DRIVERS_LICENSE';
    }
  }

  String get label {
    switch (this) {
      case DocumentType.nationalId:
        return 'Carte nationale d\'identité';
      case DocumentType.passport:
        return 'Passeport';
      case DocumentType.drivingLicense:
        return 'Permis de conduire';
    }
  }
}

class VerificationModel {
  final String verificationId; // Firestore doc ID (= userId)
  final String userId;
  final String? sessionId;     // Veriff session ID (stored server-side)
  final VeriffStatus status;
  final String? declineReason;
  final DateTime? submittedAt;
  final DateTime? decidedAt;
  final int attemptCount;      // max 3
  final DocumentType? documentType;
  final String provider;       // 'veriff' (défaut) ou 'stripe'

  const VerificationModel({
    required this.verificationId,
    required this.userId,
    this.sessionId,
    this.status = VeriffStatus.unverified,
    this.declineReason,
    this.submittedAt,
    this.decidedAt,
    this.attemptCount = 0,
    this.documentType,
    this.provider = 'veriff',
  });

  bool get canRetry => attemptCount < 3;
  bool get isVerified => status == VeriffStatus.verified;
  bool get isPending => status == VeriffStatus.pending;
  bool get needsResubmission => status == VeriffStatus.resubmissionRequested;

  factory VerificationModel.fromMap(Map<String, dynamic> map, String docId) {
    return VerificationModel(
      verificationId: docId,
      userId: map['userId'] as String? ?? docId,
      sessionId: map['sessionId'] as String?,
      status: VeriffStatus.fromString(map['status'] as String?),
      declineReason: map['declineReason'] as String?,
      submittedAt: _parseTs(map['submittedAt']),
      decidedAt: _parseTs(map['decidedAt']),
      attemptCount: (map['attemptCount'] as num?)?.toInt() ?? 0,
      documentType: _parseDocType(map['documentType'] as String?),
      provider: map['provider'] as String? ?? 'veriff',
    );
  }

  static DateTime? _parseTs(dynamic v) {
    if (v == null) return null;
    if (v is String) return DateTime.tryParse(v);
    // Firestore Timestamp
    try {
      return (v as dynamic).toDate() as DateTime?;
    } catch (_) {
      return null;
    }
  }

  static DocumentType? _parseDocType(String? s) {
    switch (s) {
      case 'NATIONAL_IDENTITY_CARD':
        return DocumentType.nationalId;
      case 'PASSPORT':
        return DocumentType.passport;
      case 'DRIVERS_LICENSE':
        return DocumentType.drivingLicense;
      default:
        return null;
    }
  }
}
