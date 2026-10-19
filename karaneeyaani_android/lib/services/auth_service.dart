import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'pin_auth_service.dart';
import 'supabase_service.dart';

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
        _user = null;
      }
    }
    notifyListeners();
  }

  Future<void> _saveUser() async {
    if (_user == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(_user!.toMap()));
  }

  static bool isValidUsername(String username) {
    return RegExp(r'^[a-zA-Z0-9_]{3,20}$').hasMatch(username.trim());
  }

  static bool isValidPin(String pin) {
    return RegExp(r'^\d{6}$').hasMatch(pin.trim());
  }

  /// First-time sign in or registration with Username & 6-digit PIN against Supabase `users_auth` table
  Future<String?> authenticateOrRegisterWithUsername({
    required String username,
    required String pin,
    required PinAuthService pinAuth,
  }) async {
    final cleanUsername = username.trim();
    if (!isValidUsername(cleanUsername)) {
      return 'Username must be 3-20 alphanumeric characters or underscores.';
    }
    if (!isValidPin(pin)) {
      return 'PIN must be exactly 6 digits.';
    }

    final hasInternet = await SupabaseService.hasInternetConnection();
    if (!hasInternet) {
      return 'Active internet connection is required for account authentication.';
    }

    final client = SupabaseService.client;
    final normUser = cleanUsername.toLowerCase();
    final pinHash = PinAuthService.hashPin(normUser, pin);

    try {
      if (client != null) {
        final record = await client
            .from('users_auth')
            .select()
            .eq('username', normUser)
            .maybeSingle();

        if (record != null) {
          final remoteHash = record['pin_hash'] as String?;
          if (remoteHash != pinHash) {
            return 'Incorrect PIN for user "$cleanUsername".';
          }
          final uid = record['user_id'] as String? ?? record['id'] as String;
          _user = LocalUser(
            uid: uid,
            displayName: cleanUsername,
            email: '$normUser@karaneeyaani.auth',
          );
          await _saveUser();
          await pinAuth.saveCredentials(
            username: cleanUsername,
            pin: pin,
            userId: uid,
          );
          notifyListeners();
          return null;
        } else {
          // Register new user profile in users_auth
          final newUid = const Uuid().v4();
          await client.from('users_auth').insert({
            'user_id': newUid,
            'username': normUser,
            'pin_hash': pinHash,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          });
          _user = LocalUser(
            uid: newUid,
            displayName: cleanUsername,
            email: '$normUser@karaneeyaani.auth',
          );
          await _saveUser();
          await pinAuth.saveCredentials(
            username: cleanUsername,
            pin: pin,
            userId: newUid,
          );
          notifyListeners();
          return null;
        }
      } else {
        // Fallback for local mock/offline development mode
        final uid = const Uuid().v4();
        _user = LocalUser(
          uid: uid,
          displayName: cleanUsername,
          email: '$normUser@karaneeyaani.local',
        );
        await _saveUser();
        await pinAuth.saveCredentials(
          username: cleanUsername,
          pin: pin,
          userId: uid,
        );
        notifyListeners();
        return null;
      }
    } catch (e) {
      debugPrint('Supabase users_auth auth error: $e');
      return 'Authentication failed: $e';
    }
  }

  /// Switch account / Sign out requiring Username and 6-digit PIN verified against Supabase
  Future<String?> switchAccount({
    required String username,
    required String pin,
    required PinAuthService pinAuth,
  }) async {
    return authenticateOrRegisterWithUsername(
      username: username,
      pin: pin,
      pinAuth: pinAuth,
    );
  }

  /// Ensure an authenticated session exists for local execution
  Future<String?> ensureAuthenticatedUser() async {
    if (_user == null) {
      final prefs = await SharedPreferences.getInstance();
      final cachedUid = prefs.getString('cached_user_id') ?? 'local_user';
      final cachedName = prefs.getString('cached_username') ?? 'Flow User';
      _user = LocalUser(
        uid: cachedUid,
        displayName: cachedName,
        email: '$cachedName@karaneeyaani.local',
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
