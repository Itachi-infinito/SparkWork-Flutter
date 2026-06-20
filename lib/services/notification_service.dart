import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:go_router/go_router.dart';

/// Gestion des notifications push FCM.
/// - Sur mobile (Android/iOS) : token FCM enregistré dans Firestore.
/// - Sur web (Chrome) : FCM web nécessite un service worker supplémentaire
///   — le token n'est pas récupéré mais la structure est en place.
class NotificationService {
  static final _messaging = FirebaseMessaging.instance;

  /// Référence globale au router, assignée une fois par SparkWorkApp.build().
  /// Permet de naviguer depuis un tap de notification, hors de l'arbre de widgets.
  static GoRouter? router;

  static Future<void> initialize() async {
    try {
      // Demande de permission (iOS / web)
      await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      // Écoute des messages en foreground
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        // Les notifications en foreground sont gérées par le canal local
        // (affichage manuel si besoin à l'avenir)
      });

      // Tap sur une notification alors que l'app est en arrière-plan
      FirebaseMessaging.onMessageOpenedApp.listen(_handleTap);
    } catch (_) {
      // Silencieux — FCM peut échouer sur web sans service worker
    }
  }

  /// À appeler une fois [router] assigné (app était fermée et a été ouverte
  /// via un tap de notification). Séparé de [initialize] car celle-ci tourne
  /// avant que MaterialApp.router (et donc [router]) n'existe.
  static Future<void> checkInitialMessage() async {
    try {
      final initial = await _messaging.getInitialMessage();
      if (initial != null) await _handleTap(initial);
    } catch (_) {
      // Silencieux
    }
  }

  /// Route vers l'écran approprié selon le type de notification reçue.
  static Future<void> _handleTap(RemoteMessage message) async {
    final data = message.data;
    final type = data['type'];
    final r = router;
    if (r == null) return;

    switch (type) {
      case 'hire_confirmed':
        final matchId = data['matchId'];
        if (matchId != null) r.push('/messages/$matchId');
        break;

      case 'rating_reminder':
        final matchId = data['matchId'];
        if (matchId == null) return;
        r.push('/rate/$matchId', extra: {
          'targetUserId': data['targetUserId'] ?? '',
          'targetName': data['targetName'] ?? '',
          'isRecruiter': data['isRecruiter'] == 'true',
        });
        break;

      case 'verification_update':
        r.push('/candidate/verification');
        break;

      case 'competition_alert':
        final candidateId = data['candidateId'];
        if (candidateId != null) r.push('/recruiter/candidates/$candidateId');
        break;

      case 'boosted_offer':
        final offerId = data['offerId'];
        if (offerId != null) r.push('/candidate/offers/$offerId');
        break;

      case 'spark_invite':
        final offerId = data['offerId'];
        final inviteId = data['inviteId'];
        if (inviteId != null) {
          FirebaseFirestore.instance
              .collection('sparkInvites')
              .doc(inviteId)
              .update({'status': 'viewed'});
        }
        if (offerId != null) r.push('/candidate/offers/$offerId');
        break;

      case 'video_interview':
        final matchId = data['matchId'];
        if (matchId != null) r.push('/messages/$matchId');
        break;

      default:
        break;
    }
  }

  /// Récupère le token FCM et le stocke dans Firestore sous users/{uid}.
  static Future<void> registerToken(String userId) async {
    try {
      final token = await _messaging.getToken();
      if (token == null || token.isEmpty) return;
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .set({'fcmToken': token}, SetOptions(merge: true));

      // Mise à jour automatique du token si renouvelé
      _messaging.onTokenRefresh.listen((newToken) {
        FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .set({'fcmToken': newToken}, SetOptions(merge: true));
      });
    } catch (_) {
      // Silencieux — le token n'est pas critique au lancement
    }
  }

  /// Récupère le token courant (utile pour debug).
  static Future<String?> getToken() async {
    try {
      return await _messaging.getToken();
    } catch (_) {
      return null;
    }
  }

  static Future<void> showMatch({
    required String jobOfferTitle,
    required String companyName,
  }) async {
    // Notification locale à déclencher via flutter_local_notifications
    // quand le package sera ajouté (Sprint 3).
  }

  static Future<void> showMessage({
    required String senderName,
    required String messagePreview,
  }) async {}
}
