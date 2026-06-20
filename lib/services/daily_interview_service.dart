import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final dailyInterviewServiceProvider = Provider<DailyInterviewService>((ref) => DailyInterviewService());

/// ⚠️ Nécessite un compte Daily.co et la clé DAILY_API_KEY configurée côté
/// Cloud Functions (createDailyRoom) — non fonctionnel tant que ce compte
/// n'est pas créé, comme Veriff/Stripe/RevenueCat.
class DailyInterviewService {
  final _functions = FirebaseFunctions.instanceFor(region: 'europe-west1');

  /// Crée une salle vidéo réutilisable pour ce match. L'URL retournée est
  /// destinée à être collée dans Interview.meetingLink (flow existant de
  /// proposition d'entretien) plutôt que de créer un nouveau modèle.
  Future<String> createRoom({required String matchId}) async {
    final callable = _functions.httpsCallable('createDailyRoom');
    final result = await callable.call({'matchId': matchId});
    return (result.data as Map)['roomUrl'] as String;
  }
}
