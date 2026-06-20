enum SecurityFlagSeverity { medium, high }

extension SecurityFlagSeverityExt on SecurityFlagSeverity {
  static SecurityFlagSeverity fromString(String? s) =>
      s == 'high' ? SecurityFlagSeverity.high : SecurityFlagSeverity.medium;

  String get value => this == SecurityFlagSeverity.high ? 'high' : 'medium';
}

/// Anomalie comportementale détectée par la Cloud Function
/// analyzeSessionAnomaly (ex: trop d'appareils distincts en 24h, OS
/// différents le même jour, pays inhabituel...).
class SecurityFlag {
  final String flagId;
  final String userId;
  final String flagType;
  final SecurityFlagSeverity severity;
  final DateTime detectedAt;
  final bool resolved;
  final DateTime? resolvedAt;

  const SecurityFlag({
    required this.flagId,
    required this.userId,
    required this.flagType,
    required this.severity,
    required this.detectedAt,
    this.resolved = false,
    this.resolvedAt,
  });

  factory SecurityFlag.fromMap(Map<String, dynamic> map, String docId) =>
      SecurityFlag(
        flagId: docId,
        userId: map['userId'] as String? ?? '',
        flagType: map['flagType'] as String? ?? '',
        severity: SecurityFlagSeverityExt.fromString(map['severity'] as String?),
        detectedAt: _parseDate(map['detectedAt']) ?? DateTime.now(),
        resolved: map['resolved'] as bool? ?? false,
        resolvedAt: _parseDate(map['resolvedAt']),
      );

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is String) return DateTime.tryParse(v);
    try {
      return (v as dynamic).toDate() as DateTime?;
    } catch (_) {
      return null;
    }
  }
}
