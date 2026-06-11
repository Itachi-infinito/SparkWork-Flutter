# AUDIT SparkWork — 10 juin 2026

Audit complet des 72 fichiers Dart + règles Firebase + configuration.
Classement : 🔴 Bloquant · 🟠 Majeur · 🟡 Mineur

---

## 🔴 BLOQUANTS

### B1 — Clés Firebase Android/iOS factices : l'app ne peut PAS tourner sur mobile
**Fichier :** `lib/firebase_options.dart:32-47`
`android.apiKey = 'YOUR_ANDROID_API_KEY'` et `ios.apiKey = 'YOUR_IOS_API_KEY'` avec des appId à zéros. Comme `main.dart` passe explicitement `DefaultFirebaseOptions.currentPlatform`, ces placeholders **écrasent** le `google-services.json` natif → Firebase échoue au démarrage sur Android et iOS. De plus, `ios/Runner/GoogleService-Info.plist` est absent.
**Correctif :** `flutterfire configure --project=sparkwork-f41ec` (le `firebase.json` contient déjà les vrais appId : `...android:1d871d5dd8d05c8d5feb4f` et `...ios:6267024edcb16cbb5feb4f`).

### B2 — Échec d'init Firebase avalé silencieusement
**Fichier :** `lib/main.dart:11-13`
`try { await Firebase.initializeApp(...) } catch (_) {}` : si l'init échoue, l'app démarre quand même et **chaque** accès Firestore/Auth crashe ensuite avec des erreurs incompréhensibles.
**Correctif :** supprimer le try/catch, ou afficher un écran d'erreur bloquant ("Impossible de se connecter au service").

### B3 — Valeurs de profil candidat incohérentes : matching silencieusement cassé
**Fichier :** `lib/views/candidate/edit_candidate_profile_page.dart:307, 324, 376`
La page d'édition utilise des listes hardcodées qui **divergent** de `AppSkills` :
- Niveaux : `['Junior', 'Intermédiaire', 'Senior', 'Expert']` vs `AppSkills.levels = ['Débutant', 'Junior', 'Confirmé', 'Senior', 'Expert']` → un candidat "Intermédiaire" ne matchera **jamais** un niveau d'offre, et n'apparaîtra jamais dans les filtres niveau.
- Télétravail : `['Présentiel', 'Hybride', 'Télétravail']` vs `AppSkills.remoteModes = ['Présentiel', 'Télétravail partiel', 'Télétravail total']` → même problème.
- Contrats : il manque `Alternance` et `Temps partiel`.
La page d'inscription (`register_candidate_page.dart`) utilise, elle, les bonnes constantes → un profil édité après inscription **dégrade** ses données.
**Correctif :** remplacer les 3 listes par `AppSkills.levels`, `AppSkills.remoteModes`, `AppSkills.contractTypes`. Prévoir une migration des profils existants ("Intermédiaire"→"Confirmé", "Hybride"→"Télétravail partiel", "Télétravail"→"Télétravail total").

### B4 — Le chat n'est PAS temps réel
**Fichier :** `lib/views/shared/conversation_detail_page.dart:34-58`
La page utilise `getMessages()` (lecture unique) alors que `MessageRepository.watchMessages()` (stream) **existe déjà** (`message_repository.dart:17`). Les messages de l'interlocuteur n'apparaissent qu'après l'envoi d'un message ou un retour sur la page. Pour une app de matching, c'est rédhibitoire.
**Correctif :** `StreamBuilder`/`ref.watch` sur `watchMessages(matchId)` + `markMessagesSeen` à chaque snapshot.

### B5 — Swipe vers le haut (SuperLike) : la carte disparaît sans rien enregistrer
**Fichier :** `lib/views/candidate/candidate_swipe_page.dart:394-412`
L'overlay affiche "SUPERLIKE" quand on glisse vers le haut (`Listener` lignes 598-613), mais `_onSwipeEnd` ne gère que `AxisDirection.right` et `left`. Un swipe up retire la carte **sans créer de like** : l'offre est perdue pour la session. Côté recruteur (`recruiter_swipe_page.dart:408`), le up est traité comme like mais `addLike(... isSuperLike: false)` : le flag `isSuperLike` n'est **jamais** mis à `true` nulle part → `hasSuperLiked()` (interrogé 20× par batch côté candidat !) renvoie toujours `false`. La feature SuperLike est entièrement morte.
**Correctif :** traiter `AxisDirection.up` comme like (ou superlike persisté avec `isSuperLike: true`), et passer le flag depuis le bouton ⚡.

### B6 — Storage : n'importe qui peut écraser la photo de n'importe qui
**Fichier :** `storage.rules:4-7`
`allow write: if request.auth != null` sur `profile_photos/{fileName}` : tout utilisateur connecté peut uploader/écraser `{nimporteQuelUid}.jpg`, sans limite de taille ni de type.
**Correctif :**
```
match /profile_photos/{fileName} {
  allow read: if request.auth != null;
  allow write: if request.auth != null
      && fileName == request.auth.uid + '.jpg'
      && request.resource.size < 5 * 1024 * 1024
      && request.resource.contentType.matches('image/.*');
}
```

### B7 — Un candidat peut se créer un match sans réciprocité
**Fichier :** `firestore.rules:71-73` + logique client
`allow create` sur `matches` exige seulement que l'un des deux IDs soit l'appelant. Toute la logique de réciprocité (like mutuel) est côté client → un client modifié peut créer un match avec n'importe quel recruteur et lui écrire des messages. De plus, `candidate_job_likes` et `recruiter_candidate_likes` sont **lisibles par tous les authentifiés** (`firestore.rules:50, 59`) : n'importe qui peut télécharger qui a liké qui (donnée privée).
**Correctif :** court terme, restreindre la lecture des likes aux parties concernées ; moyen terme, créer les matches via une Cloud Function (`onCreate` d'un like → vérifie la réciprocité → crée le match).

### B8 — Suppression de compte absente de l'UI (rejet App Store garanti)
**Fichiers :** `lib/views/shared/settings_page.dart` (rien), `lib/services/auth_service.dart:62-64`
La règle Apple 5.1.1(v) impose la suppression de compte in-app. `AuthService.deleteAccount()` existe mais : (1) n'est appelé nulle part, (2) ne supprime **que** le compte Auth — profil, likes, matches, messages et photo restent en base (problème RGPD), (3) ne gère pas `requires-recent-login`. Même constat pour `changePassword()` : implémenté mais aucune UI ne l'appelle.
**Correctif :** section "Compte" dans Settings avec changement de mot de passe + suppression (ré-authentification, puis purge Firestore/Storage — idéalement via Cloud Function `onUserDeleted`).

### B9 — Règle messages : un participant peut modifier le contenu des messages de l'autre
**Fichier :** `firestore.rules:86`
`allow update: if isMatchParticipant(...)` sans restriction de champs : prévu pour `markAsSeen`, mais permet de réécrire `content` d'un message reçu.
**Correctif :**
```
allow update: if isAuth() && isMatchParticipant(resource.data.matchId)
    && request.resource.data.diff(resource.data).affectedKeys().hasOnly(['seenAt']);
```

---

## 🟠 MAJEURS

### M1 — Chargements sans gestion d'erreur (spinner infini ou crash async)
Aucun try/catch autour des accès réseau dans :
- `recruiter_swipe_page.dart:67-117` (`_load`, try/**finally** sans catch → exception non gérée)
- `add_job_offer_page.dart:45-91` (`_save`, idem : une erreur Firestore = crash silencieux, l'utilisateur croit que c'est publié)
- `edit_recruiter_profile_page.dart:27-51` (`_save`, idem)
- `conversation_detail_page.dart:34` (`_load`)
- `messages_page.dart:61` (`_load`)
- `recruiter_job_offers_page.dart:29`, `likes_received_page.dart:29`, `recruiter_matches_page.dart:34`, `recruiter_profile_page.dart:30`, `recruiter_stats_page.dart:30`, `job_offer_list_page.dart:42`, `candidate_profile_page.dart:32`, `edit_candidate_profile_page.dart:46`, `liked_offers_page.dart`
**Correctif :** wrapper standard try/catch → état `_error` + bouton "Réessayer" (le pattern existe déjà dans `candidate_swipe_page.dart:539`).

### M2 — Requêtes N+1 généralisées (coût Firestore + lenteur)
- `messages_page.dart:73-77` : 2 requêtes **par match** (offre + dernier message).
- `unread_service.dart:24-31` : 1 requête par match à **chaque** invalidation du provider (la nav bar le watch sur toutes les pages).
- `candidate_swipe_page.dart:115` : `hasSuperLiked` = 20 requêtes par batch — pour une feature morte (cf. B5).
- `candidate_matches_page.dart:66-69`, `recruiter_matches_page.dart:41-48`, `liked_offers_page` : 1-2 requêtes par item.
- `candidate_job_like_repository.dart:54-72` : `countLikesForOffers`/`getLikeCountPerOffer` = 1 requête par offre (et télécharge les docs entiers au lieu de `count()`).
- `likes_received_page.dart:35-39` : télécharge **toute** la collection `candidate_profiles` puis filtre en mémoire.
**Correctif :** dénormaliser (stocker `lastMessage`, `offerTitle`, `unreadCount` sur le doc match, mis à jour à l'envoi), utiliser `whereIn` (batches de 30) et `AggregateQuery.count()`.

### M3 — "Likes reçus" affiche en réalité les likes ENVOYÉS
**Fichiers :** `likes_received_page.dart:32-40`, `recruiter_home_page.dart:223-227`
La home recruteur annonce "Likes reçus" mais la page liste `getLikedCandidateIds(recruiterId)` = les candidats que le recruteur a likés (le titre de la page dit d'ailleurs "Candidats likés"). La vraie fonctionnalité "candidats qui ont liké mes offres" — l'or d'une app de matching côté recruteur — **n'existe pas**.
**Correctif :** requête `candidate_job_likes where jobOfferId in [mes offres]` + renommer le bouton home.

### M4 — Rejets de swipe non persistés
Swiper à gauche n'écrit rien (`candidate_swipe_page.dart:403`, juste un Set local). À chaque ouverture, l'utilisateur revoit **toutes** les offres déjà rejetées. Combiné à la pagination, le filtre `!_likedIds.contains(...)` re-télécharge sans cesse les mêmes docs.
**Correctif :** collection `passes` (ou champ sur le like avec `type: pass`) + exclusion au chargement, éventuellement avec expiration (re-proposer après 30 jours).

### M5 — Horloge client pour `sentAt` / matches `createdAt`
**Fichiers :** `message_repository.dart:42`, `match_repository.dart:28`
`DateTime.now().toIso8601String()` dépend de l'horloge du téléphone : tri des conversations faux si horloge décalée, incohérent avec `FieldValue.serverTimestamp()` utilisé pour les likes.
**Correctif :** `FieldValue.serverTimestamp()` partout + adapter modèle/tri.

### M6 — Course à l'inscription : session chargée avant l'écriture du doc user
**Fichiers :** `auth_service.dart:22-34`, `session_service.dart:42-55`
`createUserWithEmailAndPassword` déclenche `authStateChanges` **immédiatement** ; `_onAuthChanged` lit `users/{uid}` qui n'existe pas encore (le `set()` arrive après) → `SessionState` sans user → le router peut rediriger vers `/welcome` en plein milieu de l'inscription. Le `context.go('/candidate/home')` de `register_candidate_page.dart:74` peut aussi arriver avant que le rôle soit connu.
**Correctif :** écrire le doc user **avant** de considérer la session prête (par ex. `sessionProvider.reload()` après le `set()`, ou retry court dans `_onAuthChanged` si doc absent).

### M7 — Profil entreprise recruteur inexistant
`firestore.rules` déclare `recruiter_profiles` mais **aucun repository ni écran ne l'utilise**. Le "profil" recruteur n'édite que `users.fullName` (`edit_recruiter_profile_page.dart:38-41` — qui écrit d'ailleurs directement dans Firestore depuis la vue, en court-circuitant la couche repository). Pas de logo, pas de description d'établissement ; `companyName` est dupliqué dans chaque offre.
**Correctif :** créer `RecruiterProfileRepository` + écran d'édition (nom établissement, logo, description, adresse) et l'afficher côté candidat sur le détail d'offre.

### M8 — Badge "non-lus" placé sur l'onglet Matches côté recruteur
**Fichier :** `nav_bar.dart:68-72`
Le badge `unreadMessagesProvider` (messages non lus) s'affiche sur l'onglet **Matches** du recruteur — qui n'a pas d'onglet Messages dans sa nav. Confusion garantie : un point rouge sur Matches qui signifie "nouveau message".
**Correctif :** soit un onglet Messages dédié, soit un libellé/badge cohérent.

### M9 — `getAllProfiles()` télécharge toute la collection
**Fichiers :** `candidate_profile_repository.dart:29-32`, utilisé par `browse_candidates_page.dart` et `likes_received_page.dart`
Pas de limite, pas de pagination : coût linéaire avec le nombre d'inscrits. Avec 5 000 candidats = 5 000 lectures par ouverture de page.
**Correctif :** pagination (`getProfilesBatch` existe déjà), filtres serveur (where sur `location`, `desiredLevel`).

### M10 — `markMessagesSeen` : requête `isNotEqualTo` + batch sans limite
**Fichier :** `message_repository.dart:53-67`
`where(senderUserId, isNotEqualTo:)` exige un index et exclut les docs sans champ ; le batch Firestore est limité à 500 opérations (non géré). Et la règle messages (cf. B9) doit autoriser cet update.
**Correctif :** filtrer sur `seenAt == null` + `matchId`, puis exclure ses propres messages côté client ; chunker le batch.

### M11 — `unreadMessagesProvider` basé sur SharedPreferences local
**Fichier :** `unread_service.dart:13-15`
Le "vu" est un timestamp local par device : badge incohérent entre appareils, remis à zéro à la réinstallation. La donnée `seenAt` par message existe pourtant en base.
**Correctif :** compter les messages `seenAt == null && senderUserId != me` (dénormalisé sur le match, cf. M2).

### M12 — Dossier `test/` : un seul fichier, qui ne compile probablement plus
`test/widget_test.dart` est le test par défaut de `flutter create` (compteur) — il référence une app qui n'existe plus. Zéro test réel sur `CompatibilityService`, parsing, repositories.

---

## 🟡 MINEURS

| # | Fichier | Problème |
|---|---|---|
| m1 | `lib/core/constants/app.colors.dart` | Doublon mort de `app_colors.dart` (0 import) — supprimer |
| m2 | `lib/core/theme/theme_notifier.dart` | Doublon mort de `services/theme_service.dart` (0 import, clé prefs différente `theme_dark` vs `dark_mode`) — supprimer |
| m3 | `lib/models/user.dart` | Modèle SQLite mort (passwordHash !) — supprimer |
| m4 | `lib/services/database_service.dart` | Stub vide — supprimer |
| m5 | `lib/views/candidate/matches_page.dart`, `lib/views/public/role_selection_page.dart` | Pages "En construction" non routées — supprimer |
| m6 | `lib/services/notification_service.dart` | Stub vide appelé par le swipe (no-op trompeur) — implémenter (Sprint 2) ou retirer les appels |
| m7 | `edit_candidate_profile_page.dart:252, 314...` | Couleur hardcodée `0xFF6C63FF` ≠ `AppColors.primary` (0xFF7C4DFF) |
| m8 | `candidate_profile.dart:58`, `job_offer.dart:54`, `app_avatar.dart:18` | `initials` : crash possible sur nom avec doubles espaces (`parts[1][0]` sur chaîne vide) — `app_avatar` filtre, les modèles non |
| m9 | `messages_page.dart:108` | `DateFormat('d MMM','fr_FR')` sans `initializeDateFormatting('fr_FR')` → renvoie '' silencieusement sur certaines plateformes |
| m10 | `splash_page.dart:40-42` | Polling 50 ms sur `sessionProvider.isLoading` au lieu d'un listener |
| m11 | `login_page.dart:38` | Seul `FirebaseAuthException` est attrapé : une erreur réseau = exception non gérée |
| m12 | `add_job_offer_page.dart` / salaires | `validator` absent sur les champs salaire (saisie "12abc" → 0 silencieux) ; pas de `FilteringTextInputFormatter.digitsOnly` |
| m13 | `candidate_swipe_page.dart:639-671` | Bouton ⚡ et bouton ❤️ font exactement la même chose (`swipeRight`) |
| m14 | `job_offer_repository.dart:22` | `getAllOffers()` = alias trompeur de `getAllActiveOffers()` |
| m15 | `recruiter_job_offers_page.dart` | Pas de toggle actif/inactif (le champ `isActive` existe au modèle) ; pas de compteur de likes par offre (annoncé) |
| m16 | `pubspec.yaml` | `assets/images/` déclaré mais vide ; `fl_chart 0.69` et `go_router 14` ont des majors plus récentes ; pas de `cached_network_image` (photos re-téléchargées à chaque rebuild) |
| m17 | `conversation_detail_page.dart:43-45` | Charge **tous** les matches pour retrouver un titre — il manque `getMatchById()` au repository |
| m18 | `app_theme_ext.dart` vs `settings_page.dart:20-22` | Deux systèmes de couleurs dark divergents (0xFF2C2C2C vs 0xFF2E3347) ; la majorité des écrans utilisent `AppColors.*` en dur → dark mode incomplet sur ~80 % des pages |
| m19 | `recruiter_home_page.dart:96-98` | `split(' - ')` sur le nom : convention non documentée |
| m20 | `candidate_profile.toMap()` | `skills` sérialisé en chaîne jointe alors que le modèle est une liste — fonctionne mais fragile (un skill contenant une virgule casserait le parsing) |

---

## Architecture — constats transverses

1. **Couches saines dans l'ensemble** (modèles / repositories / services / vues) avec deux entorses : `edit_recruiter_profile_page` et `session_service` écrivent/lisent Firestore en direct.
2. **Tout le matching est côté client** : score, réciprocité, création du match. Acceptable pour un MVP, mais à terme la création de match doit être serveur (Cloud Function) — cf. B7.
3. **Dénormalisation absente** : chaque liste (messages, matches, likes) reconstruit ses données par N+1. C'est le chantier perf n°1.
4. **`StatefulWidget + initState/_load`** partout au lieu de `FutureProvider`/`StreamProvider` Riverpod : pas bloquant, mais 15 implémentations du même pattern avec 15 niveaux de robustesse différents.
5. **7 fichiers morts** à supprimer (m1-m5 + stubs).
