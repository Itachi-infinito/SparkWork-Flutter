import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final sparkBoostServiceProvider = Provider<SparkBoostService>((ref) => SparkBoostService());

class SparkBoostResult {
  final int targetCount;
  final int radiusKm;
  const SparkBoostResult({required this.targetCount, required this.radiusKm});
}

class SparkBoostService {
  final _functions = FirebaseFunctions.instanceFor(region: 'europe-west1');

  Future<SparkBoostResult> activateSmartBoost(String offerId) async {
    final callable = _functions.httpsCallable('activateSmartBoost');
    final result = await callable.call({'offerId': offerId});
    final data = result.data as Map;
    return SparkBoostResult(
      targetCount: data['targetCount'] as int,
      radiusKm: data['radiusKm'] as int,
    );
  }
}
