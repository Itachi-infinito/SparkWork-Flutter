import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  SessionState copyWith({
    bool? isLoggedIn,
    int? userId,
    String? userName,
    String? userEmail,
    String? userRole,
  }) {
    return SessionState(
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userEmail: userEmail ?? this.userEmail,
      userRole: userRole ?? this.userRole,
    );
  }
}

class SessionNotifier extends StateNotifier<SessionState> {
  SessionNotifier() : super(const SessionState());

  Future<void> login({
    required int userId,
    required String userName,
    required String userEmail,
    required String userRole,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('userId', userId);
    await prefs.setString('userName', userName);
    await prefs.setString('userEmail', userEmail);
    await prefs.setString('userRole', userRole);

    state = SessionState(
      isLoggedIn: true,
      userId: userId,
      userName: userName,
      userEmail: userEmail,
      userRole: userRole,
    );
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    state = const SessionState();
  }

  Future<bool> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('userId');
    final userName = prefs.getString('userName');
    final userEmail = prefs.getString('userEmail');
    final userRole = prefs.getString('userRole');

    if (userId != null && userName != null && userEmail != null && userRole != null) {
      state = SessionState(
        isLoggedIn: true,
        userId: userId,
        userName: userName,
        userEmail: userEmail,
        userRole: userRole,
      );
      return true;
    }
    return false;
  }
}

final sessionProvider = StateNotifierProvider<SessionNotifier, SessionState>(
  (ref) => SessionNotifier(),
);
