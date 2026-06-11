import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService extends ChangeNotifier {
  final auth.FirebaseAuth _firebaseAuth = auth.FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    // The web client ID for Flutter Web (Chrome/Laptop) - MUST NOT be used on Android natively!
    clientId: kIsWeb ? '692238134417-10mr53pc2a53hgbfovibea9n6httgm4f.apps.googleusercontent.com' : null,
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
  Future<String?> registerWithEmail(String identifier, String password, {String? name}) async {
    try {
      final auth.UserCredential cred = await _firebaseAuth.createUserWithEmailAndPassword(
        email: _formatIdentifier(identifier),
        password: password,
      );
      
      // Update display name
      String displayName = name?.trim() ?? '';
      if (displayName.isEmpty) {
        // Extract from email (e.g., john.doe@email.com -> john doe)
        final emailPart = identifier.split('@').first;
        displayName = emailPart.replaceAll(RegExp(r'[._+\-]'), ' ');
        // Capitalize words
        displayName = displayName.split(' ').map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}' : '').join(' ');
      }
      
      await cred.user?.updateDisplayName(displayName);
      await cred.user?.reload();
      _user = _firebaseAuth.currentUser;
      notifyListeners();
      
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
      print('DEBUG_AUTH: Starting Google Sign In flow');
      // Clear any deadlocked or stuck previous sessions
      if (!kIsWeb) {
        await _googleSignIn.signOut();
      }
      print('DEBUG_AUTH: Waiting for user to select account from popup...');
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        print('DEBUG_AUTH: User aborted sign in');
        return 'Sign in aborted by user';
      }

      print('DEBUG_AUTH: Account selected: ${googleUser.email}');
      print('DEBUG_AUTH: Fetching authentication tokens from Google Play Services...');
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      print('DEBUG_AUTH: Tokens received! idToken: ${googleAuth.idToken != null}, accessToken: ${googleAuth.accessToken != null}');
      final auth.OAuthCredential credential = auth.GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
        // Omit accessToken because it causes native deadlocks on some Android ROMs (like Xiaomi)
      );

      print('DEBUG_AUTH: Sending credentials to Firebase Auth...');
      await _firebaseAuth.signInWithCredential(credential).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw Exception('Connection to Firebase timed out. Please disable any Ad-Blockers, Private DNS, or VPNs, and check your internet.'),
      );
      
      print('DEBUG_AUTH: Firebase sign in successful!');
      return null;
    } on auth.FirebaseAuthException catch (e) {
      print('DEBUG_AUTH: FirebaseAuthException caught: ${e.message}');
      return e.message;
    } catch (e) {
      print('DEBUG_AUTH: Unknown Exception caught: $e');
      return e.toString().replaceAll('Exception: ', '');
    }
  }

  // Logout
  Future<void> logout() async {
    if (!kIsWeb) {
      await _googleSignIn.signOut();
    }
    await _firebaseAuth.signOut();
    _user = null;
    notifyListeners();
  }

  // Delete Account
  Future<String?> deleteAccount() async {
    try {
      final currentUser = _firebaseAuth.currentUser;
      if (currentUser != null) {
        await currentUser.delete();
        _user = null;
        if (!kIsWeb) await _googleSignIn.signOut();
        notifyListeners();
      }
      return null;
    } on auth.FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        return 'Please log out and log back in to verify your identity before deleting.';
      }
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }
}
