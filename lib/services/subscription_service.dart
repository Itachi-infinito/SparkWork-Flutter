import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/subscription.dart';

final subscriptionServiceProvider =
    Provider<SubscriptionService>((ref) => SubscriptionService());

/// Clés publiques RevenueCat — non sensibles, prévues pour être embarquées
/// dans le binaire client. Fournies au build via :
///   flutter run --dart-define=REVENUECAT_IOS_KEY=appl_xxx
///   flutter run --dart-define=REVENUECAT_ANDROID_KEY=goog_xxx
const _revenueCatIosKey = String.fromEnvironment('REVENUECAT_IOS_KEY');
const _revenueCatAndroidKey = String.fromEnvironment('REVENUECAT_ANDROID_KEY');

enum PurchaseOutcome { success, userCancelled, paymentError, networkError, notConfigured }

class PurchaseResult {
  final PurchaseOutcome outcome;
  final String? message;
  const PurchaseResult(this.outcome, {this.message});

  bool get isSuccess => outcome == PurchaseOutcome.success;
}

class SubscriptionService {
  final _db = FirebaseFirestore.instance;

  // Le SDK Purchases est un singleton global côté plateforme — l'état
  // "initialisé" doit donc être partagé entre toutes les instances de
  // SubscriptionService (créées librement partout dans l'app), pas
  // réinitialisé à false à chaque `SubscriptionService()`.
  static bool _initialized = false;

  CollectionReference<Map<String, dynamic>> get _subs =>
      _db.collection('recruiter_subscriptions');
  CollectionReference<Map<String, dynamic>> get _quotas =>
      _db.collection('swipe_quotas');
  CollectionReference<Map<String, dynamic>> get _boosts =>
      _db.collection('boost_credits');

  // ─── REVENUECAT — INITIALISATION & CYCLE DE VIE ────────────────────────────

  bool get isRevenueCatConfigured =>
      defaultTargetPlatform == TargetPlatform.iOS
          ? _revenueCatIosKey.isNotEmpty
          : _revenueCatAndroidKey.isNotEmpty;

  /// À appeler une fois au démarrage de l'app (après Firebase.initializeApp).
  Future<void> initialize() async {
    if (_initialized || !isRevenueCatConfigured) return;
    final apiKey = defaultTargetPlatform == TargetPlatform.iOS
        ? _revenueCatIosKey
        : _revenueCatAndroidKey;
    await Purchases.setLogLevel(LogLevel.warn);
    await Purchases.configure(PurchasesConfiguration(apiKey));
    _initialized = true;
  }

  /// Associe les achats RevenueCat au compte Firebase de l'utilisateur connecté.
  Future<void> logIn(String userId) async {
    if (!_initialized) return;
    try {
      await Purchases.logIn(userId);
    } catch (_) {}
  }

  Future<void> logOut() async {
    if (!_initialized) return;
    try {
      await Purchases.logOut();
    } catch (_) {}
  }

  // ─── ABONNEMENT ────────────────────────────────────────────────────────────

  /// Retourne l'abonnement actuel. En cas d'erreur : fallback plan Gratuit.
  ///
  /// Mode restreint (anti-partage de compte, Sprint 5) : si
  /// `users/{userId}.isRestricted` est vrai, le plan effectif retombe
  /// systématiquement à Gratuit ici — donc dans TOUTE l'app, sans avoir à
  /// dupliquer la vérification dans chaque écran/feature gating.
  Future<RecruiterSubscription> getSubscription(String userId) async {
    try {
      final userDoc = await _db.collection('users').doc(userId).get();
      if (userDoc.data()?['isRestricted'] as bool? ?? false) {
        return RecruiterSubscription.free(userId);
      }

      final doc = await _subs.doc(userId).get();
      if (!doc.exists) return RecruiterSubscription.free(userId);
      final sub = RecruiterSubscription.fromMap({
        ...doc.data()!,
        'userId': userId,
      });
      // Expiration automatique du trial (autorisée par les Security Rules :
      // transition trial -> expired uniquement, jamais vers un plan payant).
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

  /// Lance l'achat réel via RevenueCat. Le document Firestore
  /// `recruiter_subscriptions/{userId}` n'est PAS mis à jour ici : c'est le
  /// webhook RevenueCat (Cloud Function, Admin SDK) qui fait foi côté serveur.
  /// Cette méthode ne fait que déclencher le paiement et interpréter le résultat
  /// pour l'UX (toast, navigation) — jamais pour accorder le plan elle-même.
  Future<PurchaseResult> purchasePlan(SubscriptionPlan plan) async {
    if (!isRevenueCatConfigured) {
      return const PurchaseResult(PurchaseOutcome.notConfigured,
          message: 'Les paiements ne sont pas encore configurés sur cet appareil.');
    }
    try {
      final offerings = await Purchases.getOfferings();
      final package = offerings.current?.availablePackages.firstWhere(
        (p) => p.storeProduct.identifier == plan.productId,
        orElse: () => throw Exception('Produit ${plan.productId} introuvable dans RevenueCat.'),
      );
      if (package == null) {
        return const PurchaseResult(PurchaseOutcome.paymentError,
            message: 'Cette offre n\'est pas disponible pour le moment.');
      }
      await Purchases.purchasePackage(package);
      return const PurchaseResult(PurchaseOutcome.success);
    } on PurchasesErrorCode catch (e) {
      if (e == PurchasesErrorCode.purchaseCancelledError) {
        return const PurchaseResult(PurchaseOutcome.userCancelled);
      }
      if (e == PurchasesErrorCode.networkError) {
        return const PurchaseResult(PurchaseOutcome.networkError,
            message: 'Erreur réseau. Vérifiez votre connexion et réessayez.');
      }
      return PurchaseResult(PurchaseOutcome.paymentError, message: e.toString());
    } catch (e) {
      return PurchaseResult(PurchaseOutcome.paymentError, message: e.toString());
    }
  }

  /// Restaure les achats existants (réinstallation, changement d'appareil).
  Future<bool> restorePurchases() async {
    if (!isRevenueCatConfigured) return false;
    try {
      final info = await Purchases.restorePurchases();
      return info.entitlements.active.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Ouvre la page de gestion d'abonnement du store (App Store / Play
  /// Store) via l'URL fournie par RevenueCat. La résiliation réelle se fait
  /// toujours là — jamais via une simple écriture Firestore côté client.
  Future<void> openManageSubscriptions() async {
    if (!isRevenueCatConfigured) return;
    try {
      final info = await Purchases.getCustomerInfo();
      final url = info.managementURL;
      if (url == null) return;
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  Future<void> _expireTrial(String userId) async {
    try {
      await _subs.doc(userId).update({'status': 'expired'});
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
