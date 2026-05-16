import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashPage(),
      ),
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const WelcomePage(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(
        path: '/register/candidate',
        builder: (context, state) => const RegisterCandidatePage(),
      ),
      GoRoute(
        path: '/register/recruiter',
        builder: (context, state) => const RegisterRecruiterPage(),
      ),

      // Candidate routes
      GoRoute(
        path: '/candidate/home',
        builder: (context, state) => const CandidateHomePage(),
      ),
      GoRoute(
        path: '/candidate/swipe',
        builder: (context, state) => const CandidateSwipePage(),
      ),
      GoRoute(
        path: '/candidate/matches',
        builder: (context, state) => const CandidateMatchesPage(),
      ),
      GoRoute(
        path: '/candidate/profile',
        builder: (context, state) => const CandidateProfilePage(),
      ),
      GoRoute(
        path: '/candidate/profile/edit',
        builder: (context, state) => const EditCandidateProfilePage(),
      ),
      GoRoute(
        path: '/candidate/offers',
        builder: (context, state) => const JobOfferListPage(),
      ),
      GoRoute(
        path: '/candidate/offers/:id',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return JobOfferDetailPage(jobOfferId: id);
        },
      ),

      // Recruiter routes
      GoRoute(
        path: '/recruiter/home',
        builder: (context, state) => const RecruiterHomePage(),
      ),
      GoRoute(
        path: '/recruiter/swipe',
        builder: (context, state) => const RecruiterSwipePage(),
      ),
      GoRoute(
        path: '/recruiter/offers',
        builder: (context, state) => const RecruiterJobOffersPage(),
      ),
      GoRoute(
        path: '/recruiter/offers/add',
        builder: (context, state) => const AddJobOfferPage(),
      ),
      GoRoute(
        path: '/recruiter/offers/:id/edit',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return EditJobOfferPage(jobOfferId: id);
        },
      ),
      GoRoute(
        path: '/recruiter/candidates',
        builder: (context, state) => const BrowseCandidatesPage(),
      ),
      GoRoute(
        path: '/recruiter/candidates/:id',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return CandidateDetailPage(candidateUserId: id);
        },
      ),
      GoRoute(
        path: '/recruiter/matches',
        builder: (context, state) => const RecruiterMatchesPage(),
      ),
      GoRoute(
        path: '/recruiter/profile',
        builder: (context, state) => const RecruiterProfilePage(),
      ),
      GoRoute(
        path: '/recruiter/profile/edit',
        builder: (context, state) => const EditRecruiterProfilePage(),
      ),
      GoRoute(
        path: '/recruiter/likes',
        builder: (context, state) => const LikesReceivedPage(),
      ),

      // Shared routes
      GoRoute(
        path: '/messages',
        builder: (context, state) => const MessagesPage(),
      ),
      GoRoute(
        path: '/messages/:matchId',
        builder: (context, state) {
          final matchId = int.parse(state.pathParameters['matchId']!);
          return ConversationDetailPage(matchId: matchId);
        },
      ),
      GoRoute(
        path: '/match',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return MatchPage(
            matchId: extra['matchId'] as int? ?? 0,
            jobOfferTitle: extra['jobOfferTitle'] as String? ?? '',
            companyName: extra['companyName'] as String? ?? '',
          );
        },
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsPage(),
      ),
    ],
  );
});