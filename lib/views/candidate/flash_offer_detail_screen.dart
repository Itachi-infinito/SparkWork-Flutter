import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_theme_ext.dart';
import '../../models/job_offer.dart';
import '../../repositories/candidate_job_like_repository.dart';
import '../../repositories/match_repository.dart';
import '../../repositories/recruiter_candidate_like_repository.dart';
import '../../services/notification_service.dart';
import '../../services/session_service.dart';

class FlashOfferDetailScreen extends ConsumerStatefulWidget {
  final JobOffer offer;
  const FlashOfferDetailScreen({super.key, required this.offer});

  @override
  ConsumerState<FlashOfferDetailScreen> createState() => _FlashOfferDetailScreenState();
}

class _FlashOfferDetailScreenState extends ConsumerState<FlashOfferDetailScreen> {
  late Timer _timer;
  bool _applying = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  Future<void> _apply() async {
    setState(() => _applying = true);
    try {
      final session = ref.read(sessionProvider);
      final userId = session.userId;
      final likeRepo = ref.read(candidateJobLikeRepositoryProvider);
      final recruiterLikeRepo = ref.read(recruiterCandidateLikeRepositoryProvider);
      final matchRepo = ref.read(matchRepositoryProvider);

      await likeRepo.addLike(userId, widget.offer.jobOfferId);

      final mutual = await recruiterLikeRepo.hasRecruiterLikedCandidateAny(
          widget.offer.recruiterUserId, userId);

      if (mutual) {
        final exists = await matchRepo.matchExists(
            userId, widget.offer.recruiterUserId, widget.offer.jobOfferId);
        if (!exists) {
          final matchId = await matchRepo.addMatch(
            candidateUserId: userId,
            recruiterUserId: widget.offer.recruiterUserId,
            jobOfferId: widget.offer.jobOfferId,
            jobOfferTitle: widget.offer.title,
            companyName: widget.offer.companyName,
          );
          NotificationService.showMatch(
            jobOfferTitle: widget.offer.title,
            companyName: widget.offer.companyName,
          );
          if (mounted) {
            context.pop();
            context.push('/match', extra: {
              'matchId': matchId,
              'jobOfferTitle': widget.offer.title,
              'companyName': widget.offer.companyName,
            });
          }
          return;
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Candidature envoyée !'),
            backgroundColor: Color(0xFFF59E0B),
          ),
        );
        context.pop();
      }
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.offer;
    final remaining = o.flashRemainingDisplay;
    final isExpired = !o.isFlashActive;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF92400E), Color(0xFFB45309), Color(0xFFF59E0B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      top: -30, right: -30,
                      child: Container(
                        width: 150, height: 150,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.07),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -20, left: -20,
                      child: Container(
                        width: 100, height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.05),
                        ),
                      ),
                    ),
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 40),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.15),
                            ),
                            child: const Icon(Icons.bolt, color: Colors.white, size: 40),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(Icons.timer_outlined, color: Colors.white, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                isExpired ? 'Expirée' : remaining,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13),
                              ),
                            ]),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => context.pop(),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.bolt, color: Color(0xFFF59E0B), size: 16),
                    const SizedBox(width: 4),
                    const Text('MISSION FLASH',
                        style: TextStyle(
                            color: Color(0xFFF59E0B),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            letterSpacing: 1)),
                  ]),
                  const SizedBox(height: 8),
                  Text(o.title,
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: context.textPrimaryColor)),
                  const SizedBox(height: 4),
                  Text(o.companyName,
                      style: TextStyle(fontSize: 16, color: context.textSecondaryColor)),
                  const SizedBox(height: 16),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    if (o.location.isNotEmpty)
                      _InfoChip(Icons.location_on_outlined, o.location),
                    if (o.contractType.isNotEmpty)
                      _InfoChip(Icons.description_outlined, o.contractType),
                    if (o.remoteMode.isNotEmpty)
                      _InfoChip(Icons.home_work_outlined, o.remoteMode),
                    if (o.hasSalary)
                      _InfoChip(Icons.euro, o.salaryDisplay, color: AppColors.green),
                  ]),
                  if (o.urgencyLevel == 'very_urgent' || o.urgencyLevel == 'urgent') ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: (o.urgencyLevel == 'very_urgent'
                                ? AppColors.red
                                : const Color(0xFFF59E0B))
                            .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: o.urgencyLevel == 'very_urgent'
                              ? AppColors.red
                              : const Color(0xFFF59E0B),
                        ),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(
                          Icons.priority_high,
                          size: 14,
                          color: o.urgencyLevel == 'very_urgent'
                              ? AppColors.red
                              : const Color(0xFFF59E0B),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          o.urgencyLevel == 'very_urgent' ? 'Très urgent' : 'Urgent',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: o.urgencyLevel == 'very_urgent'
                                  ? AppColors.red
                                  : const Color(0xFFF59E0B)),
                        ),
                      ]),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Text('Description',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: context.textPrimaryColor)),
                  const SizedBox(height: 8),
                  Text(o.description,
                      style: TextStyle(
                          height: 1.6, color: context.textSecondaryColor)),
                  if (o.requiredSkillList.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text('Compétences requises',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: context.textPrimaryColor)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: o.requiredSkillList
                          .map((s) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryLight,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(s,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w500)),
                              ))
                          .toList(),
                    ),
                  ],
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: isExpired
          ? Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.redLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.timer_off, color: AppColors.red, size: 18),
                  SizedBox(width: 8),
                  Text('Cette mission Flash a expiré',
                      style: TextStyle(color: AppColors.red, fontWeight: FontWeight.w600)),
                ]),
              ),
            )
          : Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              child: ElevatedButton.icon(
                onPressed: _applying ? null : _apply,
                icon: _applying
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.bolt, color: Colors.white),
                label: const Text('Postuler maintenant',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF59E0B),
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  const _InfoChip(this.icon, this.label, {this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.textSecondaryColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withOpacity(0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: c),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, color: c, fontWeight: FontWeight.w500)),
      ]),
    );
  }
}
