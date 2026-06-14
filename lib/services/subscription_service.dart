import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/subscription.dart';

final subscriptionServiceProvider =
    Provider<SubscriptionService>((ref) => SubscriptionService());

class SubscriptionService {
  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _subs =>
      _db.collection('recruiter_subscriptions');
  CollectionReference<Map<String, dynamic>> get _quotas =>
      _db.collection('swipe_quotas');
  CollectionReference<Map<String, dynamic>> get _boosts =>
      _db.collection('boost_credits');

  // ─── ABONNEMENT ────────────────────────────────────────────────────────────

  /// Retourne l'abonnement actuel. En cas d'erreur : fallback plan Gratuit.
  Future<RecruiterSubscription> getSubscription(String userId) async {
    try {
      final doc = await _subs.doc(userId).get();
      if (!doc.exists) return RecruiterSubscription.free(userId);
      final sub = RecruiterSubscription.fromMap({
        ...doc.data()!,
        'userId': userId,
      });
      // Expiration automatique du trial
      if (sub.status == 'trial' && !sub.isTrialActive) {
        await _expireTrial(userId);
        return RecruiterSubscription.free(userId);
      }
      return sub;
    } catch (_) {
      return RecruiterSubscription.free(userId);
    }
  }

  Future<SubscriptionPlan> getCurrentPlan(String userId) async {
    final sub = await getSubscription(userId);
    return sub.effectivePlan;
  }

  Future<bool> isTrialActive(String userId) async {
    final sub = await getSubscription(userId);
    return sub.isTrialActive;
  }

  /// Active 14 jours Pro offerts au premier signup recruteur.
  /// Sans effet si un abonnement existe déjà.
  Future<void> startTrial(String userId) async {
    final doc = await _subs.doc(userId).get();
    if (doc.exists) return;
    final now = DateTime.now();
    await _subs.doc(userId).set({
      'userId': userId,
      'plan': 'free',
      'status': 'trial',
      'trialStartDate': now.toIso8601String(),
      'trialEndDate': now.add(const Duration(days: 14)).toIso8601String(),
    });
  }

  /// Bascule vers un plan payant (mode dev — brancher RevenueCat ici).
  // TODO: connect RevenueCat — remplacer ce set() par la vérification du receipt
  Future<void> upgradePlan(String userId, SubscriptionPlan plan) async {
    final now = DateTime.now();
    await _subs.doc(userId).set({
      'userId': userId,
      'plan': plan.name,
      'status': 'active',
      'startDate': now.toIso8601String(),
      'endDate': now.add(const Duration(days: 30)).toIso8601String(),
    }, SetOptions(merge: true));

    // Mettre à jour le badge vérifié sur le profil recruteur
    final profileDocs = await _db
        .collection('recruiter_profiles')
        .where('userId', isEqualTo: userId)
        .get();
    final isVerified = plan == SubscriptionPlan.pro;
    for (final d in profileDocs.docs) {
      await d.reference.update({'isVerifiedEmployer': isVerified});
    }
  }

  Future<void> _expireTrial(String userId) async {
    try {
      await _subs.doc(userId).update({'status': 'expired'});
      // Rétrograder le badge vérifié
      final profileDocs = await _db
          .collection('recruiter_profiles')
          .where('userId', isEqualTo: userId)
          .get();
      for (final d in profileDocs.docs) {
        await d.reference.update({'isVerifiedEmployer': false});
      }
    } catch (_) {}
  }

  // ─── QUOTA SWIPES ──────────────────────────────────────────────────────────

  /// Swipes restants aujourd'hui. 9999 = illimité (plan Pro).
  Future<int> getRemainingSwipes(String userId) async {
    try {
      final plan = await getCurrentPlan(userId);
      if (plan.unlimitedSwipes) return 9999;
      final used = await _getUsedSwipesToday(userId);
      return (plan.dailySwipes - used).clamp(0, plan.dailySwipes);
    } catch (_) {
      return 5;
    }
  }

  /// Décrémente le quota. Retourne false si quota épuisé → bloquer l'action.
  Future<bool> consumeSwipe(String userId) async {
    try {
      final plan = await getCurrentPlan(userId);
      if (plan.unlimitedSwipes) return true;

      final quotaDoc = _quotas.doc(userId);
      final doc = await quotaDoc.get();
      final now = DateTime.now();
      int used;
      DateTime resetAt;

      if (!doc.exists) {
        used = 0;
        resetAt = now;
      } else {
        final data = doc.data()!;
        resetAt = DateTime.tryParse(data['resetAt'] as String? ?? '') ?? now;
        used = data['used'] as int? ?? 0;
        if (now.difference(resetAt).inHours >= 24) {
          used = 0;
          resetAt = now;
        }
      }

      if (used >= plan.dailySwipes) return false;

      await quotaDoc.set({
        'userId': userId,
        'used': used + 1,
        'resetAt': resetAt.toIso8601String(),
        'max': plan.dailySwipes,
      });
      return true;
    } catch (_) {
      return true; // erreur → autoriser (ne jamais bloquer)
    }
  }

  /// Heure du prochain reset de quota (= resetAt + 24h).
  Future<DateTime?> getQuotaResetTime(String userId) async {
    try {
      final doc = await _quotas.doc(userId).get();
      if (!doc.exists) return null;
      final resetAt =
          DateTime.tryParse(doc.data()!['resetAt'] as String? ?? '');
      return resetAt?.add(const Duration(hours: 24));
    } catch (_) {
      return null;
    }
  }

  Future<int> _getUsedSwipesToday(String userId) async {
    final doc = await _quotas.doc(userId).get();
    if (!doc.exists) return 0;
    final data = doc.data()!;
    final resetAt = DateTime.tryParse(data['resetAt'] as String? ?? '');
    if (resetAt == null) return 0;
    if (DateTime.now().difference(resetAt).inHours >= 24) return 0;
    return data['used'] as int? ?? 0;
  }

  // ─── OFFRES ────────────────────────────────────────────────────────────────

  Future<int> getActiveOffersCount(String userId) async {
    final q = await _db
        .collection('job_offers')
        .where('recruiterUserId', isEqualTo: userId)
        .where('isActive', isEqualTo: true)
        .get();
    return q.size;
  }

  Future<bool> canCreateOffer(String userId) async {
    try {
      final plan = await getCurrentPlan(userId);
      final count = await getActiveOffersCount(userId);
      return count < plan.maxActiveOffers;
    } catch (_) {
      return true;
    }
  }

  // ─── BOOSTS ────────────────────────────────────────────────────────────────

  Future<int> getRemainingBoosts(String userId) async {
    try {
      final plan = await getCurrentPlan(userId);
      if (plan.monthlyBoosts == 0) return 0;

      final doc = await _boosts.doc(userId).get();
      if (!doc.exists) return plan.monthlyBoosts;

      final data = doc.data()!;
      final resetAt = DateTime.tryParse(data['resetAt'] as String? ?? '');
      final now = DateTime.now();

      if (resetAt == null ||
          now.month != resetAt.month ||
          now.year != resetAt.year) {
        return plan.monthlyBoosts;
      }

      return (data['available'] as int? ?? plan.monthlyBoosts)
          .clamp(0, plan.monthlyBoosts);
    } catch (_) {
      return 0;
    }
  }

  /// Consomme un boost. Retourne false si aucun boost disponible.
  Future<bool> useBoost(String userId, String offerId) async {
    try {
      final remaining = await getRemainingBoosts(userId);
      if (remaining <= 0) return false;

      final now = DateTime.now();
      await _boosts.doc(userId).set({
        'userId': userId,
        'available': remaining - 1,
        'resetAt': now.toIso8601String(),
        'lastBoostedOfferId': offerId,
      }, SetOptions(merge: true));

      await _db.collection('job_offers').doc(offerId).update({
        'isBoosted': true,
        'boostedAt': now.toIso8601String(),
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  // ─── STATS ─────────────────────────────────────────────────────────────────

  Future<RecruiterStats> getStats(String userId) async {
    try {
      final plan = await getCurrentPlan(userId);

      final offerDocs = await _db
          .collection('job_offers')
          .where('recruiterUserId', isEqualTo: userId)
          .get();
      final matchDocs = await _db
          .collection('matches')
          .where('recruiterUserId', isEqualTo: userId)
          .get();
      final likeDocs = await _db
          .collection('recruiter_candidate_likes')
          .where('recruiterUserId', isEqualTo: userId)
          .get();

      final totalOffers = offerDocs.size;
      final totalMatches = matchDocs.size;
      final totalLikes = likeDocs.size;

      final matchedCandidateIds = matchDocs.docs
          .map((d) => d.data()['candidateUserId'] as String? ?? '')
          .toSet();

      List<String> unmatchedLikerIds = [];
      if (plan.hasAdvancedStats) {
        // Candidats qui ont liké une offre mais sans match
        final candidateLikeDocs = await _db
            .collection('candidate_job_likes')
            .where('recruiterUserId', isEqualTo: userId)
            .get();
        unmatchedLikerIds = candidateLikeDocs.docs
            .map((d) => d.data()['candidateUserId'] as String? ?? '')
            .where((id) => !matchedCandidateIds.contains(id))
            .toSet()
            .toList();
      }

      return RecruiterStats(
        totalOffers: totalOffers,
        totalMatches: totalMatches,
        totalLikes: totalLikes,
        unmatchedLikerIds: unmatchedLikerIds,
        plan: plan,
      );
    } catch (_) {
      return RecruiterStats(
        totalOffers: 0,
        totalMatches: 0,
        totalLikes: 0,
        unmatchedLikerIds: [],
        plan: SubscriptionPlan.free,
      );
    }
  }
}

class RecruiterStats {
  final int totalOffers;
  final int totalMatches;
  final int totalLikes;
  final List<String> unmatchedLikerIds;
  final SubscriptionPlan plan;

  RecruiterStats({
    required this.totalOffers,
    required this.totalMatches,
    required this.totalLikes,
    required this.unmatchedLikerIds,
    required this.plan,
  });

  double get matchRate =>
      totalLikes > 0 ? (totalMatches / totalLikes * 100) : 0;
}
