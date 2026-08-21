import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/subscription.dart';

final subscriptionServiceProvider =
    Provider<SubscriptionService>((ref) => SubscriptionService());

/// Clés publiques RevenueCat — non sensibles, prévues pour être embarquées
/// dans le binaire client. Fournies au build via :
///   flutter run --dart-define-from-file=dart_defines.json
/// (ou --dart-define=REVENUECAT_IOS_KEY=appl_xxx individuellement).
const _revenueCatIosKeyDefine = String.fromEnvironment('REVENUECAT_IOS_KEY');
const _revenueCatAndroidKeyDefine = String.fromEnvironment('REVENUECAT_ANDROID_KEY');

/// Clé RevenueCat « Test Store » — publique et sans risque (conçue pour le
/// client). Elle sert de REPLI automatique en développement : si l'app est
/// lancée sans `--dart-define-from-file` (ex : `flutter run` nu, ou un IDE
/// mal configuré), le tunnel d'achat reste testable au lieu de tomber en
/// erreur « paiements non configurés ». En build release ce repli n'est
/// JAMAIS utilisé : il faut fournir une vraie clé goog_/appl_ via dart-define,
/// sinon les paiements restent désactivés (on évite d'expédier la Test Store
/// en production par accident).
const _revenueCatTestStoreKey = 'test_QFiJECNKLAzrRldipVMhDeoHgpZ';

/// Résout la clé effective pour la plateforme courante : dart-define en
/// priorité, puis repli Test Store hors release.
String _resolveApiKey(String define) {
  if (define.isNotEmpty) return define;
  return kReleaseMode ? '' : _revenueCatTestStoreKey;
}

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

  /// Clé API active pour la plateforme courante (vide = paiements indispo.).
  String get _apiKey => defaultTargetPlatform == TargetPlatform.iOS
      ? _resolveApiKey(_revenueCatIosKeyDefine)
      : _resolveApiKey(_revenueCatAndroidKeyDefine);

  bool get isRevenueCatConfigured => _apiKey.isNotEmpty;

  /// Vrai si l'app tourne sur la « Test Store » RevenueCat (dev) plutôt qu'un
  /// vrai store. Sert à adapter la résiliation : le Test Store n'a pas de page
  /// de gestion, on réinitialise donc côté serveur au lieu de rediriger.
  bool get isTestStore => _apiKey.startsWith('test_');

  /// Vrai une fois `configure()` réellement effectué — les appels d'achat ne
  /// peuvent réussir qu'à partir de ce moment.
  bool get isReady => _initialized;

  /// À appeler une fois au démarrage de l'app (après Firebase.initializeApp).
  Future<void> initialize() async {
    if (_initialized) return;
    final apiKey = _apiKey;
    if (apiKey.isEmpty) {
      if (kDebugMode) {
        debugPrint('[SparkWork] RevenueCat non configuré '
            '(aucune clé pour ${defaultTargetPlatform.name}) — paiements désactivés.');
      }
      return;
    }
    try {
      await Purchases.setLogLevel(kDebugMode ? LogLevel.debug : LogLevel.warn);
      await Purchases.configure(PurchasesConfiguration(apiKey));
      _initialized = true;
      if (kDebugMode) {
        debugPrint('[SparkWork] RevenueCat initialisé '
            '(${apiKey.startsWith('test_') ? 'Test Store' : 'production'}).');
      }
    } catch (e) {
      // Ne bloque jamais le démarrage : les paiements resteront simplement
      // indisponibles et l'UI le signalera proprement.
      if (kDebugMode) debugPrint('[SparkWork] Échec init RevenueCat : $e');
    }
  }

  /// Associe les achats RevenueCat au compte Firebase de l'utilisateur connecté.
  /// Essentiel : sans ça, le webhook RevenueCat reçoit l'ID anonyme du SDK et
  /// ne peut pas rattacher l'abonnement au bon document Firestore.
  Future<void> logIn(String userId) async {
    if (!await _ensureReady()) return;
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
    if (!await _ensureReady()) {
      return const PurchaseResult(PurchaseOutcome.notConfigured,
          message: 'Les paiements ne sont pas encore configurés sur cet appareil.');
    }
    try {
      final offerings = await Purchases.getOfferings();
      // On cherche le package par identifiant de produit dans TOUTES les
      // offerings (pas seulement `current`) : un mauvais réglage de l'offering
      // par défaut côté RevenueCat ne doit pas casser l'achat.
      final package = _findPackage(offerings, plan.productId);
      if (package == null) {
        return PurchaseResult(PurchaseOutcome.paymentError,
            message: 'Cette offre (${plan.displayName}) n\'est pas disponible '
                'pour le moment. Réessayez plus tard.');
      }
      await Purchases.purchasePackage(package);
      return const PurchaseResult(PurchaseOutcome.success);
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      if (code == PurchasesErrorCode.purchaseCancelledError) {
        return const PurchaseResult(PurchaseOutcome.userCancelled);
      }
      if (code == PurchasesErrorCode.networkError) {
        return const PurchaseResult(PurchaseOutcome.networkError,
            message: 'Erreur réseau. Vérifiez votre connexion et réessayez.');
      }
      if (code == PurchasesErrorCode.paymentPendingError) {
        return const PurchaseResult(PurchaseOutcome.success,
            message: 'Paiement en attente de validation par votre banque/store.');
      }
      if (code == PurchasesErrorCode.productAlreadyPurchasedError) {
        // Déjà abonné à ce produit — on restaure pour resynchroniser l'état.
        await restorePurchases();
        return const PurchaseResult(PurchaseOutcome.success);
      }
      return PurchaseResult(PurchaseOutcome.paymentError, message: e.message);
    } catch (e) {
      return PurchaseResult(PurchaseOutcome.paymentError, message: e.toString());
    }
  }

  /// Recherche un package par identifiant de produit dans toutes les offerings.
  Package? _findPackage(Offerings offerings, String productId) {
    for (final offering in [
      if (offerings.current != null) offerings.current!,
      ...offerings.all.values,
    ]) {
      for (final pkg in offering.availablePackages) {
        // Les identifiants store peuvent être suffixés (ex: "id:base-plan"),
        // on tolère donc un préfixe plutôt qu'une égalité stricte.
        final id = pkg.storeProduct.identifier;
        if (id == productId || id.startsWith('$productId:')) return pkg;
      }
    }
    return null;
  }

  /// Garantit que le SDK est configuré et prêt. Tente une init paresseuse si
  /// `initialize()` n'a pas encore réussi (ex: appelé avant la fin du démarrage
  /// ou après un échec réseau transitoire). Retourne false si aucune clé.
  Future<bool> _ensureReady() async {
    if (_initialized) return true;
    if (!isRevenueCatConfigured) return false;
    await initialize();
    return _initialized;
  }

  /// Réconcilie l'abonnement Firestore depuis RevenueCat (source de vérité),
  /// sans attendre le webhook. À appeler après un achat / restore / annulation
  /// et à l'ouverture des écrans d'abonnement pour un état toujours à jour.
  /// Retourne le plan résolu ('free' | 'starter' | 'pro'), ou null si échec.
  Future<String?> syncSubscriptionStatus() async {
    try {
      final functions = FirebaseFunctions.instanceFor(region: 'europe-west1');
      final res = await functions.httpsCallable('syncSubscriptionStatus').call();
      final data = res.data as Map?;
      return data?['plan'] as String?;
    } catch (e) {
      if (kDebugMode) debugPrint('[SparkWork] syncSubscriptionStatus échec : $e');
      return null;
    }
  }

  /// Résiliation en environnement de test (Test Store, sans page de gestion
  /// store) : réinitialise le client RevenueCat de test et repasse au plan
  /// Gratuit. En production, la résiliation passe par [openManageSubscriptions].
  /// Retourne true si la réinitialisation a réussi.
  Future<bool> resetTestSubscription() async {
    try {
      final functions = FirebaseFunctions.instanceFor(region: 'europe-west1');
      await functions.httpsCallable('resetTestSubscription').call();
      // Resynchronise le SDK local pour purger le cache d'entitlements.
      if (_initialized) {
        try { await Purchases.invalidateCustomerInfoCache(); } catch (_) {}
      }
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[SparkWork] resetTestSubscription échec : $e');
      return false;
    }
  }

  /// Restaure les achats existants (réinstallation, changement d'appareil).
  Future<bool> restorePurchases() async {
    if (!await _ensureReady()) return false;
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
  /// Retourne false si aucune URL de gestion n'est disponible (ex: aucun
  /// abonnement store actif), pour que l'UI puisse en informer l'utilisateur.
  Future<bool> openManageSubscriptions() async {
    if (!await _ensureReady()) return false;
    try {
      final info = await Purchases.getCustomerInfo();
      final url = info.managementURL;
      if (url == null) return false;
      return await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
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
  ///
  /// L'écriture se fait côté serveur (Callable transactionnel) : les Security
  /// Rules interdisent au client de modifier `swipe_quotas`, sinon n'importe
  /// qui pourrait remettre son compteur à zéro.
  Future<bool> consumeSwipe(String userId) async {
    try {
      final functions = FirebaseFunctions.instanceFor(region: 'europe-west1');
      final res = await functions.httpsCallable('consumeSwipe').call();
      final data = res.data as Map?;
      return data?['allowed'] as bool? ?? true;
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
  ///
  /// Écriture serveur uniquement (Callable transactionnel) : un crédit de
  /// boost a une valeur monétaire, le client ne doit jamais pouvoir se
  /// créditer ou marquer une offre boostée lui-même.
  Future<bool> useBoost(String userId, String offerId) async {
    try {
      final functions = FirebaseFunctions.instanceFor(region: 'europe-west1');
      final res = await functions.httpsCallable('useBoost').call({'offerId': offerId});
      final data = res.data as Map?;
      return data?['allowed'] as bool? ?? false;
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
        // Candidats qui ont liké une offre mais sans match. Les documents
        // candidate_job_likes n'ont pas de champ recruiterUserId (ni les
        // règles Firestore, qui vérifient via une jointure sur job_offers) —
        // il faut donc filtrer par jobOfferId parmi les offres du recruteur.
        final offerIds = offerDocs.docs.map((d) => d.id).toList();
        final matchedIdsFromLikes = <String>{};
        const chunkSize = 10; // limite Firestore whereIn
        for (var i = 0; i < offerIds.length; i += chunkSize) {
          final chunk = offerIds.skip(i).take(chunkSize).toList();
          if (chunk.isEmpty) continue;
          final candidateLikeDocs = await _db
              .collection('candidate_job_likes')
              .where('jobOfferId', whereIn: chunk)
              .get();
          matchedIdsFromLikes.addAll(candidateLikeDocs.docs
              .map((d) => d.data()['candidateUserId'] as String? ?? ''));
        }
        unmatchedLikerIds = matchedIdsFromLikes
            .where((id) => !matchedCandidateIds.contains(id))
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
