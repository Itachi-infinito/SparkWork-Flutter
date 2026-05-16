import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_skills.dart';
import '../../models/job_offer.dart';
import '../../repositories/job_offer_repository.dart';

class EditJobOfferPage extends ConsumerStatefulWidget {
  final int jobOfferId;
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
  final List<String> _requiredSkills = [];
  final List<String> _niceSkills = [];
  bool _initialLoading = true;
  bool _saving = false;
  String? _error;
  JobOffer? _originalOffer;

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
      if (offer == null) { setState(() { _error = 'Offre introuvable.'; _initialLoading = false; }); return; }
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
        _initialLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _error = "Erreur lors du chargement de l'offre."; _initialLoading = false; });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _saving = true; _error = null; });
    try {
      final salaryMin = int.tryParse(_salaryMinCtrl.text.trim()) ?? 0;
      final salaryMax = int.tryParse(_salaryMaxCtrl.text.trim()) ?? 0;
      final updated = _originalOffer!.copyWith(
        title: _titleCtrl.text.trim(),
        companyName: _companyCtrl.text.trim(),
        location: _locationCtrl.text.trim(),
        contractType: _contractType ?? '',
        level: _level ?? '',
        remoteMode: _remoteMode ?? '',
        salaryMin: salaryMin,
        salaryMax: salaryMax,
        requiredSkills: AppSkills.formatSkills(_requiredSkills),
        niceToHaveSkills: AppSkills.formatSkills(_niceSkills),
        description: _descriptionCtrl.text.trim(),
      );
      await ref.read(jobOfferRepositoryProvider).updateOffer(updated);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Offre mise à jour !'), backgroundColor: AppColors.green));
      context.pop();
    } catch (e) {
      if (mounted) setState(() => _error = 'Erreur lors de la sauvegarde.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Modifier l'offre"),
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () => context.pop()),
        actions: [
          TextButton(
            onPressed: (_saving || _initialLoading) ? null : _save,
            child: _saving
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Sauvegarder', style: TextStyle(color: AppColors.green, fontWeight: FontWeight.w600)),
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
                  TextFormField(controller: _titleCtrl, decoration: const InputDecoration(labelText: 'Titre du poste *', prefixIcon: Icon(Icons.work_outline)),
                    validator: (v) => (v == null || v.trim().length < 3) ? 'Titre requis (min 3 caractères)' : null),
                  const SizedBox(height: 12),
                  TextFormField(controller: _companyCtrl, decoration: const InputDecoration(labelText: "Nom de l'établissement *", prefixIcon: Icon(Icons.business_outlined)),
                    validator: (v) => (v == null || v.trim().length < 2) ? "Nom requis" : null),
                  const SizedBox(height: 12),
                  TextFormField(controller: _locationCtrl, decoration: const InputDecoration(labelText: 'Localisation *', prefixIcon: Icon(Icons.location_on_outlined)),
                    validator: (v) => (v == null || v.trim().length < 2) ? 'Localisation requise' : null),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(value: _contractType, decoration: const InputDecoration(labelText: 'Type de contrat *', prefixIcon: Icon(Icons.description_outlined)),
                    items: AppSkills.contractTypes.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (v) => setState(() => _contractType = v),
                    validator: (v) => v == null ? 'Requis' : null),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(value: _level, decoration: const InputDecoration(labelText: "Niveau d'expérience", prefixIcon: Icon(Icons.bar_chart_outlined)),
                    items: AppSkills.levels.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
                    onChanged: (v) => setState(() => _level = v)),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(value: _remoteMode, decoration: const InputDecoration(labelText: 'Mode de travail', prefixIcon: Icon(Icons.home_work_outlined)),
                    items: AppSkills.remoteModes.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                    onChanged: (v) => setState(() => _remoteMode = v)),
                  const SizedBox(height: 24),
                  const Text('Rémunération (€/mois)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AppColors.textPrimary)),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: TextFormField(controller: _salaryMinCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Min', prefixIcon: Icon(Icons.euro_outlined)))),
                    const SizedBox(width: 12),
                    Expanded(child: TextFormField(controller: _salaryMaxCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Max', prefixIcon: Icon(Icons.euro_outlined)))),
                  ]),
                  const SizedBox(height: 24),
                  const Text('Compétences requises', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AppColors.textPrimary)),
                  const SizedBox(height: 12),
                  _SkillPicker(selected: _requiredSkills, accentColor: AppColors.primary, bgColor: AppColors.primaryLight, onChanged: (s) => setState(() { _requiredSkills..clear()..addAll(s); })),
                  const SizedBox(height: 24),
                  const Text('Compétences appréciées', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AppColors.textPrimary)),
                  const SizedBox(height: 12),
                  _SkillPicker(selected: _niceSkills, accentColor: AppColors.green, bgColor: AppColors.greenLight, onChanged: (s) => setState(() { _niceSkills..clear()..addAll(s); })),
                  const SizedBox(height: 24),
                  const Text('Description du poste *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AppColors.textPrimary)),
                  const SizedBox(height: 12),
                  TextFormField(controller: _descriptionCtrl, maxLines: 6, decoration: const InputDecoration(hintText: 'Décrivez le poste...'),
                    validator: (v) => (v == null || v.trim().length < 10) ? 'Description requise (min 10 caractères)' : null),
                  const SizedBox(height: 32),
                  SizedBox(width: double.infinity, child: ElevatedButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Sauvegarder les modifications'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.green, minimumSize: const Size(double.infinity, 52)),
                  )),
                  const SizedBox(height: 24),
                ]),
              ),
            ),
    );
  }
}

class _SkillPicker extends StatefulWidget {
  final List<String> selected;
  final Color accentColor;
  final Color bgColor;
  final ValueChanged<List<String>> onChanged;
  const _SkillPicker({required this.selected, required this.accentColor, required this.bgColor, required this.onChanged});

  @override
  State<_SkillPicker> createState() => _SkillPickerState();
}

class _SkillPickerState extends State<_SkillPicker> {
  String? _value;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      DropdownButton<String>(
        value: null,
        isExpanded: true,
        underline: Container(height: 1, color: AppColors.border),
        hint: const Text('Sélectionner une compétence'),
        items: AppSkills.horecaSkills.where((s) => !widget.selected.contains(s)).map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
        onChanged: (v) { if (v != null && !widget.selected.contains(v)) { widget.onChanged([...widget.selected, v]); } },
      ),
      if (widget.selected.isNotEmpty) ...[
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 6, children: widget.selected.map((s) => Chip(
          label: Text(s, style: TextStyle(fontSize: 12, color: widget.accentColor)),
          backgroundColor: widget.bgColor,
          deleteIcon: Icon(Icons.close, size: 14, color: widget.accentColor),
          onDeleted: () { widget.onChanged([...widget.selected]..remove(s)); },
        )).toList()),
      ],
    ]);
  }
}