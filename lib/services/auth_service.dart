import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/official_accounts.dart';
import '../core/student_progress.dart';
import 'official_office_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();
  Stream<User?> get idTokenChanges => _auth.idTokenChanges();

  static bool isRegentEmail(String email) {
    return RegExp(r'^[^@\s]+@regent\.edu\.gh$', caseSensitive: false)
        .hasMatch(email.trim());
  }

  Future<void> syncCurrentUserBackend() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final officialAccount = OfficialAccounts.byEmail(user.email);
      if (officialAccount != null) {
        await OfficialOfficeService(
          auth: _auth,
          firestore: _firestore,
        ).syncCurrentOfficerBackend();
        return;
      }

      final userReference = _firestore.collection('users').doc(user.uid);
      final existingUser = await userReference.get();
      final existingData = existingUser.data() ?? <String, dynamic>{};
      final displayName = existingData['displayName'] ??
          existingData['fullName'] ??
          user.displayName ??
          user.email ??
          'Regent student';
      final level = int.tryParse(existingData['level']?.toString() ?? '');
      final graduationMetadata = StudentProgress.isAlumniProfile(existingData)
          ? {
              'isAlumni': true,
              'graduationStatus': 'completed',
              'studyYearsRemaining': 0,
            }
          : StudentProgress.graduationMetadataForLevel(level);

      await userReference.set({
        'uid': user.uid,
        'email': user.email,
        'displayName': displayName,
        'fullName': existingData['fullName'] ?? displayName,
        if (existingData['session'] != null) 'session': existingData['session'],
        if (existingData['level'] != null) 'level': existingData['level'],
        if (existingData['program'] != null) 'program': existingData['program'],
        ...graduationMetadata,
        if (existingData['graduationDate'] != null)
          'graduationDate': existingData['graduationDate'],
        if (existingData['completionDate'] != null)
          'completionDate': existingData['completionDate'],
        'role': 'student',
        'isOfficial': false,
        'officialAccountId': null,
        'chatIdentity': user.uid,
        'emailVerified': user.emailVerified,
        'isOnline': true,
        'lastSeen': FieldValue.serverTimestamp(),
        if (!existingUser.exists) 'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (error) {
      print('User profile sync deferred: $error');
    }
  }

  // Sign up with email and password
  Future<User?> signUp({
    required String email,
    required String password,
    required String displayName,
    required String program,
    required int level,
    required String role,
    required String stream,
    required String session,
  }) async {
    try {
      final normalizedEmail = email.trim().toLowerCase();
      if (!isRegentEmail(normalizedEmail)) {
        throw Exception(
          'Use your Regent University email address ending in @regent.edu.gh.',
        );
      }
      if (OfficialAccounts.byEmail(normalizedEmail) != null) {
        throw Exception(
          'Official office accounts are activated by the Regent Connect administrator. Use Officer access on the sign-in page.',
        );
      }

      final credential = await _auth.createUserWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );

      final user = credential.user;
      if (user != null) {
        final resolvedDisplayName = displayName.trim();
        try {
          await user.updateDisplayName(resolvedDisplayName);
        } catch (error) {
          print('Could not update display name: $error');
        }
        try {
          await user.sendEmailVerification();
        } catch (error) {
          print('Could not send verification email: $error');
        }

        // Save user data to Firestore
        try {
          await _firestore.collection('users').doc(user.uid).set({
            'uid': user.uid,
            'email': normalizedEmail,
            'displayName': resolvedDisplayName,
            'fullName': resolvedDisplayName,
            'program': program,
            'level': level,
            'role': 'student',
            'stream': stream,
            'session': session,
            ...StudentProgress.graduationMetadataForLevel(level),
            'about': 'Hey there! I\'m using Regent Connect',
            'isOfficial': false,
            'officialAccountId': null,
            'chatIdentity': user.uid,
            'emailVerified': false,
            'createdAt': FieldValue.serverTimestamp(),
            'isOnline': true,
            'lastSeen': FieldValue.serverTimestamp(),
            'showOnlineStatus': true,
            'readReceipts': true,
            'pushNotifications': true,
          });
        } catch (error) {
          print('Could not save student profile yet: $error');
        }
      }

      return user;
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('An error occurred: $e');
    }
  }

  // Sign in with email and password
  Future<User?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final normalizedEmail = email.trim().toLowerCase();
      if (!isRegentEmail(normalizedEmail)) {
        throw Exception(
          'Only registered Regent University accounts ending in @regent.edu.gh can sign in.',
        );
      }
      final officialAccount = OfficialAccounts.byEmail(normalizedEmail);

      UserCredential credential;
      try {
        credential = await _auth.signInWithEmailAndPassword(
          email: normalizedEmail,
          password: password,
        );
      } on FirebaseAuthException catch (_) {
        if (officialAccount == null) {
          rethrow;
        }
        throw FirebaseAuthException(
          code: 'official-account-not-activated',
          message:
              'This official account has not been activated. Ask the Regent Connect administrator to provision the HoD inbox first.',
        );
      }

      // Update online status
      if (credential.user != null) {
        final user = credential.user!;
        try {
          await user.reload();
        } catch (error) {
          print('Could not refresh sign-in user: $error');
        }
        final refreshedUser = _auth.currentUser ?? user;
        final currentOfficialAccount =
            OfficialAccounts.byEmail(refreshedUser.email);

        if (currentOfficialAccount != null) {
          final officeService = OfficialOfficeService(
            auth: _auth,
            firestore: _firestore,
          );
          try {
            await refreshedUser.updateDisplayName(currentOfficialAccount.name);
          } catch (error) {
            print('Could not update officer display name: $error');
          }
          try {
            await officeService.syncCurrentOfficerBackend();
          } catch (error) {
            print('Officer sync deferred: $error');
          }
          return refreshedUser;
        }

        await syncCurrentUserBackend();
      }

      return credential.user;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' ||
          e.code == 'invalid-credential' ||
          e.code == 'invalid-login-credentials') {
        throw Exception(
          'No account exists for this email. Create an account first, then sign in.',
        );
      }
      throw Exception(e.message);
    } catch (e) {
      throw Exception('An error occurred: $e');
    }
  }

  // Sign out
  Future<void> signOut() async {
    final user = _auth.currentUser;
    try {
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).update({
          'isOnline': false,
          'lastSeen': FieldValue.serverTimestamp(),
        });
      }
    } on FirebaseException {
      // Authentication must still end if the profile is missing or restricted.
    } finally {
      await _auth.signOut();
    }
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (!isRegentEmail(normalizedEmail)) {
      throw Exception(
        'Password reset is available only for @regent.edu.gh accounts.',
      );
    }
    await _auth.sendPasswordResetEmail(email: normalizedEmail);
  }

  Future<void> resendVerificationEmail() async {
    final user = _auth.currentUser;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }
  }
}
