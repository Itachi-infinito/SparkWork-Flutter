import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Rappels locaux (pipeline kanban) — notification programmée sur
/// l'appareil, sans dépendre d'un serveur ni d'une connexion au moment du
/// déclenchement. Les IDs sont dérivés du hash de l'identifiant de carte
/// pour rester stables (permet d'annuler/remplacer un rappel existant).
class LocalNotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static const _channelId = 'pipeline_reminders';

  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    tz_data.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    await _plugin.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );

    const channel = AndroidNotificationChannel(
      _channelId,
      'Rappels pipeline',
      description: 'Rappels programmés sur vos candidats en cours de recrutement',
      importance: Importance.high,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  static Future<void> requestPermission() async {
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  static int _idFor(String cardId) => cardId.hashCode & 0x7FFFFFFF;

  static Future<void> scheduleReminder({
    required String cardId,
    required String title,
    required String body,
    required DateTime scheduledAt,
  }) async {
    if (scheduledAt.isBefore(DateTime.now())) return;
    await initialize();
    await _plugin.zonedSchedule(
      _idFor(cardId),
      title,
      body,
      tz.TZDateTime.from(scheduledAt, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId, 'Rappels pipeline',
          importance: Importance.high, priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      // "Inexact" évite la permission spéciale SCHEDULE_EXACT_ALARM (soumise
      // à restriction Play Store) — un rappel recruteur n'a pas besoin
      // d'être déclenché à la seconde près, une fenêtre de quelques
      // minutes est largement acceptable.
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  static Future<void> cancelReminder(String cardId) async {
    await initialize();
    await _plugin.cancel(_idFor(cardId));
  }
}
