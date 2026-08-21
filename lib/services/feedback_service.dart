import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final feedbackServiceProvider =
    Provider<FeedbackService>((ref) => FeedbackService());

/// Retour sensoriel centralisé — haptique + son.
///
/// Un seul point d'entrée pour toute l'app : garantit des sensations
/// cohérentes (même intensité pour la même action partout) et un unique
/// endroit où respecter la préférence « son de match » de l'utilisateur.
class FeedbackService {
  static const _soundPrefKey = 'match_sound_enabled';

  // Player unique, à latence faible : le son de match doit partir dans la
  // même frame que l'animation, pas 300 ms après.
  static final AudioPlayer _player = AudioPlayer()
    ..setPlayerMode(PlayerMode.lowLatency);

  // ─── HAPTIQUE ──────────────────────────────────────────────────────────────

  /// Petit tap — swipe like classique.
  void like() => HapticFeedback.lightImpact();

  /// Tap appuyé — super like.
  void superLike() => HapticFeedback.mediumImpact();

  /// Impact fort — match, moment clé.
  void match() => HapticFeedback.heavyImpact();

  /// Sélection légère (toggles, choix dans une liste).
  void select() => HapticFeedback.selectionClick();

  // ─── SON DE MATCH ──────────────────────────────────────────────────────────

  Future<bool> isMatchSoundEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_soundPrefKey) ?? true;
  }

  Future<void> setMatchSoundEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_soundPrefKey, enabled);
  }

  /// Joue le chime de match (si non désactivé). Ne lève jamais : un échec
  /// audio ne doit jamais casser l'écran de match.
  Future<void> playMatchSound() async {
    try {
      if (!await isMatchSoundEnabled()) return;
      await _player.stop(); // relance propre si un match suit un autre
      await _player.play(AssetSource('sounds/match.wav'), volume: 0.85);
    } catch (_) {}
  }
}
