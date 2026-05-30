import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_skills.dart';
import '../../models/candidate_profile.dart';
import '../../repositories/candidate_profile_repository.dart';
import '../../services/session_service.dart';

class EditCandidateProfilePage extends ConsumerStatefulWidget {
  const EditCandidateProfilePage({super.key});

  @override
  ConsumerState<EditCandidateProfilePage> createState() =>
      _EditCandidateProfilePageState();
}

class _EditCandidateProfilePageState
    extends ConsumerState<EditCandidateProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _locationCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final _salaryMinCtrl = TextEditingController();
  final _salaryMaxCtrl = TextEditingController();

  CandidateProfile? _profile;
  String? _contractType;
  String? _level;
  String? _remotePreference;
  List<String> _skills = [];
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final userId = ref.read(sessionProvider).userId;
    final profile = await ref
        .read(candidateProfileRepositoryProvider)
        .getProfile(userId);
    if (profile != null && mounted) {
      setState(() {
        _profile = profile;
        _locationCtrl.text = profile.location;
        _bioCtrl.text = profile.bio;
        _salaryMinCtrl.text =
            profile.desiredSalaryMin > 0 ? profile.desiredSalaryMin.toString() : '';
        _salaryMaxCtrl.text =
            profile.desiredSalaryMax > 0 ? profile.desiredSalaryMax.toString() : '';
        _contractType = AppSkills.contractTypes.contains(profile.desiredContractType)
          ? profile.desiredContractType
          : null;
        _level = AppSkills.levels.contains(profile.desiredLevel)
            ? profile.desiredLevel
            : null;
        _remotePreference = AppSkills.remoteModes.contains(profile.remotePreference)
            ? profile.remotePreference
            : null;
        _skills = profile.skillList.toList();
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _profile == null) return;
    setState(() => _saving = true);
    try {
      final updated = _profile!.copyWith(
        location: _locationCtrl.text.trim(),
        bio: _bioCtrl.text.trim(),
        desiredSalaryMin: int.tryParse(_salaryMinCtrl.text.trim()) ?? 0,
        desiredSalaryMax: int.tryParse(_salaryMaxCtrl.text.trim()) ?? 0,
        desiredContractType: _contractType ?? '',
        desiredLevel: _level ?? '',
        remotePreference: _remotePreference ?? '',
        skills: AppSkills.formatSkills(_skills),
      );
      await ref.read(candidateProfileRepositoryProvider).updateProfile(updated);
      ref.read(profileVersionProvider.notifier).state++; // ← ajoute cette ligne
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profil mis à jour !'),
          backgroundColor: AppColors.green,
        ),
      );
      context.pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _locationCtrl.dispose();
    _bioCtrl.dispose();
    _salaryMinCtrl.dispose();
    _salaryMaxCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Modifier le profil'),
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Sauvegarder',
                    style: TextStyle(
                        color: AppColors.primary, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                      
                      decoration: const InputDecoration(
                          labelText: 'Type de contrat souhaité'),
                      items: AppSkills.contractTypes
                          .map((c) =>
                              DropdownMenuItem(value: c, child: Text(c)))
                          .toList(),
                      onChanged: (v) => setState(() => _contractType = v),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _level,
                      decoration: const InputDecoration(
                          labelText: "Niveau d'expérience"),
                      items: AppSkills.levels
                          .map((l) =>
                              DropdownMenuItem(value: l, child: Text(l)))
                          .toList(),
                      onChanged: (v) => setState(() => _level = v),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _remotePreference,
                      decoration: const InputDecoration(
                          labelText: 'Préférence télétravail'),
                      items: AppSkills.remoteModes
                          .map((r) =>
                              DropdownMenuItem(value: r, child: Text(r)))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _remotePreference = v),
                    ),
                    const SizedBox(height: 20),
                    const Text('Prétentions salariales (€/mois)',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _salaryMinCtrl,
                            keyboardType: TextInputType.number,
                            decoration:
                                const InputDecoration(labelText: 'Min'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _salaryMaxCtrl,
                            keyboardType: TextInputType.number,
                            decoration:
                                const InputDecoration(labelText: 'Max'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Text('Compétences',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 12),
                    _SkillSelector(
                      selected: _skills,
                      onChanged: (updated) =>
                          setState(() => _skills = updated),
                    ),
                    const SizedBox(height: 20),
                    const Text('Bio',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _bioCtrl,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: 'Présentez-vous...',
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
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