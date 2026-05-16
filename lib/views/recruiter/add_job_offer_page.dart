import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_skills.dart';
import '../../models/job_offer.dart';
import '../../repositories/job_offer_repository.dart';
import '../../services/session_service.dart';

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
  final List<String> _requiredSkills = [];
  final List<String> _niceSkills = [];
  bool _loading = false;
  String? _error;

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
    setState(() { _loading = true; _error = null; });
    try {
      final session = ref.read(sessionProvider);
      final salaryMin = int.tryParse(_salaryMinCtrl.text.trim()) ?? 0;
      final salaryMax = int.tryParse(_salaryMaxCtrl.text.trim()) ?? 0;

      if (salaryMin < 0 || salaryMax < 0) {
        setState(() { _error = 'Le salaire ne peut pas être négatif.'; });
        return;
      }
      if (salaryMin > 0 && salaryMax > 0 && salaryMin > salaryMax) {
        setState(() { _error = 'Le salaire minimum ne peut pas dépasser le maximum.'; });
        return;
      }

      final offer = JobOffer(
        jobOfferId: 0,
        recruiterUserId: session.userId,
        title: _titleCtrl.text.trim(),
        companyName: _companyCtrl.text.trim(),
        location: _locationCtrl.text.trim(),
        contractType: _contractType ?? '',
        description: _descriptionCtrl.text.trim(),
        address: '',
        latitude: 0,
        longitude: 0,
        salaryMin: salaryMin,
        salaryMax: salaryMax,
        requiredSkills: AppSkills.formatSkills(_requiredSkills),
        niceToHaveSkills: AppSkills.formatSkills(_niceSkills),
        remoteMode: _remoteMode ?? '',
        level: _level ?? '',
      );

      await ref.read(jobOfferRepositoryProvider).insertOffer(offer);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Offre publiée avec succès !'),
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Nouvelle offre'),
        backgroundColor: AppColors.background,
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
                : const Text('Publier',
                    style: TextStyle(
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

              _sectionLabel('Informations du poste'),
              const SizedBox(height: 12),
              TextFormField(
                controller: _titleCtrl,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Titre du poste *',
                  hintText: 'Ex: Serveur en salle',
                  prefixIcon: Icon(Icons.work_outline),
                ),
                validator: (v) {
                  if (v == null || v.trim().length < 3) {
                    return 'Titre requis (min 3 caractères)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _companyCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nom de l\'établissement *',
                  hintText: 'Ex: Restaurant Le Gourmet',
                  prefixIcon: Icon(Icons.business_outlined),
                ),
                validator: (v) {
                  if (v == null || v.trim().length < 2) {
                    return 'Nom de l\'établissement requis';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _locationCtrl,
                decoration: const InputDecoration(
                  labelText: 'Localisation *',
                  hintText: 'Ex: Bruxelles, Ixelles',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
                validator: (v) {
                  if (v == null || v.trim().length < 2) {
                    return 'Localisation requise';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              DropdownButtonFormField<String>(
                value: _contractType,
                decoration: const InputDecoration(
                  labelText: 'Type de contrat *',
                  prefixIcon: Icon(Icons.description_outlined),
                ),
                items: AppSkills.contractTypes
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => _contractType = v),
                validator: (v) => v == null ? 'Type de contrat requis' : null,
              ),
              const SizedBox(height: 12),

              DropdownButtonFormField<String>(
                value: _level,
                decoration: const InputDecoration(
                  labelText: 'Niveau d\'expérience',
                  prefixIcon: Icon(Icons.bar_chart_outlined),
                ),
                items: AppSkills.levels
                    .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                    .toList(),
                onChanged: (v) => setState(() => _level = v),
              ),
              const SizedBox(height: 12),

              DropdownButtonFormField<String>(
                value: _remoteMode,
                decoration: const InputDecoration(
                  labelText: 'Mode de travail',
                  prefixIcon: Icon(Icons.home_work_outlined),
                ),
                items: AppSkills.remoteModes
                    .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                    .toList(),
                onChanged: (v) => setState(() => _remoteMode = v),
              ),
              const SizedBox(height: 24),

              _sectionLabel('Rémunération (€/mois)'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _salaryMinCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Salaire min',
                        prefixIcon: Icon(Icons.euro_outlined),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _salaryMaxCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Salaire max',
                        prefixIcon: Icon(Icons.euro_outlined),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              _sectionLabel('Compétences requises'),
              const SizedBox(height: 12),
              _SkillPicker(
                selected: _requiredSkills,
                accentColor: AppColors.primary,
                bgColor: AppColors.primaryLight,
                onChanged: (skills) => setState(() {
                  _requiredSkills
                    ..clear()
                    ..addAll(skills);
                }),
              ),
              const SizedBox(height: 24),

              _sectionLabel('Compétences appréciées'),
              const SizedBox(height: 12),
              _SkillPicker(
                selected: _niceSkills,
                accentColor: AppColors.green,
                bgColor: AppColors.greenLight,
                onChanged: (skills) => setState(() {
                  _niceSkills
                    ..clear()
                    ..addAll(skills);
                }),
              ),
              const SizedBox(height: 24),

              _sectionLabel('Description du poste *'),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionCtrl,
                maxLines: 6,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Décrivez le poste, les missions, le contexte...',
                  alignLabelWithHint: true,
                ),
                validator: (v) {
                  if (v == null || v.trim().length < 10) {
                    return 'Description requise (min 10 caractères)';
                  }
                  return null;
                },
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
                    : const Text('Publier l\'offre'),
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
        style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            color: AppColors.textPrimary));
  }
}

class _SkillPicker extends StatelessWidget {
  final List<String> selected;
  final Color accentColor;
  final Color bgColor;
  final ValueChanged<List<String>> onChanged;
  const _SkillPicker({required this.selected, required this.accentColor, required this.bgColor, required this.onChanged});

  void _showPicker(BuildContext context) {
    final available = AppSkills.horecaSkills
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
          label: const Text('Ajouter une compétence'),
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

