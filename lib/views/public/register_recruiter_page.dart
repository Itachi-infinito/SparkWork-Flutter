import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/company_number.dart';
import '../../core/widgets/onboarding_step_scaffold.dart';
import '../../core/widgets/partner_code_field.dart';
import '../../core/widgets/sector_selector.dart';
import '../../core/widgets/terms_checkbox.dart';
import '../../models/partner.dart';
import '../../models/recruiter_profile.dart';
import '../../repositories/recruiter_profile_repository.dart';
import '../../services/auth_service.dart';
import '../../services/partner_service.dart';
import '../../l10n/generated/app_localizations.dart';

const _kRecruiterGradient = LinearGradient(
  colors: [Color(0xFF059669), AppColors.green],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

class RegisterRecruiterPage extends ConsumerStatefulWidget {
  const RegisterRecruiterPage({super.key});

  @override
  ConsumerState<RegisterRecruiterPage> createState() =>
      _RegisterRecruiterPageState();
}

class _RegisterRecruiterPageState
    extends ConsumerState<RegisterRecruiterPage> {
  final _accountFormKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _companyCtrl = TextEditingController();
  final _companyNumberCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _obscure = true;
  bool _acceptedTerms = false;
  Partner? _resolvedPartner;
  final List<String> _sectors = [];
  int _step = 0;

  static const _totalSteps = 2;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _companyCtrl.dispose();
    _companyNumberCtrl.dispose();
    super.dispose();
  }

  void _goBack() {
    if (_step == 0) {
      context.pop();
      return;
    }
    setState(() { _step -= 1; _error = null; });
  }

  void _goNext() {
    final loc = AppLocalizations.of(context)!;
    setState(() => _error = null);
    if (_step == 0) {
      if (_sectors.isEmpty) {
        setState(() => _error = loc.regRecSectorsRequired);
        return;
      }
      setState(() => _step = 1);
      return;
    }
    _register();
  }

  Future<void> _register() async {
    final loc = AppLocalizations.of(context)!;
    if (!_accountFormKey.currentState!.validate()) return;
    if (!_acceptedTerms) {
      setState(() => _error = loc.regRecTermsRequired);
      return;
    }
    setState(() { _loading = true; _error = null; });

    // Capture avant le premier await : GoRouter peut démonter le widget
    // dès que l'état d'authentification change.
    final authService = ref.read(authServiceProvider);
    final profileRepo = ref.read(recruiterProfileRepositoryProvider);
    final name = _nameCtrl.text.trim();
    final company = _companyCtrl.text.trim();
    final companyNumber = CompanyNumber.normalize(_companyNumberCtrl.text);
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    final sectors = List<String>.from(_sectors);

    try {
      final fullName = '$name - $company';
      final (ok, msg) = await authService.register(
        fullName: fullName,
        email: email,
        password: password,
        role: 'recruiter',
        extraData: {
          'companyNumber': companyNumber,
          // La structure du numéro BCE a été validée (clé mod-97)
          'companyNumberVerified': true,
        },
      );
      if (!ok) {
        if (mounted) setState(() => _error = msg);
        return;
      }
      // Crée le profil entreprise (nom + numéro BCE) pour les cartes de swipe
      final uid = authService.currentUser!.uid;
      await profileRepo.upsertProfile(RecruiterProfile(
        profileId: '',
        userId: uid,
        companyName: company,
        companyNumber: companyNumber,
        sectors: sectors,
      ));

      // Code partenaire — n'a jamais d'incidence sur le succès de l'inscription
      final partner = _resolvedPartner;
      if (partner != null) {
        try {
          await ref.read(partnerServiceProvider).registerReferral(
                partnerId: partner.partnerId,
                referredUserId: uid,
                referredUserType: 'recruiter',
                partnerName: partner.name,
                candidateId: uid,
              );
        } catch (_) {
          // Le parrainage est secondaire — on ne bloque jamais l'inscription
        }
      }

      if (mounted) context.go('/recruiter/home');
    } catch (e) {
      if (mounted) setState(() => _error = loc.regRecGenericError);
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final steps = <(String, String, Widget)>[
      (loc.regRecSectionSectors, loc.regRecSectionSectorsHint, _buildSectorsStep()),
      (loc.regRecStepAccountTitle, loc.regRecStepAccountSubtitle, _buildAccountStep(loc)),
    ];
    final current = steps[_step];

    return OnboardingStepScaffold(
      step: _step,
      totalSteps: _totalSteps,
      title: current.$1,
      subtitle: current.$2,
      headerIcon: Icons.business_center_rounded,
      headerGradient: _kRecruiterGradient,
      buttonColor: AppColors.green,
      onBack: _goBack,
      onNext: _loading ? null : _goNext,
      nextLabel: _step == _totalSteps - 1 ? loc.regRecSubmit : loc.wizardNext,
      loading: _loading,
      errorText: _error,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: KeyedSubtree(key: ValueKey(_step), child: current.$3),
      ),
    );
  }

  Widget _buildSectorsStep() {
    return SectorSelector(
      selected: _sectors,
      onChanged: (sectors) => setState(() {
        _sectors
          ..clear()
          ..addAll(sectors);
      }),
    );
  }

  Widget _buildAccountStep(AppLocalizations loc) {
    return Form(
      key: _accountFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: _nameCtrl,
            decoration: InputDecoration(
              labelText: loc.regRecFullName,
              prefixIcon: const Icon(Icons.person_outline),
            ),
            validator: (v) =>
                (v == null || v.trim().length < 2) ? loc.regRecFullNameError : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _companyCtrl,
            decoration: InputDecoration(
              labelText: loc.regRecCompanyName,
              prefixIcon: const Icon(Icons.business_outlined),
            ),
            validator: (v) =>
                (v == null || v.trim().length < 2) ? loc.regRecCompanyNameError : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _companyNumberCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: loc.regRecCompanyNumber,
              hintText: loc.regRecCompanyNumberHint,
              prefixIcon: const Icon(Icons.verified_outlined),
              helperText: loc.regRecCompanyNumberHelper,
              helperMaxLines: 2,
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return loc.regRecCompanyNumberRequired;
              }
              if (!CompanyNumber.isValid(v)) {
                return loc.regRecCompanyNumberInvalid;
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: loc.regRecEmail,
              prefixIcon: const Icon(Icons.email_outlined),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return loc.regRecEmailRequired;
              if (!v.contains('@')) return loc.regRecEmailInvalid;
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _passwordCtrl,
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: loc.regRecPassword,
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(_obscure
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            validator: (v) {
              if (v == null || v.length < 6) return loc.regRecPasswordError;
              return null;
            },
          ),
          const SizedBox(height: 24),
          PartnerCodeField(
            onResolved: (p) => setState(() => _resolvedPartner = p),
          ),
          const SizedBox(height: 24),
          TermsCheckbox(
            value: _acceptedTerms,
            onChanged: (v) => setState(() => _acceptedTerms = v),
          ),
        ],
      ),
    );
  }
}
