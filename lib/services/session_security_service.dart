import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/active_session.dart';
import '../models/security_flag.dart';
import 'device_info_service.dart';

final sessionSecurityServiceProvider =
    Provider<SessionSecurityService>((ref) => SessionSecurityService(ref));

/// Passe à `true` quand la session courante est invalidée (connexion
/// détectée sur un autre appareil). Un widget racine l'observe pour
/// afficher un dialogue de déconnexion forcée non-dismissable.
final forceLogoutTriggerProvider = StateProvider<bool>((ref) => false);

class SessionSecurityService {
  static const _sessionIdKey = 'sparkwork_session_id';

  final Ref _ref;
  final _db = FirebaseFirestore.instance;
  final _storage = const FlutterSecureStorage();
  final _functions = FirebaseFunctions.instanceFor(region: 'europe-west1');

  SessionSecurityService(this._ref);

  CollectionReference<Map<String, dynamic>> get _sessions =>
      _db.collection('active_sessions');

  /// Réutilise la session active déjà enregistrée pour cet appareil (ex :
  /// l'app redémarre sur un appareil déjà connecté) ou en crée une nouvelle
  /// via la Cloud Function createActiveSession.
  ///
  /// La création passe par un Callable (pas une écriture Firestore directe)
  /// pour que le serveur puisse capturer l'IP — nécessaire à la détection
  /// d'anomalies — sans jamais l'exposer au client. Cette même fonction
  /// invalide aussi toute session active sur un AUTRE appareil et notifie
  /// son propriétaire (session unique par appareil).
  Future<String> getOrCreateSession(String userId) async {
    final deviceSvc = _ref.read(deviceInfoServiceProvider);
    final deviceId = await deviceSvc.getDeviceId();

    // Réutilise la session locale si elle est toujours valide et sur ce même appareil.
    final existingId = await getCurrentSessionId();
    if (existingId != null) {
      final doc = await _sessions.doc(existingId).get();
      final data = doc.data();
      if (doc.exists &&
          data?['isActive'] == true &&
          data?['deviceId'] == deviceId &&
          data?['userId'] == userId) {
        await heartbeat();
        return existingId;
      }
    }

    final callable = _functions.httpsCallable('createActiveSession');
    final result = await callable.call({
      'deviceId': deviceId,
      'deviceModel': await deviceSvc.getDeviceModel(),
      'deviceOS': await deviceSvc.getDeviceOS(),
      'appVersion': await deviceSvc.getAppVersion(),
    });
    final sessionId = (result.data as Map)['sessionId'] as String;
    await _storage.write(key: _sessionIdKey, value: sessionId);
    return sessionId;
  }

  Future<String?> getCurrentSessionId() => _storage.read(key: _sessionIdKey);

  Future<void> clearCurrentSessionId() => _storage.delete(key: _sessionIdKey);

  /// Met à jour le timestamp de dernière activité (appelé toutes les 5 min).
  Future<void> heartbeat() async {
    final sessionId = await getCurrentSessionId();
    if (sessionId == null) return;
    try {
      await _sessions.doc(sessionId).update({
        'lastActiveAt': DateTime.now().toIso8601String(),
      });
    } catch (_) {}
  }

  /// Stream émettant `false` dès que la session courante est invalidée
  /// (connexion sur un nouvel appareil, déconnexion forcée par sécurité...).
  /// Émet `true` tant que tout va bien ou que la session n'existe pas encore.
  Stream<bool> watchCurrentSessionActive() async* {
    final sessionId = await getCurrentSessionId();
    if (sessionId == null) {
      yield true;
      return;
    }
    yield* _sessions.doc(sessionId).snapshots().map((snap) {
      if (!snap.exists) return true;
      final data = snap.data();
      final isActive = data?['isActive'] as bool? ?? false;
      if (isActive) return true;
      // Une déconnexion volontaire (logoutReason == 'manual', cf.
      // markCurrentSessionLoggedOut) ne doit jamais déclencher le popup
      // "vous avez été déconnecté à distance" — celui-ci est réservé aux
      // vraies déconnexions forcées (nouvel appareil, action sécurité).
      if (data?['logoutReason'] == 'manual') return true;
      return false;
    });
  }

  /// true si au moins 2 appareils distincts se sont connectés aujourd'hui —
  /// signal "doux" pour proposer la Gestion d'équipe (upsell trigger 1),
  /// indépendant des seuils plus stricts de analyzeSessionAnomaly côté serveur.
  Future<bool> hasMultipleDevicesToday(String userId) async {
    final startOfDay = DateTime.now().toIso8601String().substring(0, 10);
    try {
      final q = await _sessions
          .where('userId', isEqualTo: userId)
          .where('loginAt', isGreaterThanOrEqualTo: startOfDay)
          .get();
      final deviceIds = q.docs.map((d) => d.data()['deviceId']).toSet();
      return deviceIds.length >= 2;
    } catch (_) {
      return false;
    }
  }

  /// Sessions des 30 derniers jours pour l'écran "Gérer mes sessions actives".
  Future<List<ActiveSession>> getRecentSessions(String userId) async {
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    try {
      final q = await _sessions
          .where('userId', isEqualTo: userId)
          .where('loginAt', isGreaterThan: cutoff.toIso8601String())
          .orderBy('loginAt', descending: true)
          .get();
      return q.docs.map((d) => ActiveSession.fromMap(d.data(), d.id)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> terminateSession(String sessionId) async {
    await _sessions.doc(sessionId).update({
      'isActive': false,
      'logoutReason': 'manual',
    });
  }

  /// Déconnecte tous les appareils sauf celui en cours.
  Future<void> terminateAllOtherSessions(String userId) async {
    final currentSessionId = await getCurrentSessionId();
    final q = await _sessions
        .where('userId', isEqualTo: userId)
        .where('isActive', isEqualTo: true)
        .get();
    final batch = _db.batch();
    for (final doc in q.docs) {
      if (doc.id == currentSessionId) continue;
      batch.update(doc.reference, {
        'isActive': false,
        'logoutReason': 'security',
      });
    }
    await batch.commit();
  }

  Future<void> markCurrentSessionLoggedOut() async {
    final sessionId = await getCurrentSessionId();
    if (sessionId == null) return;
    try {
      await _sessions.doc(sessionId).update({
        'isActive': false,
        'logoutReason': 'manual',
      });
    } catch (_) {}
    await clearCurrentSessionId();
  }

  // ─── ANOMALIES & DÉBLOCAGE ──────────────────────────────────────────────────

  /// Confirme "Oui c'est moi" sur une alerte. Retourne la sévérité résolue
  /// (le client décide d'afficher l'upsell équipe si severity == 'medium').
  Future<String> resolveFlag(String flagId) async {
    final callable = _functions.httpsCallable('resolveSecurityFlag');
    final result = await callable.call({'flagId': flagId});
    return (result.data as Map)['severity'] as String;
  }

  Stream<List<SecurityFlag>> watchUnresolvedFlags(String userId) {
    return _db
        .collection('security_flags')
        .where('userId', isEqualTo: userId)
        .where('resolved', isEqualTo: false)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => SecurityFlag.fromMap(d.data(), d.id)).toList());
  }

  /// Stream du statut "mode restreint" du compte (users/{uid}.isRestricted).
  Stream<bool> watchRestrictedStatus(String userId) {
    return _db.collection('users').doc(userId).snapshots().map(
        (snap) => snap.data()?['isRestricted'] as bool? ?? false);
  }

  /// Demande un code de déblocage à 6 chiffres.
  /// TODO: aucun fournisseur d'emailing n'est branché — le code retourné en
  /// dev doit être retiré dès qu'un envoi d'email réel est en place côté CF.
  Future<String?> requestUnlockOtp() async {
    final callable = _functions.httpsCallable('requestRestrictedUnlockOtp');
    final result = await callable.call();
    return (result.data as Map)['devOnlyCode'] as String?;
  }

  Future<bool> verifyUnlockOtp(String code) async {
    final callable = _functions.httpsCallable('verifyRestrictedUnlockOtp');
    final result = await callable.call({'code': code});
    return (result.data as Map)['unlocked'] as bool? ?? false;
  }

  /// Droit à l'effacement RGPD — supprime les logs de sécurité (90 jours)
  /// de l'utilisateur courant.
  Future<int> deleteMySecurityLogs() async {
    final callable = _functions.httpsCallable('deleteMySecurityLogs');
    final result = await callable.call();
    return (result.data as Map)['deletedCount'] as int? ?? 0;
  }
}
