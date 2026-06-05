import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../services/session_service.dart';
import '../../views/public/splash_page.dart';
import '../../views/public/welcome_page.dart';
import '../../views/public/login_page.dart';
import '../../views/public/register_page.dart';
import '../../views/public/register_candidate_page.dart';
import '../../views/public/register_recruiter_page.dart';
import '../../views/candidate/candidate_home_page.dart';
import '../../views/candidate/candidate_swipe_page.dart';
import '../../views/candidate/candidate_matches_page.dart';
import '../../views/candidate/candidate_profile_page.dart';
import '../../views/candidate/edit_candidate_profile_page.dart';
import '../../views/candidate/job_offer_list_page.dart';
import '../../views/candidate/job_offer_detail_page.dart';
import '../../views/recruiter/recruiter_home_page.dart';
import '../../views/recruiter/recruiter_swipe_page.dart';
import '../../views/recruiter/recruiter_job_offers_page.dart';
import '../../views/recruiter/add_job_offer_page.dart';
import '../../views/recruiter/edit_job_offer_page.dart';
import '../../views/recruiter/browse_candidates_page.dart';
import '../../views/recruiter/candidate_detail_page.dart';
import '../../views/recruiter/recruiter_matches_page.dart';
import '../../views/recruiter/recruiter_profile_page.dart';
import '../../views/recruiter/edit_recruiter_profile_page.dart';
import '../../views/recruiter/likes_received_page.dart';
import '../../views/shared/messages_page.dart';
import '../../views/shared/conversation_detail_page.dart';
import '../../views/shared/match_page.dart';
import '../../views/shared/settings_page.dart';
import '../../views/recruiter/recruiter_stats_page.dart';

const _publicPaths = [
  '/splash',
  '/welcome',
  '/login',
  '/register',
  '/register/candidate',
  '/register/recruiter',
];

bool _isPublic(String path) =>
    _publicPaths.any((p) => path == p || path.startsWith('$p/'));

final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterRefreshNotifier(ref);
  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: notifier,
    redirect: (context, state) {
      final session = ref.read(sessionProvider);
      final path = state.matchedLocation;

      if (session.isLoading) {
        return path == '/splash' ? null : '/splash';
      }

      if (!session.isLoggedIn && !_isPublic(path)) {
        return '/welcome';
      }

      if (session.isLoggedIn && _isPublic(path) && path != '/splash') {
        return session.isCandidate ? '/candidate/home' : '/recruiter/home';
      }

      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashPage()),
      GoRoute(path: '/welcome', builder: (_, __) => const WelcomePage()),
      GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterPage()),
      GoRoute(path: '/register/candidate', builder: (_, __) => const RegisterCandidatePage()),
      GoRoute(path: '/register/recruiter', builder: (_, __) => const RegisterRecruiterPage()),

      // Candidate
      GoRoute(path: '/candidate/home', builder: (_, __) => const CandidateHomePage()),
      GoRoute(path: '/candidate/swipe', builder: (_, __) => const CandidateSwipePage()),
      GoRoute(path: '/candidate/matches', builder: (_, __) => const CandidateMatchesPage()),
      GoRoute(path: '/candidate/profile', builder: (_, __) => const CandidateProfilePage()),
      GoRoute(path: '/candidate/profile/edit', builder: (_, __) => const EditCandidateProfilePage()),
      GoRoute(path: '/candidate/offers', builder: (_, __) => const JobOfferListPage()),
      GoRoute(
        path: '/candidate/offers/:id',
        builder: (_, state) => JobOfferDetailPage(
            jobOfferId: state.pathParameters['id']!),
      ),

      // Recruiter
      GoRoute(path: '/recruiter/home', builder: (_, __) => const RecruiterHomePage()),
      GoRoute(path: '/recruiter/swipe', builder: (_, __) => const RecruiterSwipePage()),
      GoRoute(path: '/recruiter/offers', builder: (_, __) => const RecruiterJobOffersPage()),
      GoRoute(path: '/recruiter/offers/add', builder: (_, __) => const AddJobOfferPage()),
      GoRoute(
        path: '/recruiter/offers/:id/edit',
        builder: (_, state) => EditJobOfferPage(
            jobOfferId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/recruiter/candidates', builder: (_, __) => const BrowseCandidatesPage()),
      GoRoute(
        path: '/recruiter/candidates/:id',
        builder: (_, state) => CandidateDetailPage(
            candidateUserId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/recruiter/matches', builder: (_, __) => const RecruiterMatchesPage()),
      GoRoute(path: '/recruiter/profile', builder: (_, __) => const RecruiterProfilePage()),
      GoRoute(path: '/recruiter/profile/edit', builder: (_, __) => const EditRecruiterProfilePage()),
      GoRoute(path: '/recruiter/likes', builder: (_, __) => const LikesReceivedPage()),
      GoRoute(path: '/recruiter/stats', builder: (_, __) => const RecruiterStatsPage()),

      // Shared
      GoRoute(path: '/messages', builder: (_, __) => const MessagesPage()),
      GoRoute(
        path: '/messages/:matchId',
        builder: (_, state) => ConversationDetailPage(
            matchId: state.pathParameters['matchId']!),
      ),
      GoRoute(
        path: '/match',
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return MatchPage(
            matchId: extra['matchId'] as String? ?? '',
            jobOfferTitle: extra['jobOfferTitle'] as String? ?? '',
            companyName: extra['companyName'] as String? ?? '',
          );
        },
      ),
      GoRoute(path: '/settings', builder: (_, __) => const SettingsPage()),
    ],
  );
});

class _RouterRefreshNotifier extends ChangeNotifier {
  late final ProviderSubscription<SessionState> _sub;

  _RouterRefreshNotifier(Ref ref) {
    _sub = ref.listen<SessionState>(sessionProvider, (_, __) {
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _sub.close();
    super.dispose();
  }
}