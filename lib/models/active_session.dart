/// Représente une session active sur un appareil. Une seule session
/// `isActive: true` est autorisée par utilisateur — la connexion sur un
/// nouvel appareil invalide automatiquement les précédentes (voir Cloud
/// Function onSessionCreated).
///
/// Note RGPD : l'adresse IP n'est jamais incluse dans ce modèle — elle est
/// loguée uniquement côté serveur (Cloud Functions) à des fins de détection
/// de fraude, conformément à l'intérêt légitime (RGPD art. 6(1)(f)), et
/// supprimée automatiquement après 90 jours.
class ActiveSession {
  final String sessionId;
  final String userId;
  final String deviceId;
  final String deviceModel;
  final String deviceOS;
  final String appVersion;
  final DateTime loginAt;
  final DateTime lastActiveAt;
  final bool isActive;
  final String? logoutReason; // new_session / manual / security / expired

  const ActiveSession({
    required this.sessionId,
    required this.userId,
    required this.deviceId,
    required this.deviceModel,
    required this.deviceOS,
    required this.appVersion,
    required this.loginAt,
    required this.lastActiveAt,
    required this.isActive,
    this.logoutReason,
  });

  bool get isCurrentDevice => false; // calculé côté UI en comparant deviceId

  Map<String, dynamic> toMap() => {
        'sessionId': sessionId,
        'userId': userId,
        'deviceId': deviceId,
        'deviceModel': deviceModel,
        'deviceOS': deviceOS,
        'appVersion': appVersion,
        'loginAt': loginAt.toIso8601String(),
        'lastActiveAt': lastActiveAt.toIso8601String(),
        'isActive': isActive,
        if (logoutReason != null) 'logoutReason': logoutReason,
      };

  factory ActiveSession.fromMap(Map<String, dynamic> map, String docId) =>
      ActiveSession(
        sessionId: docId,
        userId: map['userId'] as String? ?? '',
        deviceId: map['deviceId'] as String? ?? '',
        deviceModel: map['deviceModel'] as String? ?? 'Appareil inconnu',
        deviceOS: map['deviceOS'] as String? ?? '',
        appVersion: map['appVersion'] as String? ?? '',
        loginAt: _parseDate(map['loginAt']) ?? DateTime.now(),
        lastActiveAt: _parseDate(map['lastActiveAt']) ?? DateTime.now(),
        isActive: map['isActive'] as bool? ?? false,
        logoutReason: map['logoutReason'] as String?,
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
