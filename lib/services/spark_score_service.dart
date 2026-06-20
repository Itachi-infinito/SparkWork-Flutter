import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/spark_score.dart';

final sparkScoreServiceProvider = Provider<SparkScoreService>((ref) => SparkScoreService());

/// SparkScore IA détaillé — le calcul pondéré complet se fait côté serveur
/// (Cloud Function calculateSparkScore, mise en cache 24h) pour rester la
/// source de vérité et permettre d'affiner les facteurs sans redéployer l'app.
class SparkScoreService {
  final _functions = FirebaseFunctions.instanceFor(region: 'europe-west1');

  Future<SparkScoreResult> getDetailedScore({
    required String offerId,
    required String candidateId,
  }) async {
    final callable = _functions.httpsCallable('calculateSparkScore');
    final result = await callable.call({'offerId': offerId, 'candidateId': candidateId});
    return SparkScoreResult.fromMap(result.data as Map);
  }
}
