import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
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
  final _nameCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();

  List<String> _selectedSkills = [];
  String? _experienceLevel;
  List<String> _selectedContractTypes = [];
  String _remotePreference = '';
  final _salaryMinCtrl = TextEditingController();
  final _salaryMaxCtrl = TextEditingController();
  String? _currentPhotoUrl;
  File? _newImageFile;
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
        _experienceLevel = profile.experienceLevel;
        _selectedContractTypes = profile.contractType.isEmpty
            ? []
            : profile.contractType.split(',');
        _remotePreference = profile.remotePreference;
        _salaryMinCtrl.text = profile.desiredSalaryMin > 0
            ? profile.desiredSalaryMin.toString()
            : '';
        _salaryMaxCtrl.text = profile.desiredSalaryMax > 0
            ? profile.desiredSalaryMax.toString()
            : '';
        _currentPhotoUrl = profile.photoUrl;
      });
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
        source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) {
      setState(() => _newImageFile = File(picked.path));
    }
  }

  Future<String?> _uploadPhoto(String userId) async {
    if (_newImageFile == null) return _currentPhotoUrl;
    final ref = FirebaseStorage.instance
        .ref()
        .child('profile_photos')
        .child('$userId.jpg');
    await ref.putFile(_newImageFile!);
    return await ref.getDownloadURL();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final userId = ref.read(sessionProvider).userId;
      final photoUrl = await _uploadPhoto(userId);
      final profile = CandidateProfile(
        profileId: userId,
        userId: userId,
        fullName: _nameCtrl.text.trim(),
        jobTitle: _titleCtrl.text.trim().isEmpty ? null : _titleCtrl.text.trim(),
        bio: _bioCtrl.text.trim(),
        location: _cityCtrl.text.trim(),
        skills: _selectedSkills,
        desiredLevel: _experienceLevel ?? '',
        desiredContractType: _selectedContractTypes.join(','),
        desiredSalaryMin: int.tryParse(_salaryMinCtrl.text.trim()) ?? 0,
        desiredSalaryMax: int.tryParse(_salaryMaxCtrl.text.trim()) ?? 0,
        remotePreference: _remotePreference,
        photoUrl: photoUrl,
      );
      await ref
          .read(candidateProfileRepositoryProvider)
          .upsertProfile(profile);
      ref.read(profileVersionProvider.notifier).state++;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil mis à jour !')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e')),
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon profil'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child:
                        CircularProgressIndicator(strokeWidth: 2))
                : const Text('Enregistrer',
                    style: TextStyle(fontWeight: FontWeight.bold)),
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
                      CircleAvatar(
                        radius: 52,
                        backgroundColor: Colors.grey[200],
                        backgroundImage: _newImageFile != null
                            ? FileImage(_newImageFile!) as ImageProvider
                            : (_currentPhotoUrl != null
                                ? NetworkImage(_currentPhotoUrl!)
                                : null),
                        child: (_newImageFile == null &&
                                _currentPhotoUrl == null)
                            ? const Icon(Icons.person,
                                size: 52, color: Colors.grey)
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Color(0xFF6C63FF),
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
                decoration: const InputDecoration(
                  labelText: 'Nom complet *',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Champ requis' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Titre du poste',
                  hintText: 'ex: Chef de partie',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _bioCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Bio',
                  hintText: 'Parle de toi en quelques mots...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _cityCtrl,
                decoration: const InputDecoration(
                  labelText: 'Ville',
                  prefixIcon: Icon(Icons.location_on_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              const Text('Niveau d\'expérience',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: ['Junior', 'Intermédiaire', 'Senior', 'Expert']
                    .map((level) => ChoiceChip(
                          label: Text(level),
                          selected: _experienceLevel == level,
                          onSelected: (_) =>
                              setState(() => _experienceLevel = level),
                          selectedColor:
                              const Color(0xFF6C63FF).withOpacity(0.2),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 20),
              const Text('Type de contrat',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: ['CDI', 'CDD', 'Intérim', 'Freelance', 'Stage']
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
              const Text('Salaire souhaité (€/mois)',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _salaryMinCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Minimum',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _salaryMaxCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Maximum',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text('Mode de travail',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: ['Présentiel', 'Hybride', 'Télétravail']
                    .map((mode) => ChoiceChip(
                          label: Text(mode),
                          selected: _remotePreference == mode,
                          onSelected: (_) =>
                              setState(() => _remotePreference = mode),
                          selectedColor:
                              const Color(0xFF6C63FF).withOpacity(0.2),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 20),
              const Text('Compétences',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: AppSkills.all
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
                          selectedColor:
                              const Color(0xFF6C63FF).withOpacity(0.2),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}