import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../models/candidate_profile.dart';
import '../../models/job_offer.dart';
import '../../repositories/candidate_profile_repository.dart';
import '../../repositories/job_offer_repository.dart';
import '../../repositories/recruiter_candidate_like_repository.dart';
import '../../repositories/candidate_job_like_repository.dart';
import '../../repositories/match_repository.dart';
import '../../services/session_service.dart';

class CandidateDetailPage extends ConsumerStatefulWidget {
  final int candidateUserId;
  const CandidateDetailPage({super.key, required this.candidateUserId});

  @override
  ConsumerState<CandidateDetailPage> createState() => _CandidateDetailPageState();
}

class _CandidateDetailPageState extends ConsumerState<CandidateDetailPage> {
  CandidateProfile? _profile;
  List<JobOffer> _recruiterOffers = [];
  JobOffer? _selectedOffer;
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
      if (mounted) {
        setState(() {
          _profile = profile;
          _recruiterOffers = offers;
          _selectedOffer = offers.isNotEmpty ? offers.first : null;
          _alreadyLiked = alreadyLiked;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
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
          await matchRepo.addMatch(candidateUserId: widget.candidateUserId, recruiterUserId: session.userId, jobOfferId: _selectedOffer!.jobOfferId);
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Match créé avec ${_profile?.fullName ?? 'ce candidat'} !'), backgroundColor: AppColors.green));
        }
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${_profile?.fullName ?? 'Candidat'} liké !'), backgroundColor: AppColors.primary));
      }
      if (mounted) setState(() => _alreadyLiked = true);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erreur lors du like.'), backgroundColor: AppColors.red));
    } finally {
      if (mounted) setState(() => _liking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(backgroundColor: AppColors.background, body: Center(child: CircularProgressIndicator(color: AppColors.primary)));
    if (_profile == null) return Scaffold(backgroundColor: AppColors.background, appBar: AppBar(title: const Text('Profil candidat'), backgroundColor: AppColors.background, elevation: 0), body: const Center(child: Text('Profil introuvable.', style: TextStyle(color: AppColors.textSecondary))));

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
                decoration: const BoxDecoration(gradient: LinearGradient(colors: [AppColors.primary, AppColors.primaryDark], begin: Alignment.topLeft, end: Alignment.bottomRight)),
                child: SafeArea(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const SizedBox(height: 48),
                  CircleAvatar(radius: 44, backgroundColor: Colors.white.withOpacity(0.2), child: Text(profile.initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 36))),
                  const SizedBox(height: 12),
                  Text(profile.fullName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22)),
                  if (profile.location.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.location_on, color: Colors.white.withOpacity(0.8), size: 14),
                      const SizedBox(width: 4),
                      Text(profile.location, style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13)),
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
                  _DetailRow(icon: Icons.description_outlined, label: 'Contrat', value: profile.desiredContractType.isNotEmpty ? profile.desiredContractType : 'Non renseigné'),
                  const Divider(height: 1, color: AppColors.border),
                  _DetailRow(icon: Icons.bar_chart_outlined, label: 'Niveau', value: profile.desiredLevel.isNotEmpty ? profile.desiredLevel : 'Non renseigné'),
                  const Divider(height: 1, color: AppColors.border),
                  _DetailRow(icon: Icons.home_work_outlined, label: 'Télétravail', value: profile.remotePreference.isNotEmpty ? profile.remotePreference : 'Non renseigné'),
                ]),
                const SizedBox(height: 16),
                if (profile.skillList.isNotEmpty) ...[
                  const Text('Compétences', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AppColors.textPrimary)),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity, padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
                    child: Wrap(spacing: 8, runSpacing: 6, children: profile.skillList.map((s) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(8)),
                      child: Text(s, style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w500)),
                    )).toList()),
                  ),
                  const SizedBox(height: 16),
                ],
                if (profile.bio.isNotEmpty) ...[
                  const Text('À propos', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AppColors.textPrimary)),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity, padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
                    child: Text(profile.bio, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, height: 1.6)),
                  ),
                  const SizedBox(height: 24),
                ],
                if (_recruiterOffers.isNotEmpty) ...[
                  const Text('Associer à une offre', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AppColors.textPrimary)),
                  const SizedBox(height: 10),
                  if (_recruiterOffers.length == 1)
                    Container(
                      width: double.infinity, padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                      child: Row(children: [
                        const Icon(Icons.work_outline, size: 18, color: AppColors.textSecondary),
                        const SizedBox(width: 10),
                        Expanded(child: Text(_selectedOffer?.title ?? '', style: const TextStyle(color: AppColors.textPrimary, fontSize: 14))),
                      ]),
                    )
                  else
                    DropdownButtonFormField<JobOffer>(
                      value: _selectedOffer,
                      decoration: const InputDecoration(prefixIcon: Icon(Icons.work_outline), labelText: 'Sélectionner une offre'),
                      items: _recruiterOffers.map((o) => DropdownMenuItem(value: o, child: Text(o.title, overflow: TextOverflow.ellipsis))).toList(),
                      onChanged: (v) => setState(() => _selectedOffer = v),
                    ),
                  const SizedBox(height: 20),
                ],
                if (_recruiterOffers.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: AppColors.orangeLight, borderRadius: BorderRadius.circular(12)),
                    child: const Row(children: [
                      Icon(Icons.info_outline, color: AppColors.orange, size: 18),
                      SizedBox(width: 10),
                      Expanded(child: Text('Publiez une offre avant de pouvoir liker un candidat.', style: TextStyle(fontSize: 13, color: AppColors.textPrimary))),
                    ]),
                  ),
                const SizedBox(height: 16),
                SizedBox(width: double.infinity, child: ElevatedButton.icon(
                  onPressed: (_liking || _alreadyLiked || _recruiterOffers.isEmpty || _selectedOffer == null) ? null : _likeCandidate,
                  icon: _liking
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Icon(_alreadyLiked ? Icons.favorite : Icons.favorite_border, size: 20),
                  label: Text(_alreadyLiked ? 'Déjà liké' : 'Liker ce candidat', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _alreadyLiked ? AppColors.textSecondary : AppColors.red,
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                )),
                const SizedBox(height: 32),
              ]),
            ),
          ),
        ],
      ),
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
      Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AppColors.textPrimary)),
      const SizedBox(height: 10),
      Container(decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)), child: Column(children: children)),
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
        Flexible(child: Text(value, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500, fontSize: 14), textAlign: TextAlign.end)),
      ]),
    );
  }
}