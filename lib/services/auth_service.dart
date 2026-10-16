import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class LocalUser {
  final String uid;
  final String? email;
  final String? displayName;

  LocalUser({
    required this.uid,
    this.email,
    this.displayName,
  });

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'email': email,
        'displayName': displayName,
      };

  factory LocalUser.fromMap(Map<String, dynamic> map) => LocalUser(
        uid: map['uid'] ?? 'local_user',
        email: map['email'],
        displayName: map['displayName'],
      );
}

class AuthService extends ChangeNotifier {
  static const String _userKey = 'current_local_user';
  LocalUser? _user;
  LocalUser? get user => _user;

  AuthService() {
    _loadUser();
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_userKey);
    if (raw != null) {
      try {
        _user = LocalUser.fromMap(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {
        _user = LocalUser(
          uid: 'local_user',
          displayName: 'Flow User',
          email: 'user@karaneeyaani.local',
        );
      }
    } else {
      _user = LocalUser(
        uid: 'local_user',
        displayName: 'Flow User',
        email: 'user@karaneeyaani.local',
      );
      await _saveUser();
    }
    notifyListeners();
  }

  Future<void> _saveUser() async {
    if (_user == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(_user!.toMap()));
  }

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
    String displayName = name?.trim() ?? '';
    if (displayName.isEmpty) {
      final emailPart = identifier.split('@').first;
      displayName = emailPart.replaceAll(RegExp(r'[._+\-]'), ' ');
      displayName = displayName
          .split(' ')
          .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}' : '')
          .join(' ');
    }

    _user = LocalUser(
      uid: const Uuid().v4(),
      email: _formatIdentifier(identifier),
      displayName: displayName.isNotEmpty ? displayName : 'Flow User',
    );
    await _saveUser();
    notifyListeners();
    return null;
  }

  // Login with Email or Phone
  Future<String?> loginWithEmail(String identifier, String password) async {
    final emailPart = identifier.split('@').first;
    var displayName = emailPart.replaceAll(RegExp(r'[._+\-]'), ' ');
    displayName = displayName
        .split(' ')
        .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}' : '')
        .join(' ');

    _user = LocalUser(
      uid: _user?.uid ?? const Uuid().v4(),
      email: _formatIdentifier(identifier),
      displayName: displayName.isNotEmpty ? displayName : 'Flow User',
    );
    await _saveUser();
    notifyListeners();
    return null;
  }

  // Anonymous Login for Testing
  Future<String?> signInAnonymously() async {
    _user = LocalUser(
      uid: 'local_user',
      displayName: 'Guest User',
      email: 'guest@karaneeyaani.local',
    );
    await _saveUser();
    notifyListeners();
    return null;
  }

  // Ensure an authenticated session exists
  Future<String?> ensureAuthenticatedUser() async {
    if (_user == null) {
      _user = LocalUser(
        uid: 'local_user',
        displayName: 'Flow User',
        email: 'user@karaneeyaani.local',
      );
      await _saveUser();
      notifyListeners();
    }
    return null;
  }

  // Logout
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
    _user = null;
    notifyListeners();
  }

  // Delete Account
  Future<String?> deleteAccount() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
    _user = null;
    notifyListeners();
    return null;
  }
}
