import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Sign in with Google via Firebase Auth (Google Cloud Identity Platform).
Future<User?> signInWithGoogleCloud() async {
  final googleSignIn = GoogleSignIn(scopes: const ['email', 'profile']);
  final account = await googleSignIn.signIn();
  if (account == null) {
    return null;
  }
  final auth = await account.authentication;
  final credential = GoogleAuthProvider.credential(
    accessToken: auth.accessToken,
    idToken: auth.idToken,
  );
  final result = await FirebaseAuth.instance.signInWithCredential(credential);
  return result.user;
}
