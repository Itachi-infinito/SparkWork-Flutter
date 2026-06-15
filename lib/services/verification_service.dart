import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final verificationServiceProvider =
    Provider<VerificationService>((ref) => VerificationService());

class VerificationService {
  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  Future<DocumentReference?> _profileRef(String userId) async {
    final q = await _db
        .collection('candidate_profiles')
        .where('userId', isEqualTo: userId)
        .limit(1)
        .get();
    if (q.docs.isEmpty) return null;
    return q.docs.first.reference;
  }

  /// Soumet un document d'identité pour vérification.
  // TODO: integrate Onfido ou Stripe Identity pour la vérification automatique
  Future<String> submitDocument(String userId, File document, String side) async {
    final storageRef = _storage
        .ref('verification_docs/$userId/${side}_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await storageRef.putFile(document);
    final url = await storageRef.getDownloadURL();

    final ref = await _profileRef(userId);
    if (ref != null) {
      await ref.update({
        'verificationStatus': 'pending',
        'verificationMethod': 'document',
        'verificationRejectionReason': null,
      });
    }

    // Créer une entrée dans la collection verification_requests pour l'admin
    await _db.collection('verification_requests').add({
      'userId': userId,
      'documentUrl': url,
      'documentSide': side,
      'status': 'pending',
      'submittedAt': DateTime.now().toIso8601String(),
    });

    return url;
  }

  /// [Admin] Approuve une vérification.
  Future<void> approveVerification(String userId) async {
    final now = DateTime.now().toIso8601String();
    final ref = await _profileRef(userId);
    if (ref != null) {
      await ref.update({
        'verificationStatus': 'verified',
        'verificationDate': now,
        'verificationRejectionReason': null,
      });
    }
    // Mettre à jour la requête admin
    final requests = await _db
        .collection('verification_requests')
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .get();
    for (final doc in requests.docs) {
      await doc.reference.update({'status': 'approved', 'reviewedAt': now});
    }
  }

  /// [Admin] Rejette une vérification avec raison.
  Future<void> rejectVerification(String userId, String reason) async {
    final now = DateTime.now().toIso8601String();
    final ref = await _profileRef(userId);
    if (ref != null) {
      await ref.update({
        'verificationStatus': 'rejected',
        'verificationRejectionReason': reason,
        'verificationDate': now,
      });
    }
    final requests = await _db
        .collection('verification_requests')
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .get();
    for (final doc in requests.docs) {
      await doc.reference.update({
        'status': 'rejected',
        'rejectionReason': reason,
        'reviewedAt': now,
      });
    }
  }
}
