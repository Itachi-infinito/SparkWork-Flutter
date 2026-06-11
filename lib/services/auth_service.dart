import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'notification_service.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

class AuthService {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signIn(String email, String password) async {
    final cred =
        await _auth.signInWithEmailAndPassword(email: email, password: password);
    // Enregistrement du token FCM en arrière-plan (non bloquant)
    if (cred.user != null) {
      NotificationService.registerToken(cred.user!.uid);
    }
    return cred;
  }

  Future<(bool, String)> register({
    required String fullName,
    required String email,
    required String password,
    required String role,
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final uid = cred.user!.uid;
      await _db.collection('users').doc(uid).set({
        'uid': uid,
        'fullName': fullName,
        'email': email,
        'role': role,
        'acceptedTermsAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      // Email de vérification — non bloquant si l'envoi échoue
      try {
        await cred.user!.sendEmailVerification();
      } catch (_) {}
      return (true, '');
    } on FirebaseAuthException catch (e) {
      return (false, _authError(e.code));
    } catch (e) {
      return (false, e.toString());
    }
  }

  Future<(bool, String)> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return (true, '');
    } on FirebaseAuthException catch (e) {
      return (false, _authError(e.code));
    } catch (e) {
      return (false, 'Erreur lors de l\'envoi de l\'email.');
    }
  }

  Future<(bool, String)> resendVerificationEmail() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return (false, 'Non connecté.');
      await user.sendEmailVerification();
      return (true, '');
    } on FirebaseAuthException catch (e) {
      return (false, _authError(e.code));
    } catch (e) {
      return (false, 'Erreur lors de l\'envoi.');
    }
  }

  Future<(bool, String)> changePassword({
    String userId = '',
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null || user.email == null) return (false, 'Non connecté.');
      final cred = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(cred);
      await user.updatePassword(newPassword);
      return (true, '');
    } on FirebaseAuthException catch (e) {
      return (false, _authError(e.code));
    } catch (e) {
      return (false, 'Erreur lors du changement de mot de passe.');
    }
  }

  /// Supprime le compte ET toutes les données associées (RGPD / App Store).
  /// Ré-authentifie d'abord avec le mot de passe pour éviter
  /// l'erreur requires-recent-login.
  Future<(bool, String)> deleteAccountFully(
      {required String password}) async {
    try {
      final user = _auth.currentUser;
      if (user == null || user.email == null) return (false, 'Non connecté.');
      final cred = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );
      await user.reauthenticateWithCredential(cred);
      final uid = user.uid;

      await _purgeUserData(uid);

      // Photo de profil
      try {
        await FirebaseStorage.instance
            .ref('profile_photos/$uid.jpg')
            .delete();
      } catch (_) {}

      await _db.collection('users').doc(uid).delete();
      await user.delete();
      return (true, '');
    } on FirebaseAuthException catch (e) {
      return (false, _authError(e.code));
    } catch (e) {
      return (false, 'Erreur lors de la suppression : $e');
    }
  }

  Future<void> _purgeUserData(String uid) async {
    // Matches où l'utilisateur est candidat OU recruteur,
    // avec leurs messages (les messages d'abord : la règle de
    // suppression des messages vérifie le doc match).
    for (final field in ['candidateUserId', 'recruiterUserId']) {
      final matches =
          await _db.collection('matches').where(field, isEqualTo: uid).get();
      for (final match in matches.docs) {
        final msgs = await _db
            .collection('messages')
            .where('matchId', isEqualTo: match.id)
            .get();
        await _deleteInBatches(msgs.docs.map((d) => d.reference).toList());
        await match.reference.delete();
      }
    }

    // Likes envoyés / reçus
    for (final (col, field) in [
      ('candidate_job_likes', 'candidateUserId'),
      ('recruiter_candidate_likes', 'recruiterUserId'),
      ('recruiter_candidate_likes', 'candidateUserId'),
    ]) {
      final q = await _db.collection(col).where(field, isEqualTo: uid).get();
      await _deleteInBatches(q.docs.map((d) => d.reference).toList());
    }

    // Offres du recruteur
    final offers = await _db
        .collection('job_offers')
        .where('recruiterUserId', isEqualTo: uid)
        .get();
    await _deleteInBatches(offers.docs.map((d) => d.reference).toList());

    // Profil candidat
    final profiles = await _db
        .collection('candidate_profiles')
        .where('userId', isEqualTo: uid)
        .get();
    await _deleteInBatches(profiles.docs.map((d) => d.reference).toList());
  }

  Future<void> _deleteInBatches(List<DocumentReference> refs) async {
    // Limite Firestore : 500 opérations par batch
    for (var i = 0; i < refs.length; i += 400) {
      final batch = _db.batch();
      for (final ref in refs.skip(i).take(400)) {
        batch.delete(ref);
      }
      await batch.commit();
    }
  }

  @Deprecated('Utiliser deleteAccountFully (purge les données)')
  Future<void> deleteAccount([String userId = '']) async {
    await _auth.currentUser?.delete();
  }

  Future<void> signOut() => _auth.signOut();

  String _authError(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'Un compte existe déjà avec cet email.';
      case 'invalid-email':
        return 'Email invalide.';
      case 'weak-password':
        return 'Mot de passe trop faible (6 caractères minimum).';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Email ou mot de passe incorrect.';
      case 'too-many-requests':
        return 'Trop de tentatives. Réessayez plus tard.';
      case 'requires-recent-login':
        return 'Reconnectez-vous puis réessayez.';
      default:
        return 'Erreur: $code';
    }
  }
}
