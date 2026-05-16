import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../models/candidate_profile.dart';
import '../../models/job_offer.dart';
import '../../repositories/candidate_job_like_repository.dart';
import '../../repositories/candidate_profile_repository.dart';
import '../../repositories/job_offer_repository.dart';
import '../../repositories/match_repository.dart';
import '../../repositories/recruiter_candidate_like_repository.dart';
import '../../services/compatibility_service.dart';
import '../../services/session_service.dart';

class JobOfferDetailPage extends ConsumerStatefulWidget {
  final int jobOfferId;
  const JobOfferDetailPage({super.key, required this.jobOfferId});

  @override
  ConsumerState<JobOfferDetailPage> createState() => _JobOfferDetailPageState();
}

class _JobOfferDetailPageState extends ConsumerState<JobOfferDetailPage> {
  JobOffer? _offer;
  CandidateProfile? _candidateProfile;
  int? _score;
  bool _alreadyLiked = false;
  bool _loading = true;
  bool _liking = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() { _loading = true; _error = null; });
    try {
      final session = ref.read(sessionProvider);
      final userId = session.userId;
      final offerRepo = ref.read(jobOfferRepositoryProvider);
      final likeRepo = ref.read(candidateJobLikeRepositoryProvider);
      final profileRepo = ref.read(candidateProfileRepositoryProvider);
      final compatService = ref.read(compatibilityServiceProvider);

      final offer = await offerRepo.getOfferById(widget.jobOfferId);
      final profile = await profileRepo.getProfile(userId);
      final alreadyLiked = await likeRepo.hasLiked(userId, widget.jobOfferId);

      int? score;
      if (offer != null && profile != null) {
        score = compatService.calculateScore(profile, offer);
      }

      if (mounted) {
        setState(() {
          _offer = offer;
          _candidateProfile = profile;
          _score = score;
          _alreadyLiked = alreadyLiked;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = "Erreur lors du chargement de l'offre."; _loading = false; });
    }
  }

  Future<void> _handleLike() async {
    if (_offer == null || _alreadyLiked || _liking) return;
    setState(() => _liking = true);
    try {
      final session = ref.read(sessionProvider);
      final candidateUserId = session.userId;
      final offer = _offer!;
      final likeRepo = ref.read(candidateJobLikeRepositoryProvider);
      final recruiterLikeRepo = ref.read(recruiterCandidateLikeRepositoryProvider);
      final matchRepo = ref.read(matchRepositoryProvider);

      await likeRepo.addLike(candidateUserId, offer.jobOfferId);
      if (mounted) setState(() => _alreadyLiked = true);

      final mutual = await recruiterLikeRepo.hasRecruiterLikedCandidate(
          offer.recruiterUserId, candidateUserId, offer.jobOfferId);

      if (mutual) {
        final alreadyExists = await matchRepo.matchExists(candidateUserId, offer.recruiterUserId, offer.jobOfferId);
        if (!alreadyExists) {
          final matchId = await matchRepo.addMatch(
            candidateUserId: candidateUserId,
            recruiterUserId: offer.recruiterUserId,
            jobOfferId: offer.jobOfferId,
          );
          if (mounted) {
            context.push('/match', extra: {
              'matchId': matchId,
              'jobOfferTitle': offer.title,
              'companyName': offer.companyName,
            });
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Offre likée ! En attente du recruteur...'),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
          ));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Une erreur est survenue.'),
          backgroundColor: AppColors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _liking = false);
    }
  }

  Widget _buildStickyBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, -4))],
      ),
      child: _alreadyLiked
          ? Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(color: AppColors.greenLight, borderRadius: BorderRadius.circular(12)),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, color: AppColors.green, size: 20),
                  SizedBox(width: 8),
                  Text('Déjà liké', style: TextStyle(color: AppColors.green, fontWeight: FontWeight.w600, fontSize: 16)),
                ],
              ),
            )
          : SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _liking ? null : _handleLike,
                icon: _liking
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.favorite, size: 20),
                label: const Text("J'aime cette offre", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text("Détail de l'offre"), backgroundColor: AppColors.background, elevation: 0),
        body: const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }
    if (_error != null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text("Détail de l'offre"), backgroundColor: AppColors.background, elevation: 0),
        body: Center(child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.error_outline, size: 56, color: AppColors.red),
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: AppColors.textSecondary), textAlign: TextAlign.center),
            const SizedBox(height: 20),
            OutlinedButton(onPressed: _loadData, child: const Text('Réessayer')),
          ]),
        )),
      );
    }
    if (_offer == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text("Détail de l'offre"), backgroundColor: AppColors.background, elevation: 0),
        body: const Center(child: Text('Offre introuvable.', style: TextStyle(color: AppColors.textSecondary))),
      );
    }

    final offer = _offer!;
    final requiredSkills = offer.requiredSkillList;
    final niceSkills = offer.niceSkillList;

    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: _buildStickyBar(),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: AppColors.primary,
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [AppColors.primary, AppColors.primaryDark], begin: Alignment.topLeft, end: Alignment.bottomRight),
                ),
                child: Stack(children: [
                  Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const SizedBox(height: 40),
                    Text(offer.initials, style: const TextStyle(color: Colors.white, fontSize: 64, fontWeight: FontWeight.bold, letterSpacing: 2)),
                  ])),
                  if (_score != null)
                    Positioned(
                      top: 60, right: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _score! >= 70 ? AppColors.green : const Color(0xFFF59E0B),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.bolt, color: Colors.white, size: 16),
                          const SizedBox(width: 4),
                          Text('$_score% compatible', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                        ]),
                      ),
                    ),
                ]),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(offer.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                const SizedBox(height: 6),
                Text(offer.companyName, style: const TextStyle(fontSize: 16, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
                const SizedBox(height: 6),
                Row(children: [
                  const Icon(Icons.location_on_outlined, size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Expanded(child: Text(offer.location, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14))),
                ]),
                const SizedBox(height: 16),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  if (offer.contractType.isNotEmpty) _Badge(label: offer.contractType, icon: Icons.work_outline),
                  if (offer.level.isNotEmpty) _Badge(label: offer.level, icon: Icons.trending_up_outlined),
                  if (offer.remoteMode.isNotEmpty) _Badge(label: offer.remoteMode, icon: Icons.home_work_outlined),
                ]),
                if (offer.hasSalary) ...[
                  const SizedBox(height: 20),
                  _SectionCard(title: 'Salaire', child: Row(children: [
                    const Icon(Icons.euro, size: 20, color: AppColors.green),
                    const SizedBox(width: 8),
                    Text(offer.salaryDisplay, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.green)),
                  ])),
                ],
                if (requiredSkills.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _SectionCard(title: 'Compétences requises', child: Wrap(
                    spacing: 8, runSpacing: 8,
                    children: requiredSkills.map((s) => _SkillChip(label: s, color: AppColors.primary, bgColor: AppColors.primaryLight)).toList(),
                  )),
                ],
                if (niceSkills.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _SectionCard(title: 'Compétences appréciées', child: Wrap(
                    spacing: 8, runSpacing: 8,
                    children: niceSkills.map((s) => _SkillChip(label: s, color: AppColors.green, bgColor: AppColors.greenLight)).toList(),
                  )),
                ],
                if (offer.description.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _SectionCard(title: 'Description du poste', child: Text(offer.description, style: const TextStyle(color: AppColors.textSecondary, height: 1.6, fontSize: 14))),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final IconData icon;
  const _Badge({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: AppColors.textSecondary),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
      ]),
    );
  }
}

class _SkillChip extends StatelessWidget {
  final String label;
  final Color color;
  final Color bgColor;
  const _SkillChip({required this.label, required this.color, required this.bgColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500)),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary)),
        const SizedBox(height: 12),
        child,
      ]),
    );
  }
}