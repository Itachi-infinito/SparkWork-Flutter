import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../services/database_service.dart';
import '../../services/session_service.dart';

class EditRecruiterProfilePage extends ConsumerStatefulWidget {
  const EditRecruiterProfilePage({super.key});

  @override
  ConsumerState<EditRecruiterProfilePage> createState() =>
      _EditRecruiterProfilePageState();
}

class _EditRecruiterProfilePageState
    extends ConsumerState<EditRecruiterProfilePage> {
  final _nameCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl.text = ref.read(sessionProvider).userName;
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('Le nom doit contenir au moins 2 caractères.'),
          backgroundColor: AppColors.red));
      return;
    }
    setState(() => _saving = true);
    try {
      final session = ref.read(sessionProvider);
      final db =
          await ref.read(databaseServiceProvider).database;
      await db.update('users', {'fullName': name},
          where: 'userId = ?',
          whereArgs: [session.userId]);
      await ref.read(sessionProvider.notifier).login(
            userId: session.userId,
            userName: name,
            userEmail: session.userEmail,
            userRole: session.userRole,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Profil mis à jour !'),
          backgroundColor: AppColors.green));
      context.pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Modifier le profil'),
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => context.pop()),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.green))
                : const Text('Sauvegarder',
                    style: TextStyle(
                        color: AppColors.green,
                        fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Nom complet',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                  labelText: 'Votre nom',
                  prefixIcon: Icon(Icons.person_outline)),
            ),
            const SizedBox(height: 20),
            const Text('Email',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.email_outlined,
                      color: AppColors.textHint, size: 20),
                  const SizedBox(width: 12),
                  Text(session.userEmail,
                      style: const TextStyle(
                          color: AppColors.textSecondary)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Text('L\'email ne peut pas être modifié.',
                style: TextStyle(
                    fontSize: 12, color: AppColors.textHint)),
          ],
        ),
      ),
    );
  }
}