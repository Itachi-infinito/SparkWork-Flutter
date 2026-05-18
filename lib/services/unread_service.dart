import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../repositories/match_repository.dart';
import '../repositories/message_repository.dart';
import 'session_service.dart';

final unreadMessagesProvider = FutureProvider<bool>((ref) async {
  final session = ref.watch(sessionProvider);
  if (!session.isLoggedIn) return false;

  final prefs = await SharedPreferences.getInstance();
  final lastSeenStr =
      prefs.getString('last_seen_messages_${session.userId}');
  final lastSeen = lastSeenStr != null
      ? DateTime.tryParse(lastSeenStr) ??
          DateTime.fromMillisecondsSinceEpoch(0)
      : DateTime.fromMillisecondsSinceEpoch(0);

  final matchRepo = ref.read(matchRepositoryProvider);
  final msgRepo = ref.read(messageRepositoryProvider);

  final matches = session.isCandidate
      ? await matchRepo.getMatchesByCandidate(session.userId)
      : await matchRepo.getMatchesByRecruiter(session.userId);

  for (final m in matches) {
    final last = await msgRepo.getLastMessage(m.matchId);
    if (last != null &&
        last.senderUserId != session.userId &&
        (DateTime.tryParse(last.sentAt)?.isAfter(lastSeen) ?? false)) {
      return true;
    }
  }
  return false;
});

Future<void> markMessagesAsSeen(int userId) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(
    'last_seen_messages_$userId',
    DateTime.now().toIso8601String(),
  );
}