import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_theme_ext.dart';
import '../../core/widgets/sector_selector.dart';
import '../../models/recruiter_profile.dart';
import '../../repositories/recruiter_profile_repository.dart';
import '../../services/session_service.dart';
import '../../l10n/generated/app_localizations.dart';

class EditRecruiterProfilePage extends ConsumerStatefulWidget {
  const EditRecruiterProfilePage({super.key});

  @override
  ConsumerState<EditRecruiterProfilePage> createState() =>
      _EditRecruiterProfilePageState();
}

class _EditRecruiterProfilePageState
    extends ConsumerState<EditRecruiterProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _companyCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();

  String? _currentContactPhotoUrl;
  String? _currentLogoUrl;
  String _companyNumber = '';
  final List<String> _sectors = [];
  Uint8List? _newContactPhotoBytes;
  Uint8List? _newLogoBytes;

  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _companyCtrl.dispose();
    _descCtrl.dispose();
    _locationCtrl.dispose();
    _websiteCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _loading = true);
    final userId = ref.read(sessionProvider).userId;
    final profile =
        await ref.read(recruiterProfileRepositoryProvider).getProfile(userId);
    if (profile != null && mounted) {
      _companyCtrl.text = profile.companyName;
      _descCtrl.text = profile.companyDescription;
      _locationCtrl.text = profile.location;
      _websiteCtrl.text = profile.website;
      setState(() {
        _currentContactPhotoUrl = profile.contactPhotoUrl;
        _currentLogoUrl = profile.companyLogoUrl;
        _companyNumber = profile.companyNumber;
        _sectors
          ..clear()
          ..addAll(profile.sectors);
      });
    } else {
      // Pre-fill company name from session
      _companyCtrl.text = ref.read(sessionProvider).userName;
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _pickPhoto(_PhotoTarget target) async {
    final picker = ImagePicker();
    final picked =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() {
      if (target == _PhotoTarget.contact) {
        _newContactPhotoBytes = bytes;
      } else {
        _newLogoBytes = bytes;
      }
    });
  }

  Future<String?> _uploadBytes(
      Uint8List bytes, String folder, String userId) async {
    final ref = FirebaseStorage.instance
        .ref()
        .child(folder)
        .child('$userId.jpg');
    await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    return ref.getDownloadURL();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final loc = AppLocalizations.of(context)!;
    setState(() => _saving = true);
    try {
      final userId = ref.read(sessionProvider).userId;

      String? contactPhotoUrl = _currentContactPhotoUrl;
      String? logoUrl = _currentLogoUrl;

      if (_newContactPhotoBytes != null) {
        try {
          contactPhotoUrl = await _uploadBytes(
              _newContactPhotoBytes!, 'recruiter_photos', userId);
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(loc.recEditContactPhotoError(e.toString())),
                backgroundColor: Colors.orange));
          }
        }
      }
      if (_newLogoBytes != null) {
        try {
          logoUrl = await _uploadBytes(_newLogoBytes!, 'company_logos', userId);
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(loc.recEditLogoError(e.toString())),
                backgroundColor: Colors.orange));
          }
        }
      }

      final profile = RecruiterProfile(
        profileId: '',
        userId: userId,
        companyName: _companyCtrl.text.trim(),
        companyDescription: _descCtrl.text.trim(),
        location: _locationCtrl.text.trim(),
        website: _websiteCtrl.text.trim(),
        companyNumber: _companyNumber,
        sectors: _sectors,
        contactPhotoUrl: contactPhotoUrl,
        companyLogoUrl: logoUrl,
      );

      await ref
          .read(recruiterProfileRepositoryProvider)
          .upsertProfile(profile);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(loc.candEditProfileUpdated),
            backgroundColor: AppColors.green));
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(loc.recEditGenericError(e.toString()))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator(color: AppColors.green)));
    }

    final loc = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
            icon: const Icon(Icons.close), onPressed: () => context.pop()),
        title: Text(loc.recEditTitle),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.green))
                : Text(loc.candEditSave,
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
              // Photo section
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Contact photo
                  Expanded(
                    child: _PhotoUploadTile(
                      label: loc.recEditContactPhotoLabel,
                      hint: loc.recEditContactPhotoHint,
                      bytes: _newContactPhotoBytes,
                      existingUrl: _currentContactPhotoUrl,
                      onTap: () => _pickPhoto(_PhotoTarget.contact),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Company logo
                  Expanded(
                    child: _PhotoUploadTile(
                      label: loc.recEditLogoLabel,
                      hint: loc.recEditLogoHint,
                      bytes: _newLogoBytes,
                      existingUrl: _currentLogoUrl,
                      onTap: () => _pickPhoto(_PhotoTarget.logo),
                      isSquare: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              _Label(loc.recEditCompanyName),
              const SizedBox(height: 8),
              TextFormField(
                controller: _companyCtrl,
                decoration: InputDecoration(
                  labelText: loc.recEditCompanyNameHint,
                  prefixIcon: const Icon(Icons.business_outlined),
                  border: const OutlineInputBorder(),
                ),
                validator: (v) =>
                    v == null || v.trim().length < 2 ? loc.recEditCompanyNameRequired : null,
              ),
              const SizedBox(height: 16),

              _Label(loc.recEditSectors),
              const SizedBox(height: 8),
              SectorSelector(
                selected: _sectors,
                onChanged: (sectors) => setState(() {
                  _sectors
                    ..clear()
                    ..addAll(sectors);
                }),
              ),
              const SizedBox(height: 16),

              _Label(loc.recEditCompanyDescription),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: loc.recEditCompanyDescriptionHint,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              _Label(loc.recEditLocation),
              const SizedBox(height: 8),
              TextFormField(
                controller: _locationCtrl,
                decoration: InputDecoration(
                  labelText: loc.recEditLocationHint,
                  prefixIcon: const Icon(Icons.location_on_outlined),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              _Label(loc.recEditWebsite),
              const SizedBox(height: 8),
              TextFormField(
                controller: _websiteCtrl,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  labelText: loc.recEditWebsiteHint,
                  prefixIcon: const Icon(Icons.link_outlined),
                  border: const OutlineInputBorder(),
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

enum _PhotoTarget { contact, logo }

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Text(text,
      style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
          color: context.textPrimaryColor));
}

class _PhotoUploadTile extends StatelessWidget {
  final String label;
  final String hint;
  final Uint8List? bytes;
  final String? existingUrl;
  final VoidCallback onTap;
  final bool isSquare;

  const _PhotoUploadTile({
    required this.label,
    required this.hint,
    required this.bytes,
    required this.existingUrl,
    required this.onTap,
    this.isSquare = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget preview;
    if (bytes != null) {
      preview = isSquare
          ? ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(bytes!, width: 80, height: 80, fit: BoxFit.cover))
          : ClipOval(
              child: Image.memory(bytes!, width: 80, height: 80, fit: BoxFit.cover));
    } else if (existingUrl != null && existingUrl!.isNotEmpty) {
      preview = isSquare
          ? ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                  imageUrl: existingUrl!, width: 80, height: 80, fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => _placeholder()))
          : ClipOval(
              child: CachedNetworkImage(
                  imageUrl: existingUrl!, width: 80, height: 80, fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => _placeholder()));
    } else {
      preview = _placeholder();
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.borderColor),
        ),
        child: Column(
          children: [
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                SizedBox(width: 80, height: 80, child: preview),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: AppColors.green,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.camera_alt, color: Colors.white, size: 14),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(label,
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: context.textPrimaryColor),
                textAlign: TextAlign.center),
            const SizedBox(height: 2),
            Text(hint,
                style: TextStyle(
                    fontSize: 10, color: context.textSecondaryColor),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: AppColors.greenLight,
          shape: isSquare ? BoxShape.rectangle : BoxShape.circle,
          borderRadius: isSquare ? BorderRadius.circular(12) : null,
        ),
        child: const Icon(Icons.add_photo_alternate_outlined,
            color: AppColors.green, size: 32),
      );
}
