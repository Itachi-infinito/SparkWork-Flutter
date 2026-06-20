import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/restricted_mode_banner.dart';
import 'core/widgets/team_upsell_sheet.dart';
import 'firebase_options.dart';
import 'models/security_flag.dart';
import 'services/notification_service.dart';
import 'services/session_security_service.dart';
import 'services/session_service.dart';
import 'services/subscription_service.dart';
import 'services/theme_service.dart';
import 'services/recruiter_theme_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Données de locale pour les dates en français (DateFormat 'fr_FR')
  await initializeDateFormatting('fr_FR');
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    runApp(_FirebaseErrorApp(error: e.toString()));
    return;
  }

  // Crashlytics désactivé en debug (sinon chaque hot-reload/erreur de dev
  // polluerait le dashboard) — actif uniquement sur les builds release/profile.
  await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(!kDebugMode);
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  await NotificationService.initialize();
  await SubscriptionService().initialize();
  runApp(const ProviderScope(child: SparkWorkApp()));
}

class _FirebaseErrorApp extends StatelessWidget {
  final String error;
  const _FirebaseErrorApp({required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.cloud_off, size: 64, color: Colors.redAccent),
                const SizedBox(height: 16),
                const Text(
                  'Impossible de se connecter au service.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Vérifiez votre connexion puis relancez l\'application.\n\n$error',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SparkWorkApp extends ConsumerStatefulWidget {
  const SparkWorkApp({super.key});

  @override
  ConsumerState<SparkWorkApp> createState() => _SparkWorkAppState();
}

class _SparkWorkAppState extends ConsumerState<SparkWorkApp> {
  // Dernier userId synchronisé avec RevenueCat. null = personne ou pas encore résolu.
  String? _revenueCatSyncedUserId;

  // Dernier userId pour lequel la session de sécurité (appareil unique,
  // heartbeat, surveillance de déconnexion forcée) a été démarrée.
  String? _securitySyncedUserId;
  StreamSubscription<bool>? _sessionWatchSub;
  StreamSubscription<List<SecurityFlag>>? _flagsSub;
  Timer? _heartbeatTimer;
  bool _forcedLogoutHandled = false;
  final Set<String> _handledFlagIds = {};

  @override
  void dispose() {
    _sessionWatchSub?.cancel();
    _flagsSub?.cancel();
    _heartbeatTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeProvider);
    final session = ref.watch(sessionProvider);
    final recruiterTheme = ref.watch(recruiterThemeProvider);
    final accent = session.isRecruiter ? recruiterTheme : null;
    // Une ambiance colorée a sa propre luminosité (Alpine/Terracotta sont
    // claires, Spark/Midnight/Emerald sont sombres) — elle prime alors sur
    // le toggle clair/sombre classique, sinon les couleurs de texte se
    // désynchronisent du fond réellement affiché.
    final effectiveThemeMode = accent != null
        ? (accent.isDarkStyle ? ThemeMode.dark : ThemeMode.light)
        : themeMode;

    // Branche le router global une seule fois pour permettre la navigation
    // depuis un tap de notification (hors arbre de widgets).
    if (NotificationService.router != router) {
      NotificationService.router = router;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        NotificationService.checkInitialMessage();
      });
    }

    // Associe/dissocie RevenueCat à l'utilisateur Firebase connecté.
    // Comparer à l'état courant (pas seulement écouter les transitions via
    // ref.listen) couvre aussi le cas d'une session déjà active au démarrage
    // de l'app (token persisté) — sinon RevenueCat reste sur son ID anonyme
    // et les achats ne sont jamais rattachés au bon compte côté webhook.
    final currentUserId = session.isLoggedIn ? session.userId : null;
    if (_revenueCatSyncedUserId != currentUserId) {
      _revenueCatSyncedUserId = currentUserId;
      final svc = SubscriptionService();
      if (currentUserId != null) {
        svc.logIn(currentUserId);
      } else {
        svc.logOut();
      }
      FirebaseCrashlytics.instance.setUserIdentifier(currentUserId ?? '');
    }

    // Démarre/arrête la surveillance de session unique par appareil pour
    // le même genre de raison (couvre aussi le redémarrage sur session déjà active).
    if (_securitySyncedUserId != currentUserId) {
      _securitySyncedUserId = currentUserId;
      _sessionWatchSub?.cancel();
      _flagsSub?.cancel();
      _heartbeatTimer?.cancel();
      _forcedLogoutHandled = false;
      _handledFlagIds.clear();
      if (currentUserId != null) {
        _startSessionSecurity(currentUserId);
      }
    }

    // ref.listen doit être appelé directement dans build() — le callback
    // `builder:` de MaterialApp.router s'exécute hors de ce contexte et
    // déclenche une assertion Riverpod ("ref.listen can only be used
    // within the build method of a ConsumerWidget").
    ref.listen<bool>(forceLogoutTriggerProvider, (previous, next) {
      if (next && !_forcedLogoutHandled) {
        _forcedLogoutHandled = true;
        final ctx = NotificationService.router?.routerDelegate.navigatorKey.currentContext;
        if (ctx != null && ctx.mounted) _showForcedLogoutDialog(ctx);
      }
    });

    return MaterialApp.router(
      title: 'SparkWork',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme(accent: accent),
      darkTheme: AppTheme.darkTheme(accent: accent),
      themeMode: effectiveThemeMode,
      // Widgets Material en français (date pickers, dialogs...)
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('fr', 'FR'), Locale('en')],
      locale: const Locale('fr', 'FR'),
      routerConfig: router,
      builder: (context, child) {
        return Column(
          children: [
            const RestrictedModeBanner(),
            Expanded(child: child ?? const SizedBox.shrink()),
          ],
        );
      },
    );
  }

  Future<void> _startSessionSecurity(String userId) async {
    final sessionSvc = ref.read(sessionSecurityServiceProvider);
    await sessionSvc.getOrCreateSession(userId);

    _heartbeatTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      sessionSvc.heartbeat();
    });

    _sessionWatchSub = sessionSvc.watchCurrentSessionActive().listen((isActive) {
      if (!isActive) {
        ref.read(forceLogoutTriggerProvider.notifier).state = true;
      }
    });

    // Alerte "Oui c'est moi / Non, sécuriser" sur chaque nouvelle anomalie
    // non résolue détectée côté serveur (analyzeSessionAnomaly).
    _flagsSub = sessionSvc.watchUnresolvedFlags(userId).listen((flags) {
      for (final flag in flags) {
        if (_handledFlagIds.contains(flag.flagId)) continue;
        final ctx = NotificationService.router?.routerDelegate.navigatorKey.currentContext;
        if (ctx == null || !ctx.mounted) continue;
        _handledFlagIds.add(flag.flagId);
        _showAnomalyConfirmDialog(ctx, flag);
      }
    });

    // Upsell "doux" (trigger 1) : 2 appareils distincts le même jour, proposé
    // au plus 1x/semaine, jamais punitif.
    if (await sessionSvc.hasMultipleDevicesToday(userId)) {
      final prefs = await SharedPreferences.getInstance();
      final lastShownMs = prefs.getInt('lastSoftTeamUpsellAt') ?? 0;
      final daysSince = (DateTime.now().millisecondsSinceEpoch - lastShownMs) / 86400000;
      if (daysSince >= 7) {
        await prefs.setInt('lastSoftTeamUpsellAt', DateTime.now().millisecondsSinceEpoch);
        final ctx = NotificationService.router?.routerDelegate.navigatorKey.currentContext;
        if (ctx != null && ctx.mounted) {
          showTeamUpsellSheet(ctx, strong: false);
        }
      }
    }
  }

  void _showAnomalyConfirmDialog(BuildContext context, SecurityFlag flag) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Activité inhabituelle détectée'),
        content: const Text(
          'Nous avons remarqué une connexion inhabituelle sur votre compte. '
          'Votre sécurité est notre priorité — pouvez-vous confirmer que c\'est bien vous ?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.push('/security/alert');
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Non, sécuriser mon compte'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final severity =
                  await ref.read(sessionSecurityServiceProvider).resolveFlag(flag.flagId);
              // Trigger 2 : upsell "fort" immédiat après confirmation d'une
              // anomalie medium — signal direct de partage de compte probable.
              if (severity == 'medium' && context.mounted) {
                showTeamUpsellSheet(context, strong: true);
              }
            },
            child: const Text('Oui, c\'est moi'),
          ),
        ],
      ),
    );
  }

  void _showForcedLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: const Text('Session fermée'),
          content: const Text(
            'Votre compte a été ouvert sur un nouvel appareil. Vous avez été '
            'déconnecté automatiquement pour protéger votre compte. Si ce '
            'n\'est pas vous, changez votre mot de passe immédiatement.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                await ref.read(sessionSecurityServiceProvider).clearCurrentSessionId();
                ref.read(forceLogoutTriggerProvider.notifier).state = false;
                await ref.read(sessionProvider.notifier).logout();
              },
              child: const Text('Se reconnecter'),
            ),
          ],
        ),
      ),
    );
  }
}
