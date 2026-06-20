import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_skills.dart';
import '../../core/widgets/partner_code_field.dart';
import '../../core/widgets/terms_checkbox.dart';
import '../../models/candidate_profile.dart';
import '../../models/partner.dart';
import '../../repositories/candidate_profile_repository.dart';
import '../../services/auth_service.dart';
import '../../services/partner_service.dart';

class RegisterCandidatePage extends ConsumerStatefulWidget {
  const RegisterCandidatePage({super.key});

  @override
  ConsumerState<RegisterCandidatePage> createState() =>
      _RegisterCandidatePageState();
}

class _RegisterCandidatePageState extends ConsumerState<RegisterCandidatePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final _salaryMinCtrl = TextEditingController();
  final _salaryMaxCtrl = TextEditingController();

  final List<String> _contractTypes = [];
  String? _level;
  final List<String> _remotePreferences = [];
  final List<String> _skills = [];
  bool _loading = false;
  String? _error;
  bool _obscure = true;
  bool _acceptedTerms = false;
  Partner? _resolvedPartner;

  @override
  void dispose() {
    _nameCtrl.dispose(); _emailCtrl.dispose(); _passwordCtrl.dispose();
    _locationCtrl.dispose(); _bioCtrl.dispose();
    _salaryMinCtrl.dispose(); _salaryMaxCtrl.dispose();
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

    // Capture everything before first await so we can complete the write
    // even if GoRouter redirects (auth state change) and unmounts this widget.
    final authService = ref.read(authServiceProvider);
    final profileRepo = ref.read(candidateProfileRepositoryProvider);
    final fullName = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    final location = _locationCtrl.text.trim();
    final bio = _bioCtrl.text.trim();
    final salaryMin = int.tryParse(_salaryMinCtrl.text.trim()) ?? 0;
    final salaryMax = int.tryParse(_salaryMaxCtrl.text.trim()) ?? 0;
    final contractType = _contractTypes.join(',');
    final level = _level ?? '';
    final remotePreference = _remotePreferences.join(',');
    final skills = List<String>.from(_skills);

    try {
      final (ok, msg) = await authService.register(
        fullName: fullName,
        email: email,
        password: password,
        role: 'candidate',
      );
      if (!ok) {
        if (mounted) setState(() => _error = msg);
        return;
      }

      final uid = authService.currentUser!.uid;
      final profile = CandidateProfile(
        profileId: '',
        userId: uid,
        fullName: fullName,
        location: location,
        desiredContractType: contractType,
        desiredLevel: level,
        skills: skills,
        bio: bio,
        desiredSalaryMin: salaryMin,
        desiredSalaryMax: salaryMax,
        remotePreference: remotePreference,
      );
      // Write profile even if widget was already unmounted by GoRouter redirect.
      await profileRepo.insertProfile(profile);

      // Code partenaire — n'a jamais d'incidence sur le succès de l'inscription
      final partner = _resolvedPartner;
      if (partner != null) {
        try {
          await ref.read(partnerServiceProvider).registerReferral(
                partnerId: partner.partnerId,
                referredUserId: uid,
                referredUserType: 'candidate',
                partnerName: partner.name,
                candidateId: uid,
              );
        } catch (_) {
          // Le parrainage est secondaire — on ne bloque jamais l'inscription
        }
      }

      if (mounted) context.go('/candidate/home');
    } catch (e) {
      if (mounted) setState(() => _error = 'Erreur lors de l\'inscription.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ... (garde le reste du build() identique à l'original)

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Profil candidat'),
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
                  const SizedBox(height: 14),
                  const Icon(Icons.person_search_rounded,
                      color: Colors.white, size: 28),
                  const SizedBox(height: 8),
                  const Text('Profil candidat',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5)),
                  const SizedBox(height: 4),
                  Text('Trouvez votre prochain emploi Horeca',
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
              _buildSection('Informations personnelles'),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Nom complet *'),
                validator: (v) =>
                    (v == null || v.trim().length < 2) ? 'Nom requis (min 2 caractères)' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email *'),
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
                  suffixIcon: IconButton(
                    icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.length < 6) return 'Minimum 6 caractères';
                  return null;
                },
              ),
              const SizedBox(height: 24),
              _buildSection('Localisation & préférences'),
              const SizedBox(height: 12),
              TextFormField(
                controller: _locationCtrl,
                decoration: const InputDecoration(
                  labelText: 'Ville / Région',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
              ),
              const SizedBox(height: 12),
              // Multi-sélection : un candidat peut viser CDI ET CDD, etc.
              const Text('Type(s) de contrat souhaité(s)',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: AppSkills.contractTypes
                    .map((c) => FilterChip(
                          label: Text(c),
                          selected: _contractTypes.contains(c),
                          onSelected: (sel) => setState(() {
                            sel
                                ? _contractTypes.add(c)
                                : _contractTypes.remove(c);
                          }),
                          selectedColor: AppColors.primaryLight,
                          checkmarkColor: AppColors.primary,
                        ))
                    .toList(),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _level,
                decoration: const InputDecoration(labelText: 'Niveau d\'expérience'),
                items: AppSkills.levels
                    .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                    .toList(),
                onChanged: (v) => setState(() => _level = v),
              ),
              const SizedBox(height: 16),
              const Text('Mode(s) de travail accepté(s)',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: AppSkills.remoteModes
                    .map((r) => FilterChip(
                          label: Text(r),
                          selected: _remotePreferences.contains(r),
                          onSelected: (sel) => setState(() {
                            sel
                                ? _remotePreferences.add(r)
                                : _remotePreferences.remove(r);
                          }),
                          selectedColor: AppColors.primaryLight,
                          checkmarkColor: AppColors.primary,
                        ))
                    .toList(),
              ),
              const SizedBox(height: 24),
              _buildSection('Prétentions salariales (€/mois)'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _salaryMinCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Min'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _salaryMaxCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Max'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildSection('Compétences'),
              const SizedBox(height: 12),
              _SkillSelector(
                selected: _skills,
                onChanged: (skills) => setState(() {
                  _skills
                    ..clear()
                    ..addAll(skills);
                }),
              ),
              const SizedBox(height: 24),
              _buildSection('Bio'),
              const SizedBox(height: 12),
              TextFormField(
                controller: _bioCtrl,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Présentez-vous brièvement...',
                  alignLabelWithHint: true,
                ),
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
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loading ? null : _register,
                child: _loading
                    ? const SizedBox(height: 20, width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Créer mon compte'),
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

  Widget _buildSection(String title) {
    return Text(title,
        style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            color: AppColors.textPrimary));
  }
}

class _SkillSelector extends StatefulWidget {
  final List<String> selected;
  final ValueChanged<List<String>> onChanged;

  const _SkillSelector({required this.selected, required this.onChanged});

  @override
  State<_SkillSelector> createState() => _SkillSelectorState();
}

class _SkillSelectorState extends State<_SkillSelector> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ElevatedButton.icon(
          onPressed: () {
            showModalBottomSheet(
              context: context,
              builder: (ctx) => ListView(
                children: AppSkills.horecaSkills
                    .where((s) => !widget.selected.contains(s))
                    .map((s) => ListTile(
                          title: Text(s),
                          onTap: () {
                            widget.onChanged([...widget.selected, s]);
                            Navigator.pop(ctx);
                          },
                        ))
                    .toList(),
              ),
            );
          },
          icon: const Icon(Icons.add),
          label: const Text('Ajouter une compétence'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
          ),
        ),
        if (widget.selected.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: widget.selected
                .map((s) => Chip(
                      label: Text(s, style: const TextStyle(fontSize: 12)),
                      backgroundColor: AppColors.primaryLight,
                      labelStyle: const TextStyle(color: AppColors.primary),
                      deleteIcon: const Icon(Icons.close,
                          size: 14, color: AppColors.primary),
                      onDeleted: () {
                        final updated = [...widget.selected]..remove(s);
                        widget.onChanged(updated);
                      },
                    ))
                .toList(),
          ),
        ],
      ],
    );
  }
}
