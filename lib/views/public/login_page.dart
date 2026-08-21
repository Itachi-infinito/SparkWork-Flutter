import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/auth_service.dart';
import '../../services/session_service.dart';

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
      await ref
          .read(authServiceProvider)
          .signIn(_emailCtrl.text.trim(), _passwordCtrl.text);
      // signIn() n'assure que l'authentification Firebase — la session
      // applicative (lecture du profil Firestore par SessionNotifier) se
      // résout de façon asynchrone. Sans cette attente, un compte
      // authentifié mais sans document Firestore (compte incomplet, App
      // Check refusé, etc.) laisse l'utilisateur bloqué sur cette page sans
      // aucun message ni redirection.
      final loggedIn = await _waitForSession();
      if (!loggedIn && mounted) {
        setState(() =>
            _error = AppLocalizations.of(context)!.loginErrorIncompleteAccount);
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = _errorMessage(AppLocalizations.of(context)!, e.code));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<bool> _waitForSession() async {
    for (var i = 0; i < 24; i++) {
      final state = ref.read(sessionProvider);
      if (!state.isLoading) return state.isLoggedIn;
      await Future.delayed(const Duration(milliseconds: 250));
    }
    return ref.read(sessionProvider).isLoggedIn;
  }

  Future<void> _forgotPassword() async {
    final loc = AppLocalizations.of(context)!;
    final emailCtrl = TextEditingController(text: _emailCtrl.text.trim());
    final sent = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.loginForgotPasswordTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              loc.loginForgotPasswordBody,
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              autofocus: true,
              decoration: InputDecoration(
                labelText: loc.loginEmail,
                prefixIcon: const Icon(Icons.email_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(loc.loginCancel),
          ),
          ElevatedButton(
            onPressed: () async {
              final email = emailCtrl.text.trim();
              if (email.isEmpty || !email.contains('@')) return;
              final (ok, _) =
                  await ref.read(authServiceProvider).sendPasswordReset(email);
              if (ctx.mounted) Navigator.pop(ctx, ok);
            },
            child: Text(loc.loginSend),
          ),
        ],
      ),
    );
    if (sent == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(loc.loginResetEmailSent),
        backgroundColor: AppColors.green,
      ));
    }
  }

  String _errorMessage(AppLocalizations loc, String code) {
    switch (code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return loc.loginErrorWrongCredentials;
      case 'too-many-requests':
        return loc.loginErrorTooManyRequests;
      default:
        return loc.loginErrorGeneric;
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Gradient header
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(
                  24, MediaQuery.of(context).padding.top + 16, 24, 36),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1E0A3C), AppColors.primary],
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
                  const SizedBox(height: 20),
                  const Icon(Icons.bolt, color: Colors.white, size: 32),
                  const SizedBox(height: 10),
                  Text(loc.loginWelcomeBack,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5)),
                  const SizedBox(height: 4),
                  Text(loc.loginSubtitle,
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.75), fontSize: 14)),
                ],
              ),
            ),

            // Form
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
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline,
                                color: AppColors.red, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                                child: Text(_error!,
                                    style: const TextStyle(
                                        color: AppColors.red, fontSize: 13))),
                          ],
                        ),
                      ),
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: loc.loginEmail,
                        prefixIcon: const Icon(Icons.email_outlined),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return loc.loginEmailRequired;
                        if (!v.contains('@')) return loc.loginEmailInvalid;
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordCtrl,
                      obscureText: _obscure,
                      decoration: InputDecoration(
                        labelText: loc.loginPassword,
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return loc.loginPasswordRequired;
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _forgotPassword,
                        style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 32)),
                        child: Text(loc.loginForgotPassword,
                            style: const TextStyle(
                                color: AppColors.primary, fontSize: 13)),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Gradient CTA button
                    Container(
                      width: double.infinity,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.primaryDark, AppColors.primary],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                              color: AppColors.primaryGlow,
                              blurRadius: 16,
                              offset: const Offset(0, 4)),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _loading ? null : _login,
                          borderRadius: BorderRadius.circular(14),
                          child: Center(
                            child: _loading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2))
                                : Text(loc.loginSubmit,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                    Center(
                      child: GestureDetector(
                        onTap: () => context.push('/register'),
                        child: RichText(
                          text: TextSpan(
                            text: loc.loginNoAccount,
                            style: const TextStyle(color: AppColors.textSecondary),
                            children: [
                              TextSpan(
                                text: loc.loginSignUp,
                                style: const TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600),
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
          ],
        ),
      ),
    );
  }
}
