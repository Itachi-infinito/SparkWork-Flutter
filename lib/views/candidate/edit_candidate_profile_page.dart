import 'dart:typed_data';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_skills.dart';
import '../../core/widgets/sector_selector.dart';
import '../../models/candidate_profile.dart';
import '../../models/work_experience.dart';
import '../../repositories/candidate_profile_repository.dart';
import '../../services/session_service.dart';
import '../../l10n/generated/app_localizations.dart';

class EditCandidateProfilePage extends ConsumerStatefulWidget {
  const EditCandidateProfilePage({super.key});

  @override
  ConsumerState<EditCandidateProfilePage> createState() =>
      _EditCandidateProfilePageState();
}

class _EditCandidateProfilePageState
    extends ConsumerState<EditCandidateProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();

  List<String> _selectedSkills = [];
  List<String> _selectedSectors = [];
  String? _experienceLevel;
  List<String> _selectedContractTypes = [];
  List<String> _selectedRemoteModes = [];
  final _salaryMinCtrl = TextEditingController();
  final _salaryMaxCtrl = TextEditingController();
  String? _currentPhotoUrl;
  XFile? _newImageFile;
  Uint8List? _newImageBytes;
  List<WorkExperience> _workHistory = [];
  bool _loading = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _loading = true);
    final userId = ref.read(sessionProvider).userId;
    final profile = await ref
        .read(candidateProfileRepositoryProvider)
        .getProfileByUserId(userId);
    if (profile != null && mounted) {
      _nameCtrl.text = profile.fullName;
      _titleCtrl.text = profile.jobTitle ?? '';
      _bioCtrl.text = profile.bio ?? '';
      _cityCtrl.text = profile.locationCity ?? '';
      setState(() {
        _selectedSkills = List.from(profile.skills);
        _selectedSectors = List.from(profile.sectors);
        _experienceLevel = profile.experienceLevel;
        _selectedContractTypes = profile.contractType.isEmpty
            ? []
            : profile.contractType.split(',');
        _selectedRemoteModes = profile.remotePreference.isEmpty
            ? []
            : profile.remotePreference.split(',').map((s) => s.trim()).toList();
        _salaryMinCtrl.text = profile.desiredSalaryMin > 0
            ? profile.desiredSalaryMin.toString()
            : '';
        _salaryMaxCtrl.text = profile.desiredSalaryMax > 0
            ? profile.desiredSalaryMax.toString()
            : '';
        _currentPhotoUrl = profile.photoUrl;
        _workHistory = List.from(profile.workHistory);
      });
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
        source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() {
        _newImageFile = picked;
        _newImageBytes = bytes;
      });
    }
  }

  Widget _buildPhotoPreview() {
    const double r = 52;
    Widget placeholder = CircleAvatar(
      radius: r,
      backgroundColor: Colors.grey[200],
      child: const Icon(Icons.person, size: r, color: Colors.grey),
    );

    if (_newImageBytes != null) {
      return ClipOval(
        child: Image.memory(
          _newImageBytes!,
          width: r * 2,
          height: r * 2,
          fit: BoxFit.cover,
        ),
      );
    }
    if (_currentPhotoUrl != null && _currentPhotoUrl!.isNotEmpty) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: _currentPhotoUrl!,
          width: r * 2,
          height: r * 2,
          fit: BoxFit.cover,
          errorWidget: (_, __, ___) => placeholder,
          placeholder: (_, __) => placeholder,
        ),
      );
    }
    return placeholder;
  }

  Future<String?> _uploadPhoto(String userId) async {
    if (_newImageFile == null || _newImageBytes == null) return _currentPhotoUrl;
    final storageRef = FirebaseStorage.instance
        .ref()
        .child('profile_photos')
        .child('$userId.jpg');
    await storageRef.putData(
      _newImageBytes!,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    final url = await storageRef.getDownloadURL();
    debugPrint('[SparkWork] Photo uploadée: $url');
    return url;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final loc = AppLocalizations.of(context)!;
    setState(() => _saving = true);
    try {
      final userId = ref.read(sessionProvider).userId;

      // Upload photo separately — if it fails, keep the existing URL
      // so the rest of the profile data is not lost.
      String? photoUrl = _currentPhotoUrl;
      if (_newImageBytes != null) {
        try {
          photoUrl = await _uploadPhoto(userId);
        } catch (uploadError) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(loc.candEditPhotoSaveError(uploadError.toString())),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 4),
              ),
            );
          }
        }
      }

      final profile = CandidateProfile(
        profileId: userId,
        userId: userId,
        fullName: _nameCtrl.text.trim(),
        jobTitle: _titleCtrl.text.trim().isEmpty ? null : _titleCtrl.text.trim(),
        bio: _bioCtrl.text.trim(),
        location: _cityCtrl.text.trim(),
        sectors: _selectedSectors,
        skills: _selectedSkills,
        desiredLevel: _experienceLevel ?? '',
        desiredContractType: _selectedContractTypes.join(','),
        desiredSalaryMin: int.tryParse(_salaryMinCtrl.text.trim()) ?? 0,
        desiredSalaryMax: int.tryParse(_salaryMaxCtrl.text.trim()) ?? 0,
        remotePreference: _selectedRemoteModes.join(','),
        photoUrl: photoUrl,
        workHistory: _workHistory,
      );
      await ref
          .read(candidateProfileRepositoryProvider)
          .upsertProfile(profile);
      ref.read(profileVersionProvider.notifier).state++;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.candEditProfileUpdated)),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.candEditGenericError(e.toString()))),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _titleCtrl.dispose();
    _bioCtrl.dispose();
    _cityCtrl.dispose();
    _salaryMinCtrl.dispose();
    _salaryMaxCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final loc = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(loc.candEditTitle),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child:
                        CircularProgressIndicator(strokeWidth: 2))
                : Text(loc.candEditSave,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: GestureDetector(
                  onTap: _pickPhoto,
                  child: Stack(
                    children: [
                      _buildPhotoPreview(),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.camera_alt,
                              size: 16, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameCtrl,
                decoration: InputDecoration(
                  labelText: loc.candEditFullName,
                  border: const OutlineInputBorder(),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? loc.candEditFieldRequired : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleCtrl,
                decoration: InputDecoration(
                  labelText: loc.candEditJobTitle,
                  hintText: loc.candEditJobTitleHint,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _bioCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: loc.candEditBio,
                  hintText: loc.candEditBioHint,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _cityCtrl,
                decoration: InputDecoration(
                  labelText: loc.candEditCity,
                  prefixIcon: const Icon(Icons.location_on_outlined),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              Text(loc.candEditLevel,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: AppSkills.levels
                    .map((level) => ChoiceChip(
                          label: Text(level),
                          selected: _experienceLevel == level,
                          onSelected: (_) =>
                              setState(() => _experienceLevel = level),
                          selectedColor: AppColors.primaryLight,
                        ))
                    .toList(),
              ),
              const SizedBox(height: 20),
              Text(loc.candEditContractType,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: AppSkills.contractTypes
                    .map((type) => FilterChip(
                      label: Text(type),
                      selected: _selectedContractTypes.contains(type),
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedContractTypes.add(type);
                          } else {
                            _selectedContractTypes.remove(type);
                          }
                        });
                      },
                      selectedColor: const Color(0xFF6C63FF).withOpacity(0.2),
                    ))
                    .toList(),
              ),
              const SizedBox(height: 20),
              Text(loc.candEditSalaryWanted,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _salaryMinCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: loc.candEditSalaryMin,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _salaryMaxCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: loc.candEditSalaryMax,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(loc.candEditWorkMode,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: AppSkills.remoteModes
                    .map((mode) => FilterChip(
                          label: Text(mode),
                          selected: _selectedRemoteModes.contains(mode),
                          onSelected: (sel) => setState(() {
                            sel
                                ? _selectedRemoteModes.add(mode)
                                : _selectedRemoteModes.remove(mode);
                          }),
                          selectedColor: AppColors.primaryLight,
                        ))
                    .toList(),
              ),
              const SizedBox(height: 20),
              Text(loc.candEditSectors,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              SectorSelector(
                selected: _selectedSectors,
                onChanged: (sectors) => setState(() {
                  _selectedSectors = sectors;
                  final available =
                      AppSkills.skillsForSectors(_selectedSectors).toSet();
                  _selectedSkills =
                      _selectedSkills.where(available.contains).toList();
                }),
              ),
              const SizedBox(height: 20),
              Text(loc.candEditSkills,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: AppSkills.skillsForSectors(_selectedSectors)
                    .map((skill) => FilterChip(
                          label: Text(skill),
                          selected: _selectedSkills.contains(skill),
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedSkills.add(skill);
                              } else {
                                _selectedSkills.remove(skill);
                              }
                            });
                          },
                          selectedColor: AppColors.primaryLight,
                        ))
                    .toList(),
              ),
              const SizedBox(height: 20),
              _buildWorkHistorySection(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWorkHistorySection() {
    final loc = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(loc.candEditWorkHistory,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        ..._workHistory.asMap().entries.map((e) => _buildWorkExpTile(e.key, e.value)),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => _showWorkExpDialog(),
          icon: const Icon(Icons.add),
          label: Text(loc.candEditAddExperience),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 44),
          ),
        ),
      ],
    );
  }

  Widget _buildWorkExpTile(int index, WorkExperience exp) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        title: Text(exp.jobTitle, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(
          '${exp.company}\n${exp.periodLabel} · ${exp.durationLabel}',
          style: const TextStyle(fontSize: 12),
        ),
        isThreeLine: true,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20),
              onPressed: () => _showWorkExpDialog(index: index, existing: exp),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.red),
              onPressed: () => setState(() => _workHistory.removeAt(index)),
            ),
          ],
        ),
      ),
    );
  }

  String _monthName(int m) {
    const names = ['', 'Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Jun',
                   'Jul', 'Aoû', 'Sep', 'Oct', 'Nov', 'Déc'];
    return names[m.clamp(1, 12)];
  }

  Future<void> _showWorkExpDialog({int? index, WorkExperience? existing}) async {
    final loc = AppLocalizations.of(context)!;
    final titleCtrl = TextEditingController(text: existing?.jobTitle ?? '');
    final companyCtrl = TextEditingController(text: existing?.company ?? '');
    final now = DateTime.now();

    bool isCurrent = existing?.isCurrent ?? false;
    int startYear = existing != null ? int.parse(existing.startDate.split('-')[0]) : now.year;
    int startMonth = existing != null ? int.parse(existing.startDate.split('-')[1]) : now.month;
    int endYear = existing?.endDate != null ? int.parse(existing!.endDate!.split('-')[0]) : now.year;
    int endMonth = existing?.endDate != null ? int.parse(existing!.endDate!.split('-')[1]) : now.month;

    final years = List.generate(35, (i) => now.year - i);

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(existing == null ? loc.candEditAddExperience : loc.candEditDialogEditTitle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: InputDecoration(
                    labelText: loc.candEditExperienceJobTitle,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: companyCtrl,
                  decoration: InputDecoration(
                    labelText: loc.candEditExperienceCompany,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                Text(loc.candEditStartDate, style: const TextStyle(fontSize: 13, color: Colors.grey)),
                const SizedBox(height: 6),
                Row(children: [
                  Expanded(
                    child: DropdownButton<int>(
                      isExpanded: true,
                      value: startMonth,
                      items: List.generate(12, (i) => DropdownMenuItem(value: i + 1, child: Text(_monthName(i + 1)))),
                      onChanged: (v) => setDialogState(() => startMonth = v!),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButton<int>(
                      isExpanded: true,
                      value: startYear,
                      items: years.map((y) => DropdownMenuItem(value: y, child: Text(y.toString()))).toList(),
                      onChanged: (v) => setDialogState(() => startYear = v!),
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
                CheckboxListTile(
                  title: Text(loc.candEditCurrentJob),
                  value: isCurrent,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  onChanged: (v) => setDialogState(() => isCurrent = v ?? false),
                ),
                if (!isCurrent) ...[
                  Text(loc.candEditEndDate, style: const TextStyle(fontSize: 13, color: Colors.grey)),
                  const SizedBox(height: 6),
                  Row(children: [
                    Expanded(
                      child: DropdownButton<int>(
                        isExpanded: true,
                        value: endMonth,
                        items: List.generate(12, (i) => DropdownMenuItem(value: i + 1, child: Text(_monthName(i + 1)))),
                        onChanged: (v) => setDialogState(() => endMonth = v!),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButton<int>(
                        isExpanded: true,
                        value: endYear,
                        items: years.map((y) => DropdownMenuItem(value: y, child: Text(y.toString()))).toList(),
                        onChanged: (v) => setDialogState(() => endYear = v!),
                      ),
                    ),
                  ]),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(loc.candEditDialogCancel),
            ),
            ElevatedButton(
              onPressed: () {
                if (titleCtrl.text.trim().isEmpty || companyCtrl.text.trim().isEmpty) return;
                final start = '${startYear.toString().padLeft(4, '0')}-${startMonth.toString().padLeft(2, '0')}';
                final end = isCurrent ? null : '${endYear.toString().padLeft(4, '0')}-${endMonth.toString().padLeft(2, '0')}';
                final exp = WorkExperience(
                  jobTitle: titleCtrl.text.trim(),
                  company: companyCtrl.text.trim(),
                  startDate: start,
                  endDate: end,
                  isCurrent: isCurrent,
                );
                setState(() {
                  if (index != null) {
                    _workHistory[index] = exp;
                  } else {
                    _workHistory.add(exp);
                  }
                });
                Navigator.pop(ctx);
              },
              child: Text(loc.candEditSave),
            ),
          ],
        ),
      ),
    );

    titleCtrl.dispose();
    companyCtrl.dispose();
  }
}