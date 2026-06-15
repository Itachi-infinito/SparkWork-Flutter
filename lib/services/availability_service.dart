import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final availabilityServiceProvider =
    Provider<AvailabilityService>((ref) => AvailabilityService());

class AvailabilityService {
  final _db = FirebaseFirestore.instance;

  Future<DocumentReference?> _profileRef(String userId) async {
    final q = await _db
        .collection('candidate_profiles')
        .where('userId', isEqualTo: userId)
        .limit(1)
        .get();
    if (q.docs.isEmpty) return null;
    return q.docs.first.reference;
  }

  /// Active le mode "Disponible maintenant" pour 7 jours.
  Future<void> enableAvailableNow(String userId) async {
    final ref = await _profileRef(userId);
    if (ref == null) return;
    final now = DateTime.now();
    final until = now.add(const Duration(days: 7));
    await ref.update({
      'isAvailableNow': true,
      'availableNowUntil': until.toIso8601String(),
      'availableNowUpdatedAt': now.toIso8601String(),
    });
  }

  /// Désactive le mode "Disponible maintenant".
  Future<void> disableAvailableNow(String userId) async {
    final ref = await _profileRef(userId);
    if (ref == null) return;
    await ref.update({
      'isAvailableNow': false,
      'availableNowUntil': null,
    });
  }

  /// Renouvelle pour 7 jours supplémentaires.
  Future<void> renewAvailableNow(String userId) => enableAvailableNow(userId);

  /// Vérifie et expire automatiquement si dépassé.
  Future<bool> checkAndExpire(String userId) async {
    try {
      final ref = await _profileRef(userId);
      if (ref == null) return false;
      final snap = await ref.get();
      if (!snap.exists) return false;
      final data = snap.data() as Map<String, dynamic>? ?? {};
      final isActive = data['isAvailableNow'] as bool? ?? false;
      if (!isActive) return false;
      final until = data['availableNowUntil'] as String?;
      if (until == null) return false;
      final expiry = DateTime.tryParse(until);
      if (expiry == null || expiry.isBefore(DateTime.now())) {
        await ref.update({'isAvailableNow': false, 'availableNowUntil': null});
        return false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }
}
