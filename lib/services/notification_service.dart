import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

/// Gestion des notifications push FCM.
/// - Sur mobile (Android/iOS) : token FCM enregistré dans Firestore.
/// - Sur web (Chrome) : FCM web nécessite un service worker supplémentaire
///   — le token n'est pas récupéré mais la structure est en place.
class NotificationService {
  static final _messaging = FirebaseMessaging.instance;

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
    } catch (_) {
      // Silencieux — FCM peut échouer sur web sans service worker
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
