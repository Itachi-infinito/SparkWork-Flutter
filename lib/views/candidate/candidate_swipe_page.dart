import 'package:appinio_swiper/appinio_swiper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
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
import '../shared/nav_bar.dart';

class CandidateSwipePage extends ConsumerStatefulWidget {
  const CandidateSwipePage({super.key});
  @override
  ConsumerState<CandidateSwipePage> createState() => _CandidateSwipePageState();
}

class _CandidateSwipePageState extends ConsumerState<CandidateSwipePage> {
  final _swiperController = AppinioSwiperController();
  List<JobOffer> _offers = [];
  CandidateProfile? _profile;
  bool _loading = true;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final session = ref.read(sessionProvider);
    final profileRepo = ref.read(candidateProfileRepositoryProvider);
    final offerRepo = ref.read(jobOfferRepositoryProvider);
    final likeRepo = ref.read(candidateJobLikeRepositoryProvider);

    _profile = await profileRepo.getProfile(session.userId);
    final all = await offerRepo.getAllOffers();
    final likedIds = await likeRepo.getLikedJobOfferIds(session.userId);

    setState(() {
      _offers = all.where((o) => !likedIds.contains(o.jobOfferId)).toList();
      _currentIndex = 0;
      _loading = false;
    });
  }

  Future<void> _handleLike(int index) async {
    if (index >= _offers.length) return;
    final offer = _offers[index];
    final session = ref.read(sessionProvider);
    final likeRepo = ref.read(candidateJobLikeRepositoryProvider);
    final recruiterLikeRepo = ref.read(recruiterCandidateLikeRepositoryProvider);
    final matchRepo = ref.read(matchRepositoryProvider);

    await likeRepo.addLike(session.userId, offer.jobOfferId);

    final recruiterLiked = await recruiterLikeRepo.hasRecruiterLikedCandidate(
      offer.recruiterUserId, session.userId);

    if (recruiterLiked) {
      await matchRepo.addMatch(
        candidateUserId: session.userId,
        candidateName: session.userName,
        recruiterUserId: offer.recruiterUserId,
        offer: offer,
      );
      if (mounted) {
        context.go('/match', extra: {
          'participantId': offer.recruiterUserId,
          'participantName': offer.companyName,
        });
      }
    }
  }

  int _score(JobOffer offer) {
    if (_profile == null) return 0;
    return ref.read(compatibilityServiceProvider).calculateScore(_profile!, offer);
  }

  Color _scoreColor(int score) {
    if (score >= 75) return AppColors.green;
    if (score >= 45) return AppColors.primary;
    return AppColors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: const CandidateNavBar(currentIndex: 1),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Découvrir', style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, color: AppColors.textSecondary),
                    onPressed: _load,
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : _offers.isEmpty
                      ? _buildEmpty()
                      : AppinioSwiper(
                          controller: _swiperController,
                          cardCount: _offers.length,
                          backgroundCardCount: 2,
                          backgroundCardScale: 0.92,
                          backgroundCardOffset: const Offset(0, 16),
                          onSwipeEnd: (prev, current, activity) {
                            if (activity is Swipe) {
                              if (activity.direction == AxisDirection.right) {
                                _handleLike(prev);
                              }
                              setState(() => _currentIndex = current ?? _offers.length);
                            }
                          },
                          cardBuilder: (context, index) => _buildCard(_offers[index]),
                        ),
            ),
            if (!_loading && _offers.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 16, top: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _ActionBtn(icon: Icons.close_rounded, color: AppColors.red, size: 52,
                        onTap: () => _swiperController.swipeLeft()),
                    const SizedBox(width: 20),
                    _ActionBtn(icon: Icons.bolt_rounded, color: AppColors.superLike, size: 44,
                        onTap: () => _swiperController.swipeRight()),
                    const SizedBox(width: 20),
                    _ActionBtn(icon: Icons.favorite_rounded, color: AppColors.green, size: 52,
                        onTap: () => _swiperController.swipeRight()),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(JobOffer offer) {
    final score = _score(offer);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Container(
            height: 160,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary.withOpacity(0.8), AppColors.primary],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Stack(
              children: [
                Center(
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Container(
                      width: 72, height: 72,
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                      child: Center(
                        child: Text(offer.initials, style: GoogleFonts.inter(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.primary)),
                      ),
                    ),
                  ]),
                ),
                Positioned(
                  top: 12, right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: _scoreColor(score).withOpacity(0.15), borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _scoreColor(score).withOpacity(0.5))),
                    child: Text('%', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: _scoreColor(score))),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(offer.title, style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary), maxLines: 2),
                const SizedBox(height: 4),
                Text(offer.companyName, style: GoogleFonts.inter(fontSize: 15, color: AppColors.primary, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(offer.location, style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),
                ]),
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  if (offer.contractType.isNotEmpty) _Badge(offer.contractType, AppColors.primaryLight, AppColors.primary),
                  if (offer.level.isNotEmpty) _Badge(offer.level, AppColors.greenLight, AppColors.green),
                  if (offer.remoteMode.isNotEmpty) _Badge(offer.remoteMode, const Color(0xFFFFF8E1), const Color(0xFFF59E0B)),
                ]),
                if (offer.hasSalary) ...[
                  const SizedBox(height: 12),
                  Row(children: [
                    const Icon(Icons.euro_rounded, size: 16, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(offer.salaryDisplay, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  ]),
                ],
                if (offer.requiredSkillList.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text('Compétences requises', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                  const SizedBox(height: 6),
                  Wrap(spacing: 6, runSpacing: 6, children: offer.requiredSkillList.take(5)
                      .map((s) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(6), border: Border.all(color: AppColors.border)),
                            child: Text(s, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textPrimary)),
                          ))
                      .toList()),
                ],
                if (offer.description.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(offer.description, style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary, height: 1.5), maxLines: 3, overflow: TextOverflow.ellipsis),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.search_off_rounded, size: 72, color: AppColors.textLight),
          const SizedBox(height: 16),
          Text('Plus d\'offres disponibles', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text('Reviens bientôt pour de nouvelles offres.', style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary), textAlign: TextAlign.center),
          const SizedBox(height: 24),
          ElevatedButton.icon(onPressed: _load, icon: const Icon(Icons.refresh_rounded), label: const Text('Actualiser')),
        ]),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final VoidCallback onTap;
  const _ActionBtn({required this.icon, required this.color, required this.size, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size, height: size,
        decoration: BoxDecoration(color: AppColors.surface, shape: BoxShape.circle,
            border: Border.all(color: AppColors.border, width: 1.5),
            boxShadow: [BoxShadow(color: color.withOpacity(0.15), blurRadius: 12, offset: const Offset(0, 4))]),
        child: Icon(icon, color: color, size: size * 0.45),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;
  const _Badge(this.label, this.bg, this.fg);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
    );
  }
}
