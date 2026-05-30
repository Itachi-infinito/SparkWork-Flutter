import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );
    _initialized = true;
  }

  static Future<void> showMatch({
    required String jobTitle,
    required String company,
  }) async {
    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'Nouveau match !',
      'Vous avez matché avec $company — "$jobTitle"',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'matches', 'Matches',
          channelDescription: 'Notifications de nouveaux matches',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  static Future<void> showMessage({required String senderName}) async {
    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'Nouveau message',
      '$senderName vous a envoyé un message',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'messages', 'Messages',
          channelDescription: 'Notifications de messages',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }
}