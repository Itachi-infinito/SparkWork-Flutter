import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../views/public/splash_page.dart';
import '../../views/public/welcome_page.dart';
import '../../views/public/login_page.dart';
import '../../views/public/register_page.dart';
import '../../views/public/role_selection_page.dart';
import '../../views/public/register_candidate_page.dart';
import '../../views/public/register_recruiter_page.dart';
import '../../views/candidate/candidate_home_page.dart';
import '../../views/candidate/candidate_swipe_page.dart';
import '../../views/candidate/candidate_profile_page.dart';
import '../../views/candidate/edit_candidate_profile_page.dart';
import '../../views/candidate/job_offer_list_page.dart';
import '../../views/candidate/job_offer_detail_page.dart';
import '../../views/candidate/matches_page.dart';
import '../../views/recruiter/recruiter_home_page.dart';
import '../../views/recruiter/recruiter_swipe_page.dart';
import '../../views/recruiter/recruiter_profile_page.dart';
import '../../views/recruiter/edit_recruiter_profile_page.dart';
import '../../views/recruiter/recruiter_job_offers_page.dart';
import '../../views/recruiter/add_job_offer_page.dart';
import '../../views/recruiter/edit_job_offer_page.dart';
import '../../views/recruiter/browse_candidates_page.dart';
import '../../views/recruiter/recruiter_matches_page.dart';
import '../../views/recruiter/likes_received_page.dart';
import '../../views/recruiter/candidate_detail_page.dart';
import '../../views/shared/messages_page.dart';
import '../../views/shared/conversation_detail_page.dart';
import '../../views/shared/match_page.dart';
import '../../views/shared/settings_page.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashPage()),
      GoRoute(path: '/welcome', builder: (_, __) => const WelcomePage()),
      GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterPage()),
      GoRoute(path: '/role-selection', builder: (_, __) => const RoleSelectionPage()),
      GoRoute(path: '/register-candidate', builder: (_, __) => const RegisterCandidatePage()),
      GoRoute(path: '/register-recruiter', builder: (_, __) => const RegisterRecruiterPage()),

      GoRoute(path: '/candidate/home', builder: (_, __) => const CandidateHomePage()),
      GoRoute(path: '/candidate/swipe', builder: (_, __) => const CandidateSwipePage()),
      GoRoute(path: '/candidate/profile', builder: (_, __) => const CandidateProfilePage()),
      GoRoute(path: '/candidate/profile/edit', builder: (_, __) => const EditCandidateProfilePage()),
      GoRoute(path: '/candidate/offers', builder: (_, __) => const JobOfferListPage()),
      GoRoute(
        path: '/candidate/offers/:id',
        builder: (_, state) => JobOfferDetailPage(
          offerId: int.parse(state.pathParameters['id']!),
        ),
      ),
      GoRoute(path: '/candidate/matches', builder: (_, __) => const MatchesPage()),

      GoRoute(path: '/recruiter/home', builder: (_, __) => const RecruiterHomePage()),
      GoRoute(path: '/recruiter/swipe', builder: (_, __) => const RecruiterSwipePage()),
      GoRoute(path: '/recruiter/profile', builder: (_, __) => const RecruiterProfilePage()),
      GoRoute(path: '/recruiter/profile/edit', builder: (_, __) => const EditRecruiterProfilePage()),
      GoRoute(path: '/recruiter/offers', builder: (_, __) => const RecruiterJobOffersPage()),
      GoRoute(path: '/recruiter/offers/add', builder: (_, __) => const AddJobOfferPage()),
      GoRoute(
        path: '/recruiter/offers/:id/edit',
        builder: (_, state) => EditJobOfferPage(
          offerId: int.parse(state.pathParameters['id']!),
        ),
      ),
      GoRoute(path: '/recruiter/candidates', builder: (_, __) => const BrowseCandidatesPage()),
      GoRoute(path: '/recruiter/matches', builder: (_, __) => const RecruiterMatchesPage()),
      GoRoute(path: '/recruiter/likes', builder: (_, __) => const LikesReceivedPage()),
      GoRoute(
        path: '/recruiter/candidates/:id',
        builder: (_, state) => CandidateDetailPage(
          candidateId: int.parse(state.pathParameters['id']!),
        ),
      ),

      GoRoute(path: '/messages', builder: (_, __) => const MessagesPage()),
      GoRoute(
        path: '/messages/:matchId',
        builder: (_, state) => ConversationDetailPage(
          matchId: int.parse(state.pathParameters['matchId']!),
        ),
      ),
      GoRoute(
        path: '/match',
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>;
          return MatchPage(
            participantId: extra['participantId'] as int,
            participantName: extra['participantName'] as String,
          );
        },
      ),
      GoRoute(path: '/settings', builder: (_, __) => const SettingsPage()),
    ],
  );
});