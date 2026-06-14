class NotificationPreferences {
  final String userId;

  // Engagement
  final bool matchReminder;         // match sans message après 48h
  final bool newProfilesForRecruiter; // recruteur inactif 5 jours
  final bool noSwipeReminderCandidate; // candidat sans swipe 7 jours

  // Quota & abonnement
  final bool swipeRechargeAlert;    // quota swipes rechargé
  final bool trialExpiryReminder;  // essai Pro expire dans 3 jours

  // Offres
  final bool noMatchOfferSuggestion; // offre sans match 7 jours
  final bool flashOfferNearby;       // offre flash à proximité

  // Profil
  final bool availableNowExpiry;    // Disponible Maintenant expire 24h avant
  final bool verificationUpdate;    // statut vérification modifié
  final bool ratingReminder;        // rappel notation 3 jours après embauche

  // Plage horaire anti-spam (8h – 22h)
  final int quietHourStart; // heure locale de début silence (22)
  final int quietHourEnd;   // heure locale de fin silence (8)

  const NotificationPreferences({
    required this.userId,
    this.matchReminder = true,
    this.newProfilesForRecruiter = true,
    this.noSwipeReminderCandidate = true,
    this.swipeRechargeAlert = true,
    this.trialExpiryReminder = true,
    this.noMatchOfferSuggestion = true,
    this.flashOfferNearby = true,
    this.availableNowExpiry = true,
    this.verificationUpdate = true,
    this.ratingReminder = true,
    this.quietHourStart = 22,
    this.quietHourEnd = 8,
  });

  factory NotificationPreferences.defaults(String userId) =>
      NotificationPreferences(userId: userId);

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'matchReminder': matchReminder,
        'newProfilesForRecruiter': newProfilesForRecruiter,
        'noSwipeReminderCandidate': noSwipeReminderCandidate,
        'swipeRechargeAlert': swipeRechargeAlert,
        'trialExpiryReminder': trialExpiryReminder,
        'noMatchOfferSuggestion': noMatchOfferSuggestion,
        'flashOfferNearby': flashOfferNearby,
        'availableNowExpiry': availableNowExpiry,
        'verificationUpdate': verificationUpdate,
        'ratingReminder': ratingReminder,
        'quietHourStart': quietHourStart,
        'quietHourEnd': quietHourEnd,
      };

  factory NotificationPreferences.fromMap(Map<String, dynamic> map) =>
      NotificationPreferences(
        userId: map['userId'] as String? ?? '',
        matchReminder: map['matchReminder'] as bool? ?? true,
        newProfilesForRecruiter: map['newProfilesForRecruiter'] as bool? ?? true,
        noSwipeReminderCandidate: map['noSwipeReminderCandidate'] as bool? ?? true,
        swipeRechargeAlert: map['swipeRechargeAlert'] as bool? ?? true,
        trialExpiryReminder: map['trialExpiryReminder'] as bool? ?? true,
        noMatchOfferSuggestion: map['noMatchOfferSuggestion'] as bool? ?? true,
        flashOfferNearby: map['flashOfferNearby'] as bool? ?? true,
        availableNowExpiry: map['availableNowExpiry'] as bool? ?? true,
        verificationUpdate: map['verificationUpdate'] as bool? ?? true,
        ratingReminder: map['ratingReminder'] as bool? ?? true,
        quietHourStart: (map['quietHourStart'] as num?)?.toInt() ?? 22,
        quietHourEnd: (map['quietHourEnd'] as num?)?.toInt() ?? 8,
      );

  NotificationPreferences copyWith({
    bool? matchReminder,
    bool? newProfilesForRecruiter,
    bool? noSwipeReminderCandidate,
    bool? swipeRechargeAlert,
    bool? trialExpiryReminder,
    bool? noMatchOfferSuggestion,
    bool? flashOfferNearby,
    bool? availableNowExpiry,
    bool? verificationUpdate,
    bool? ratingReminder,
    int? quietHourStart,
    int? quietHourEnd,
  }) =>
      NotificationPreferences(
        userId: userId,
        matchReminder: matchReminder ?? this.matchReminder,
        newProfilesForRecruiter: newProfilesForRecruiter ?? this.newProfilesForRecruiter,
        noSwipeReminderCandidate: noSwipeReminderCandidate ?? this.noSwipeReminderCandidate,
        swipeRechargeAlert: swipeRechargeAlert ?? this.swipeRechargeAlert,
        trialExpiryReminder: trialExpiryReminder ?? this.trialExpiryReminder,
        noMatchOfferSuggestion: noMatchOfferSuggestion ?? this.noMatchOfferSuggestion,
        flashOfferNearby: flashOfferNearby ?? this.flashOfferNearby,
        availableNowExpiry: availableNowExpiry ?? this.availableNowExpiry,
        verificationUpdate: verificationUpdate ?? this.verificationUpdate,
        ratingReminder: ratingReminder ?? this.ratingReminder,
        quietHourStart: quietHourStart ?? this.quietHourStart,
        quietHourEnd: quietHourEnd ?? this.quietHourEnd,
      );
}
