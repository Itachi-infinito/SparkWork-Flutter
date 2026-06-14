import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final availabilityServiceProvider =
    Provider<AvailabilityService>((ref) => AvailabilityService());

class AvailabilityService {
  final _db = FirebaseFirestore.instance;

  /// Active le mode "Disponible maintenant" pour 7 jours.
  Future<void> enableAvailableNow(String userId) async {
    final now = DateTime.now();
    final until = now.add(const Duration(days: 7));
    await _db.collection('candidate_profiles').doc(userId).update({
      'isAvailableNow': true,
      'availableNowUntil': until.toIso8601String(),
      'availableNowUpdatedAt': now.toIso8601String(),
    });
  }

  /// Désactive le mode "Disponible maintenant".
  Future<void> disableAvailableNow(String userId) async {
    await _db.collection('candidate_profiles').doc(userId).update({
      'isAvailableNow': false,
      'availableNowUntil': null,
    });
  }

  /// Renouvelle pour 7 jours supplémentaires.
  Future<void> renewAvailableNow(String userId) => enableAvailableNow(userId);

  /// Vérifie et expire automatiquement si dépassé.
  Future<bool> checkAndExpire(String userId) async {
    try {
      final doc = await _db.collection('candidate_profiles').doc(userId).get();
      if (!doc.exists) return false;
      final data = doc.data()!;
      final isActive = data['isAvailableNow'] as bool? ?? false;
      if (!isActive) return false;
      final until = data['availableNowUntil'] as String?;
      if (until == null) return false;
      final expiry = DateTime.tryParse(until);
      if (expiry == null || expiry.isBefore(DateTime.now())) {
        await disableAvailableNow(userId);
        return false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }
}
