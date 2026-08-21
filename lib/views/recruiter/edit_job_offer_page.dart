import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_theme_ext.dart';
import '../../core/constants/app_sectors.dart';
import '../../core/constants/app_skills.dart';
import '../../models/job_offer.dart';
import '../../repositories/job_offer_repository.dart';
import '../../l10n/generated/app_localizations.dart';

class EditJobOfferPage extends ConsumerStatefulWidget {
  final String jobOfferId;
  const EditJobOfferPage({super.key, required this.jobOfferId});

  @override
  ConsumerState<EditJobOfferPage> createState() => _EditJobOfferPageState();
}

class _EditJobOfferPageState extends ConsumerState<EditJobOfferPage> {
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
  bool _initialLoading = true;
  bool _saving = false;
  String? _error;
  JobOffer? _originalOffer;
  bool _isFlash = false;
  DateTime? _flashEndDateTime;

  @override
  void initState() {
    super.initState();
    _loadOffer();
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

  Future<void> _loadOffer() async {
    try {
      final offer = await ref.read(jobOfferRepositoryProvider).getOfferById(widget.jobOfferId);
      if (!mounted) return;
      final loc = AppLocalizations.of(context)!;
      if (offer == null) { setState(() { _error = loc.candOfferDetailNotFound; _initialLoading = false; }); return; }
      _originalOffer = offer;
      _titleCtrl.text = offer.title;
      _companyCtrl.text = offer.companyName;
      _locationCtrl.text = offer.location;
      _descriptionCtrl.text = offer.description;
      _salaryMinCtrl.text = offer.salaryMin > 0 ? offer.salaryMin.toString() : '';
      _salaryMaxCtrl.text = offer.salaryMax > 0 ? offer.salaryMax.toString() : '';
      _requiredSkills..clear()..addAll(offer.requiredSkillList);
      _niceSkills..clear()..addAll(offer.niceSkillList);
      setState(() {
        _contractType = AppSkills.contractTypes.contains(offer.contractType) ? offer.contractType : null;
        _level = AppSkills.levels.contains(offer.level) ? offer.level : null;
        _remoteMode = AppSkills.remoteModes.contains(offer.remoteMode) ? offer.remoteMode : null;
        _sector = offer.sector;
        _isFlash = offer.isFlash;
        if (offer.isFlash && offer.flashEndDate.isNotEmpty) {
          try {
            _flashEndDateTime = DateTime.parse(offer.flashEndDate).toLocal();
          } catch (_) {}
        }
        _initialLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _error = AppLocalizations.of(context)!.recEditOfferLoadError; _initialLoading = false; });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final loc = AppLocalizations.of(context)!;
    setState(() { _saving = true; _error = null; });
    try {
      final salaryMin = int.tryParse(_salaryMinCtrl.text.trim()) ?? 0;
      final salaryMax = int.tryParse(_salaryMaxCtrl.text.trim()) ?? 0;
      if (_isFlash && _flashEndDateTime == null) {
        setState(() => _error = loc.recEditOfferFlashDateRequired);
        return;
      }
      final updated = _originalOffer!.copyWith(
        title: _titleCtrl.text.trim(),
        companyName: _companyCtrl.text.trim(),
        location: _locationCtrl.text.trim(),
        contractType: _contractType ?? '',
        level: _level ?? '',
        remoteMode: _remoteMode ?? '',
        sector: _sector ?? _originalOffer!.sector,
        salaryMin: salaryMin,
        salaryMax: salaryMax,
        requiredSkills: AppSkills.formatSkills(_requiredSkills),
        niceToHaveSkills: AppSkills.formatSkills(_niceSkills),
        description: _descriptionCtrl.text.trim(),
        isFlash: _isFlash,
        flashEndDate: _isFlash && _flashEndDateTime != null
            ? _flashEndDateTime!.toUtc().toIso8601String()
            : '',
      );
      await ref.read(jobOfferRepositoryProvider).updateOffer(updated);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.recEditOfferSuccess), backgroundColor: AppColors.green));
      context.pop();
    } catch (e) {
      if (mounted) setState(() => _error = loc.recEditOfferSaveError);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(loc.recEditOfferTitle),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () => context.pop()),
        actions: [
          TextButton(
            onPressed: (_saving || _initialLoading) ? null : _save,
            child: _saving
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(loc.recEditOfferSave, style: const TextStyle(color: AppColors.green, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: _initialLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  DropdownButtonFormField<String>(value: _sector, decoration: InputDecoration(labelText: loc.recAddOfferSector, prefixIcon: const Icon(Icons.category_outlined)),
                    items: AppSectors.all.map((s) => DropdownMenuItem(value: s.id, child: Text(s.label))).toList(),
                    onChanged: (v) => setState(() {
                      _sector = v;
                      final available = AppSkills.skillsForSectors([v ?? '']).toSet();
                      _requiredSkills.removeWhere((s) => !available.contains(s));
                      _niceSkills.removeWhere((s) => !available.contains(s));
                    }),
                    validator: (v) => v == null ? loc.recAddOfferSectorRequired : null),
                  const SizedBox(height: 12),
                  TextFormField(controller: _titleCtrl, decoration: InputDecoration(labelText: loc.recAddOfferJobTitle, prefixIcon: const Icon(Icons.work_outline)),
                    validator: (v) => (v == null || v.trim().length < 3) ? loc.recAddOfferJobTitleError : null),
                  const SizedBox(height: 12),
                  TextFormField(controller: _companyCtrl, decoration: InputDecoration(labelText: loc.recAddOfferCompanyName, prefixIcon: const Icon(Icons.business_outlined)),
                    validator: (v) => (v == null || v.trim().length < 2) ? loc.recEditOfferNameRequired : null),
                  const SizedBox(height: 12),
                  TextFormField(controller: _locationCtrl, decoration: InputDecoration(labelText: loc.recAddOfferLocation, prefixIcon: const Icon(Icons.location_on_outlined)),
                    validator: (v) => (v == null || v.trim().length < 2) ? loc.recAddOfferLocationError : null),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(value: _contractType, decoration: InputDecoration(labelText: loc.recAddOfferContractType, prefixIcon: const Icon(Icons.description_outlined)),
                    items: AppSkills.contractTypes.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (v) => setState(() => _contractType = v),
                    validator: (v) => v == null ? loc.recEditOfferRequired : null),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(value: _level, decoration: InputDecoration(labelText: loc.recAddOfferLevel, prefixIcon: const Icon(Icons.bar_chart_outlined)),
                    items: AppSkills.levels.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
                    onChanged: (v) => setState(() => _level = v)),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(value: _remoteMode, decoration: InputDecoration(labelText: loc.recAddOfferWorkMode, prefixIcon: const Icon(Icons.home_work_outlined)),
                    items: AppSkills.remoteModes.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                    onChanged: (v) => setState(() => _remoteMode = v)),
                  const SizedBox(height: 24),
                  Text(loc.recAddOfferSectionSalary, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: context.textPrimaryColor)),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: TextFormField(controller: _salaryMinCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: loc.recEditOfferSalaryMin, prefixIcon: const Icon(Icons.euro_outlined)))),
                    const SizedBox(width: 12),
                    Expanded(child: TextFormField(controller: _salaryMaxCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: loc.recEditOfferSalaryMax, prefixIcon: const Icon(Icons.euro_outlined)))),
                  ]),
                  const SizedBox(height: 24),
                  Text(loc.candOfferDetailRequiredSkills, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: context.textPrimaryColor)),
                  const SizedBox(height: 12),
                  _SkillPicker(selected: _requiredSkills, availableSkills: AppSkills.skillsForSectors([_sector ?? '']), accentColor: AppColors.primary, bgColor: AppColors.primaryLight, onChanged: (s) => setState(() { _requiredSkills..clear()..addAll(s); })),
                  const SizedBox(height: 24),
                  Text(loc.candOfferDetailNiceSkills, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: context.textPrimaryColor)),
                  const SizedBox(height: 12),
                  _SkillPicker(selected: _niceSkills, availableSkills: AppSkills.skillsForSectors([_sector ?? '']), accentColor: AppColors.green, bgColor: AppColors.greenLight, onChanged: (s) => setState(() { _niceSkills..clear()..addAll(s); })),
                  const SizedBox(height: 24),
                  Text(loc.recAddOfferSectionDescription, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: context.textPrimaryColor)),
                  const SizedBox(height: 12),
                  TextFormField(controller: _descriptionCtrl, maxLines: 6, decoration: InputDecoration(hintText: loc.recEditOfferDescriptionHint),
                    validator: (v) => (v == null || v.trim().length < 10) ? loc.recAddOfferDescriptionError : null),
                  const SizedBox(height: 24),
                  Text(loc.recAddOfferFlashSection, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: context.textPrimaryColor)),
                  const SizedBox(height: 8),
                  _EditFlashSection(
                    isFlash: _isFlash,
                    flashEndDateTime: _flashEndDateTime,
                    onToggle: (v) => setState(() {
                      _isFlash = v;
                      if (!v) _flashEndDateTime = null;
                    }),
                    onPickDate: _pickFlashDateTime,
                  ),
                  const SizedBox(height: 32),
                  SizedBox(width: double.infinity, child: ElevatedButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(loc.recEditOfferSubmit),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.green, minimumSize: const Size(double.infinity, 52)),
                  )),
                  const SizedBox(height: 24),
                ]),
              ),
            ),
    );
  }

  Future<void> _pickFlashDateTime() async {
    final loc = AppLocalizations.of(context)!;
    final date = await showDatePicker(
      context: context,
      initialDate: _flashEndDateTime ?? DateTime.now().add(const Duration(hours: 6)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      helpText: loc.recEditOfferExpiryDateHelp,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
          _flashEndDateTime ?? DateTime.now().add(const Duration(hours: 6))),
      helpText: loc.recEditOfferExpiryTimeHelp,
    );
    if (time == null || !mounted) return;
    setState(() {
      _flashEndDateTime =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }
}

class _EditFlashSection extends StatelessWidget {
  final bool isFlash;
  final DateTime? flashEndDateTime;
  final ValueChanged<bool> onToggle;
  final VoidCallback onPickDate;

  const _EditFlashSection({
    required this.isFlash,
    required this.flashEndDateTime,
    required this.onToggle,
    required this.onPickDate,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    const amber = Color(0xFFFF9800);
    return Container(
      decoration: BoxDecoration(
        color: isFlash ? const Color(0xFFFFF8E1) : context.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isFlash ? amber : context.borderColor),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                const Icon(Icons.bolt, color: amber, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(loc.offerFlashTitle,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14)),
                      Text(loc.recEditOfferFlashSubtitle,
                          style: TextStyle(
                              fontSize: 11, color: context.textSecondaryColor)),
                    ],
                  ),
                ),
                Switch(value: isFlash, onChanged: onToggle, activeColor: amber),
              ],
            ),
          ),
          if (isFlash) ...[
            const Divider(height: 1),
            ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              leading: const Icon(Icons.schedule, color: amber),
              title: Text(
                flashEndDateTime == null
                    ? loc.recEditOfferChooseExpiryDate
                    : DateFormat('dd/MM/yyyy HH:mm').format(flashEndDateTime!),
                style: TextStyle(
                    fontSize: 13,
                    color: flashEndDateTime == null
                        ? context.textHintColor
                        : context.textPrimaryColor),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: onPickDate,
            ),
          ],
        ],
      ),
    );
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
