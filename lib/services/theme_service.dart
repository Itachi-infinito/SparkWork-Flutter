import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'session_service.dart';

/// Le mode sombre est une préférence PAR COMPTE (clé dark_mode_<uid>).
/// Déconnecté (login, inscription) : toujours en mode clair.
final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>((ref) {
  final notifier = ThemeNotifier();
  // Recharge la préférence du nouvel utilisateur à chaque changement de session
  ref.listen<SessionState>(sessionProvider, (prev, next) {
    notifier.onUserChanged(next.userId);
  }, fireImmediately: true);
  return notifier;
});

class ThemeNotifier extends StateNotifier<ThemeMode> {
  String _uid = '';

  ThemeNotifier() : super(ThemeMode.light);

  Future<void> onUserChanged(String uid) async {
    _uid = uid;
    if (uid.isEmpty) {
      // Déconnecté : mode clair par défaut
      if (mounted) state = ThemeMode.light;
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool('dark_mode_$uid') ?? false;
    // L'utilisateur a pu changer entre-temps
    if (mounted && _uid == uid) {
      state = isDark ? ThemeMode.dark : ThemeMode.light;
    }
  }

  Future<void> toggle() async {
    if (_uid.isEmpty) return; // pas de préférence hors session
    final newDark = state != ThemeMode.dark;
    state = newDark ? ThemeMode.dark : ThemeMode.light;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_mode_$_uid', newDark);
  }

  bool get isDark => state == ThemeMode.dark;
}
