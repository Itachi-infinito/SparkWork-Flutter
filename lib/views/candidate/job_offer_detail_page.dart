import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_theme_ext.dart';
import '../../core/utils/avatar_colors.dart';
import '../../models/candidate_profile.dart';
import '../../models/job_offer.dart';
import '../../repositories/candidate_job_like_repository.dart';
import '../../repositories/candidate_profile_repository.dart';
import '../../repositories/job_offer_repository.dart';
import '../../repositories/match_repository.dart';
import '../../repositories/recruiter_candidate_like_repository.dart';
import '../../services/compatibility_service.dart';
import '../../services/session_service.dart';
import '../../core/constants/app_skills.dart';
import '../../l10n/generated/app_localizations.dart';

class JobOfferDetailPage extends ConsumerStatefulWidget {
  final String jobOfferId;
  const JobOfferDetailPage({super.key, required this.jobOfferId});

  @override
  ConsumerState<JobOfferDetailPage> createState() =>
      _JobOfferDetailPageState();
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
      final offer = await ref.read(jobOfferRepositoryProvider).getOfferById(widget.jobOfferId);
      final profile = await ref.read(candidateProfileRepositoryProvider).getProfile(userId);
      final alreadyLiked = await ref.read(candidateJobLikeRepositoryProvider).hasLiked(userId, widget.jobOfferId);
      int? score;
      if (offer != null && profile != null) {
        score = ref.read(compatibilityServiceProvider).calculateScore(profile, offer);
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
    final loc = AppLocalizations.of(context)!;
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
        final alreadyExists = await matchRepo.matchExists(
            candidateUserId, offer.recruiterUserId, offer.jobOfferId);
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
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(loc.candOfferDetailLikeSuccess),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
          ));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(loc.candOfferDetailError),
          backgroundColor: AppColors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _liking = false);
    }
  }

  // Calcul du breakdown de compatibilité
  List<_CompatCriteria> _buildBreakdown() {
    final p = _candidateProfile;
    final o = _offer;
    if (p == null || o == null) return [];
    final loc = AppLocalizations.of(context)!;

    final matchingSkills = p.skillList
        .where((s) => o.requiredSkillList.any(
            (rs) => rs.toLowerCase() == s.toLowerCase()))
        .length;
    final totalRequired = o.requiredSkillList.length;

    return [
      _CompatCriteria(
        label: loc.candOfferDetailCriteriaSkills,
        detail: totalRequired == 0
            ? loc.candOfferDetailCriteriaNoneRequired
            : loc.candOfferDetailCriteriaSkillsCount(matchingSkills, totalRequired),
        match: totalRequired == 0 || matchingSkills >= (totalRequired / 2).ceil(),
        icon: Icons.star_outline,
      ),
      _CompatCriteria(
        label: loc.candOfferDetailCriteriaContractType,
        detail: o.contractType.isEmpty
            ? loc.candOfferDetailCriteriaNotSpecified
            : (AppSkills.parseSkills(p.desiredContractType)
                    .any((t) => t.toLowerCase() == o.contractType.toLowerCase())
                ? o.contractType
                : '${AppSkills.parseSkills(p.desiredContractType).join(', ')} ≠ ${o.contractType}'),
        match: o.contractType.isEmpty ||
            AppSkills.parseSkills(p.desiredContractType)
                .any((t) => t.toLowerCase() == o.contractType.toLowerCase()),
        icon: Icons.work_outline,
      ),
      _CompatCriteria(
        label: loc.candOfferDetailCriteriaLevel,
        detail: o.level.isEmpty
            ? loc.candOfferDetailCriteriaNotSpecified
            : (p.desiredLevel == o.level
                ? o.level
                : '${p.desiredLevel} ≠ ${o.level}'),
        match: o.level.isEmpty || p.desiredLevel == o.level,
        icon: Icons.trending_up,
      ),
      _CompatCriteria(
        label: loc.candOfferDetailSalary,
        detail: !o.hasSalary
            ? loc.candOfferDetailCriteriaNotSpecified
            : (p.desiredSalaryMin <= o.salaryMax
                ? o.salaryDisplay
                : loc.candOfferDetailCriteriaBelowExpectations),
        match: !o.hasSalary || p.desiredSalaryMin <= o.salaryMax,
        icon: Icons.euro,
      ),
      _CompatCriteria(
        label: loc.candOfferDetailCriteriaRemote,
        detail: o.remoteMode.isEmpty
            ? loc.candOfferDetailCriteriaNotSpecified
            : (p.remotePreference == o.remoteMode
                ? o.remoteMode
                : '${p.remotePreference} ≠ ${o.remoteMode}'),
        match: o.remoteMode.isEmpty || p.remotePreference == o.remoteMode,
        icon: Icons.home_work_outlined,
      ),
    ];
  }

  Widget _buildStickyBar() {
    final loc = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, -4))
        ],
      ),
      child: _alreadyLiked
          ? Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                  color: AppColors.greenLight,
                  borderRadius: BorderRadius.circular(12)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle, color: AppColors.green, size: 20),
                  const SizedBox(width: 8),
                  Text(loc.candOfferDetailAlreadyLiked,
                      style: const TextStyle(
                          color: AppColors.green,
                          fontWeight: FontWeight.w600,
                          fontSize: 16)),
                ],
              ),
            )
          : SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _liking ? null : _handleLike,
                icon: _liking
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.favorite, size: 20),
                label: Text(loc.candOfferDetailLikeButton,
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(loc.candOfferDetailTitle), elevation: 0),
        body: const Center(
            child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: Text(loc.candOfferDetailTitle), elevation: 0),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.error_outline, size: 56, color: AppColors.red),
              const SizedBox(height: 16),
              Text(_error!,
                  style: TextStyle(color: context.textSecondaryColor),
                  textAlign: TextAlign.center),
              const SizedBox(height: 20),
              OutlinedButton(
                  onPressed: _loadData, child: Text(loc.candOfferDetailRetry)),
            ]),
          ),
        ),
      );
    }
    if (_offer == null) {
      return Scaffold(
        appBar: AppBar(title: Text(loc.candOfferDetailTitle), elevation: 0),
        body: Center(
            child: Text(loc.candOfferDetailNotFound,
                style: TextStyle(color: context.textSecondaryColor))),
      );
    }

    final offer = _offer!;
    final gradient = AvatarColors.gradientForString(offer.companyName);
    final scoreColor =
        _score != null && _score! >= 70 ? AppColors.green : const Color(0xFFF59E0B);
    final breakdown = _buildBreakdown();

    return Scaffold(
      bottomNavigationBar: _buildStickyBar(),
      body: CustomScrollView(
        slivers: [
          // Header avec gradient dynamique
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: AppColors.primary,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
              onPressed: () => context.pop(),
            ),
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(gradient: gradient),
                child: Stack(children: [
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 40),
                          Hero(
                            tag: 'offer_avatar_${widget.jobOfferId}',
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  offer.initials,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                        ),
                        const SizedBox(height: 12),
                        Text(offer.companyName,
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 14,
                                fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                  if (_score != null)
                    Positioned(
                      top: 60,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: scoreColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.bolt, color: Colors.white, size: 16),
                          const SizedBox(width: 4),
                          Text(loc.candOfferDetailScore(_score ?? 0),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13)),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Titre + lieu
                  Text(offer.title,
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: context.textPrimaryColor)),
                  const SizedBox(height: 4),
                  Row(children: [
                    Icon(Icons.location_on_outlined,
                        size: 15, color: context.textSecondaryColor),
                    const SizedBox(width: 4),
                    Expanded(
                        child: Text(offer.location,
                            style: TextStyle(
                                color: context.textSecondaryColor,
                                fontSize: 13))),
                  ]),
                  const SizedBox(height: 14),

                  // Badges contrat / niveau / remote
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    if (offer.contractType.isNotEmpty)
                      _Badge(
                          label: offer.contractType,
                          icon: Icons.work_outline),
                    if (offer.level.isNotEmpty)
                      _Badge(
                          label: offer.level,
                          icon: Icons.trending_up_outlined),
                    if (offer.remoteMode.isNotEmpty)
                      _Badge(
                          label: offer.remoteMode,
                          icon: Icons.home_work_outlined),
                  ]),

                  // Salaire
                  if (offer.hasSalary) ...[
                    const SizedBox(height: 16),
                    _SectionCard(
                      title: loc.candOfferDetailSalary,
                      child: Row(children: [
                        const Icon(Icons.euro,
                            size: 20, color: AppColors.green),
                        const SizedBox(width: 8),
                        Text(offer.salaryDisplay,
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.green)),
                      ]),
                    ),
                  ],

                  // Breakdown compatibilité
                  if (breakdown.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _SectionCard(
                      title: loc.candOfferDetailCompatBreakdown,
                      child: Column(
                        children: breakdown
                            .map((c) => _CompatRow(criteria: c))
                            .toList(),
                      ),
                    ),
                  ],

                  // Compétences requises
                  if (offer.requiredSkillList.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _SectionCard(
                      title: loc.candOfferDetailRequiredSkills,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: offer.requiredSkillList
                            .map((s) => _SkillChip(
                                label: s,
                                color: AppColors.primary,
                                bgColor: AppColors.primaryLight,
                                matched: _candidateProfile?.skillList
                                        .any((ps) =>
                                            ps.toLowerCase() ==
                                            s.toLowerCase()) ??
                                    false))
                            .toList(),
                      ),
                    ),
                  ],

                  // Compétences appréciées
                  if (offer.niceSkillList.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _SectionCard(
                      title: loc.candOfferDetailNiceSkills,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: offer.niceSkillList
                            .map((s) => _SkillChip(
                                label: s,
                                color: AppColors.green,
                                bgColor: AppColors.greenLight))
                            .toList(),
                      ),
                    ),
                  ],

                  // Description
                  if (offer.description.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _SectionCard(
                      title: loc.candOfferDetailDescription,
                      child: Text(offer.description,
                          style: TextStyle(
                              color: context.textSecondaryColor,
                              height: 1.6,
                              fontSize: 14)),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompatCriteria {
  final String label;
  final String detail;
  final bool match;
  final IconData icon;
  const _CompatCriteria(
      {required this.label,
      required this.detail,
      required this.match,
      required this.icon});
}

class _CompatRow extends StatelessWidget {
  final _CompatCriteria criteria;
  const _CompatRow({required this.criteria});

  @override
  Widget build(BuildContext context) {
    final color = criteria.match ? AppColors.green : AppColors.red;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(criteria.icon, size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(criteria.label,
                    style: TextStyle(
                        fontSize: 12,
                        color: context.textSecondaryColor,
                        fontWeight: FontWeight.w500)),
                Text(criteria.detail,
                    style: TextStyle(
                        fontSize: 13,
                        color: context.textPrimaryColor,
                        fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Icon(
            criteria.match ? Icons.check_circle : Icons.cancel,
            color: color,
            size: 20,
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
      decoration: BoxDecoration(
          color: context.surfaceVariantColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: context.borderColor)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: context.textSecondaryColor),
        const SizedBox(width: 5),
        Text(label,
            style: TextStyle(
                fontSize: 12,
                color: context.textSecondaryColor,
                fontWeight: FontWeight.w500)),
      ]),
    );
  }
}

class _SkillChip extends StatelessWidget {
  final String label;
  final Color color;
  final Color bgColor;
  final bool matched;
  const _SkillChip(
      {required this.label,
      required this.color,
      required this.bgColor,
      this.matched = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: matched
            ? Border.all(color: AppColors.green, width: 1.5)
            : null,
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (matched) ...[
          const Icon(Icons.check, size: 11, color: AppColors.green),
          const SizedBox(width: 3),
        ],
        Text(label,
            style: TextStyle(
                fontSize: 12, color: color, fontWeight: FontWeight.w500)),
      ]),
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
      decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.borderColor)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: context.textPrimaryColor)),
        const SizedBox(height: 12),
        child,
      ]),
    );
  }
}