import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_skills.dart';
import '../../models/candidate_profile.dart';
import '../../core/widgets/app_avatar.dart';
import '../../models/job_offer.dart';
import '../../repositories/candidate_profile_repository.dart';
import '../../repositories/job_offer_repository.dart';
import '../../repositories/recruiter_candidate_like_repository.dart';
import '../../repositories/candidate_job_like_repository.dart';
import '../../repositories/match_repository.dart';
import '../../services/compatibility_service.dart';
import '../../services/session_service.dart';

class CandidateDetailPage extends ConsumerStatefulWidget {
  final String candidateUserId;
  const CandidateDetailPage({super.key, required this.candidateUserId});

  @override
  ConsumerState<CandidateDetailPage> createState() => _CandidateDetailPageState();
}

class _CandidateDetailPageState extends ConsumerState<CandidateDetailPage> {
  CandidateProfile? _profile;
  List<JobOffer> _recruiterOffers = [];
  JobOffer? _selectedOffer;
  int? _score;
  bool _loading = true;
  bool _liking = false;
  bool _alreadyLiked = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final session = ref.read(sessionProvider);
      final profile = await ref.read(candidateProfileRepositoryProvider).getProfile(widget.candidateUserId);
      final offers = await ref.read(jobOfferRepositoryProvider).getOffersByRecruiter(session.userId);
      final likeRepo = ref.read(recruiterCandidateLikeRepositoryProvider);
      bool alreadyLiked = false;
      for (final offer in offers) {
        if (await likeRepo.hasRecruiterLikedCandidate(session.userId, widget.candidateUserId, offer.jobOfferId)) {
          alreadyLiked = true;
          break;
        }
      }
      final firstOffer = offers.isNotEmpty ? offers.first : null;
      int? score;
      if (profile != null && firstOffer != null) {
        score = ref.read(compatibilityServiceProvider).calculateScore(profile, firstOffer);
      }
      if (mounted) {
        setState(() {
          _profile = profile;
          _recruiterOffers = offers;
          _selectedOffer = firstOffer;
          _score = score;
          _alreadyLiked = alreadyLiked;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onOfferChanged(JobOffer? offer) {
    if (offer == null || _profile == null) return;
    final score = ref.read(compatibilityServiceProvider).calculateScore(_profile!, offer);
    setState(() {
      _selectedOffer = offer;
      _score = score;
    });
  }

  Future<void> _likeCandidate() async {
    if (_selectedOffer == null || _liking) return;
    setState(() => _liking = true);
    try {
      final session = ref.read(sessionProvider);
      final likeRepo = ref.read(recruiterCandidateLikeRepositoryProvider);
      final candidateLikeRepo = ref.read(candidateJobLikeRepositoryProvider);
      final matchRepo = ref.read(matchRepositoryProvider);

      await likeRepo.addLike(session.userId, widget.candidateUserId, _selectedOffer!.jobOfferId);
      final candidateLiked = await candidateLikeRepo.hasLiked(widget.candidateUserId, _selectedOffer!.jobOfferId);

      if (candidateLiked) {
        final alreadyMatched = await matchRepo.matchExists(widget.candidateUserId, session.userId, _selectedOffer!.jobOfferId);
        if (!alreadyMatched) {
          await matchRepo.addMatch(
            candidateUserId: widget.candidateUserId,
            recruiterUserId: session.userId,
            jobOfferId: _selectedOffer!.jobOfferId,
          );
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Match créé avec ${_profile?.fullName ?? 'ce candidat'} !'),
            backgroundColor: AppColors.green,
          ));
        }
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${_profile?.fullName ?? 'Candidat'} liké !'),
          backgroundColor: AppColors.primary,
        ));
      }
      if (mounted) setState(() => _alreadyLiked = true);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Erreur lors du like.'),
        backgroundColor: AppColors.red,
      ));
    } finally {
      if (mounted) setState(() => _liking = false);
    }
  }

  Widget _buildScoreCard() {
    if (_score == null || _selectedOffer == null || _profile == null) {
      return const SizedBox();
    }
    final score = _score!;
    final color = score >= 70 ? AppColors.green : score >= 40 ? AppColors.orange : AppColors.red;
    final bgColor = score >= 70 ? AppColors.greenLight : score >= 40 ? AppColors.orangeLight : const Color(0xFFFFE4E4);
    final label = score >= 70 ? 'Excellent match' : score >= 40 ? 'Match partiel' : 'Match faible';

    final offer = _selectedOffer!;
    final profile = _profile!;
    final candidateSkills = profile.skillList.map((s) => s.toLowerCase()).toSet();
    final candidateContractTypes = AppSkills.parseSkills(profile.desiredContractType).map((t) => t.toLowerCase()).toList();

    final skillsMatch = offer.requiredSkillList.isEmpty
        ? null
        : offer.requiredSkillList.where((s) => candidateSkills.contains(s.toLowerCase())).length;
    final skillsTotal = offer.requiredSkillList.length;

    final contractMatch = offer.contractType.isEmpty ||
        candidateContractTypes.contains(offer.contractType.toLowerCase());
    final levelMatch = offer.level.isEmpty ||
        profile.desiredLevel.toLowerCase() == offer.level.toLowerCase();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Compatibilité avec l\'offre',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AppColors.textPrimary)),
      const SizedBox(height: 10),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(24)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.bolt, color: color, size: 18),
                const SizedBox(width: 6),
                Text('$score%',
                    style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 20)),
              ]),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 14)),
                Text('avec "${offer.title}"',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    overflow: TextOverflow.ellipsis),
              ]),
            ),
          ]),
          const SizedBox(height: 14),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 12),
          if (skillsMatch != null)
            _ScoreRow(
              icon: Icons.code_outlined,
              label: 'Compétences requises',
              ok: skillsMatch == skillsTotal,
              detail: '$skillsMatch / $skillsTotal correspondantes',
            ),
          _ScoreRow(
            icon: Icons.description_outlined,
            label: 'Type de contrat',
            ok: contractMatch,
            detail: profile.desiredContractType.isNotEmpty
                ? candidateContractTypes.join(', ')
                : 'Non renseigné',
          ),
          _ScoreRow(
            icon: Icons.bar_chart_outlined,
            label: 'Niveau',
            ok: levelMatch,
            detail: profile.desiredLevel.isNotEmpty ? profile.desiredLevel : 'Non renseigné',
          ),
          if (offer.hasSalary && profile.hasSalary)
            _ScoreRow(
              icon: Icons.euro_outlined,
              label: 'Salaire',
              ok: (((profile.desiredSalaryMin + profile.desiredSalaryMax) / 2) -
                      ((offer.salaryMin + offer.salaryMax) / 2)).abs() <= 500,
              detail: profile.salaryDisplay,
            ),
        ]),
      ),
      const SizedBox(height: 16),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }
    if (_profile == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Profil candidat'), backgroundColor: AppColors.background, elevation: 0),
        body: const Center(child: Text('Profil introuvable.', style: TextStyle(color: AppColors.textSecondary))),
      );
    }

    final profile = _profile!;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 220, pinned: true,
            backgroundColor: AppColors.primary,
            iconTheme: const IconThemeData(color: Colors.white),
            title: const Text('Profil candidat', style: TextStyle(color: Colors.white)),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const SizedBox(height: 48),
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                    child: AppAvatar(name: profile.fullName, radius: 44, photoPath: profile.photoUrl),
                  ),
                  const SizedBox(height: 12),
                  Text(profile.fullName,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22)),
                  if (profile.location.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.location_on, color: Colors.white.withOpacity(0.8), size: 14),
                      const SizedBox(width: 4),
                      Text(profile.location,
                          style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13)),
                    ]),
                  ],
                ])),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _SectionCard(title: 'Préférences', children: [
                  _DetailRow(
                    icon: Icons.description_outlined,
                    label: 'Contrat',
                    value: profile.desiredContractType.isNotEmpty ? profile.desiredContractType : 'Non renseigné',
                  ),
                  const Divider(height: 1, color: AppColors.border),
                  _DetailRow(
                    icon: Icons.bar_chart_outlined,
                    label: 'Niveau',
                    value: profile.desiredLevel.isNotEmpty ? profile.desiredLevel : 'Non renseigné',
                  ),
                  const Divider(height: 1, color: AppColors.border),
                  _DetailRow(
                    icon: Icons.home_work_outlined,
                    label: 'Télétravail',
                    value: profile.remotePreference.isNotEmpty ? profile.remotePreference : 'Non renseigné',
                  ),
                  if (profile.hasSalary) ...[
                    const Divider(height: 1, color: AppColors.border),
                    _DetailRow(
                      icon: Icons.euro_outlined,
                      label: 'Salaire souhaité',
                      value: profile.salaryDisplay,
                    ),
                  ],
                ]),
                const SizedBox(height: 16),
                if (profile.skillList.isNotEmpty) ...[
                  const Text('Compétences',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AppColors.textPrimary)),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border)),
                    child: Wrap(
                      spacing: 8, runSpacing: 6,
                      children: profile.skillList.map((s) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                            color: AppColors.primaryLight, borderRadius: BorderRadius.circular(8)),
                        child: Text(s,
                            style: const TextStyle(
                                color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w500)),
                      )).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (profile.bio.isNotEmpty) ...[
                  const Text('À propos',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AppColors.textPrimary)),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border)),
                    child: Text(profile.bio,
                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, height: 1.6)),
                  ),
                  const SizedBox(height: 24),
                ],
                if (_recruiterOffers.isNotEmpty) ...[
                  const Text('Associer à une offre',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AppColors.textPrimary)),
                  const SizedBox(height: 10),
                  if (_recruiterOffers.length == 1)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border)),
                      child: Row(children: [
                        const Icon(Icons.work_outline, size: 18, color: AppColors.textSecondary),
                        const SizedBox(width: 10),
                        Expanded(child: Text(_selectedOffer?.title ?? '',
                            style: const TextStyle(color: AppColors.textPrimary, fontSize: 14))),
                      ]),
                    )
                  else
                    DropdownButtonFormField<JobOffer>(
                      value: _selectedOffer,
                      decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.work_outline),
                          labelText: 'Sélectionner une offre'),
                      items: _recruiterOffers
                          .map((o) => DropdownMenuItem(
                              value: o,
                              child: Text(o.title, overflow: TextOverflow.ellipsis)))
                          .toList(),
                      onChanged: _onOfferChanged,
                    ),
                  const SizedBox(height: 20),
                  _buildScoreCard(),
                ],
                if (_recruiterOffers.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                        color: AppColors.orangeLight, borderRadius: BorderRadius.circular(12)),
                    child: const Row(children: [
                      Icon(Icons.info_outline, color: AppColors.orange, size: 18),
                      SizedBox(width: 10),
                      Expanded(child: Text(
                        'Publiez une offre avant de pouvoir liker un candidat.',
                        style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
                      )),
                    ]),
                  ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: (_liking || _alreadyLiked || _recruiterOffers.isEmpty || _selectedOffer == null)
                        ? null
                        : _likeCandidate,
                    icon: _liking
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Icon(_alreadyLiked ? Icons.favorite : Icons.favorite_border, size: 20),
                    label: Text(
                        _alreadyLiked ? 'Déjà liké' : 'Liker ce candidat',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _alreadyLiked ? AppColors.textSecondary : AppColors.red,
                      minimumSize: const Size(double.infinity, 52),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool ok;
  final String detail;
  const _ScoreRow({required this.icon, required this.label, required this.ok, required this.detail});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            Text(detail,
                style: const TextStyle(fontSize: 12, color: AppColors.textPrimary, fontWeight: FontWeight.w500)),
          ]),
        ),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: ok ? AppColors.greenLight : const Color(0xFFFFE4E4),
            shape: BoxShape.circle,
          ),
          child: Icon(
            ok ? Icons.check : Icons.close,
            size: 12,
            color: ok ? AppColors.green : AppColors.red,
          ),
        ),
      ]),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _SectionCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AppColors.textPrimary)),
      const SizedBox(height: 10),
      Container(
        decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border)),
        child: Column(children: children),
      ),
    ]);
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _DetailRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
        const Spacer(),
        Flexible(child: Text(value,
            style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500, fontSize: 14),
            textAlign: TextAlign.end)),
      ]),
    );
  }
}