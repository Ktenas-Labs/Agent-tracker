import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

/// Initiates a Google sign-in via Firebase Auth (Google Cloud Identity Platform).
///
/// On web: uses [signInWithPopup] which opens a popup window, completes the
/// sign-in, and returns the [User] directly — no page reload needed.
///
/// On mobile: uses [google_sign_in] to get a credential, then authenticates
/// with Firebase and returns the [User].
Future<User?> signInWithGoogleCloud() async {
  if (kIsWeb) {
    final provider = GoogleAuthProvider()
      ..addScope('email')
      ..addScope('profile');
    final result = await FirebaseAuth.instance.signInWithPopup(provider);
    return result.user;
  }

  // Mobile path (not currently used — app targets web only).
  const oauthClientId =
      '212956760758-h2lofljhearn40h323mps2gqsuqg2o00.apps.googleusercontent.com';
  final googleSignIn = GoogleSignIn(
    clientId: oauthClientId,
    scopes: const ['email', 'profile'],
  );
  final account = await googleSignIn.signIn();
  if (account == null) return null;
  final auth = await account.authentication;
  final credential = GoogleAuthProvider.credential(
    accessToken: auth.accessToken,
    idToken: auth.idToken,
  );
  final result = await FirebaseAuth.instance.signInWithCredential(credential);
  return result.user;
}
