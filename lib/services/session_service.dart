import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/app_user.dart';
import 'session_security_service.dart';

final profileVersionProvider = StateProvider<int>((ref) => 0);

final sessionProvider =
    StateNotifierProvider<SessionNotifier, SessionState>((ref) {
  return SessionNotifier(ref);
});

class SessionState {
  final AppUser? user;
  final bool isLoading;

  const SessionState({this.user, this.isLoading = true});

  bool get isLoggedIn => user != null;
  String get role => user?.role ?? '';
  String get userId => user?.uid ?? '';
  String get email => user?.email ?? '';
  String get fullName => user?.fullName ?? '';
  bool get isCandidate => role == 'candidate';
  bool get isRecruiter => role == 'recruiter';
  bool get isAdmin => user?.isAdmin ?? false;

  // Backward-compat aliases
  String get userRole => role;
  String get userName => fullName;
  String get userEmail => email;
}

class SessionNotifier extends StateNotifier<SessionState> {
  final Ref _ref;
  StreamSubscription<User?>? _authSub;

  SessionNotifier(this._ref) : super(const SessionState(isLoading: true)) {
    _authSub =
        FirebaseAuth.instance.authStateChanges().listen(_onAuthChanged);
  }

  Future<void> _onAuthChanged(User? firebaseUser) async {
    if (firebaseUser == null) {
      state = const SessionState(isLoading: false);
      return;
    }
    try {
      // Juste après une inscription, le compte Auth existe avant que le
      // document users/{uid} (écrit séparément par AuthService.register)
      // n'apparaisse — sans cette tentative répétée, ce changement d'état
      // d'auth peut être traité dans cette fenêtre et abandonner
      // définitivement, sans jamais relire le document une fois écrit.
      DocumentSnapshot<Map<String, dynamic>> doc = await FirebaseFirestore
          .instance
          .collection('users')
          .doc(firebaseUser.uid)
          .get();
      for (var attempt = 0; !doc.exists && attempt < 5; attempt++) {
        await Future.delayed(Duration(milliseconds: 300 * (attempt + 1)));
        doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(firebaseUser.uid)
            .get();
      }
      if (!doc.exists) {
        state = const SessionState(isLoading: false);
        return;
      }
      final data = doc.data()!;
      final appUser = AppUser(
        uid: firebaseUser.uid,
        email: firebaseUser.email ?? '',
        fullName: data['fullName'] as String? ?? '',
        role: data['role'] as String? ?? '',
        isAdmin: data['isAdmin'] as bool? ?? false,
      );
      state = SessionState(user: appUser, isLoading: false);
    } catch (_) {
      state = const SessionState(isLoading: false);
    }
  }

  Future<void> reload() async {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser != null) await _onAuthChanged(firebaseUser);
  }

  Future<void> logout() async {
    // Marquer la session inactive AVANT le signOut : une fois déconnecté,
    // les Security Rules refuseraient l'écriture sur active_sessions.
    try {
      await _ref.read(sessionSecurityServiceProvider).markCurrentSessionLoggedOut();
    } catch (_) {}
    await FirebaseAuth.instance.signOut();
    state = const SessionState(isLoading: false);
  }

  void clear() => state = const SessionState(isLoading: false);

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}