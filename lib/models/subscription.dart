/// Plans d'abonnement recruteur.
/// Les candidats sont toujours gratuits, sans restriction.
enum SubscriptionPlan { free, starter, pro }

extension SubscriptionPlanExt on SubscriptionPlan {
  String get displayName {
    switch (this) {
      case SubscriptionPlan.free: return 'Gratuit';
      case SubscriptionPlan.starter: return 'Starter';
      case SubscriptionPlan.pro: return 'Pro';
    }
  }

  double get monthlyPrice {
    switch (this) {
      case SubscriptionPlan.free: return 0;
      case SubscriptionPlan.starter: return 49;
      case SubscriptionPlan.pro: return 129;
    }
  }

  /// Swipes par 24h. -1 = illimité.
  int get dailySwipes {
    switch (this) {
      case SubscriptionPlan.free: return 5;
      case SubscriptionPlan.starter: return 50;
      case SubscriptionPlan.pro: return -1;
    }
  }

  bool get unlimitedSwipes => dailySwipes == -1;

  int get maxActiveOffers {
    switch (this) {
      case SubscriptionPlan.free: return 1;
      case SubscriptionPlan.starter: return 3;
      case SubscriptionPlan.pro: return 10;
    }
  }

  int get monthlyBoosts {
    switch (this) {
      case SubscriptionPlan.free: return 0;
      case SubscriptionPlan.starter: return 1;
      case SubscriptionPlan.pro: return 3;
    }
  }

  /// Conversations simultanées maximum. -1 = illimité.
  int get maxConversations {
    switch (this) {
      case SubscriptionPlan.free: return 3;
      case SubscriptionPlan.starter: return -1;
      case SubscriptionPlan.pro: return -1;
    }
  }

  bool get hasBasicStats => this != SubscriptionPlan.free;
  bool get hasAdvancedStats => this == SubscriptionPlan.pro;
  bool get hasVerifiedBadge => this == SubscriptionPlan.pro;

  // TODO: connect RevenueCat — brancher ces IDs aux produits App Store / Play Store
  String get productId {
    switch (this) {
      case SubscriptionPlan.free: return '';
      case SubscriptionPlan.starter: return 'sparkwork_starter_monthly';
      case SubscriptionPlan.pro: return 'sparkwork_pro_monthly';
    }
  }
}

class RecruiterSubscription {
  final String userId;
  final SubscriptionPlan plan;

  /// active | trial | expired | cancelled
  final String status;

  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime? trialStartDate;
  final DateTime? trialEndDate;

  const RecruiterSubscription({
    required this.userId,
    required this.plan,
    required this.status,
    this.startDate,
    this.endDate,
    this.trialStartDate,
    this.trialEndDate,
  });

  bool get isTrialActive {
    if (status != 'trial') return false;
    if (trialEndDate == null) return false;
    return DateTime.now().isBefore(trialEndDate!);
  }

  int get trialDaysRemaining {
    if (!isTrialActive) return 0;
    return trialEndDate!.difference(DateTime.now()).inDays;
  }

  /// Plan effectif : Pro pendant l'essai, sinon le plan souscrit (ou free).
  SubscriptionPlan get effectivePlan {
    if (isTrialActive) return SubscriptionPlan.pro;
    if (status == 'active') return plan;
    return SubscriptionPlan.free;
  }

  bool get isActive => status == 'active' || isTrialActive;

  factory RecruiterSubscription.free(String userId) => RecruiterSubscription(
        userId: userId,
        plan: SubscriptionPlan.free,
        status: 'active',
      );

  factory RecruiterSubscription.fromMap(Map<String, dynamic> map) =>
      RecruiterSubscription(
        userId: map['userId'] as String? ?? '',
        plan: _planFromString(map['plan'] as String? ?? 'free'),
        status: map['status'] as String? ?? 'active',
        startDate: _parseDate(map['startDate']),
        endDate: _parseDate(map['endDate']),
        trialStartDate: _parseDate(map['trialStartDate']),
        trialEndDate: _parseDate(map['trialEndDate']),
      );

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'plan': plan.name,
        'status': status,
        if (startDate != null) 'startDate': startDate!.toIso8601String(),
        if (endDate != null) 'endDate': endDate!.toIso8601String(),
        if (trialStartDate != null) 'trialStartDate': trialStartDate!.toIso8601String(),
        if (trialEndDate != null) 'trialEndDate': trialEndDate!.toIso8601String(),
      };

  static SubscriptionPlan _planFromString(String s) =>
      SubscriptionPlan.values.firstWhere(
        (p) => p.name == s,
        orElse: () => SubscriptionPlan.free,
      );

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is String) return DateTime.tryParse(v);
    return null;
  }
}
