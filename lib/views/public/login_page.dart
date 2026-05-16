import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../services/auth_service.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      final user = await ref.read(authServiceProvider).login(
        _emailCtrl.text.trim(),
        _passwordCtrl.text,
      );
      if (!mounted) return;
      if (user == null) {
        setState(() { _error = 'Email ou mot de passe incorrect.'; });
      } else {
        context.go(user.role == 'recruiter' ? '/recruiter/home' : '/candidate/home');
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
        title: const Text('Connexion'),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              Text('Bon retour !',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  )),
              const SizedBox(height: 6),
              const Text('Connectez-vous à votre compte',
                  style: TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 32),
              if (_error != null)
                Container(
                  padding: const EdgeInsets.all(14),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: AppColors.redLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppColors.red, size: 18),
                      const SizedBox(width: 10),
                      Expanded(child: Text(_error!,
                          style: const TextStyle(color: AppColors.red, fontSize: 13))),
                    ],
                  ),
                ),
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Email requis';
                  if (!v.contains('@')) return 'Email invalide';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordCtrl,
                obscureText: _obscure,
                decoration: InputDecoration(
                  labelText: 'Mot de passe',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Mot de passe requis';
                  return null;
                },
              ),
              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: _loading ? null : _login,
                child: _loading
                    ? const SizedBox(height: 20, width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Se connecter'),
              ),
              const SizedBox(height: 20),
              Center(
                child: GestureDetector(
                  onTap: () => context.push('/register'),
                  child: RichText(
                    text: const TextSpan(
                      text: "Pas encore de compte ? ",
                      style: TextStyle(color: AppColors.textSecondary),
                      children: [
                        TextSpan(
                          text: "S'inscrire",
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}