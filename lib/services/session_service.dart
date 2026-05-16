import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final sessionProvider = StateNotifierProvider<SessionNotifier, SessionState>((ref) {
  return SessionNotifier();
});

class SessionState {
  final bool isLoggedIn;
  final int userId;
  final String userName;
  final String userEmail;
  final String userRole;

  const SessionState({
    this.isLoggedIn = false,
    this.userId = 0,
    this.userName = '',
    this.userEmail = '',
    this.userRole = '',
  });

  bool get isCandidate => userRole == 'candidate';
  bool get isRecruiter => userRole == 'recruiter';
}

class SessionNotifier extends StateNotifier<SessionState> {
  SessionNotifier() : super(const SessionState());

  Future<void> login({
    required int userId,
    required String userName,
    required String userEmail,
    required String userRole,
  }) async {
    state = SessionState(
      isLoggedIn: true,
      userId: userId,
      userName: userName,
      userEmail: userEmail,
      userRole: userRole,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', true);
    await prefs.setInt('userId', userId);
    await prefs.setString('userName', userName);
    await prefs.setString('userEmail', userEmail);
    await prefs.setString('userRole', userRole);
  }

  Future<void> logout() async {
    state = const SessionState();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  Future<bool> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    if (!isLoggedIn) return false;

    final userId = prefs.getInt('userId') ?? 0;
    final userName = prefs.getString('userName') ?? '';
    final userEmail = prefs.getString('userEmail') ?? '';
    final userRole = prefs.getString('userRole') ?? '';

    if (userId == 0 || userRole.isEmpty) return false;

    state = SessionState(
      isLoggedIn: true,
      userId: userId,
      userName: userName,
      userEmail: userEmail,
      userRole: userRole,
    );
    return true;
  }
}