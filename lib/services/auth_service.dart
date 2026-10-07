import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:flutter/foundation.dart';

class AuthService extends ChangeNotifier {
  final auth.FirebaseAuth _firebaseAuth = auth.FirebaseAuth.instance;

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

  // Anonymous Login for Testing
  Future<String?> signInAnonymously() async {
    try {
      await _firebaseAuth.signInAnonymously();
      return null;
    } on auth.FirebaseAuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  // Ensure an authenticated session exists (anonymous if no account signed in)
  Future<String?> ensureAuthenticatedUser() async {
    try {
      if (_firebaseAuth.currentUser == null) {
        await _firebaseAuth.signInAnonymously();
      }
      _user = _firebaseAuth.currentUser;
      notifyListeners();
      return null;
    } on auth.FirebaseAuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  // Logout
  Future<void> logout() async {
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
