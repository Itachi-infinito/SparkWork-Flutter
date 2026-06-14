import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_theme_ext.dart';
import '../../services/rating_service.dart';
import '../../services/session_service.dart';

class RatingScreen extends ConsumerStatefulWidget {
  final String matchId;
  final String targetUserId;
  final String targetName;
  final bool isRecruiter;
  const RatingScreen({
    super.key,
    required this.matchId,
    required this.targetUserId,
    required this.targetName,
    required this.isRecruiter,
  });

  @override
  ConsumerState<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends ConsumerState<RatingScreen> {
  int _score = 0;
  final _commentCtrl = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_score == 0) {
      setState(() => _error = 'Veuillez choisir une note');
      return;
    }
    setState(() { _submitting = true; _error = null; });
    try {
      final svc = ref.read(ratingServiceProvider);
      final session = ref.read(sessionProvider);
      await svc.submitRating(
        fromUserId: session.userId,
        toUserId: widget.targetUserId,
        matchId: widget.matchId,
        score: _score,
        comment: _commentCtrl.text.trim(),
        targetType: widget.isRecruiter ? 'candidate' : 'recruiter',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Évaluation envoyée — merci !'), backgroundColor: AppColors.green),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _submitting = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Évaluer'),
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () => context.pop()),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [AppColors.primary, AppColors.primaryDark],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: AppColors.primary.withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 8)),
                      ],
                    ),
                    child: const Icon(Icons.star, color: Colors.white, size: 36),
                  ),
                  const SizedBox(height: 16),
                  Text('Évaluer ${widget.targetName}',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: context.textPrimaryColor)),
                  const SizedBox(height: 6),
                  Text(
                    widget.isRecruiter
                        ? 'Comment s\'est passée la collaboration avec ce candidat ?'
                        : 'Comment s\'est passée votre expérience avec cet employeur ?',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: context.textSecondaryColor, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  final star = i + 1;
                  return GestureDetector(
                    onTap: () => setState(() => _score = star),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Icon(
                        star <= _score ? Icons.star_rounded : Icons.star_outline_rounded,
                        size: 48,
                        color: star <= _score ? const Color(0xFFFBBF24) : context.textHintColor,
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                _score == 0 ? 'Sélectionnez une note'
                    : _score == 1 ? 'Très insuffisant'
                    : _score == 2 ? 'Insuffisant'
                    : _score == 3 ? 'Satisfaisant'
                    : _score == 4 ? 'Bien'
                    : 'Excellent',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _score == 0 ? context.textHintColor : const Color(0xFFFBBF24)),
              ),
            ),
            const SizedBox(height: 24),
            Text('Commentaire (optionnel)',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.textPrimaryColor)),
            const SizedBox(height: 8),
            TextField(
              controller: _commentCtrl,
              maxLines: 4,
              maxLength: 300,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Partagez votre expérience...',
                hintStyle: TextStyle(color: context.textHintColor),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.redLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(children: [
                  const Icon(Icons.error_outline, color: AppColors.red, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_error!, style: const TextStyle(color: AppColors.red, fontSize: 13))),
                ]),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _submitting
                    ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Envoyer l\'évaluation',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
