import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../services/auth_service.dart';
import '../../services/session_service.dart';
import '../../services/database_service.dart';
import '../../models/candidate_profile.dart';

class RegisterCandidatePage extends ConsumerStatefulWidget {
  const RegisterCandidatePage({super.key});
  @override
  ConsumerState<RegisterCandidatePage> createState() => _RegisterCandidatePageState();
}

class _RegisterCandidatePageState extends ConsumerState<RegisterCandidatePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  bool _obscureConfirm = true;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose(); _emailCtrl.dispose();
    _passwordCtrl.dispose(); _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (_passwordCtrl.text != _confirmCtrl.text) {
      setState(() => _error = 'Les mots de passe ne correspondent pas.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final auth = ref.read(authServiceProvider);
      final (success, msg) = await auth.register(
        fullName: _nameCtrl.text, email: _emailCtrl.text,
        password: _passwordCtrl.text, role: 'Candidate',
      );
      if (!success) { setState(() { _error = msg; _loading = false; }); return; }

      final user = await ref.read(databaseServiceProvider).getUserByEmail(_emailCtrl.text.trim().toLowerCase());
      if (user == null) { setState(() { _error = 'Erreur création compte.'; _loading = false; }); return; }

      final db = ref.read(databaseServiceProvider);
      final dbConn = await db.database;
      await dbConn.insert('candidate_profiles', CandidateProfile(
        userId: user.userId, fullName: user.fullName, email: user.email,
      ).toMap());

      await ref.read(sessionProvider.notifier).login(
        userId: user.userId, userName: user.fullName,
        userEmail: user.email, userRole: user.role,
      );
      if (!mounted) return;
      context.go('/candidate/home');
    } catch (e) {
      setState(() { _error = 'Erreur : '; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded), onPressed: () => context.go('/register')),
        title: Text('Inscription candidat', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Form(
            key: _formKey,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SizedBox(height: 8),
              Text('Ton profil candidat', style: GoogleFonts.inter(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
              const SizedBox(height: 6),
              Text('Tu pourras compléter ton profil après l\'inscription.', style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary)),
              const SizedBox(height: 32),
              _label('Nom complet'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(hintText: 'Jean Dupont', prefixIcon: Icon(Icons.person_outline_rounded, color: AppColors.textLight)),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null,
              ),
              const SizedBox(height: 20),
              _label('Email'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(hintText: 'ton@email.com', prefixIcon: Icon(Icons.email_outlined, color: AppColors.textLight)),
                validator: (v) => (v == null || !v.contains('@')) ? 'Email invalide' : null,
              ),
              const SizedBox(height: 20),
              _label('Mot de passe'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _passwordCtrl, obscureText: _obscure,
                decoration: InputDecoration(
                  hintText: '••••••••',
                  prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.textLight),
                  suffixIcon: IconButton(icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: AppColors.textLight), onPressed: () => setState(() => _obscure = !_obscure)),
                ),
                validator: (v) => (v == null || v.length < 6) ? 'Minimum 6 caractères' : null,
              ),
              const SizedBox(height: 20),
              _label('Confirmer le mot de passe'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _confirmCtrl, obscureText: _obscureConfirm,
                decoration: InputDecoration(
                  hintText: '••••••••',
                  prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.textLight),
                  suffixIcon: IconButton(icon: Icon(_obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: AppColors.textLight), onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm)),
                ),
                validator: (v) => (v == null || v.isEmpty) ? 'Requis' : null,
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.redLight, borderRadius: BorderRadius.circular(10)),
                  child: Row(children: [
                    const Icon(Icons.error_outline_rounded, color: AppColors.red, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_error!, style: GoogleFonts.inter(color: AppColors.red, fontSize: 13))),
                  ]),
                ),
              ],
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _register,
                  child: _loading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text("Créer mon compte candidat"),
                ),
              ),
              const SizedBox(height: 32),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Text(text, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary));
}
