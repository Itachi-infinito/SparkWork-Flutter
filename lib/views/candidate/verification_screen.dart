import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_theme_ext.dart';
import '../../models/verification_model.dart';
import '../../services/session_service.dart';
import '../../services/stripe_identity_service.dart';
import '../../services/veriff_service.dart';

/// Steps of the verification flow
enum _Step { info, docType, consent, waiting, result }

class VerificationScreen extends ConsumerStatefulWidget {
  const VerificationScreen({super.key});

  @override
  ConsumerState<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends ConsumerState<VerificationScreen> {
  _Step _step = _Step.info;
  VerificationModel? _verificationModel;
  bool _loading = true;
  bool _launching = false;
  bool _consentGiven = false;

  DocumentType _selectedDocType = DocumentType.nationalId;
  String? _sessionUrl;
  VeriffLaunchStatus? _launchResult;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    final userId = ref.read(sessionProvider).userId;
    final svc = ref.read(veriffServiceProvider);
    VerificationModel? v;
    try {
      v = await svc.getVerificationStatus(userId);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showError('Impossible de charger le statut de vérification. Vérifiez votre connexion et réessayez.');
      return;
    }
    if (!mounted) return;
    setState(() {
      _verificationModel = v;
      _loading = false;
    });

    // Jump directly to result step if there's a decided status
    if (v != null) {
      final s = v.status;
      if (s == VeriffStatus.verified ||
          s == VeriffStatus.rejected ||
          s == VeriffStatus.resubmissionRequested) {
        setState(() => _step = _Step.result);
      } else if (s == VeriffStatus.pending) {
        setState(() => _step = _Step.waiting);
      }
    }
  }

  // ── Navigation between steps ────────────────────────────────────────────────

  void _goToDocType() => setState(() => _step = _Step.docType);
  void _goToConsent() => setState(() => _step = _Step.consent);
  void _backToInfo() => setState(() => _step = _Step.info);
  void _backToDocType() => setState(() => _step = _Step.docType);

  Future<void> _startVerification() async {
    if (!_consentGiven) return;

    // Check camera permission before launching
    final cameraStatus = await Permission.camera.request();
    if (!cameraStatus.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'La caméra est nécessaire pour vérifier votre identité. Veuillez l\'autoriser dans les paramètres.'),
            backgroundColor: AppColors.orange,
            duration: Duration(seconds: 4),
          ),
        );
      }
      return;
    }

    setState(() => _launching = true);
    try {
      final userId = ref.read(sessionProvider).userId;
      final svc = ref.read(veriffServiceProvider);

      // Create session on backend — API key stays server-side
      final sessionResult = await svc.createSession(
        userId: userId,
        documentType: _selectedDocType,
      );
      _sessionUrl = sessionResult.sessionUrl;

      setState(() => _step = _Step.waiting);

      // Launch native Veriff SDK
      final launchStatus = await svc.launchVerification(_sessionUrl!);

      if (!mounted) return;
      setState(() {
        _launchResult = launchStatus;
        _launching = false;
      });

      if (launchStatus == VeriffLaunchStatus.done) {
        // SDK completed — final decision comes via webhook to backend
        await Future.delayed(const Duration(seconds: 2));
        await _loadStatus();
      } else if (launchStatus == VeriffLaunchStatus.canceled) {
        setState(() => _step = _Step.consent);
      } else {
        setState(() => _step = _Step.result);
      }
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      setState(() { _launching = false; _step = _Step.consent; });
      _showError(_mapFunctionsError(e));
    } catch (e) {
      if (!mounted) return;
      setState(() { _launching = false; _step = _Step.consent; });
      _showError('Une erreur est survenue. Vérifiez votre connexion et réessayez.');
    }
  }

  /// Alternative à Veriff : ouvre la page Stripe Identity hébergée dans le
  /// navigateur. La décision finale arrive via webhook côté backend, comme
  /// pour Veriff — au retour dans l'app, on rafraîchit simplement le statut.
  Future<void> _startStripeVerification() async {
    setState(() => _launching = true);
    try {
      final session = await ref.read(stripeIdentityServiceProvider).createSession();
      final uri = Uri.parse(session.sessionUrl);
      if (!mounted) return;
      setState(() { _launching = false; _step = _Step.waiting; });
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) await _loadStatus();
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      setState(() => _launching = false);
      _showError(_mapFunctionsError(e));
    } catch (e) {
      if (!mounted) return;
      setState(() => _launching = false);
      _showError('Une erreur est survenue. Vérifiez votre connexion et réessayez.');
    }
  }

  String _mapFunctionsError(FirebaseFunctionsException e) {
    switch (e.code) {
      case 'unauthenticated':
        return 'Vous devez être connecté pour vérifier votre identité.';
      case 'resource-exhausted':
        return 'Vous avez atteint le nombre maximum de tentatives (3/3). Contactez le support.';
      default:
        return 'Erreur : ${e.message}';
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.red),
    );
  }

  Future<void> _deleteData() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer mes données'),
        content: const Text(
            'Voulez-vous supprimer vos données de vérification ? Vous devrez recommencer la vérification.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer', style: TextStyle(color: AppColors.red)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    final userId = ref.read(sessionProvider).userId;
    await ref.read(veriffServiceProvider).deleteVerificationData(userId);
    if (mounted) {
      setState(() {
        _verificationModel = null;
        _step = _Step.info;
        _consentGiven = false;
      });
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vérification d\'identité'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_step == _Step.docType) {
              _backToInfo();
            } else if (_step == _Step.consent) {
              _backToDocType();
            } else {
              context.pop();
            }
          },
        ),
        actions: [
          if (_verificationModel != null &&
              _verificationModel!.status != VeriffStatus.unverified)
            TextButton(
              onPressed: _deleteData,
              child: const Text('Supprimer',
                  style: TextStyle(color: AppColors.red, fontSize: 12)),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _buildStep(),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case _Step.info:
        return _buildInfoStep();
      case _Step.docType:
        return _buildDocTypeStep();
      case _Step.consent:
        return _buildConsentStep();
      case _Step.waiting:
        return _buildWaitingStep();
      case _Step.result:
        return _buildResultStep();
    }
  }

  // ── Step 1 : Info ────────────────────────────────────────────────────────────

  Widget _buildInfoStep() {
    final attemptCount = _verificationModel?.attemptCount ?? 0;
    final attemptsLeft = 3 - attemptCount;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6C63FF), Color(0xFF3B82F6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  )
                ],
              ),
              child: const Icon(Icons.shield_outlined, size: 56, color: Colors.white),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Prouvez que c\'est bien vous',
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: context.textPrimaryColor),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'La vérification d\'identité est rapide (< 2 min) et 100% sécurisée. '
            'Elle est gérée par Veriff, certifié eIDAS et conforme au RGPD.',
            style: TextStyle(
                fontSize: 13, color: context.textSecondaryColor, height: 1.6),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),

          ..._benefits.map((b) => _BenefitRow(icon: b.$1, text: b.$2)),

          if (attemptCount > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.orange.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.orange.withOpacity(0.3)),
              ),
              child: Row(children: [
                const Icon(Icons.info_outline, color: AppColors.orange, size: 16),
                const SizedBox(width: 10),
                Text(
                  '${3 - attemptCount} tentative${(3 - attemptCount) > 1 ? 's' : ''} restante${(3 - attemptCount) > 1 ? 's' : ''}',
                  style: const TextStyle(
                      color: AppColors.orange,
                      fontSize: 13,
                      fontWeight: FontWeight.w600),
                ),
              ]),
            ),
          ],

          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: attemptsLeft > 0 ? _goToDocType : null,
              icon: const Icon(Icons.arrow_forward, color: Colors.white),
              label: Text(
                attemptsLeft > 0
                    ? 'Commencer la vérification'
                    : 'Tentatives épuisées — contactez le support',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                disabledBackgroundColor: Colors.grey.shade300,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static const _benefits = [
    (Icons.verified_user_outlined, 'Badge "ID Vérifié" visible par les recruteurs'),
    (Icons.trending_up, 'Priorité dans les résultats de recherche'),
    (Icons.handshake_outlined, '+40 % de chances d\'être contacté'),
    (Icons.lock_outline, 'Vos documents ne quittent jamais Veriff — SparkWork ne les stocke pas'),
  ];

  // ── Step 2 : Choix du document ───────────────────────────────────────────────

  Widget _buildDocTypeStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Quel document allez-vous utiliser ?',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: context.textPrimaryColor)),
          const SizedBox(height: 8),
          Text('Choisissez un document officiel en cours de validité.',
              style: TextStyle(fontSize: 13, color: context.textSecondaryColor)),
          const SizedBox(height: 24),
          ...DocumentType.values.map((dt) => _DocTypeCard(
                docType: dt,
                selected: _selectedDocType == dt,
                onTap: () => setState(() => _selectedDocType = dt),
              )),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _goToConsent,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Continuer',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _launching ? null : _startStripeVerification,
              style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 52)),
              child: const Text('Vérifier avec Stripe Identity'),
            ),
          ),
        ],
      ),
    );
  }

  // ── Step 3 : Consentement RGPD ───────────────────────────────────────────────

  Widget _buildConsentStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Avant de continuer',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: context.textPrimaryColor)),
          const SizedBox(height: 20),

          // RGPD notice
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.primary.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.privacy_tip_outlined,
                      color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Text('Protection de vos données',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: context.textPrimaryColor)),
                ]),
                const SizedBox(height: 10),
                Text(
                  '• Vos données d\'identité sont transmises directement à Veriff, '
                  'partenaire certifié eIDAS et conforme au RGPD.\n'
                  '• SparkWork ne stocke jamais vos images de documents.\n'
                  '• Veriff supprime automatiquement vos données après 7 jours.\n'
                  '• Nous conservons uniquement : statut de vérification et date de décision.',
                  style: TextStyle(
                      fontSize: 12, color: context.textSecondaryColor, height: 1.7),
                ),
                const SizedBox(height: 10),
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                        fontSize: 12, color: context.textSecondaryColor),
                    children: [
                      const TextSpan(text: 'Politique de confidentialité : '),
                      TextSpan(
                        text: 'veriff.com/privacy',
                        style: const TextStyle(
                            color: AppColors.primary,
                            decoration: TextDecoration.underline),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () {
                            // TODO: url_launcher → https://www.veriff.com/privacy-policy
                          },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // What Veriff does
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.surfaceColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: context.borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ce que Veriff va faire :',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: context.textPrimaryColor)),
                const SizedBox(height: 10),
                ..._veriffSteps.map((s) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.check_circle_outline,
                                color: AppColors.green, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(s,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: context.textSecondaryColor,
                                      height: 1.5)),
                            ),
                          ]),
                    )),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Consent checkbox
          GestureDetector(
            onTap: () => setState(() => _consentGiven = !_consentGiven),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: _consentGiven,
                  onChanged: (v) => setState(() => _consentGiven = v ?? false),
                  activeColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      'J\'accepte que mes données d\'identité soient transmises à Veriff '
                      'dans le cadre de ma vérification d\'identité, conformément au RGPD.',
                      style: TextStyle(
                          fontSize: 12,
                          color: context.textSecondaryColor,
                          height: 1.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: (_consentGiven && !_launching) ? _startVerification : null,
              icon: _launching
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.play_circle_outline, color: Colors.white),
              label: Text(
                _launching ? 'Lancement...' : 'Commencer la vérification',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                disabledBackgroundColor: Colors.grey.shade300,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static const _veriffSteps = [
    'Capture guidée de votre document (recto-verso)',
    'Vérification automatique de la qualité de l\'image',
    'Selfie avec détection de vivacité (liveness check)',
    'Matching facial entre selfie et document',
    'Résultat en moins de 2 minutes',
  ];

  // ── Step 4 : En attente ──────────────────────────────────────────────────────

  Widget _buildWaitingStep() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_launching) ...[
              const SizedBox(
                width: 80, height: 80,
                child: CircularProgressIndicator(
                    color: AppColors.primary, strokeWidth: 3),
              ),
              const SizedBox(height: 24),
              Text('Lancement de la vérification…',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: context.textPrimaryColor)),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.orange.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.hourglass_bottom_outlined,
                    size: 64, color: AppColors.orange),
              ),
              const SizedBox(height: 24),
              Text('Vérification en cours',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: context.textPrimaryColor)),
              const SizedBox(height: 12),
              Text(
                'Vos documents sont en cours d\'analyse par Veriff.\n'
                'Cela prend généralement moins de 2 minutes.\n'
                'Vous recevrez une notification dès que la décision est prise.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13,
                    color: context.textSecondaryColor,
                    height: 1.6),
              ),
              const SizedBox(height: 32),
              OutlinedButton.icon(
                onPressed: _loadStatus,
                icon: const Icon(Icons.refresh, color: AppColors.primary),
                label: const Text('Vérifier le statut',
                    style: TextStyle(color: AppColors.primary)),
                style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.primary)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Step 5 : Résultat ────────────────────────────────────────────────────────

  Widget _buildResultStep() {
    if (_launchResult == VeriffLaunchStatus.error &&
        (_verificationModel?.status == VeriffStatus.pending ||
            _verificationModel == null)) {
      return _buildSdkErrorState();
    }
    final status = _verificationModel?.status ?? VeriffStatus.unverified;
    switch (status) {
      case VeriffStatus.verified:
        return _buildApprovedState();
      case VeriffStatus.rejected:
        return _buildRejectedState();
      case VeriffStatus.resubmissionRequested:
        return _buildResubmissionState();
      case VeriffStatus.pending:
        return _buildWaitingStep();
      default:
        return _buildInfoStep();
    }
  }

  Widget _buildApprovedState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFF3B82F6), Color(0xFF06B6D4)]),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: const Color(0xFF3B82F6).withOpacity(0.4),
                      blurRadius: 28),
                ],
              ),
              child: const Icon(Icons.verified_user, size: 64, color: Colors.white),
            ),
            const SizedBox(height: 24),
            const Text('Identité vérifiée !',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF3B82F6))),
            const SizedBox(height: 12),
            Text(
              'Votre badge "ID Vérifié" est actif. '
              'Les recruteurs peuvent voir que votre identité a été confirmée.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13,
                  color: context.textSecondaryColor,
                  height: 1.6),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => context.pop(),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  minimumSize: const Size(200, 48)),
              child: const Text('Retour au profil',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRejectedState() {
    final reason = _verificationModel?.declineReason;
    final canRetry = _verificationModel?.canRetry ?? false;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.gpp_bad_outlined,
                  size: 64, color: AppColors.red),
            ),
            const SizedBox(height: 24),
            const Text('Vérification refusée',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.red)),
            const SizedBox(height: 12),
            if (reason != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.redLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('Motif : $reason',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.red, height: 1.5)),
              ),
              const SizedBox(height: 12),
            ],
            Text(
              canRetry
                  ? 'Vous pouvez réessayer avec un document différent ou de meilleure qualité.'
                  : 'Vous avez atteint le nombre maximum de tentatives (3/3). Contactez notre support.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13,
                  color: context.textSecondaryColor,
                  height: 1.6),
            ),
            const SizedBox(height: 28),
            if (canRetry)
              ElevatedButton.icon(
                onPressed: () => setState(() {
                  _step = _Step.docType;
                  _launchResult = null;
                }),
                icon: const Icon(Icons.refresh, color: Colors.white),
                label: const Text('Réessayer',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    minimumSize: const Size(200, 48)),
              )
            else
              OutlinedButton.icon(
                onPressed: () { /* TODO: open support */ },
                icon: const Icon(Icons.support_agent, color: AppColors.primary),
                label: const Text('Contacter le support',
                    style: TextStyle(color: AppColors.primary)),
                style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.primary)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildResubmissionState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.orange.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.document_scanner_outlined,
                  size: 64, color: AppColors.orange),
            ),
            const SizedBox(height: 24),
            const Text('Document illisible',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.orange)),
            const SizedBox(height: 12),
            Text(
              'Votre document n\'était pas lisible (flou, reflet, image coupée). '
              'Recommencez avec un document bien éclairé et sans reflet.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13,
                  color: context.textSecondaryColor,
                  height: 1.6),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: () => setState(() {
                _step = _Step.consent;
                _consentGiven = true;
                _launchResult = null;
              }),
              icon: const Icon(Icons.replay, color: Colors.white),
              label: const Text('Resoumettre',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.orange,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  minimumSize: const Size(200, 48)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSdkErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: AppColors.red),
            const SizedBox(height: 20),
            const Text('Erreur inattendue',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.red)),
            const SizedBox(height: 12),
            Text(
              'Une erreur s\'est produite lors du lancement de la vérification. '
              'Vérifiez votre connexion et réessayez.',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.textSecondaryColor, height: 1.5),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => setState(() {
                _step = _Step.consent;
                _launchResult = null;
              }),
              icon: const Icon(Icons.refresh, color: Colors.white),
              label: const Text('Réessayer',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  minimumSize: const Size(180, 48)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sub-widgets ──────────────────────────────────────────────────────────────

class _BenefitRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _BenefitRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: AppColors.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(text,
                  style: TextStyle(
                      fontSize: 13,
                      color: context.textPrimaryColor,
                      height: 1.5)),
            ),
          ),
        ],
      ),
    );
  }
}

class _DocTypeCard extends StatelessWidget {
  final DocumentType docType;
  final bool selected;
  final VoidCallback onTap;
  const _DocTypeCard({
    required this.docType,
    required this.selected,
    required this.onTap,
  });

  static const _icons = {
    DocumentType.nationalId: Icons.credit_card_outlined,
    DocumentType.passport: Icons.book_outlined,
    DocumentType.drivingLicense: Icons.drive_eta_outlined,
  };

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryLight : context.surfaceColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.primary : context.borderColor,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(children: [
          Icon(_icons[docType]!,
              size: 28,
              color: selected ? AppColors.primary : context.textSecondaryColor),
          const SizedBox(width: 16),
          Expanded(
            child: Text(docType.label,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? AppColors.primary
                        : context.textPrimaryColor)),
          ),
          if (selected)
            const Icon(Icons.check_circle, color: AppColors.primary, size: 22),
        ]),
      ),
    );
  }
}
