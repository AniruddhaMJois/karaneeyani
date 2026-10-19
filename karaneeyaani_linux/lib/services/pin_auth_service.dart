import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'storage_service.dart';
import 'supabase_sync_service.dart';

class PinAuthService extends ChangeNotifier {
  static const String _isLoggedInKey = 'user_is_logged_in';
  static const String _usernameKey = 'cached_username';
  static const String _userIdKey = 'cached_user_id';
  static const String _pinHashKey = 'user_6digit_pin_hash';

  final StorageService _storage;

  bool _isAuthenticated = false;
  String _userName = '';
  String _userId = '';
  String _pinHash = '';
  bool _isPinSet = false;
  bool _isLocked = true;
  bool _isInitialized = false;

  bool get isAuthenticated => _isAuthenticated;
  String get userName => _userName;
  String get userId => _userId;
  bool get hasName => _userName.trim().isNotEmpty;
  bool get isPinSet => _isPinSet;
  bool get isLocked => _isLocked;
  bool get isInitialized => _isInitialized;

  PinAuthService({StorageService? storage}) : _storage = storage ?? StorageService() {
    init();
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _userName = prefs.getString(_usernameKey) ?? '';
    _userId = prefs.getString(_userIdKey) ?? '';
    _pinHash = prefs.getString(_pinHashKey) ?? '';

    // If SharedPreferences was cleared or fresh, try reading XDG local storage
    if (_userName.isEmpty || _pinHash.isEmpty) {
      final xdgAuth = await _storage.loadAuthData();
      if (xdgAuth != null) {
        _userName = xdgAuth['username'] ?? '';
        _userId = xdgAuth['userId'] ?? '';
        _pinHash = xdgAuth['pinHash'] ?? '';
        if (_userName.isNotEmpty && _pinHash.isNotEmpty) {
          await prefs.setBool(_isLoggedInKey, true);
          await prefs.setString(_usernameKey, _userName);
          await prefs.setString(_userIdKey, _userId);
          await prefs.setString(_pinHashKey, _pinHash);
        }
      }
    }

    _isPinSet = _pinHash.isNotEmpty;
    _isAuthenticated = _isPinSet && _userName.isNotEmpty;
    // Compulsory lock on app launch if PIN is configured
    _isLocked = _isPinSet;
    _isInitialized = true;
    notifyListeners();
  }

  /// Salted SHA-256 PIN hash
  static String hashPin(String username, String pin) {
    final cleanUser = username.trim().toLowerCase();
    final salt = 'karaneeyaani_salt_$cleanUser';
    final bytes = utf8.encode('$salt:$pin');
    return sha256.convert(bytes).toString();
  }

  static bool isValidUsername(String username) {
    return RegExp(r'^[a-zA-Z0-9_]{3,20}$').hasMatch(username.trim());
  }

  static bool isValidPin(String pin) {
    return RegExp(r'^\d{6}$').hasMatch(pin.trim());
  }

  Future<void> _saveSession({
    required String username,
    required String userId,
    required String pinHash,
  }) async {
    _userName = username.trim();
    _userId = userId;
    _pinHash = pinHash;
    _isPinSet = true;
    _isAuthenticated = true;
    _isLocked = false;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isLoggedInKey, true);
    await prefs.setString(_usernameKey, _userName);
    await prefs.setString(_userIdKey, _userId);
    await prefs.setString(_pinHashKey, _pinHash);

    // Also persist in XDG local storage directory (~/.local/share/karaneeyaani/)
    await _storage.saveAuthData(
      username: _userName,
      userId: _userId,
      pinHash: _pinHash,
    );

    notifyListeners();
  }

  /// First-time login / registration against Supabase `users_auth` table
  Future<String?> authenticateOrRegisterWithUsername({
    required String username,
    required String pin,
  }) async {
    final cleanUsername = username.trim();
    if (!isValidUsername(cleanUsername)) {
      return 'Username must be 3-20 characters (letters, numbers, or underscores).';
    }
    if (!isValidPin(pin)) {
      return 'PIN must be exactly 6 numeric digits.';
    }

    final hasInternet = await SupabaseSyncService.hasInternetConnection();
    if (!hasInternet) {
      return 'Active internet connection is required for account authentication.';
    }

    final sc = SupabaseSyncService.client;
    final normUser = cleanUsername.toLowerCase();
    final computedHash = hashPin(normUser, pin);

    try {
      if (sc != null) {
        final record = await sc
            .from('users_auth')
            .select()
            .eq('username', normUser)
            .maybeSingle();

        if (record != null) {
          final remoteHash = record['pin_hash'] as String?;
          if (remoteHash != computedHash) {
            return 'Incorrect PIN for user "$cleanUsername".';
          }
          final uid = record['user_id'] as String? ?? record['id'] as String;
          await _saveSession(username: cleanUsername, userId: uid, pinHash: computedHash);
          return null;
        } else {
          // Register new user profile in users_auth
          final newUid = const Uuid().v4();
          await sc.from('users_auth').insert({
            'user_id': newUid,
            'username': normUser,
            'pin_hash': computedHash,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          });
          await _saveSession(username: cleanUsername, userId: newUid, pinHash: computedHash);
          return null;
        }
      } else {
        // Offline / mock fallback if Supabase client not available
        final newUid = const Uuid().v4();
        await _saveSession(username: cleanUsername, userId: newUid, pinHash: computedHash);
        return null;
      }
    } catch (e) {
      debugPrint('Supabase users_auth auth error: $e');
      return 'Authentication failed: $e';
    }
  }

  /// Subsequent unlock (0ms latency, zero internet required)
  Future<bool> verifyPin(String pin) async {
    if (pin.length != 6) return false;
    if (_pinHash.isEmpty || _userName.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      _userName = prefs.getString(_usernameKey) ?? _userName;
      _pinHash = prefs.getString(_pinHashKey) ?? _pinHash;
    }
    if (_pinHash.isEmpty) return false;

    final expectedHash = hashPin(_userName, pin);
    if (expectedHash == _pinHash) {
      _isLocked = false;
      notifyListeners();
      return true;
    }
    return false;
  }

  /// Change 6-digit PIN locally and in Supabase
  Future<bool> changePin(String oldPin, String newPin) async {
    if (!isValidPin(newPin)) return false;
    final valid = await verifyPin(oldPin);
    if (!valid) return false;

    final newHash = hashPin(_userName, newPin);
    _pinHash = newHash;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pinHashKey, newHash);
    await _storage.saveAuthData(
      username: _userName,
      userId: _userId,
      pinHash: newHash,
    );

    // If online, update remote hash
    final sc = SupabaseSyncService.client;
    if (sc != null) {
      try {
        final normUser = _userName.toLowerCase();
        await sc.from('users_auth').update({
          'pin_hash': newHash,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('username', normUser);
      } catch (e) {
        debugPrint('Could not update remote PIN: $e');
      }
    }

    notifyListeners();
    return true;
  }

  /// Sign out & switch account (requires internet verification)
  Future<String?> switchAccount({
    required String username,
    required String pin,
  }) async {
    return authenticateOrRegisterWithUsername(username: username, pin: pin);
  }

  void lock() {
    _isLocked = true;
    notifyListeners();
  }

  void unlock() {
    _isLocked = false;
    notifyListeners();
  }

  Future<void> logout() async {
    _isAuthenticated = false;
    _isLocked = true;
    _pinHash = '';
    _userName = '';
    _userId = '';
    _isPinSet = false;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_isLoggedInKey);
    await prefs.remove(_usernameKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_pinHashKey);

    await _storage.clearAuthData();
    notifyListeners();
  }
}
