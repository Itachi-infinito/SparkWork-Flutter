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

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1A1D27)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 20,
              offset: const Offset(0, 4)),
          BoxShadow(
              color: AppColors.primary.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, 2)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: NavigationBar(
          selectedIndex: currentIndex,
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF1A1D27)
              : AppColors.surface,
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.transparent,
          indicatorColor: AppColors.primaryLight,
          height: 64,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
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
                label: 'Accueil'),
            const NavigationDestination(
                icon: Icon(Icons.swipe_outlined),
                selectedIcon: Icon(Icons.swipe_rounded),
                label: 'Swipe'),
            const NavigationDestination(
                icon: Icon(Icons.favorite_outline_rounded),
                selectedIcon: Icon(Icons.favorite_rounded),
                label: 'Matches'),
            NavigationDestination(
              icon: Badge(
                  isLabelVisible: hasUnread,
                  child: const Icon(Icons.chat_bubble_outline_rounded)),
              selectedIcon: Badge(
                  isLabelVisible: hasUnread,
                  child: const Icon(Icons.chat_bubble_rounded)),
              label: 'Messages',
            ),
            const NavigationDestination(
                icon: Icon(Icons.person_outline_rounded),
                selectedIcon: Icon(Icons.person_rounded),
                label: 'Profil'),
          ],
        ),
      ),
    );
  }
}

class RecruiterNavBar extends ConsumerWidget {
  final int currentIndex;
  const RecruiterNavBar({super.key, required this.currentIndex});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasUnread = ref.watch(unreadMessagesProvider).value ?? false;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1A1D27)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 20,
              offset: const Offset(0, 4)),
          BoxShadow(
              color: AppColors.green.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, 2)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: NavigationBar(
          selectedIndex: currentIndex,
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF1A1D27)
              : AppColors.surface,
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.transparent,
          indicatorColor: AppColors.greenLight,
          height: 64,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
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
                label: 'Accueil'),
            const NavigationDestination(
                icon: Icon(Icons.swipe_outlined),
                selectedIcon: Icon(Icons.swipe_rounded),
                label: 'Swipe'),
            const NavigationDestination(
                icon: Icon(Icons.work_outline_rounded),
                selectedIcon: Icon(Icons.work_rounded),
                label: 'Offres'),
            NavigationDestination(
              icon: Badge(
                  isLabelVisible: hasUnread,
                  child: const Icon(Icons.favorite_outline_rounded)),
              selectedIcon: Badge(
                  isLabelVisible: hasUnread,
                  child: const Icon(Icons.favorite_rounded)),
              label: 'Matches',
            ),
            const NavigationDestination(
                icon: Icon(Icons.person_outline_rounded),
                selectedIcon: Icon(Icons.person_rounded),
                label: 'Profil'),
          ],
        ),
      ),
    );
  }
}
