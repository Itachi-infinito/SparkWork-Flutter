import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/partner.dart';

final partnerServiceProvider =
    Provider<PartnerService>((ref) => PartnerService());

class PartnerService {
  final _db = FirebaseFirestore.instance;

  /// Valide un code partenaire à l'inscription. Retourne le Partner ou null.
  Future<Partner?> validateCode(String code) async {
    if (code.trim().isEmpty) return null;
    try {
      final q = await _db
          .collection('partners')
          .where('referralCode', isEqualTo: code.trim().toUpperCase())
          .limit(1)
          .get();
      if (q.docs.isEmpty) return null;
      return Partner.fromMap(q.docs.first.data());
    } catch (_) {
      return null;
    }
  }

  /// Enregistre un filleul au moment de l'inscription.
  Future<void> registerReferral({
    required String partnerId,
    required String referredUserId,
    required String referredUserType,
    required String partnerName,
    required String candidateId,
  }) async {
    final now = DateTime.now().toIso8601String();
    final ref = _db.collection('referrals').doc();
    await ref.set(Referral(
      referralId: ref.id,
      partnerId: partnerId,
      referredUserId: referredUserId,
      referredUserType: referredUserType,
      createdAt: now,
    ).toMap());

    // Incrémenter le compteur du partenaire
    await _db.collection('partners').doc(partnerId).update({
      'totalReferrals': FieldValue.increment(1),
    });

    // Ajouter le badge sur le profil candidat si applicable
    if (referredUserType == 'candidate') {
      await _db.collection('candidate_profiles').doc(candidateId).update({
        'partnerBadge': partnerName,
      });
    }
  }

  /// Marque un filleul comme converti (plan payant souscrit).
  Future<void> markConversion(String referredUserId, double commission) async {
    final q = await _db
        .collection('referrals')
        .where('referredUserId', isEqualTo: referredUserId)
        .where('convertedToPaid', isEqualTo: false)
        .limit(1)
        .get();
    if (q.docs.isEmpty) return;
    final now = DateTime.now().toIso8601String();
    await q.docs.first.reference.update({
      'convertedToPaid': true,
      'conversionDate': now,
      'commissionEarned': commission,
    });
  }

  Future<Partner?> getPartnerById(String partnerId) async {
    try {
      final doc = await _db.collection('partners').doc(partnerId).get();
      if (!doc.exists) return null;
      return Partner.fromMap(doc.data()!);
    } catch (_) {
      return null;
    }
  }

  Future<List<Referral>> getReferrals(String partnerId) async {
    try {
      final q = await _db
          .collection('referrals')
          .where('partnerId', isEqualTo: partnerId)
          .orderBy('createdAt', descending: true)
          .get();
      return q.docs.map((d) => Referral.fromMap(d.data())).toList();
    } catch (_) {
      return [];
    }
  }
}
