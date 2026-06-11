import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService extends ChangeNotifier {
  final auth.FirebaseAuth _firebaseAuth = auth.FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    // The web client ID for Flutter Web (Chrome/Laptop)
    clientId: '692238134417-10mr53pc2a53hgbfovibea9n6httgm4f.apps.googleusercontent.com',
    // The web client ID from google-services.json (client_type: 3)
    // This is explicitly required on many Android devices to mint the Firebase idToken.
    serverClientId: '692238134417-10mr53pc2a53hgbfovibea9n6httgm4f.apps.googleusercontent.com',
  );

  auth.User? _user;
  auth.User? get user => _user;

  AuthService() {
    _firebaseAuth.authStateChanges().listen((auth.User? user) {
      _user = user;
      notifyListeners();
    });
  }

  // Helper to format identifier: if it's purely numbers (or + and numbers), it's a phone.
  String _formatIdentifier(String input) {
    final cleanInput = input.trim();
    final isPhone = RegExp(r'^\+?[0-9]{7,15}$').hasMatch(cleanInput);
    if (isPhone) {
      return '$cleanInput@karaneeyaani.phone';
    }
    return cleanInput;
  }

  // Register with Email or Phone
  Future<String?> registerWithEmail(String identifier, String password) async {
    try {
      await _firebaseAuth.createUserWithEmailAndPassword(
        email: _formatIdentifier(identifier),
        password: password,
      );
      return null;
    } on auth.FirebaseAuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  // Login with Email or Phone
  Future<String?> loginWithEmail(String identifier, String password) async {
    try {
      await _firebaseAuth.signInWithEmailAndPassword(
        email: _formatIdentifier(identifier),
        password: password,
      );
      return null;
    } on auth.FirebaseAuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  // Google Sign-In
  Future<String?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return 'Sign in aborted by user';
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final auth.OAuthCredential credential = auth.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await _firebaseAuth.signInWithCredential(credential);
      return null;
    } on auth.FirebaseAuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  // Logout
  Future<void> logout() async {
    await _googleSignIn.signOut();
    await _firebaseAuth.signOut();
  }
}
