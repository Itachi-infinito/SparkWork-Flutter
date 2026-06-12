import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/company_number.dart';
import '../../core/widgets/terms_checkbox.dart';
import '../../models/recruiter_profile.dart';
import '../../repositories/recruiter_profile_repository.dart';
import '../../services/auth_service.dart';

class RegisterRecruiterPage extends ConsumerStatefulWidget {
  const RegisterRecruiterPage({super.key});

  @override
  ConsumerState<RegisterRecruiterPage> createState() =>
      _RegisterRecruiterPageState();
}

class _RegisterRecruiterPageState
    extends ConsumerState<RegisterRecruiterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _companyCtrl = TextEditingController();
  final _companyNumberCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _obscure = true;
  bool _acceptedTerms = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _companyCtrl.dispose();
    _companyNumberCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_acceptedTerms) {
      setState(() =>
          _error = 'Vous devez accepter les conditions d\'utilisation.');
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
      ));
      if (mounted) context.go('/recruiter/home');
    } catch (e) {
      if (mounted) setState(() => _error = 'Erreur lors de l\'inscription.');
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Compte recruteur'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Gradient header
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(
                  24, MediaQuery.of(context).padding.top + 12, 24, 28),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF059669), AppColors.green],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: Colors.white, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(height: 14),
                  const Icon(Icons.business_center_rounded,
                      color: Colors.white, size: 28),
                  const SizedBox(height: 8),
                  const Text('Compte recruteur',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5)),
                  const SizedBox(height: 4),
                  Text('Trouvez les meilleurs talents Horeca',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.72),
                          fontSize: 14)),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    if (_error != null)
                Container(
                  padding: const EdgeInsets.all(14),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: AppColors.redLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(_error!,
                      style: const TextStyle(color: AppColors.red)),
                ),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Votre nom complet *',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (v) =>
                    (v == null || v.trim().length < 2) ? 'Nom requis' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _companyCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nom de l\'établissement *',
                  prefixIcon: Icon(Icons.business_outlined),
                ),
                validator: (v) =>
                    (v == null || v.trim().length < 2) ? 'Nom établissement requis' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _companyNumberCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Numéro d\'entreprise (BCE) *',
                  hintText: 'ex: 0123.456.749 ou BE0123456749',
                  prefixIcon: Icon(Icons.verified_outlined),
                  helperText:
                      'Vérifié automatiquement — atteste que vous êtes une entreprise.',
                  helperMaxLines: 2,
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Numéro d\'entreprise requis';
                  }
                  if (!CompanyNumber.isValid(v)) {
                    return 'Numéro BCE invalide (10 chiffres, clé de contrôle incorrecte)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email professionnel *',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Email requis';
                  if (!v.contains('@')) return 'Email invalide';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordCtrl,
                obscureText: _obscure,
                decoration: InputDecoration(
                  labelText: 'Mot de passe *',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.length < 6) return 'Minimum 6 caractères';
                  return null;
                },
              ),
              const SizedBox(height: 24),
              TermsCheckbox(
                value: _acceptedTerms,
                onChanged: (v) => setState(() => _acceptedTerms = v),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loading ? null : _register,
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.green),
                    child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('Créer mon compte recruteur'),
              ),
              const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}