# ROADMAP SparkWork — vers la sortie stores

Format : `ID | Titre | Fichiers | Description | Estimation | Critères d'acceptation | Dépendances`
Estimations : **S** = ½ journée · **M** = 1-2 jours · **L** = 3-5 jours

---

## Sprint 0 — Stabilisation (tous les 🔴) — ~1,5 semaine

| ID | Titre | Fichiers | Description | Est. | Critères d'acceptation | Dép. |
|----|-------|----------|-------------|------|------------------------|------|
| S0-1 | Régénérer la config Firebase native | `lib/firebase_options.dart`, `ios/Runner/GoogleService-Info.plist` | `flutterfire configure --project=sparkwork-f41ec` pour générer les vraies clés Android/iOS | S | L'app démarre sur un émulateur Android et sur l'iPhone 13 Pro | — |
| S0-2 | Ne plus avaler l'échec d'init Firebase | `lib/main.dart` | Retirer le `catch (_) {}` ; écran d'erreur bloquant si init KO | S | Un échec d'init affiche un message clair, pas une app zombie | — |
| S0-3 | Unifier les constantes profil | `edit_candidate_profile_page.dart` | Remplacer les 3 listes hardcodées par `AppSkills.*` + script de migration des profils existants (Intermédiaire→Confirmé, Hybride→Télétravail partiel, Télétravail→Télétravail total) | M | Un profil édité matche les filtres et le score ; aucun profil en base avec une valeur hors `AppSkills` | — |
| S0-4 | Chat temps réel | `conversation_detail_page.dart` | Remplacer `getMessages()` par `watchMessages()` (stream existant) ; `markMessagesSeen` sur snapshot ; `getMatchById()` dans `MatchRepository` pour le titre | M | Deux comptes ouverts : un message envoyé apparaît chez l'autre sans action | — |
| S0-5 | Réparer le SuperLike (ou le retirer) | `candidate_swipe_page.dart`, `recruiter_swipe_page.dart`, repositories likes | Gérer `AxisDirection.up` ; persister `isSuperLike: true` ; bouton ⚡ ≠ bouton ❤️ ; côté candidat ajouter `isSuperLike` à `candidate_job_likes` | M | Swipe up = like enregistré avec flag ; badge "Vous intéressez ce recruteur" fonctionne | — |
| S0-6 | Durcir storage.rules | `storage.rules` | Limiter l'écriture à `{uid}.jpg`, 5 Mo max, `image/*` | S | Un user A ne peut pas écraser la photo de B (test manuel via console) | — |
| S0-7 | Durcir firestore.rules | `firestore.rules` | Likes lisibles uniquement par les parties concernées ; update messages restreint à `seenAt` via `diff()` ; (option) création de match via Cloud Function | M | Tests dans le simulateur de règles Firebase | — |
| S0-8 | Gestion d'erreurs uniforme | toutes les pages listées en M1 | try/catch + état `_error` + bouton Réessayer (généraliser le pattern de `candidate_swipe_page`) | M | Mode avion : chaque page affiche une erreur actionnable, pas un spinner infini | — |
| S0-9 | Timestamps serveur | `message_repository.dart`, `match_repository.dart` | `FieldValue.serverTimestamp()` + adaptation modèles/tri | M | Tri des conversations correct quel que soit le device | S0-4 |
| S0-10 | Persister les rejets | repositories likes, 2 pages swipe | Enregistrer les passes ; exclure au chargement | M | Une offre rejetée ne réapparaît pas après redémarrage | — |
| S0-11 | Course à l'inscription | `auth_service.dart`, `session_service.dart` | Session prête seulement après écriture du doc user (reload ou retry) | S | 20 inscriptions d'affilée sans redirect /welcome intempestif | — |
| S0-12 | Supprimer le code mort | 7 fichiers (m1-m5) | app.colors.dart, theme_notifier.dart, user.dart, database_service.dart, matches_page.dart, role_selection_page.dart + test par défaut | S | `flutter analyze` sans référence cassée | — |

---

## Sprint 1 — Store-ready (légal + technique minimum) — ~2 semaines

| ID | Titre | Fichiers | Description | Est. | Critères d'acceptation | Dép. |
|----|-------|----------|-------------|------|------------------------|------|
| S1-1 | Mot de passe oublié | `login_page.dart`, `auth_service.dart` | `sendPasswordResetEmail` + lien sur le login | S | Email reçu, reset fonctionnel | — |
| S1-2 | Vérification d'email | `auth_service.dart`, bannière home | `sendEmailVerification` à l'inscription + bannière "vérifiez votre email" | M | Compte non vérifié = bannière visible | — |
| S1-3 | Suppression de compte in-app | `settings_page.dart`, `auth_service.dart`, Cloud Function | Ré-authentification → purge Firestore (profil, likes, matches, messages) + Storage + Auth. Function `onUserDeleted` recommandée | L | Apple 5.1.1(v) OK ; plus aucune donnée en base après suppression | S0-7 |
| S1-4 | Changement de mot de passe (UI) | `settings_page.dart` | Brancher `changePassword()` existant (dialog avec ancien/nouveau) | S | Changement effectif + erreurs gérées | — |
| S1-5 | Modération UGC : signalement + blocage | nouveau `report_repository.dart`, menus sur profils/conversations, `users.blocked[]` | Signaler un profil/message (collection `reports`), bloquer un utilisateur (masque profil + conversation) | L | Apple 1.2 OK : signaler et bloquer accessibles en ≤2 taps | — |
| S1-6 | CGU + politique de confidentialité | `register_*.dart`, pages web ou écrans statiques | Checkbox obligatoire à l'inscription + liens dans Settings | M | RGPD/stores : consentement tracé (`acceptedTermsAt`) | — |
| S1-7 | Crashlytics + Analytics | `pubspec.yaml`, `main.dart` | `firebase_crashlytics` + `firebase_analytics`, zones d'erreur globales (`runZonedGuarded`) | M | Un crash de test remonte dans la console | S0-2 |
| S1-8 | App Check | console + `main.dart` | Play Integrity / DeviceCheck / reCAPTCHA (web) | S | Requêtes sans attestation refusées | S0-1 |
| S1-9 | Icône, splash natif, nom | `flutter_launcher_icons`, `flutter_native_splash` | Identité visuelle violette ⚡ | M | Icône + splash sur device réel | — |
| S1-10 | Tests critiques | `test/` | Unit : `CompatibilityService`, `parseSkills`, `ProfileCompletion` ; widget : login, swipe like | M | `flutter test` vert en CI | — |
| S1-11 | CI/CD | GitHub Actions + Codemagic/Fastlane | analyze + tests + build APK ; build iOS via Codemagic (pas de Mac) | L | Tag → artefacts signés | S1-10 |
| S1-12 | Fiches stores | — | Screenshots (5 par plateforme), descriptions FR, classification, URL privacy | M | Fiches complètes en review | S1-6, S1-9 |

---

## Sprint 2 — Rétention & polish — ~2 semaines

| ID | Titre | Description | Est. | Dép. |
|----|-------|-------------|------|------|
| S2-1 | **Push FCM** : nouveau match, nouveau message, nouvelle offre compatible (Cloud Functions onCreate) — vital pour la rétention | L | S1-7 |
| S2-2 | Vrais "Likes reçus" recruteur (candidats ayant liké mes offres) + correction du libellé home (cf. M3) | M | S0-7 |
| S2-3 | Dénormalisation : `lastMessage`, `offerTitle`, `unreadCount` sur le match → messages_page et badge non-lus en 1 requête (cf. M2, M11) | L | S0-9 |
| S2-4 | Profil entreprise recruteur : collection `recruiter_profiles`, logo, description, visible sur le détail d'offre (cf. M7) | L | — |
| S2-5 | Compteur de likes par offre (AggregateQuery.count) + toggle actif/inactif sur "Mes offres" | M | — |
| S2-6 | Dark mode complet : migrer les écrans de `AppColors.*` vers `Theme.of(context)` / `app_theme_ext` (unifier les deux systèmes) | L | — |
| S2-7 | Onboarding profil guidé post-inscription (photo, compétences, bio) — le ProfileCompletionCard existe, l'exploiter en flow | M | — |
| S2-8 | `cached_network_image` + compression photo à l'upload | S | — |
| S2-9 | Badge messages dédié côté recruteur (cf. M8) | S | S2-3 |
| S2-10 | États hors-ligne : bannière connectivité + persistance Firestore activée | M | S0-8 |

---

## Sprint 3 — Effet wow (top 3 de la Phase 5) — ~3 semaines

| ID | Titre | Est. |
|----|-------|------|
| S3-1 | **Shifts Flash** (matching de dernière minute géolocalisé) | L+ |
| S3-2 | **Bande-son du métier** (profils audio 30 s) | L |
| S3-3 | **Réputation mutuelle post-contrat** (badges vérifiés employeur/employé) | L |

Détail en fin de document (mini-specs).

---

## Sprint 4 — Post-launch

- A/B testing du scoring de compatibilité (Remote Config)
- Monétisation : boost d'offre recruteur (mise en avant 48 h), abonnement recruteur multi-offres, SuperLikes payants candidat
- Analytics avancés : funnel swipe→like→match→message→embauche
- Indexation des offres pour recherche plein texte (Algolia/Typesense)
- Géolocalisation réelle (les champs lat/lng existent déjà aux modèles, jamais remplis) : tri par distance
- Internationalisation NL/EN (marché belge)

---

## À supprimer ou reporter sans regret

**Supprimer :**
- Les 7 fichiers morts (S0-12) — c'est du bruit.
- Les requêtes `hasSuperLiked` 20×/batch tant que le SuperLike n'est pas une vraie feature différenciée.
- Le champ `remoteMode`/télétravail en première position des filtres : dans l'Horeca, le télétravail est marginal — le garder mais le rétrograder dans l'UI au profit de la **distance** et des **horaires** (soir/week-end/coupure), qui sont les vrais critères du secteur.

**Reporter :**
- Stats recruteur avancées (la page actuelle suffit au lancement).
- Dark mode complet (S2-6) si le temps manque : le mode actuel est incomplet mais non bloquant.
- Web/desktop : rester focalisé mobile (le build web sert au dev, pas à la prod).

---

## Phase 5 — 12 fonctionnalités jamais vues (matching emploi Horeca)

Impact et Effort sur 5. Faisabilité = avec la stack actuelle (Flutter + Firebase).

| # | Idée | Concept | Pourquoi différenciant | Impact | Effort | Faisable |
|---|------|---------|------------------------|--------|--------|----------|
| 1 | **Shifts Flash** | Un restaurateur poste "il me faut un serveur CE SOIR 18h-23h" ; les candidats dispo dans un rayon de X km reçoivent un push et répondent en 1 tap. | Indeed/LinkedIn sont structurellement incapables de faire du J-0. Brigad le fait en B2B fermé ; personne ne le fait en matching ouvert style Tinder. | 5 | 4 | Oui (FCM + geoquery) |
| 2 | **Bande-son du métier** | Profil audio 30 s : le candidat se présente à la voix ("présentez votre meilleur service"). Le recruteur écoute pendant le swipe. | Dans l'Horeca on recrute une attitude, pas un CV. L'audio transmet l'énergie et le niveau de langue — aucune plateforme emploi ne le fait en format swipe. | 4 | 3 | Oui (record + Storage) |
| 3 | **Réputation mutuelle post-contrat** | Après un match concrétisé, employeur ET employé se notent sur des critères fixes (ponctualité vs respect des horaires/pourboires). Badges vérifiés cumulables. | La notation **bilatérale** est un tabou du secteur : les employeurs Horeca aussi ont mauvaise réputation. La symétrie crée la confiance et un effet réseau défensif. | 5 | 3 | Oui (Firestore) |
| 4 | **Compatibilité d'horaires en grille** | Le candidat peint sa semaine (matin/midi/soir/nuit × 7 jours) ; l'offre fait pareil ; le score intègre le recouvrement. | Dans l'Horeca, le critère n°1 c'est "peux-tu faire la coupure du samedi soir ?" — aucun job board ne matche sur grille horaire. | 5 | 2 | Oui (2 bitmasks + scoring) |
| 5 | **Essai d'un soir payé** | Bouton "proposer un shift d'essai" après un match : un service rémunéré, défini dans l'app, avant tout engagement. | Transforme le match virtuel en rencontre réelle encadrée — c'est la "première date" du recrutement, personne ne l'a productisée. | 4 | 4 | Partiel (paiement = Stripe à ajouter) |
| 6 | **Salaire transparent obligatoire + baromètre live** | Publication d'offre impossible sans fourchette ; en retour, l'app affiche "cette offre paie 8 % au-dessus de la médiane des commis à Bruxelles" calculée sur les données réelles de la plateforme. | La donnée salariale temps réel du secteur n'existe nulle part ; elle attire les candidats ET discipline les recruteurs. | 4 | 2 | Oui (agrégats Firestore) |
| 7 | **Mode coupure** | Notifications et offres flash poussées pendant les heures creuses du secteur (15h-17h30), quand les pros Horeca sont sur leur téléphone. | Connaissance intime du rythme du métier — un détail qui fait dire "cette app est faite pour nous". | 3 | 1 | Oui (scheduling FCM) |
| 8 | **Défis-preuves vidéo** | Mini-défis métier optionnels : "filme ton port de 3 assiettes", "dresse une table en 90 s". Validés par la communauté, ils donnent des badges de compétence prouvée. | La "preuve de compétence" gamifiée n'existe que dans la tech (HackerRank). Dans un métier manuel, la vidéo EST le CV. | 4 | 4 | Oui (Storage + modération S1-5) |
| 9 | **Radar de salle** | Carte de chaleur anonymisée : où ça recrute, quels postes, quelles fourchettes — par quartier. Le candidat oriente sa recherche, le recruteur voit la tension concurrentielle. | Donnée de marché hyperlocale impossible à avoir ailleurs ; pousse les deux côtés à revenir même sans chercher activement. | 3 | 3 | Oui (lat/lng déjà au modèle, jamais exploités) |
| 10 | **Équipe qui recrute** | Le recruteur ajoute 3 photos/mini-bios de l'équipe en place ("tu bosseras avec Karim, chef depuis 8 ans"). Le candidat swipe une équipe, pas une annonce. | On quitte un job pour un manager, on en accepte un pour une équipe. Aucune plateforme ne montre l'équipe au stade de l'annonce. | 4 | 2 | Oui |
| 11 | **Co-matching de binômes** | Deux candidats se lient ("on bosse ensemble") et apparaissent comme duo swipable pour les gros besoins (ouvertures, extras d'événements). | Les binômes serveur/barman qui se connaissent valent de l'or en événementiel — concept inexistant ailleurs. | 3 | 3 | Oui |
| 12 | **Passeport HACCP & extras** | Coffre-fort de certificats vérifiés (HACCP, permis cariste, langues) avec badge "vérifié" après contrôle ; partagé en 1 tap après match. | Évite la paperasse répétée de l'intérim ; la vérification crée un fossé de confiance vs job boards. | 3 | 3 | Oui (Storage + back-office léger) |

### Top 3 retenu pour le Sprint 3 — mini-specs MVP

**1. Shifts Flash (S3-1)** — impact 5
- **Écrans** : création shift (recruteur : poste, date, heures, taux horaire, rayon) · feed "Flash" candidat (cartes urgentes, compte à rebours, distance) · réponse 1-tap → mini-match instantané → chat.
- **Modèle** : `flash_shifts { shiftId, recruiterUserId, title, role, date, startTime, endTime, hourlyRate, lat, lng, radiusKm, status (open/filled/expired), applicants[] }`.
- **Services** : `FlashShiftRepository` ; Cloud Function `onCreate` → push FCM aux candidats dans le rayon (geohash, package `geoflutterfire_plus`) ; Function cron d'expiration.
- **Intégration** : badge ⚡ "Flash" dans la nav candidat ; réutilise le chat existant ; nécessite S2-1 (FCM).

**2. Bande-son du métier (S3-2)** — impact 4
- **Écrans** : enregistreur 30 s dans l'édition de profil (3 prompts au choix) · lecteur waveform sur la carte swipe recruteur et le détail candidat.
- **Modèle** : `candidate_profiles.audioUrl`, `audioDuration`, `audioPrompt`.
- **Services** : package `record` + upload Storage `profile_audios/{uid}.m4a` (règle alignée sur B6) ; lecture via `just_audio`.
- **Intégration** : +10 % au `ProfileCompletion` si audio présent ; bouton play sans quitter le swipe.

**3. Réputation mutuelle (S3-3)** — impact 5
- **Écrans** : prompt post-match J+14 "Avez-vous travaillé ensemble ?" → si oui, notation croisée 3 critères (fiabilité, ambiance, respect des conditions) + badge sur profils/offres ("Employeur fiable ✓ — 12 avis").
- **Modèle** : `work_confirmations { matchId, confirmedByBoth }` ; `reviews { reviewId, matchId, fromUserId, toUserId, role, scores{}, comment, createdAt }` — les avis ne se publient que quand **les deux** ont noté (anti-représailles, comme Airbnb).
- **Services** : `ReviewRepository` ; agrégat note moyenne dénormalisé sur profil/recruteur ; modération via `reports` (S1-5).
- **Intégration** : badge sur les cartes swipe des deux côtés ; le score de compatibilité peut pondérer la fiabilité.

