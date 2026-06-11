import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/terms_checkbox.dart';
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
    try {
      final fullName = '${_nameCtrl.text.trim()} - ${_companyCtrl.text.trim()}';
      final (ok, msg) = await ref.read(authServiceProvider).register(
        fullName: fullName,
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
        role: 'recruiter',
      );
      if (!mounted) return;
      if (!ok) {
        setState(() { _error = msg; });
      } else {
        context.go('/recruiter/home');
      }
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Compte recruteur'),
        backgroundColor: AppColors.background,
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