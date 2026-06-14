import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_theme_ext.dart';
import '../../models/candidate_profile.dart';
import '../../repositories/candidate_profile_repository.dart';
import '../../services/session_service.dart';
import '../../services/verification_service.dart';

class VerificationScreen extends ConsumerStatefulWidget {
  const VerificationScreen({super.key});

  @override
  ConsumerState<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends ConsumerState<VerificationScreen> {
  CandidateProfile? _profile;
  bool _loading = true;
  bool _uploading = false;
  File? _frontFile;
  File? _backFile;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userId = ref.read(sessionProvider).userId;
    final profile = await ref.read(candidateProfileRepositoryProvider).getProfile(userId);
    if (mounted) setState(() { _profile = profile; _loading = false; });
  }

  Future<void> _pickImage(String side) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null || !mounted) return;
    setState(() {
      if (side == 'front') {
        _frontFile = File(picked.path);
      } else {
        _backFile = File(picked.path);
      }
    });
  }

  Future<void> _submit() async {
    if (_frontFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez ajouter le recto de votre pièce d\'identité')),
      );
      return;
    }
    setState(() => _uploading = true);
    try {
      final userId = ref.read(sessionProvider).userId;
      final svc = ref.read(verificationServiceProvider);
      await svc.submitDocument(userId, _frontFile!, 'front');
      if (_backFile != null) {
        await svc.submitDocument(userId, _backFile!, 'back');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Documents envoyés — vérification en cours (24-48h)'),
              backgroundColor: AppColors.green),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors de l\'envoi'), backgroundColor: AppColors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vérification d\'identité'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    final status = _profile?.verificationStatus ?? 'unverified';

    if (status == 'verified') return _buildVerifiedState();
    if (status == 'pending') return _buildPendingState();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(status),
          const SizedBox(height: 24),
          _buildBenefits(),
          const SizedBox(height: 24),
          Text('Pièce d\'identité',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: context.textPrimaryColor)),
          const SizedBox(height: 4),
          Text('Carte nationale d\'identité, passeport ou titre de séjour',
              style: TextStyle(fontSize: 12, color: context.textSecondaryColor)),
          const SizedBox(height: 16),
          _DocPickerTile(
            label: 'Recto *',
            file: _frontFile,
            onTap: () => _pickImage('front'),
          ),
          const SizedBox(height: 12),
          _DocPickerTile(
            label: 'Verso (optionnel)',
            file: _backFile,
            onTap: () => _pickImage('back'),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lock_outline, color: AppColors.primary, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Vos documents sont chiffrés et supprimés après vérification. Ils ne sont jamais partagés avec des recruteurs.',
                    style: TextStyle(fontSize: 11, color: context.textSecondaryColor, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _uploading ? null : _submit,
              icon: _uploading
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.send_outlined, color: Colors.white),
              label: const Text('Envoyer pour vérification',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(String status) {
    final isRejected = status == 'rejected';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isRejected ? AppColors.redLight : AppColors.primaryLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isRejected ? AppColors.red.withOpacity(0.3) : AppColors.primary.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(
            isRejected ? Icons.gpp_bad_outlined : Icons.shield_outlined,
            color: isRejected ? AppColors.red : AppColors.primary,
            size: 36,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isRejected ? 'Vérification rejetée' : 'Vérifiez votre identité',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: isRejected ? AppColors.red : AppColors.primary),
                ),
                const SizedBox(height: 4),
                Text(
                  isRejected
                      ? _profile?.verificationRejectionReason ?? 'Document non valide. Veuillez re-soumettre.'
                      : 'Obtenez le badge de confiance et augmentez vos chances d\'être contacté.',
                  style: TextStyle(fontSize: 12, color: context.textSecondaryColor, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefits() {
    const items = [
      (Icons.verified_user, 'Badge de confiance sur votre profil'),
      (Icons.trending_up, 'Priorité dans les résultats recruteurs'),
      (Icons.handshake_outlined, '+40% de matches en moyenne'),
    ];
    return Column(
      children: items.map((item) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(item.$1, size: 16, color: AppColors.primary),
          ),
          const SizedBox(width: 10),
          Text(item.$2, style: TextStyle(fontSize: 13, color: context.textPrimaryColor)),
        ]),
      )).toList(),
    );
  }

  Widget _buildVerifiedState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.verified_user, size: 64, color: Color(0xFF3B82F6)),
            ),
            const SizedBox(height: 20),
            const Text('Identité vérifiée',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF3B82F6))),
            const SizedBox(height: 8),
            Text('Votre badge de confiance est actif. Les recruteurs voient que votre identité a été vérifiée.',
                textAlign: TextAlign.center,
                style: TextStyle(color: context.textSecondaryColor, height: 1.5)),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.orange.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.hourglass_bottom_outlined, size: 64, color: AppColors.orange),
            ),
            const SizedBox(height: 20),
            const Text('Vérification en cours',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.orange)),
            const SizedBox(height: 8),
            Text('Vos documents sont en cours d\'examen. Vous recevrez une notification dans les 24 à 48 heures ouvrées.',
                textAlign: TextAlign.center,
                style: TextStyle(color: context.textSecondaryColor, height: 1.5)),
          ],
        ),
      ),
    );
  }
}

class _DocPickerTile extends StatelessWidget {
  final String label;
  final File? file;
  final VoidCallback onTap;
  const _DocPickerTile({required this.label, required this.file, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          color: file != null ? AppColors.primaryLight : context.surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: file != null ? AppColors.primary : context.borderColor,
            width: file != null ? 2 : 1,
          ),
        ),
        child: file != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.file(file!, fit: BoxFit.cover),
                    Positioned(
                      bottom: 0, left: 0, right: 0,
                      child: Container(
                        color: Colors.black54,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: const Text('Appuyer pour changer',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white, fontSize: 11)),
                      ),
                    ),
                  ],
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_photo_alternate_outlined,
                      size: 32, color: context.textSecondaryColor),
                  const SizedBox(height: 8),
                  Text(label,
                      style: TextStyle(fontSize: 13, color: context.textSecondaryColor)),
                ],
              ),
      ),
    );
  }
}
