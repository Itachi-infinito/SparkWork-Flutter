import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/insight_report.dart';
import '../models/subscription.dart';
import 'subscription_service.dart';

final insightServiceProvider =
    Provider<InsightService>((ref) => InsightService(ref.read(subscriptionServiceProvider)));

class InsightService {
  final SubscriptionService _subSvc;
  InsightService(this._subSvc);

  final _db = FirebaseFirestore.instance;

  Future<void> _requirePro(String userId) async {
    final plan = await _subSvc.getCurrentPlan(userId);
    if (plan != SubscriptionPlan.pro) {
      throw Exception('Les Insights sont réservés au plan Pro.');
    }
  }

  /// Récupère les rapports disponibles pour un recruteur.
  Future<List<InsightReport>> getReports(String userId, {String? sector, String? region}) async {
    await _requirePro(userId);
    try {
      Query<Map<String, dynamic>> q = _db.collection('insight_reports');
      if (sector != null && sector.isNotEmpty) {
        q = q.where('sector', isEqualTo: sector);
      }
      if (region != null && region.isNotEmpty) {
        q = q.where('region', isEqualTo: region);
      }
      final snap = await q.orderBy('year', descending: true).orderBy('month', descending: true).limit(12).get();
      return snap.docs.map((d) => InsightReport.fromMap(d.data())).toList();
    } catch (_) {
      return [];
    }
  }

  Future<InsightReport?> getLatestReport(String userId, {String? sector, String? region}) async {
    final reports = await getReports(userId, sector: sector, region: region);
    return reports.isEmpty ? null : reports.first;
  }

  Future<InsightReport?> getReportByPeriod(String userId, int month, int year) async {
    await _requirePro(userId);
    try {
      final q = await _db
          .collection('insight_reports')
          .where('month', isEqualTo: month)
          .where('year', isEqualTo: year)
          .limit(1)
          .get();
      if (q.docs.isEmpty) return null;
      return InsightReport.fromMap(q.docs.first.data());
    } catch (_) {
      return null;
    }
  }

  /// [Cloud Function / cron] Génère un rapport mensuel — appel depuis back-end uniquement.
  /// Cette méthode est un placeholder côté client.
  Future<void> triggerReportGeneration(int month, int year) async {
    // TODO: déclencher via Cloud Function HTTP callable
  }
}
