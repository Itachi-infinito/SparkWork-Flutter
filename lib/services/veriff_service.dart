import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// TODO: switch to Stripe Identity if Stripe is already integrated
import 'package:veriff_flutter/veriff_flutter.dart';
import '../models/verification_model.dart';

final veriffServiceProvider = Provider<VeriffService>((ref) => VeriffService());

class VeriffService {
  final _db = FirebaseFirestore.instance;
  final _functions = FirebaseFunctions.instanceFor(region: 'europe-west1');
  // Single Veriff SDK instance reused across calls
  final _veriff = Veriff();

  // ── Session creation ────────────────────────────────────────────────────────

  /// Calls the backend Cloud Function to create a Veriff session.
  /// Returns the [sessionUrl] used to launch the native Veriff SDK.
  /// The secret API key never touches the Flutter client.
  Future<VeriffSessionResult> createSession({
    required String userId,
    required DocumentType documentType,
    String firstName = '',
    String lastName = '',
  }) async {
    final callable = _functions.httpsCallable('createVeriffSession');
    final result = await callable.call({
      'documentType': documentType.toVeriffString(),
      'firstName': firstName,
      'lastName': lastName,
    });
    final data = result.data as Map<String, dynamic>;
    return VeriffSessionResult(
      sessionUrl: data['sessionUrl'] as String,
      sessionId: data['sessionId'] as String,
    );
  }

  // ── SDK launch ──────────────────────────────────────────────────────────────

  /// Launches the native Veriff SDK with the given [sessionUrl].
  /// Returns [VeriffLaunchStatus] — the final pass/fail decision arrives later
  /// via the backend webhook and is reflected in Firestore.
  Future<VeriffLaunchStatus> launchVerification(String sessionUrl) async {
    try {
      // veriff_flutter 2.x API:
      //   - Configuration(sessionUrl) — takes the full session URL from the backend
      //   - Veriff().start(config)    — launches the native SDK
      //   - Result.status             — Status.done / .canceled / .error
      final config = Configuration(sessionUrl, languageLocale: 'fr');
      final result = await _veriff.start(config);

      switch (result.status) {
        case Status.done:
          return VeriffLaunchStatus.done;
        case Status.canceled:
          return VeriffLaunchStatus.canceled;
        case Status.error:
          return VeriffLaunchStatus.error;
      }
    } catch (_) {
      return VeriffLaunchStatus.error;
    }
  }

  // ── Status ──────────────────────────────────────────────────────────────────

  /// Reads the verification record for [userId] from Firestore.
  Future<VerificationModel?> getVerificationStatus(String userId) async {
    final doc = await _db.collection('verifications').doc(userId).get();
    if (!doc.exists) return null;
    return VerificationModel.fromMap(doc.data()!, doc.id);
  }

  /// Stream of real-time status changes (for live UI updates after SDK closes).
  Stream<VerificationModel?> statusStream(String userId) {
    return _db
        .collection('verifications')
        .doc(userId)
        .snapshots()
        .map((snap) =>
            snap.exists ? VerificationModel.fromMap(snap.data()!, snap.id) : null);
  }

  Future<bool> canRetry(String userId) async {
    final v = await getVerificationStatus(userId);
    return v == null || v.canRetry;
  }

  // ── RGPD: data deletion ─────────────────────────────────────────────────────

  /// Deletes the local verification record.
  /// Veriff deletes its own data automatically after 7 days per RGPD/their policy.
  Future<void> deleteVerificationData(String userId) async {
    await _db.collection('verifications').doc(userId).delete();

    final profileSnap = await _db
        .collection('candidate_profiles')
        .where('userId', isEqualTo: userId)
        .limit(1)
        .get();
    if (profileSnap.docs.isNotEmpty) {
      await profileSnap.docs.first.reference.update({
        'verificationStatus': 'unverified',
        'verificationDate': null,
        'verificationRejectionReason': null,
      });
    }
  }
}

// ── Value objects ────────────────────────────────────────────────────────────

enum VeriffLaunchStatus { done, canceled, error }

class VeriffSessionResult {
  final String sessionUrl;
  final String sessionId;
  const VeriffSessionResult({required this.sessionUrl, required this.sessionId});
}
