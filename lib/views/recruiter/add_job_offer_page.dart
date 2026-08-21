import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_theme_ext.dart';
import '../../core/constants/app_sectors.dart';
import '../../core/constants/app_skills.dart';
import '../../models/job_offer.dart';
import '../../repositories/job_offer_repository.dart';
import '../../repositories/recruiter_profile_repository.dart';
import '../../services/session_service.dart';
import '../../services/subscription_service.dart';
import '../shared/quota_reached_bottom_sheet.dart';
import '../../l10n/generated/app_localizations.dart';

class AddJobOfferPage extends ConsumerStatefulWidget {
  const AddJobOfferPage({super.key});

  @override
  ConsumerState<AddJobOfferPage> createState() => _AddJobOfferPageState();
}

class _AddJobOfferPageState extends ConsumerState<AddJobOfferPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _companyCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _salaryMinCtrl = TextEditingController();
  final _salaryMaxCtrl = TextEditingController();

  String? _contractType;
  String? _level;
  String? _remoteMode;
  String? _sector;
  final List<String> _requiredSkills = [];
  final List<String> _niceSkills = [];
  bool _loading = false;
  String? _error;
  bool _isFlash = false;
  int _flashDurationHours = 24;
  String _urgencyLevel = 'normal';

  @override
  void initState() {
    super.initState();
    _prefillSector();
  }

  Future<void> _prefillSector() async {
    final session = ref.read(sessionProvider);
    final profile = await ref
        .read(recruiterProfileRepositoryProvider)
        .getProfile(session.userId);
    if (mounted && profile != null && profile.sectors.isNotEmpty) {
      setState(() => _sector = profile.sectors.first);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _companyCtrl.dispose();
    _locationCtrl.dispose();
    _descriptionCtrl.dispose();
    _salaryMinCtrl.dispose();
    _salaryMaxCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final loc = AppLocalizations.of(context)!;
    setState(() { _loading = true; _error = null; });
    try {
      final session = ref.read(sessionProvider);
      final subSvc = ref.read(subscriptionServiceProvider);
      final canCreate = await subSvc.canCreateOffer(session.userId);
      if (!canCreate) {
        final sub = await subSvc.getSubscription(session.userId);
        if (mounted) {
          await showQuotaReachedSheet(
            context,
            quotaType: QuotaType.offers,
            currentPlan: sub.effectivePlan,
          );
        }
        return;
      }
      final salaryMin = int.tryParse(_salaryMinCtrl.text.trim()) ?? 0;
      final salaryMax = int.tryParse(_salaryMaxCtrl.text.trim()) ?? 0;

      if (salaryMin < 0 || salaryMax < 0) {
        setState(() { _error = loc.recAddOfferSalaryNegative; });
        return;
      }
      if (salaryMin > 0 && salaryMax > 0 && salaryMin > salaryMax) {
        setState(() { _error = loc.recAddOfferSalaryMinMax; });
        return;
      }
      if (_sector == null) {
        setState(() { _error = loc.recAddOfferSectorRequired; });
        return;
      }
      final now = DateTime.now().toUtc();
      final offer = JobOffer(
        jobOfferId: '',
        recruiterUserId: session.userId,
        title: _titleCtrl.text.trim(),
        companyName: _companyCtrl.text.trim(),
        location: _locationCtrl.text.trim(),
        contractType: _contractType ?? '',
        sector: _sector!,
        description: _descriptionCtrl.text.trim(),
        salaryMin: salaryMin,
        salaryMax: salaryMax,
        requiredSkills: AppSkills.formatSkills(_requiredSkills),
        niceToHaveSkills: AppSkills.formatSkills(_niceSkills),
        remoteMode: _remoteMode ?? '',
        level: _level ?? '',
        isFlash: _isFlash,
        flashStartDate: _isFlash ? now.toIso8601String() : '',
        flashDurationHours: _isFlash ? _flashDurationHours : 0,
        flashEndDate: _isFlash
            ? now.add(Duration(hours: _flashDurationHours)).toIso8601String()
            : '',
        urgencyLevel: _urgencyLevel,
      );

      await ref.read(jobOfferRepositoryProvider).insertOffer(offer);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.recAddOfferSuccess),
          backgroundColor: AppColors.green,
        ),
      );
      context.pop();
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(loc.recOffersNewOffer),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        actions: [
          TextButton(
            onPressed: _loading ? null : _save,
            child: _loading
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Text(loc.recAddOfferPublish,
                    style: const TextStyle(
                        color: AppColors.green, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_error != null)
                Container(
                  padding: const EdgeInsets.all(14),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.redLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppColors.red, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(_error!,
                            style: const TextStyle(color: AppColors.red, fontSize: 13)),
                      ),
                    ],
                  ),
                ),

              _sectionLabel(loc.recAddOfferSectionInfo),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _sector,
                decoration: InputDecoration(
                  labelText: loc.recAddOfferSector,
                  prefixIcon: const Icon(Icons.category_outlined),
                ),
                items: AppSectors.all
                    .map((s) => DropdownMenuItem(value: s.id, child: Text(s.label)))
                    .toList(),
                onChanged: (v) => setState(() {
                  _sector = v;
                  final available = AppSkills.skillsForSectors([v ?? '']).toSet();
                  _requiredSkills.removeWhere((s) => !available.contains(s));
                  _niceSkills.removeWhere((s) => !available.contains(s));
                }),
                validator: (v) => v == null ? loc.recAddOfferSectorRequired : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _titleCtrl,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: loc.recAddOfferJobTitle,
                  hintText: loc.recAddOfferJobTitleHint,
                  prefixIcon: const Icon(Icons.work_outline),
                ),
                validator: (v) {
                  if (v == null || v.trim().length < 3) {
                    return loc.recAddOfferJobTitleError;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _companyCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: loc.recAddOfferCompanyName,
                  hintText: loc.recAddOfferCompanyNameHint,
                  prefixIcon: const Icon(Icons.business_outlined),
                ),
                validator: (v) {
                  if (v == null || v.trim().length < 2) {
                    return loc.recAddOfferCompanyNameError;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _locationCtrl,
                decoration: InputDecoration(
                  labelText: loc.recAddOfferLocation,
                  hintText: loc.recAddOfferLocationHint,
                  prefixIcon: const Icon(Icons.location_on_outlined),
                ),
                validator: (v) {
                  if (v == null || v.trim().length < 2) {
                    return loc.recAddOfferLocationError;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              DropdownButtonFormField<String>(
                value: _contractType,
                decoration: InputDecoration(
                  labelText: loc.recAddOfferContractType,
                  prefixIcon: const Icon(Icons.description_outlined),
                ),
                items: AppSkills.contractTypes
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => _contractType = v),
                validator: (v) => v == null ? loc.recAddOfferContractTypeError : null,
              ),
              const SizedBox(height: 12),

              DropdownButtonFormField<String>(
                value: _level,
                decoration: InputDecoration(
                  labelText: loc.recAddOfferLevel,
                  prefixIcon: const Icon(Icons.bar_chart_outlined),
                ),
                items: AppSkills.levels
                    .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                    .toList(),
                onChanged: (v) => setState(() => _level = v),
              ),
              const SizedBox(height: 12),

              DropdownButtonFormField<String>(
                value: _remoteMode,
                decoration: InputDecoration(
                  labelText: loc.recAddOfferWorkMode,
                  prefixIcon: const Icon(Icons.home_work_outlined),
                ),
                items: AppSkills.remoteModes
                    .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                    .toList(),
                onChanged: (v) => setState(() => _remoteMode = v),
              ),
              const SizedBox(height: 24),

              _sectionLabel(loc.recAddOfferSectionSalary),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _salaryMinCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: loc.recAddOfferSalaryMin,
                        prefixIcon: const Icon(Icons.euro_outlined),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _salaryMaxCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: loc.recAddOfferSalaryMax,
                        prefixIcon: const Icon(Icons.euro_outlined),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              _sectionLabel(loc.candOfferDetailRequiredSkills),
              const SizedBox(height: 12),
              _SkillPicker(
                selected: _requiredSkills,
                availableSkills: AppSkills.skillsForSectors([_sector ?? '']),
                accentColor: AppColors.primary,
                bgColor: AppColors.primaryLight,
                onChanged: (skills) => setState(() {
                  _requiredSkills
                    ..clear()
                    ..addAll(skills);
                }),
              ),
              const SizedBox(height: 24),

              _sectionLabel(loc.candOfferDetailNiceSkills),
              const SizedBox(height: 12),
              _SkillPicker(
                selected: _niceSkills,
                availableSkills: AppSkills.skillsForSectors([_sector ?? '']),
                accentColor: AppColors.green,
                bgColor: AppColors.greenLight,
                onChanged: (skills) => setState(() {
                  _niceSkills
                    ..clear()
                    ..addAll(skills);
                }),
              ),
              const SizedBox(height: 24),

              _sectionLabel(loc.recAddOfferSectionDescription),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionCtrl,
                maxLines: 6,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: loc.recAddOfferDescriptionHint,
                  alignLabelWithHint: true,
                ),
                validator: (v) {
                  if (v == null || v.trim().length < 10) {
                    return loc.recAddOfferDescriptionError;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              _sectionLabel(loc.recAddOfferFlashSection),
              const SizedBox(height: 8),
              _FlashSection(
                isFlash: _isFlash,
                durationHours: _flashDurationHours,
                urgencyLevel: _urgencyLevel,
                onToggle: (v) => setState(() => _isFlash = v),
                onDurationChanged: (h) => setState(() => _flashDurationHours = h),
                onUrgencyChanged: (u) => setState(() => _urgencyLevel = u),
              ),
              const SizedBox(height: 32),

              ElevatedButton.icon(
                onPressed: _loading ? null : _save,
                icon: const Icon(Icons.publish),
                label: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : Text(loc.recAddOfferSubmit),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.green),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(text,
        style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            color: context.textPrimaryColor));
  }
}

class _SkillPicker extends StatelessWidget {
  final List<String> selected;
  final List<String> availableSkills;
  final Color accentColor;
  final Color bgColor;
  final ValueChanged<List<String>> onChanged;
  const _SkillPicker({required this.selected, required this.availableSkills, required this.accentColor, required this.bgColor, required this.onChanged});

  void _showPicker(BuildContext context) {
    final available = availableSkills
        .toSet()
        .where((s) => !selected.contains(s))
        .toList();
    showModalBottomSheet(
      context: context,
      builder: (ctx) => ListView.builder(
        itemCount: available.length,
        itemBuilder: (ctx, i) => ListTile(
          title: Text(available[i]),
          onTap: () {
            onChanged([...selected, available[i]]);
            Navigator.pop(ctx);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OutlinedButton.icon(
          onPressed: () => _showPicker(context),
          icon: const Icon(Icons.add),
          label: Text(AppLocalizations.of(context)!.recAddOfferAddSkill),
          style: OutlinedButton.styleFrom(
            foregroundColor: accentColor,
            side: BorderSide(color: accentColor),
          ),
        ),
        if (selected.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: selected.map((s) => Chip(
              label: Text(s, style: TextStyle(fontSize: 12, color: accentColor)),
              backgroundColor: bgColor,
              deleteIcon: Icon(Icons.close, size: 14, color: accentColor),
              onDeleted: () => onChanged([...selected]..remove(s)),
            )).toList(),
          ),
        ],
      ],
    );
  }
}

class _FlashSection extends StatelessWidget {
  final bool isFlash;
  final int durationHours;
  final String urgencyLevel;
  final ValueChanged<bool> onToggle;
  final ValueChanged<int> onDurationChanged;
  final ValueChanged<String> onUrgencyChanged;

  const _FlashSection({
    required this.isFlash,
    required this.durationHours,
    required this.urgencyLevel,
    required this.onToggle,
    required this.onDurationChanged,
    required this.onUrgencyChanged,
  });

  static const _amber = Color(0xFFFF9800);
  static const _durations = [2, 4, 8, 12, 24, 48, 72];

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Container(
      decoration: BoxDecoration(
        color: isFlash ? const Color(0xFFFFF8E1) : context.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isFlash ? _amber : context.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                const Icon(Icons.bolt, color: _amber, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(loc.offerFlashTitle,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      Text(loc.offerFlashSubtitle,
                          style: TextStyle(fontSize: 11, color: context.textSecondaryColor)),
                    ],
                  ),
                ),
                Switch(value: isFlash, onChanged: onToggle, activeColor: _amber),
              ],
            ),
          ),
          if (isFlash) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(loc.offerFlashDuration,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.textSecondaryColor)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    value: durationHours,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.schedule, color: _amber),
                      isDense: true,
                    ),
                    items: _durations.map((h) => DropdownMenuItem(
                      value: h,
                      child: Text(h < 24 ? loc.offerFlashDurationHours(h) : loc.offerFlashDurationDays(h ~/ 24)),
                    )).toList(),
                    onChanged: (v) { if (v != null) onDurationChanged(v); },
                  ),
                  const SizedBox(height: 16),
                  Text(loc.offerFlashUrgency,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.textSecondaryColor)),
                  const SizedBox(height: 8),
                  Row(children: [
                    _UrgencyChip(label: loc.offerFlashUrgencyNormal, value: 'normal', current: urgencyLevel, color: AppColors.green, onTap: onUrgencyChanged),
                    const SizedBox(width: 8),
                    _UrgencyChip(label: loc.offerFlashUrgencyUrgent, value: 'urgent', current: urgencyLevel, color: _amber, onTap: onUrgencyChanged),
                    const SizedBox(width: 8),
                    _UrgencyChip(label: loc.offerFlashUrgencyVeryUrgent, value: 'very_urgent', current: urgencyLevel, color: AppColors.red, onTap: onUrgencyChanged),
                  ]),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _UrgencyChip extends StatelessWidget {
  final String label;
  final String value;
  final String current;
  final Color color;
  final ValueChanged<String> onTap;
  const _UrgencyChip({required this.label, required this.value, required this.current, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final selected = current == value;
    return GestureDetector(
      onTap: () => onTap(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? color : context.borderColor),
        ),
        child: Text(label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: selected ? color : context.textSecondaryColor)),
      ),
    );
  }
}

