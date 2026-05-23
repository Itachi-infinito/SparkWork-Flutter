import 'package:flutter/material.dart';
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
import '../../views/recruiter/recruiter_stats_page.dart';

CustomTransitionPage<void> _slide(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 300),
    reverseTransitionDuration: const Duration(milliseconds: 250),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final slideTween =
          Tween(begin: const Offset(1.0, 0.0), end: Offset.zero)
              .chain(CurveTween(curve: Curves.easeOutCubic));
      final fadeTween =
          Tween<double>(begin: 0.0, end: 1.0)
              .chain(CurveTween(curve: Curves.easeIn));
      return SlideTransition(
        position: animation.drive(slideTween),
        child: FadeTransition(
          opacity: animation.drive(fadeTween),
          child: child,
        ),
      );
    },
  );
}

CustomTransitionPage<void> _fade(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 350),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity:
            CurvedAnimation(parent: animation, curve: Curves.easeInOut),
        child: child,
      );
    },
  );
}

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/splash',
        pageBuilder: (c, s) => _fade(s, const SplashPage()),
      ),
      GoRoute(
        path: '/welcome',
        pageBuilder: (c, s) => _fade(s, const WelcomePage()),
      ),
      GoRoute(
        path: '/login',
        pageBuilder: (c, s) => _slide(s, const LoginPage()),
      ),
      GoRoute(
        path: '/register',
        pageBuilder: (c, s) => _slide(s, const RegisterPage()),
      ),
      GoRoute(
        path: '/register/candidate',
        pageBuilder: (c, s) => _slide(s, const RegisterCandidatePage()),
      ),
      GoRoute(
        path: '/register/recruiter',
        pageBuilder: (c, s) => _slide(s, const RegisterRecruiterPage()),
      ),

      // Candidate
      GoRoute(
        path: '/candidate/home',
        pageBuilder: (c, s) => _fade(s, const CandidateHomePage()),
      ),
      GoRoute(
        path: '/candidate/swipe',
        pageBuilder: (c, s) => _slide(s, const CandidateSwipePage()),
      ),
      GoRoute(
        path: '/candidate/matches',
        pageBuilder: (c, s) => _slide(s, const CandidateMatchesPage()),
      ),
      GoRoute(
        path: '/candidate/profile',
        pageBuilder: (c, s) => _slide(s, const CandidateProfilePage()),
      ),
      GoRoute(
        path: '/candidate/profile/edit',
        pageBuilder: (c, s) =>
            _slide(s, const EditCandidateProfilePage()),
      ),
      GoRoute(
        path: '/candidate/offers',
        pageBuilder: (c, s) => _slide(s, const JobOfferListPage()),
      ),
      GoRoute(
        path: '/candidate/offers/:id',
        pageBuilder: (c, s) {
          final id = int.parse(s.pathParameters['id']!);
          return _slide(s, JobOfferDetailPage(jobOfferId: id));
        },
      ),

      // Recruiter
      GoRoute(
        path: '/recruiter/home',
        pageBuilder: (c, s) => _fade(s, const RecruiterHomePage()),
      ),
      GoRoute(
        path: '/recruiter/swipe',
        pageBuilder: (c, s) => _slide(s, const RecruiterSwipePage()),
      ),
      GoRoute(
        path: '/recruiter/offers',
        pageBuilder: (c, s) =>
            _slide(s, const RecruiterJobOffersPage()),
      ),
      GoRoute(
        path: '/recruiter/offers/add',
        pageBuilder: (c, s) => _slide(s, const AddJobOfferPage()),
      ),
      GoRoute(
        path: '/recruiter/offers/:id/edit',
        pageBuilder: (c, s) {
          final id = int.parse(s.pathParameters['id']!);
          return _slide(s, EditJobOfferPage(jobOfferId: id));
        },
      ),
      GoRoute(
        path: '/recruiter/candidates',
        pageBuilder: (c, s) => _slide(s, const BrowseCandidatesPage()),
      ),
      GoRoute(
        path: '/recruiter/candidates/:id',
        pageBuilder: (c, s) {
          final id = int.parse(s.pathParameters['id']!);
          return _slide(s, CandidateDetailPage(candidateUserId: id));
        },
      ),
      GoRoute(
        path: '/recruiter/matches',
        pageBuilder: (c, s) => _slide(s, const RecruiterMatchesPage()),
      ),
      GoRoute(
        path: '/recruiter/profile',
        pageBuilder: (c, s) => _slide(s, const RecruiterProfilePage()),
      ),
      GoRoute(
        path: '/recruiter/profile/edit',
        pageBuilder: (c, s) =>
            _slide(s, const EditRecruiterProfilePage()),
      ),
      GoRoute(
        path: '/recruiter/likes',
        pageBuilder: (c, s) => _slide(s, const LikesReceivedPage()),
      ),
      GoRoute(
        path: '/recruiter/stats',
        pageBuilder: (c, s) => _slide(s, const RecruiterStatsPage()),
      ),

      // Shared
      GoRoute(
        path: '/messages',
        pageBuilder: (c, s) => _slide(s, const MessagesPage()),
      ),
      GoRoute(
        path: '/messages/:matchId',
        pageBuilder: (c, s) {
          final matchId = int.parse(s.pathParameters['matchId']!);
          return _slide(s, ConversationDetailPage(matchId: matchId));
        },
      ),
      GoRoute(
        path: '/match',
        pageBuilder: (c, s) {
          final extra = s.extra as Map<String, dynamic>? ?? {};
          return _fade(
            s,
            MatchPage(
              matchId: extra['matchId'] as int? ?? 0,
              jobOfferTitle: extra['jobOfferTitle'] as String? ?? '',
              companyName: extra['companyName'] as String? ?? '',
            ),
          );
        },
      ),
      GoRoute(
        path: '/settings',
        pageBuilder: (c, s) => _slide(s, const SettingsPage()),
      ),
    ],
  );
});