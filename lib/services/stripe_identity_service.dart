import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final stripeIdentityServiceProvider = Provider<StripeIdentityService>((ref) => StripeIdentityService());

class StripeIdentitySession {
  final String sessionUrl;
  final String sessionId;
  const StripeIdentitySession({required this.sessionUrl, required this.sessionId});
}

/// ⚠️ Nécessite que createStripeIdentitySession soit configurée avec une
/// clé STRIPE_SECRET_KEY côté Cloud Functions (compte Stripe Identity à
/// créer) — exactement comme Veriff/RevenueCat le nécessitent déjà.
class StripeIdentityService {
  final _functions = FirebaseFunctions.instanceFor(region: 'europe-west1');

  Future<StripeIdentitySession> createSession() async {
    final callable = _functions.httpsCallable('createStripeIdentitySession');
    final result = await callable.call();
    final data = result.data as Map;
    return StripeIdentitySession(
      sessionUrl: data['sessionUrl'] as String,
      sessionId: data['sessionId'] as String,
    );
  }
}
