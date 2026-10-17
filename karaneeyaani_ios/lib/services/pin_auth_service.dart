import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PinAuthService extends ChangeNotifier {
  static const String _pinHashKey = 'app_pin_hash';
  static const String _biometricsEnabledKey = 'biometrics_enabled';

  final LocalAuthentication _localAuth = LocalAuthentication();

  bool _isPinSet = false;
  bool _isBiometricsEnabled = false;
  bool _isInitialized = false;

  bool get isPinSet => _isPinSet;
  bool get isBiometricsEnabled => _isBiometricsEnabled;
  bool get isInitialized => _isInitialized;

  PinAuthService() {
    init();
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _isPinSet = prefs.containsKey(_pinHashKey);
    _isBiometricsEnabled = prefs.getBool(_biometricsEnabledKey) ?? false;
    _isInitialized = true;
    notifyListeners();
  }

  /// Hash the 6-digit PIN using SHA-256
  String _hashPin(String pin) {
    final bytes = utf8.encode(pin);
    return sha256.convert(bytes).toString();
  }

  /// Check if a PIN is set on this device
  Future<bool> checkIsPinSet() async {
    final prefs = await SharedPreferences.getInstance();
    _isPinSet = prefs.containsKey(_pinHashKey);
    return _isPinSet;
  }

  /// Set and save a new 6-digit PIN
  Future<bool> setPin(String pin) async {
    if (pin.length != 6 || !RegExp(r'^\d{6}$').hasMatch(pin)) {
      return false;
    }
    final prefs = await SharedPreferences.getInstance();
    final hashed = _hashPin(pin);
    await prefs.setString(_pinHashKey, hashed);
    _isPinSet = true;
    notifyListeners();
    return true;
  }

  /// Verify entered PIN against stored hash
  Future<bool> verifyPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final storedHash = prefs.getString(_pinHashKey);
    if (storedHash == null) return false;
    return storedHash == _hashPin(pin);
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

  /// Reset PIN and biometric settings
  Future<void> resetAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pinHashKey);
    await prefs.remove(_biometricsEnabledKey);
    _isPinSet = false;
    _isBiometricsEnabled = false;
    notifyListeners();
  }
}
