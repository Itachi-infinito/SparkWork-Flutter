import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../repositories/match_repository.dart';
import '../repositories/message_repository.dart';
import 'session_service.dart';

final unreadMessagesProvider = FutureProvider<bool>((ref) async {
  final session = ref.watch(sessionProvider);
  if (!session.isLoggedIn) return false;

  final userId = session.userId;
  final prefs = await SharedPreferences.getInstance();
  final lastSeenStr = prefs.getString('last_seen_messages_$userId');
  final lastSeen =
      lastSeenStr != null ? DateTime.tryParse(lastSeenStr) : null;

  final matchRepo = ref.read(matchRepositoryProvider);
  final msgRepo = ref.read(messageRepositoryProvider);

  final matches = session.isCandidate
      ? await matchRepo.getMatchesByCandidate(userId)
      : await matchRepo.getMatchesByRecruiter(userId);

  for (final match in matches) {
    final last = await msgRepo.getLastMessage(match.matchId);
    if (last == null) continue;
    if (last.senderUserId == userId) continue;
    if (lastSeen == null) return true;
    final sentAt = DateTime.tryParse(last.sentAt);
    if (sentAt != null && sentAt.isAfter(lastSeen)) return true;
  }
  return false;
});

Future<void> markMessagesAsSeen(String userId) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(
    'last_seen_messages_$userId',
    DateTime.now().toIso8601String(),
  );
}