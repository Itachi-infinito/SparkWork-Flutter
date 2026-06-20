import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/recruiter_theme.dart';
import 'session_service.dart';

/// Ambiance visuelle du recruteur connecté. `null` = aucune ambiance
/// explicitement choisie → l'app reste en apparence "classique" inchangée
/// (AppColors + le toggle clair/sombre habituel). Ce n'est qu'une fois que
/// le recruteur sélectionne explicitement un thème dans Réglages que cet
/// état devient non-null. Toujours `null` pour les candidats, qui n'ont
/// accès qu'au clair/sombre (cf. ThemeNotifier), jamais aux ambiances colorées.
final recruiterThemeProvider =
    StateNotifierProvider<RecruiterThemeNotifier, RecruiterTheme?>((ref) {
  final notifier = RecruiterThemeNotifier();
  ref.listen<SessionState>(sessionProvider, (prev, next) {
    notifier.onUserChanged(next.isRecruiter ? next.userId : '');
  }, fireImmediately: true);
  return notifier;
});

class RecruiterThemeNotifier extends StateNotifier<RecruiterTheme?> {
  String _uid = '';
  final _db = FirebaseFirestore.instance;

  RecruiterThemeNotifier() : super(null);

  DocumentReference<Map<String, dynamic>> _doc(String uid) => _db
      .collection('recruiter_profiles')
      .doc(uid)
      .collection('settings')
      .doc('theme');

  Future<void> onUserChanged(String uid) async {
    _uid = uid;
    if (uid.isEmpty) {
      if (mounted) state = null;
      return;
    }

    // Chargement instantané depuis le cache local, puis vérification Firestore.
    final prefs = await SharedPreferences.getInstance();
    final cachedId = prefs.getString('recruiter_theme_id_$uid');
    if (cachedId != null && _uid == uid) {
      if (cachedId == 'custom') {
        final customMap = prefs.getString('recruiter_theme_custom_$uid');
        if (customMap != null && mounted) {
          // Stocké comme une simple chaîne "primary,secondary,bg,card,nav,gradStart,gradEnd,textP,textS" (ARGB ints)
          try {
            final parts = customMap.split(',').map(int.parse).toList();
            if (mounted && _uid == uid) {
              state = RecruiterTheme(
                themeId: 'custom',
                themeName: 'Mon thème',
                primaryColor: _c(parts[0]),
                secondaryColor: _c(parts[1]),
                backgroundColor: _c(parts[2]),
                cardColor: _c(parts[3]),
                navigationBarColor: _c(parts[4]),
                gradientStart: _c(parts[5]),
                gradientEnd: _c(parts[6]),
                textPrimaryColor: _c(parts[7]),
                textSecondaryColor: _c(parts[8]),
              );
            }
          } catch (_) {}
        }
      } else if (mounted) {
        state = RecruiterTheme.byId(cachedId);
      }
    }

    try {
      final doc = await _doc(uid).get();
      if (!mounted || _uid != uid) return;
      if (!doc.exists) {
        state = null;
        return;
      }
      final theme = RecruiterTheme.fromMap(doc.data()!);
      state = theme;
      await _cache(uid, theme);
    } catch (_) {}
  }

  Future<void> setTheme(RecruiterTheme theme) async {
    if (_uid.isEmpty) return;
    state = theme;
    await _doc(_uid).set(theme.toMap());
    await _cache(_uid, theme);
  }

  /// Revient à l'apparence classique (aucune ambiance) — supprime la
  /// préférence sauvegardée plutôt que de la remplacer par "Spark".
  Future<void> resetToDefault() async {
    if (_uid.isEmpty) return;
    state = null;
    await _doc(_uid).delete();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('recruiter_theme_id_$_uid');
    await prefs.remove('recruiter_theme_custom_$_uid');
  }

  Future<void> _cache(String uid, RecruiterTheme theme) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('recruiter_theme_id_$uid', theme.themeId);
    if (theme.themeId == 'custom') {
      final values = [
        theme.primaryColor, theme.secondaryColor, theme.backgroundColor,
        theme.cardColor, theme.navigationBarColor, theme.gradientStart,
        theme.gradientEnd, theme.textPrimaryColor, theme.textSecondaryColor,
      ].map((c) => c.toARGB32()).join(',');
      await prefs.setString('recruiter_theme_custom_$uid', values);
    }
  }

  Color _c(int argb) => Color(argb);
}
