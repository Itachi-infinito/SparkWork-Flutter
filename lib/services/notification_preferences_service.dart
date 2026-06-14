import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/notification_preferences.dart';

final notificationPreferencesServiceProvider =
    Provider<NotificationPreferencesService>((ref) => NotificationPreferencesService());

class NotificationPreferencesService {
  final _db = FirebaseFirestore.instance;

  Future<NotificationPreferences> getPreferences(String userId) async {
    try {
      final doc = await _db.collection('notification_preferences').doc(userId).get();
      if (!doc.exists) return NotificationPreferences.defaults(userId);
      return NotificationPreferences.fromMap({...doc.data()!, 'userId': userId});
    } catch (_) {
      return NotificationPreferences.defaults(userId);
    }
  }

  Future<void> savePreferences(NotificationPreferences prefs) async {
    await _db
        .collection('notification_preferences')
        .doc(prefs.userId)
        .set(prefs.toMap());
  }

  Future<void> updatePreference(String userId, String key, bool value) async {
    await _db
        .collection('notification_preferences')
        .doc(userId)
        .set({key: value, 'userId': userId}, SetOptions(merge: true));
  }

  /// Vérifie si une notification peut être envoyée maintenant (plage horaire).
  bool isWithinAllowedHours(NotificationPreferences prefs) {
    final now = DateTime.now().hour;
    final start = prefs.quietHourStart;
    final end = prefs.quietHourEnd;
    if (start > end) {
      return now >= end && now < start;
    }
    return now < start && now >= end;
  }
}
