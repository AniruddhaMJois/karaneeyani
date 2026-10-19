import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PinAuthService extends ChangeNotifier {
  static const String _pinHashKey = 'app_pin_hash';
  static const String _usernameKey = 'cached_username';
  static const String _userIdKey = 'cached_user_id';
  static const String _biometricsEnabledKey = 'biometrics_enabled';

  final LocalAuthentication _localAuth = LocalAuthentication();

  bool _isPinSet = false;
  bool _isBiometricsEnabled = false;
  bool _isInitialized = false;
  String? _username;
  String? _userId;

  bool get isPinSet => _isPinSet;
  bool get isBiometricsEnabled => _isBiometricsEnabled;
  bool get isInitialized => _isInitialized;
  String? get username => _username;
  String? get userId => _userId;

  PinAuthService() {
    init();
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _isPinSet = prefs.containsKey(_pinHashKey);
    _username = prefs.getString(_usernameKey);
    _userId = prefs.getString(_userIdKey);
    _isBiometricsEnabled = prefs.getBool(_biometricsEnabledKey) ?? false;
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

  /// Check if a PIN is set on this device
  Future<bool> checkIsPinSet() async {
    final prefs = await SharedPreferences.getInstance();
    _isPinSet = prefs.containsKey(_pinHashKey);
    _username = prefs.getString(_usernameKey);
    _userId = prefs.getString(_userIdKey);
    return _isPinSet;
  }

  /// Save credentials locally with salted SHA-256 PIN hash
  Future<bool> saveCredentials({
    required String username,
    required String pin,
    required String userId,
  }) async {
    if (pin.length != 6 || !RegExp(r'^\d{6}$').hasMatch(pin)) {
      return false;
    }
    final prefs = await SharedPreferences.getInstance();
    final cleanUser = username.trim();
    final hashed = hashPin(cleanUser, pin);

    await prefs.setString(_pinHashKey, hashed);
    await prefs.setString(_usernameKey, cleanUser);
    await prefs.setString(_userIdKey, userId);

    _isPinSet = true;
    _username = cleanUser;
    _userId = userId;
    notifyListeners();
    return true;
  }

  /// Update PIN for currently authenticated user
  Future<bool> setPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final user = prefs.getString(_usernameKey) ?? _username ?? 'user';
    final uid = prefs.getString(_userIdKey) ?? _userId ?? 'local_user';
    return saveCredentials(username: user, pin: pin, userId: uid);
  }

  /// Verify entered PIN locally with 0ms latency against cached salted hash
  Future<bool> verifyPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final storedHash = prefs.getString(_pinHashKey);
    final user = prefs.getString(_usernameKey) ?? _username ?? '';
    if (storedHash == null) return false;
    return storedHash == hashPin(user, pin);
  }

  /// Check if the device hardware supports biometrics
  Future<bool> isBiometricsSupported() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      return canCheck || isSupported;
    } on PlatformException catch (e) {
      debugPrint('Biometrics support check error: $e');
      return false;
    } catch (e) {
      debugPrint('Biometrics support check error: $e');
      return false;
    }
  }

  /// Set biometric authentication toggle preference
  Future<void> setBiometricsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_biometricsEnabledKey, enabled);
    _isBiometricsEnabled = enabled;
    notifyListeners();
  }

  /// Prompt biometric authentication (Fingerprint / Face ID)
  Future<bool> authenticateWithBiometrics({
    String reason = 'Authenticate to access Karaneeyaani',
  }) async {
    try {
      final supported = await isBiometricsSupported();
      if (!supported) return false;

      return await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
    } on PlatformException catch (e) {
      debugPrint('Biometrics authentication error: $e');
      return false;
    } catch (e) {
      debugPrint('Biometrics authentication error: $e');
      return false;
    }
  }

  /// Reset PIN, cached account and biometric settings
  Future<void> resetAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pinHashKey);
    await prefs.remove(_usernameKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_biometricsEnabledKey);
    _isPinSet = false;
    _username = null;
    _userId = null;
    _isBiometricsEnabled = false;
    notifyListeners();
  }
}
