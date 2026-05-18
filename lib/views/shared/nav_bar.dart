import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../services/unread_service.dart';

class CandidateNavBar extends ConsumerWidget {
  final int currentIndex;
  const CandidateNavBar({super.key, required this.currentIndex});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasUnread = ref.watch(unreadMessagesProvider).value ?? false;

    return NavigationBar(
      selectedIndex: currentIndex,
      backgroundColor: AppColors.surface,
      indicatorColor: AppColors.primaryLight,
      onDestinationSelected: (index) {
        switch (index) {
          case 0: context.go('/candidate/home'); break;
          case 1: context.go('/candidate/swipe'); break;
          case 2: context.go('/candidate/matches'); break;
          case 3: context.go('/messages'); break;
          case 4: context.go('/candidate/profile'); break;
        }
      },
      destinations: [
        const NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home_rounded),
          label: 'Accueil',
        ),
        const NavigationDestination(
          icon: Icon(Icons.swipe_outlined),
          selectedIcon: Icon(Icons.swipe_rounded),
          label: 'Swipe',
        ),
        const NavigationDestination(
          icon: Icon(Icons.favorite_outline_rounded),
          selectedIcon: Icon(Icons.favorite_rounded),
          label: 'Matches',
        ),
        NavigationDestination(
          icon: Badge(
            isLabelVisible: hasUnread,
            child: const Icon(Icons.chat_bubble_outline_rounded),
          ),
          selectedIcon: Badge(
            isLabelVisible: hasUnread,
            child: const Icon(Icons.chat_bubble_rounded),
          ),
          label: 'Messages',
        ),
        const NavigationDestination(
          icon: Icon(Icons.person_outline_rounded),
          selectedIcon: Icon(Icons.person_rounded),
          label: 'Profil',
        ),
      ],
    );
  }
}

class RecruiterNavBar extends ConsumerWidget {
  final int currentIndex;
  const RecruiterNavBar({super.key, required this.currentIndex});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasUnread = ref.watch(unreadMessagesProvider).value ?? false;

    return NavigationBar(
      selectedIndex: currentIndex,
      backgroundColor: AppColors.surface,
      indicatorColor: AppColors.greenLight,
      onDestinationSelected: (index) {
        switch (index) {
          case 0: context.go('/recruiter/home'); break;
          case 1: context.go('/recruiter/swipe'); break;
          case 2: context.go('/recruiter/offers'); break;
          case 3: context.go('/recruiter/matches'); break;
          case 4: context.go('/recruiter/profile'); break;
        }
      },
      destinations: [
        const NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home_rounded),
          label: 'Accueil',
        ),
        const NavigationDestination(
          icon: Icon(Icons.swipe_outlined),
          selectedIcon: Icon(Icons.swipe_rounded),
          label: 'Swipe',
        ),
        const NavigationDestination(
          icon: Icon(Icons.work_outline_rounded),
          selectedIcon: Icon(Icons.work_rounded),
          label: 'Offres',
        ),
        NavigationDestination(
          icon: Badge(
            isLabelVisible: hasUnread,
            child: const Icon(Icons.favorite_outline_rounded),
          ),
          selectedIcon: Badge(
            isLabelVisible: hasUnread,
            child: const Icon(Icons.favorite_rounded),
          ),
          label: 'Matches',
        ),
        const NavigationDestination(
          icon: Icon(Icons.person_outline_rounded),
          selectedIcon: Icon(Icons.person_rounded),
          label: 'Profil',
        ),
      ],
    );
  }
}