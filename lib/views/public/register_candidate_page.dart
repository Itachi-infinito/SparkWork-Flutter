import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_skills.dart';
import '../../core/constants/app_theme_ext.dart';
import '../../core/widgets/onboarding_step_scaffold.dart';
import '../../core/widgets/partner_code_field.dart';
import '../../core/widgets/sector_selector.dart';
import '../../core/widgets/terms_checkbox.dart';
import '../../models/candidate_profile.dart';
import '../../models/partner.dart';
import '../../repositories/candidate_profile_repository.dart';
import '../../services/auth_service.dart';
import '../../services/partner_service.dart';
import '../../l10n/generated/app_localizations.dart';

const _kCandidateGradient = LinearGradient(
  colors: [Color(0xFF1E0A3C), AppColors.primary],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

class RegisterCandidatePage extends ConsumerStatefulWidget {
  const RegisterCandidatePage({super.key});

  @override
  ConsumerState<RegisterCandidatePage> createState() =>
      _RegisterCandidatePageState();
}

class _RegisterCandidatePageState extends ConsumerState<RegisterCandidatePage> {
  final _personalFormKey = GlobalKey<FormState>();
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
  final List<String> _sectors = [];
  int _step = 0;
  bool _loading = false;
  String? _error;
  bool _obscure = true;
  bool _acceptedTerms = false;
  Partner? _resolvedPartner;

  static const _totalSteps = 5;

  @override
  void dispose() {
    _nameCtrl.dispose(); _emailCtrl.dispose(); _passwordCtrl.dispose();
    _locationCtrl.dispose(); _bioCtrl.dispose();
    _salaryMinCtrl.dispose(); _salaryMaxCtrl.dispose();
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
    switch (_step) {
      case 0:
        if (_sectors.isEmpty) {
          setState(() => _error = loc.regCandSectorsRequired);
          return;
        }
        break;
      case 1:
        if (!_personalFormKey.currentState!.validate()) return;
        break;
      case 4:
        _register();
        return;
    }
    setState(() => _step += 1);
  }

  Future<void> _register() async {
    final loc = AppLocalizations.of(context)!;
    if (!_acceptedTerms) {
      setState(() => _error = loc.regCandTermsRequired);
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
    final sectors = List<String>.from(_sectors);

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
        sectors: sectors,
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
      if (mounted) setState(() => _error = loc.regCandGenericError);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final steps = <(String, String, Widget)>[
      (loc.regCandSectionSectors, loc.regCandSectionSectorsHint, _buildSectorsStep()),
      (loc.regCandSectionPersonal, loc.regCandStepPersonalSubtitle, _buildPersonalStep(loc)),
      (loc.regCandSectionLocation, loc.regCandStepLocationSubtitle, _buildLocationStep(loc)),
      (loc.regCandSectionSkills, loc.regCandStepSkillsSubtitle, _buildSkillsStep(loc)),
      (loc.regCandTitle, loc.regCandStepFinalSubtitle, _buildFinalStep(loc)),
    ];
    final current = steps[_step];

    return OnboardingStepScaffold(
      step: _step,
      totalSteps: _totalSteps,
      title: current.$1,
      subtitle: current.$2,
      headerIcon: Icons.person_search_rounded,
      headerGradient: _kCandidateGradient,
      onBack: _goBack,
      onNext: _loading ? null : _goNext,
      nextLabel: _step == _totalSteps - 1 ? loc.regCandSubmit : loc.wizardNext,
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
        // Les compétences déjà choisies hors du nouveau périmètre de
        // secteurs n'ont plus de sens à proposer/conserver.
        final available = AppSkills.skillsForSectors(_sectors).toSet();
        _skills.removeWhere((s) => !available.contains(s));
      }),
    );
  }

  Widget _buildPersonalStep(AppLocalizations loc) {
    return Form(
      key: _personalFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: _nameCtrl,
            decoration: InputDecoration(labelText: loc.regCandFullName),
            validator: (v) =>
                (v == null || v.trim().length < 2) ? loc.regCandFullNameError : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(labelText: loc.regCandEmail),
            validator: (v) {
              if (v == null || v.isEmpty) return loc.regCandEmailRequired;
              if (!v.contains('@')) return loc.regCandEmailInvalid;
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _passwordCtrl,
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: loc.regCandPassword,
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            validator: (v) {
              if (v == null || v.length < 6) return loc.regCandPasswordError;
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLocationStep(AppLocalizations loc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _locationCtrl,
          decoration: InputDecoration(
            labelText: loc.regCandLocation,
            prefixIcon: const Icon(Icons.location_on_outlined),
          ),
        ),
        const SizedBox(height: 20),
        _PreferenceCard(
          icon: Icons.description_outlined,
          title: loc.regCandContractTypes,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: AppSkills.contractTypes
                .map((c) => _PreferenceChip(
                      label: c,
                      selected: _contractTypes.contains(c),
                      onSelected: (sel) => setState(() {
                        sel
                            ? _contractTypes.add(c)
                            : _contractTypes.remove(c);
                      }),
                    ))
                .toList(),
          ),
        ),
        const SizedBox(height: 16),
        _PreferenceCard(
          icon: Icons.bar_chart_outlined,
          title: loc.regCandLevel,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: AppSkills.levels
                .map((l) => _PreferenceChip(
                      label: l,
                      selected: _level == l,
                      onSelected: (sel) =>
                          setState(() => _level = sel ? l : null),
                    ))
                .toList(),
          ),
        ),
        const SizedBox(height: 16),
        _PreferenceCard(
          icon: Icons.home_work_outlined,
          title: loc.regCandRemoteModes,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: AppSkills.remoteModes
                .map((r) => _PreferenceChip(
                      label: r,
                      selected: _remotePreferences.contains(r),
                      onSelected: (sel) => setState(() {
                        sel
                            ? _remotePreferences.add(r)
                            : _remotePreferences.remove(r);
                      }),
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildSkillsStep(AppLocalizations loc) {
    return _SkillSelector(
      selected: _skills,
      availableSkills: AppSkills.skillsForSectors(_sectors),
      addSkillLabel: loc.regCandAddSkill,
      onChanged: (skills) => setState(() {
        _skills
          ..clear()
          ..addAll(skills);
      }),
    );
  }

  Widget _buildFinalStep(AppLocalizations loc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSection(loc.regCandSectionSalary),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _salaryMinCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: loc.regCandSalaryMin),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _salaryMaxCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: loc.regCandSalaryMax),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _buildSection(loc.regCandSectionBio),
        const SizedBox(height: 12),
        TextFormField(
          controller: _bioCtrl,
          maxLines: 4,
          decoration: InputDecoration(
            labelText: loc.regCandBioHint,
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
      ],
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

class _PreferenceCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;

  const _PreferenceCard({
    required this.icon,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(title,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: context.textPrimaryColor)),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _PreferenceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;

  const _PreferenceChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onSelected(!selected),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : context.surfaceVariantColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? AppColors.primary : context.borderColor),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : context.textPrimaryColor)),
      ),
    );
  }
}

class _SkillSelector extends StatefulWidget {
  final List<String> selected;
  final List<String> availableSkills;
  final String addSkillLabel;
  final ValueChanged<List<String>> onChanged;

  const _SkillSelector({
    required this.selected,
    required this.availableSkills,
    required this.addSkillLabel,
    required this.onChanged,
  });

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
                children: widget.availableSkills
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
          label: Text(widget.addSkillLabel),
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
