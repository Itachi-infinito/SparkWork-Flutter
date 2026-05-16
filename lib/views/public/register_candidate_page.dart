import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_skills.dart';
import '../../models/candidate_profile.dart';
import '../../repositories/candidate_profile_repository.dart';
import '../../services/auth_service.dart';
import '../../services/session_service.dart';

class RegisterCandidatePage extends ConsumerStatefulWidget {
  const RegisterCandidatePage({super.key});

  @override
  ConsumerState<RegisterCandidatePage> createState() =>
      _RegisterCandidatePageState();
}

class _RegisterCandidatePageState
    extends ConsumerState<RegisterCandidatePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final _salaryMinCtrl = TextEditingController();
  final _salaryMaxCtrl = TextEditingController();

  String? _contractType;
  String? _level;
  String? _remotePreference;
  final List<String> _skills = [];
  bool _loading = false;
  String? _error;
  bool _obscure = true;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _locationCtrl.dispose();
    _bioCtrl.dispose();
    _salaryMinCtrl.dispose();
    _salaryMaxCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      final (ok, msg) = await ref.read(authServiceProvider).register(
        fullName: _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
        role: 'candidate',
      );
      if (!mounted) return;
      if (!ok) { setState(() { _error = msg; }); return; }

      final userId = ref.read(sessionProvider).userId;
      final profile = CandidateProfile(
        profileId: 0,
        userId: userId,
        fullName: _nameCtrl.text.trim(),
        location: _locationCtrl.text.trim(),
        desiredContractType: _contractType ?? '',
        desiredLevel: _level ?? '',
        skills: AppSkills.formatSkills(_skills),
        bio: _bioCtrl.text.trim(),
        desiredSalaryMin: int.tryParse(_salaryMinCtrl.text.trim()) ?? 0,
        desiredSalaryMax: int.tryParse(_salaryMaxCtrl.text.trim()) ?? 0,
        remotePreference: _remotePreference ?? '',
        latitude: 0,
        longitude: 0,
      );
      await ref.read(candidateProfileRepositoryProvider).insertProfile(profile);
      if (!mounted) return;
      context.go('/candidate/home');
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Profil candidat'),
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
              DropdownButtonFormField<String>(
                value: _contractType,
                decoration: const InputDecoration(labelText: 'Type de contrat souhaité'),
                items: AppSkills.contractTypes
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => _contractType = v),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _level,
                decoration: const InputDecoration(labelText: 'Niveau d\'expérience'),
                items: AppSkills.levels
                    .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                    .toList(),
                onChanged: (v) => setState(() => _level = v),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _remotePreference,
                decoration: const InputDecoration(labelText: 'Préférence télétravail'),
                items: AppSkills.remoteModes
                    .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                    .toList(),
                onChanged: (v) => setState(() => _remotePreference = v),
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
              const SizedBox(height: 32),
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
  String? _pickerValue;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _pickerValue,
                hint: const Text('Ajouter une compétence'),
                items: AppSkills.horecaSkills
                    .where((s) => !widget.selected.contains(s))
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (v) {
                  if (v != null && !widget.selected.contains(v)) {
                    widget.onChanged([...widget.selected, v]);
                    setState(() => _pickerValue = null);
                  }
                },
              ),
            ),
          ],
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
                      deleteIcon:
                          const Icon(Icons.close, size: 14, color: AppColors.primary),
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
